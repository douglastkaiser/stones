import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_room_store.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'match_controller_test.dart' as fixtures;

// Deliberately permits late callbacks after cancellation, like a queued SDK
// callback crossing a reconnect. Only cancel is used by the controller.
class ManualSubscription implements StreamSubscription<MatchRoomUpdate> {
  bool cancelled = false;
  Completer<void>? cancellation;
  Object? cancellationError;
  @override
  Future<void> cancel() async {
    cancelled = true;
    if (cancellationError != null) throw cancellationError!;
    await cancellation?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ManualWatch extends Stream<MatchRoomUpdate> {
  final subscription = ManualSubscription();
  void Function(MatchRoomUpdate)? data;
  Function? error;
  void Function()? done;
  @override
  StreamSubscription<MatchRoomUpdate> listen(
      void Function(MatchRoomUpdate)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    data = onData;
    error = onError;
    done = onDone;
    return subscription;
  }
}

class UnreliableStore extends fixtures.MemoryMatchRoomStore {
  final watches = <ManualWatch>[];
  Object? readFailure;
  Object? watchFailure;
  bool lostAcknowledgement = false;
  int reads = 0;
  int submissions = 0;
  @override
  Future<MatchRoom> claimRunner(String code, String uid) async {
    final claimed = await super.claimRunner(code, uid);
    broadcast();
    return claimed;
  }
  @override
  Stream<MatchRoomUpdate> watch(String code) {
    if (watchFailure != null) throw watchFailure!;
    final channel = ManualWatch();
    watches.add(channel);
    return channel;
  }

  @override
  Future<MatchRoom> read(String code) async {
    reads++;
    if (readFailure != null) throw readFailure!;
    final snapshot = await super.read(code);
    return MatchRoom.fromMap(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(snapshot.toMap()))));
  }

  void broadcast() {
    for (final watch in List<ManualWatch>.of(watches)) {
      watch.data?.call(MatchRoomUpdate(room));
    }
  }

  @override
  Future<void> submit(
      String code, String uid, int expectedPly, MatchMove move) async {
    submissions++;
    // Both devices can enter before either transaction confirms its turn.
    await Future<void>.delayed(Duration.zero);
    await super.submit(code, uid, expectedPly, move);
    if (lostAcknowledgement) throw TimeoutException('Acknowledgement lost');
    broadcast();
  }
}

const retryDelays = [
  Duration(milliseconds: 5),
  Duration(milliseconds: 10),
  Duration(milliseconds: 20)
];

MatchConfig onlineConfig(BoardShape shape, [int count = 2]) => MatchConfig(
    shape: shape,
    size: shape == BoardShape.square ? 5 : 2,
    seats: List.generate(count, (i) => SeatConfig(SeatId.values[i],
        control: i == 0 ? SeatControl.localHuman : SeatControl.onlineHuman)));

MatchController player(UnreliableStore store, String uid,
        {Future<String> Function()? authenticate}) =>
    MatchController(
        storage: fixtures.MemoryMatchStorage(),
        authenticate: authenticate ?? () async => uid,
        store: () => store,
        networkTimeout: const Duration(milliseconds: 50),
        recoveryDelays: retryDelays);

