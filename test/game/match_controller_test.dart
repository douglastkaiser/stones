import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_room_store.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/match_storage.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/models/piece.dart';

class MemoryMatchStorage implements LocalMatchStorage {
  bool failWrites = false;
  Map<String, dynamic>? snapshot;
  @override
  Future<Map<String, dynamic>?> read() async => snapshot;
  @override
  Future<void> write(Map<String, dynamic> snapshot) async {
    if (failWrites) throw StateError('Storage unavailable');
    this.snapshot = Map<String, dynamic>.from(jsonDecode(jsonEncode(snapshot)));
  }
}

class MemoryMatchRoomStore implements MatchRoomStore {
  MatchRoom? room;
  final updates = StreamController<MatchRoom>.broadcast(sync: true);
  bool publishOnSubmit = true;
  Completer<MatchRoom>? pendingRead;
  @override
  Future<MatchRoom> create(String uid, MatchConfig config) async =>
      room = MatchRoom(code: 'UABCDEF', host: uid, config: config, owners: {
        for (final seat in config.seats)
          seat.id: seat.control == SeatControl.localHuman ? uid : null
      });
  @override
  Future<MatchRoom> join(String code, String uid) async {
    room = room!.join(uid, PieceStyle.standard);
    updates.add(room!);
    return room!;
  }

  @override
  Future<MatchRoom> read(String code) async =>
      pendingRead == null ? room! : await pendingRead!.future;
  @override
  Future<MatchRoom> claimRunner(String code, String uid) async {
    room = room!.claimRunner(uid, DateTime.now());
    updates.add(room!);
    return room!;
  }

  @override
  Future<void> expire(String code, String uid) async {
    room = room!.expire(uid, DateTime.now());
    updates.add(room!);
  }

  @override
  Stream<MatchRoomUpdate> watch(String code) =>
      updates.stream.map(MatchRoomUpdate.new);
  @override
  Future<void> submit(
      String code, String uid, int expectedPly, MatchMove move) async {
    room = room!.append(uid, expectedPly, move);
    if (publishOnSubmit) updates.add(room!);
  }

  @override
  Future<void> resign(String code, String uid, SeatId seat) async {
    room = room!.resign(uid, seat);
    updates.add(room!);
  }
}

MatchController controller(
        MemoryMatchStorage storage, MemoryMatchRoomStore store,
        {String uid = 'host',
        Future<MatchMove?> Function(MatchState, BotLevel)? search}) =>
    MatchController(
        storage: storage,
        authenticate: () async => uid,
        store: () => store,
        search: search,
        botDelay: Duration.zero);

void main() {
  test('a failed reward update can retry once without replaying the result',
      () async {
    final storage = MemoryMatchStorage();
    final store = MemoryMatchRoomStore();
    var attempts = 0;
    final host = MatchController(
        storage: storage,
        authenticate: () async => 'host',
        store: () => store,
        completed: (session) async {
          attempts++;
          if (attempts == 1) throw StateError('Rewards unavailable');
        });
    await host.start(MatchConfig.defaults(BoardShape.square));
    await host.resign(SeatId.ivory);
    await Future<void>.delayed(Duration.zero);
    expect(host.state.error, contains('reward update needs a retry'));
    expect(host.canRetryRewards, isTrue);
    host.retryRewards();
    host.retryRewards();
    await Future<void>.delayed(Duration.zero);
    expect(attempts, 2);
    expect(host.state.error, isNull);
    expect(host.canRetryRewards, isFalse);
    expect(host.state.game!.result!.winner, SeatId.charcoal);
    host.pause(false);
    expect(host.state.clock, isNull);
    host.dispose();
    await store.updates.close();
  });

  test('a stalled room read times out and a later response cannot replace play',
      () async {
    final store = MemoryMatchRoomStore();
    final config =
        MatchConfig.defaults(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]);
    await store.create('host', config);
    store.pendingRead = Completer<MatchRoom>();
    final host = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => store,
        networkTimeout: const Duration(milliseconds: 20));
    await expectLater(host.join('UABCDEF', expectedUid: 'host'),
        throwsA(isA<TimeoutException>()));
    expect(host.state.busy, isFalse);
    await host.start(MatchConfig.defaults(BoardShape.hex));
    store.pendingRead!.complete(store.room!);
    await Future<void>.delayed(Duration.zero);
    expect(host.state.game!.config.shape, BoardShape.hex);
    expect(host.state.room, isNull);
    host.dispose();
    await store.updates.close();
  });

  test(
      'an uncertain online acknowledgement reconciles without duplicating a move',
      () async {
    final store = MemoryMatchRoomStore()..publishOnSubmit = false;
    final host = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => store,
        networkTimeout: const Duration(milliseconds: 20));
    await host
        .start(MatchConfig.defaults(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]));
    await store.join('UABCDEF', 'guest');
    store.pendingRead = Completer<MatchRoom>();
    final move = MatchMove.place(const Cell(0, 0), PieceType.flat);
    expect(await host.play(move), isFalse);
    expect(host.state.connected, isFalse);
    expect(host.state.game!.ply, 0);
    expect(store.room!.moves.length, 1);
    expect(await host.play(move), isFalse);
    store.pendingRead!.complete(store.room!);
    store.pendingRead = null;
    expect(await host.reconnect(), isTrue);
    expect(host.state.game!.ply, 1);
    expect(host.state.busy, isFalse);
    expect(await host.play(move), isFalse);
    expect(store.room!.moves.length, 1);
    expect(await host.resign(SeatId.charcoal), isFalse);
    expect(await host.resign(SeatId.ivory), isTrue);
    expect(host.state.game!.result!.winner, SeatId.charcoal);
    host.dispose();
    await store.updates.close();
  });
  for (final shape in BoardShape.values) {
    for (var count = 2; count <= 4; count++) {
      test('$shape $count resignation saves the explicit ending across restart',
          () async {
        final storage = MemoryMatchStorage();
        final store = MemoryMatchRoomStore();
        final host = controller(storage, store);
        await host.start(MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 5 : 2,
            seats: SeatId.values.take(count).map(SeatConfig.new).toList()));
        expect(await host.resign(SeatId.ivory), isTrue);
        expect(host.state.game!.result!.reason,
            count == 2 ? ResultReason.resignation : ResultReason.abandoned);
        expect(host.state.game!.result!.winner,
            count == 2 ? SeatId.charcoal : null);
        host.dispose();
        final restored = controller(storage, store);
        expect(await restored.resumeLocal(), isTrue);
        expect(restored.state.game!.finished, isTrue);
        expect(restored.state.canPlay, isFalse);
        restored.dispose();
        await store.updates.close();
      });
    }
  }
  for (final shape in BoardShape.values) {
    test(
        'Court Mode on $shape hints, explains and durably takes back AI replies',
        () async {
      final storage = MemoryMatchStorage();
      final store = MemoryMatchRoomStore();
      final host = controller(storage, store,
          search: (game, level) async =>
              MatchRules.legalMoves(game).firstOrNull);
      final defaults = MatchConfig.defaults(shape);
      final config = defaults.copyWith(seats: [
        defaults.seats.first,
        for (final seat in defaults.seats.skip(1))
          seat.copyWith(control: SeatControl.ai)
      ], court: true);
      await host.start(config);
      final hint = await host.hint();
      expect(hint, isNotNull);
      expect(host.state.explanation, contains('opening'));
      expect(host.state.game!.ply, 0);
      expect(await host.play(hint!), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(host.state.game!.ply, config.seats.length);
      expect(host.state.explanation, contains('opening'));
      final id = host.state.id;
      expect(await host.takeBack(), isTrue);
      expect(host.state.game!.ply, 0);
      expect(host.state.id, id);
      host.dispose();
      final resumed = controller(storage, store);
      expect(await resumed.resumeLocal(), isTrue);
      expect(resumed.state.game!.config.court, isTrue);
      expect(resumed.state.game!.board, isEmpty);
      resumed.dispose();
      await store.updates.close();
    });
  }
  test('failed saves neither expose an unsaved move nor strand setup',
      () async {
    final storage = MemoryMatchStorage()..failWrites = true;
    final store = MemoryMatchRoomStore();
    final host = controller(storage, store);
    final config = MatchConfig.defaults(BoardShape.square);
    await expectLater(host.start(config), throwsStateError);
    expect(host.state.busy, isFalse);
    expect(host.state.game, isNull);
    storage.failWrites = false;
    await host.start(config);
    storage.failWrites = true;
    final move = MatchMove.place(const Cell(0, 0), PieceType.flat);
    expect(await host.play(move), isFalse);
    expect(host.state.game!.ply, 0);
    expect(host.state.game!.board, isEmpty);
    expect(host.state.busy, isFalse);
    storage.failWrites = false;
    expect(await host.play(move), isTrue);
    host.dispose();
    await store.updates.close();
  });
  for (final shape in BoardShape.values) {
    for (var count = 2; count <= 4; count++) {
      test('$shape $count local players persist and resume the same match',
          () async {
        final storage = MemoryMatchStorage();
        final store = MemoryMatchRoomStore();
        final host = controller(storage, store);
        final config = MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 5 : 2,
            seats: SeatId.values.take(count).map(SeatConfig.new).toList());
        await host.start(config);
        for (var ply = 0; ply < count; ply++) {
          expect(
              await host.play(MatchMove.place(
                  host.state.game!.geometry.cells[ply], PieceType.flat)),
              isTrue);
        }
        final game = host.state.game!;
        final id = host.state.id;
        host.dispose();
        final fresh = controller(storage, store);
        expect(await fresh.resumeLocal(), isTrue);
        expect(fresh.state.id, id);
        expect(fresh.state.game!.board, game.board);
        expect(fresh.state.game!.current, game.current);
        fresh.dispose();
        await store.updates.close();
      });
    }
  }

  test('two devices wait for acknowledgement and reject stale/remote turns',
      () async {
    final storage = MemoryMatchStorage();
    final store = MemoryMatchRoomStore()..publishOnSubmit = false;
    final host = controller(storage, store);
    final guest = controller(MemoryMatchStorage(), store, uid: 'guest');
    final config =
        MatchConfig.defaults(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]);
    await host.start(config);
    expect(host.state.canPlay, isFalse);
    await guest.join('UABCDEF');
    expect(host.state.canPlay, isTrue);
    final move = MatchMove.place(const Cell(0, 0), PieceType.flat);
    expect(await guest.play(move), isFalse);
    store.pendingRead = Completer<MatchRoom>();
    final submitted = host.play(move);
    await Future<void>.delayed(Duration.zero);
    expect(host.state.busy, isTrue);
    expect(host.state.game!.ply, 0);
    expect(await host.play(move), isFalse);
    store.pendingRead!.complete(store.room!);
    expect(await submitted, isTrue);
    expect(host.state.busy, isFalse);
    store.pendingRead = null;
    store.updates.add(store.room!);
    expect(host.state.game!.ply, 1);
    expect(guest.state.game!.board, host.state.game!.board);
    expect(guest.state.canPlay, isTrue);
    final fresh = controller(MemoryMatchStorage(), store, uid: 'guest');
    await fresh.join('UABCDEF', expectedUid: 'guest');
    expect(fresh.state.game!.board, host.state.game!.board);
    final stranger = controller(MemoryMatchStorage(), store, uid: 'stranger');
    await expectLater(
        stranger.join('UABCDEF', expectedUid: 'guest'), throwsStateError);
    for (final c in [host, guest, fresh, stranger]) {
      c.dispose();
    }
    await store.updates.close();
  });

  test('metadata updates cannot unlock or duplicate a pending host AI search',
      () async {
    final store = MemoryMatchRoomStore();
    final pending = Completer<MatchMove?>();
    var searches = 0;
    final host = controller(MemoryMatchStorage(), store, search: (game, level) {
      searches++;
      return pending.future;
    });
    final config = MatchConfig.defaults(BoardShape.hex).copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.ai),
      SeatConfig(SeatId.copper, control: SeatControl.onlineHuman)
    ]);
    await host.start(config);
    await store.join('UABCDEF', 'guest');
    await store.claimRunner('UABCDEF', 'host');
    await host.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(searches, 1);
    expect(host.state.busy, isTrue);
    store.updates.add(store.room!);
    expect(host.state.busy, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(searches, 1);
    pending.complete(MatchMove.place(const Cell(1, 0), PieceType.flat));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(host.state.game!.ply, 2);
    host.dispose();
    await store.updates.close();
  });

  test('leaving while AI thinks prevents its move entering another game',
      () async {
    final store = MemoryMatchRoomStore();
    final pending = Completer<MatchMove?>();
    final host = controller(MemoryMatchStorage(), store,
        search: (game, level) => pending.future);
    final config = MatchConfig.defaults(BoardShape.square).copyWith(
        seats: const [
          SeatConfig(SeatId.ivory, control: SeatControl.ai),
          SeatConfig(SeatId.charcoal)
        ]);
    await host.start(config);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(host.state.busy, isTrue);
    await host.start(MatchConfig.defaults(BoardShape.hex));
    pending.complete(MatchMove.place(const Cell(0, 0), PieceType.flat));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(host.state.game!.board, isEmpty);
    expect(host.state.game!.config.shape, BoardShape.hex);
    host.dispose();
    await store.updates.close();
  });
}