Future<void> until(bool Function() condition) async {
  for (var attempt = 0; attempt < 150 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

Future<MatchController> ready(UnreliableStore store,
    {Future<String> Function()? authenticate}) async {
  await store.create('host', onlineConfig(BoardShape.square));
  await store.join('UABCDEF', 'guest');
  final host = player(store, 'host', authenticate: authenticate);
  await host.join('UABCDEF', expectedUid: 'host');
  return host;
}

void main() {
  test('transient loss recovers automatically from confirmed server state',
      () async {
    final store = UnreliableStore();
    final host = await ready(store);
    final original = host.state.game;
    final before = store.reads;
    store.watches.last.data?.call(
        const MatchRoomUpdate(null, confirmed: false, connected: false));
    expect(host.state.canPlay, isFalse);
    await until(() => host.state.connected && store.reads > before);
    expect(host.state.game!.board, original!.board);
    expect(host.state.canPlay, isTrue);
    expect(store.submissions, 0);
    host.dispose();
    await store.updates.close();
  });

  test('overlapping reconnects share one read and one new subscription',
      () async {
    final store = UnreliableStore();
    final host = await ready(store);
    final before = store.reads;
    store.pendingRead = Completer<MatchRoom>();
    final attempts = List.generate(12, (_) => host.reconnect());
    await Future<void>.delayed(Duration.zero);
    expect(store.reads, before + 1);
    expect(host.state.reconnecting, isTrue);
    store.pendingRead!.complete(store.room!);
    expect(await Future.wait(attempts), everyElement(isTrue));
    expect(store.watches.length, 2);
    expect(host.state.reconnecting, isFalse);
    host.dispose();
    await store.updates.close();
  });

  for (final hangs in [false, true]) {
    test('failed subscription cleanup cannot block reconnect (hang=$hangs)',
        () async {
      final store = UnreliableStore();
      final host = await ready(store);
      final old = store.watches.single;
      if (hangs) {
        old.subscription.cancellation = Completer<void>();
      } else {
        old.subscription.cancellationError = StateError('Cleanup failed');
      }
      expect(await host.reconnect(), isTrue);
      old.error?.call(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
      old.done?.call();
      old.data?.call(const MatchRoomUpdate(null, confirmed: false, connected: false));
      expect(host.state.connected, isTrue);
      expect(host.state.error, isNull);
      expect(store.watches.length, 2);
      old.subscription.cancellation?.complete();
      host.dispose();
      await store.updates.close();
    });
  }

  test('automatic retries are bounded and manual recovery remains available',
      () async {
    final store = UnreliableStore();
    final host = await ready(store);
    final before = store.reads;
    store.readFailure = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    store.watches.last.error?.call(store.readFailure!);
    await until(() => store.reads == before + retryDelays.length && !host.state.busy);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(store.reads, before + retryDelays.length);
    expect(host.state.connected, isFalse);
    store.readFailure = null;
    expect(await host.reconnect(), isTrue);
    expect(host.state.canPlay, isTrue);
    host.dispose();
    await store.updates.close();
  });

  test('access denial is never treated as a transient transport error', () async {
    final store = UnreliableStore();
    final host = await ready(store);
    final before = store.reads;
    store.watches.last.error?.call(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(store.reads, before);
    expect(host.state.connected, isFalse);
    expect(host.state.game!.ply, 0);
    host.dispose();
    await store.updates.close();
  });

  test('silent subscription completion triggers authoritative recovery', () async {
    final store = UnreliableStore();
    final host = await ready(store);
    store.watches.last.done?.call();
    await until(() => host.state.connected && store.watches.length == 2);
    expect(host.state.canPlay, isTrue);
    host.dispose();
    await store.updates.close();
  });

  test('synchronous watch failure preserves the room and can recover', () async {
    final store = UnreliableStore();
    store.watchFailure = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    final host = await ready(store);
    expect(host.state.room, isNotNull);
    expect(host.state.connected, isFalse);
    store.watchFailure = null;
    await until(() => host.state.connected);
    expect(host.state.canPlay, isTrue);
    host.dispose();
    await store.updates.close();
  });

  test('working reads with a permanently broken watch cannot restart forever',
      () async {
    final store = UnreliableStore();
    final host = await ready(store);
    final before = store.reads;
    store.watchFailure = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    store.watches.single.done?.call();
    await until(() => store.reads == before + retryDelays.length && !host.state.busy);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(store.reads, before + retryDelays.length);
    expect(host.state.connected, isFalse);
    store.watchFailure = null;
    expect(await host.reconnect(), isTrue);
    host.dispose();
    await store.updates.close();
  });

  test('a watch that never confirms its first snapshot cannot silently stall',
      () async {
    final store = UnreliableStore();
    final host = await ready(store);
    final before = store.reads;
    await until(() => !host.state.connected &&
        !host.state.busy && store.reads == before + retryDelays.length);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(store.reads, before + retryDelays.length);
    expect(await host.reconnect(), isTrue);
    store.watches.last.data?.call(MatchRoomUpdate(store.room));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(host.state.connected, isTrue);
    expect(store.reads, before + retryDelays.length + 1);
    host.dispose();
    await store.updates.close();
  });

  test('a changed account cannot silently inherit an existing seat', () async {
    final store = UnreliableStore();
    var uid = 'host';
    final host = await ready(store, authenticate: () async => uid);
    uid = 'stranger';
    expect(await host.reconnect(), isFalse);
    expect(host.state.connected, isFalse);
    expect(host.state.error, contains('original account'));
    expect(store.room!.owners[SeatId.ivory], 'host');
    host.dispose();
    await store.updates.close();
  });

  test('a rewritten server history stops recovery without rolling back play',
      () async {
    final store = UnreliableStore();
    final host = await ready(store);
    await host.play(MatchRules.legalMoves(host.state.game!).first);
    final before = host.state.game!;
    final reads = store.reads;
    final payload = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(store.room!.toMap())));
    payload['moves'][0]['x'] = 1;
    final rewritten = MatchRoom.fromMap(payload);
    store.watches.last.data?.call(MatchRoomUpdate(rewritten));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(host.state.connected, isFalse);
    expect(host.state.error, contains('prefix changed'));
    expect(host.state.game!.board, before.board);
    expect(store.reads, reads);
    host.dispose();
    await store.updates.close();
  });

  test('competing guests take over an expired AI runner without duplicate moves',
      () async {
    final store = UnreliableStore();
    final config = onlineConfig(BoardShape.hex, 3).copyWith(seats: const [
      SeatConfig(SeatId.ivory, control: SeatControl.ai),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman),
      SeatConfig(SeatId.copper, control: SeatControl.onlineHuman)
    ]);
    await store.create('host', config);
    await store.join('UABCDEF', 'guest1');
    await store.join('UABCDEF', 'guest2');
    store.room = store.room!.claimRunner(
        'host', DateTime.now().subtract(const Duration(seconds: 31)));
    final clients = <MatchController>[];
    for (final uid in ['guest1', 'guest2']) {
      final client = MatchController(
          storage: fixtures.MemoryMatchStorage(),
          authenticate: () async => uid,
          store: () => store,
          botDelay: Duration.zero,
          search: (game, level) async => MatchRules.legalMoves(game).first);
      await client.join('UABCDEF', expectedUid: uid);
      clients.add(client);
    }
    await until(() => store.room!.moves.isNotEmpty);
    expect(store.room!.moves.length, 1);
    expect(store.submissions, 1);
    expect(['guest1', 'guest2'], contains(store.room!.aiRunner));
    for (final client in clients) {
      expect(client.state.game!.ply, 1);
      client.dispose();
    }
    await store.updates.close();
  });

  test('an uncertain committed move is reconciled without being resubmitted',
      () async {
    final store = UnreliableStore();
    final host = await ready(store);
    store.lostAcknowledgement = true;
    expect(await host.play(MatchRules.legalMoves(host.state.game!).first), isFalse);
    await until(() => host.state.connected && host.state.game!.ply == 1);
    expect(store.submissions, 1);
    expect(store.room!.moves.length, 1);
    host.dispose();
    await store.updates.close();
  });

  test('two devices racing one seat confirm exactly one turn and converge',
      () async {
    final store = UnreliableStore();
    final first = await ready(store);
    final second = player(store, 'host');
    await second.join('UABCDEF', expectedUid: 'host');
    final move = MatchRules.legalMoves(first.state.game!).first;
    final result = await Future.wait([first.play(move), second.play(move)]);
    expect(result.where((ok) => ok).length, 1);
    await until(() => first.state.connected && second.state.connected);
    expect(store.room!.moves.length, 1);
    expect(first.state.game!.board, second.state.game!.board);
    expect(first.state.game!.ply, 1);
    expect(second.state.game!.ply, 1);
    first.dispose();
    second.dispose();
    await store.updates.close();
  });

  test('leaving cancels automatic recovery and rejects old read completions',
      () async {
    final store = UnreliableStore();
    final host = await ready(store);
    store.pendingRead = Completer<MatchRoom>();
    final reconnecting = host.reconnect();
    await Future<void>.delayed(Duration.zero);
    await host.start(MatchConfig.defaults(BoardShape.hex));
    store.pendingRead!.complete(store.room!);
    expect(await reconnecting, isFalse);
    store.watches.first.done?.call();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(host.state.room, isNull);
    expect(host.state.game!.config.shape, BoardShape.hex);
    expect(host.state.connected, isTrue);
    host.dispose();
    await store.updates.close();
  });

  test('leaving the online screen releases the session without deleting play',
      () async {
    final store = UnreliableStore();
    final host = await ready(store);
    await host.play(MatchRules.legalMoves(host.state.game!).first);
    final confirmed = host.state.game!;
    host.suspend();
    await Future<void>.delayed(Duration.zero);
    expect(host.state.room, isNull);
    expect(store.room!.moves.length, 1);
    await host.join('UABCDEF', expectedUid: 'host');
    expect(host.state.game!.board, confirmed.board);
    expect(host.state.game!.ply, 1);
    host.dispose();
    await store.updates.close();
  });

  for (final shape in BoardShape.values) {
    for (var count = 2; count <= 4; count++) {
      for (final timed in [false, true]) {
        test('$shape $count clients converge through loss and cold recovery (timed=$timed)',
            () async {
          final store = UnreliableStore();
          final config = onlineConfig(shape, count)
              .copyWith(clockSeconds: timed ? 60 : 0);
          await store.create('host', config);
          for (var i = 1; i < count; i++) {
            await store.join('UABCDEF', 'guest$i');
          }
          final clients = <MatchController>[];
          for (var i = 0; i < count; i++) {
            final uid = i == 0 ? 'host' : 'guest$i';
            final client = player(store, uid);
            await client.join('UABCDEF', expectedUid: uid);
            clients.add(client);
          }
          final random = Random(1900 + count + shape.index);
          for (var ply = 0; ply < 40 && !store.room!.replay().finished; ply++) {
            if (ply % 7 == 0) {
              final active = store.watches
                  .where((watch) => !watch.subscription.cancelled).toList();
              final channel = active[random.nextInt(active.length)];
              channel.data?.call(const MatchRoomUpdate(null, confirmed: false, connected: false));
              await until(() => clients.every((client) => client.state.connected));
            }
            final game = store.room!.replay();
            final owner = store.room!.owners[game.current];
            final client = clients.singleWhere((client) => client.state.uid == owner);
            final options = MatchRules.legalMoves(game).take(200).toList();
            expect(await client.play(options[random.nextInt(options.length)]), isTrue);
            for (final view in clients) {
              expect(view.state.game!.board, store.room!.replay().board);
              expect(view.state.game!.ply, store.room!.moves.length);
              expect(view.state.game!.current, store.room!.replay().current);
              expect(view.state.clock?.bank, store.room!.clock?.bank);
              for (final id in config.ids) {
                expect(view.state.game!.reserves[id]!.stones,
                    store.room!.replay().reserves[id]!.stones);
                expect(view.state.game!.reserves[id]!.caps,
                    store.room!.replay().reserves[id]!.caps);
              }
            }
            if (ply % 9 == 0) {
              final index = random.nextInt(clients.length);
              final uid = clients[index].state.uid!;
              clients[index].dispose();
              final resumed = player(store, uid);
              await resumed.join('UABCDEF', expectedUid: uid);
              clients[index] = resumed;
            }
          }
          expect(store.room!.moves.length, greaterThanOrEqualTo(count));
          for (final client in clients) {
            expect(client.state.game!.board, store.room!.replay().board);
            client.dispose();
          }
          await store.updates.close();
        });
      }
    }
  }
}
