import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_room_store.dart';
import 'package:stones/game/match_state.dart';
import 'match_controller_test.dart' as fixtures;

class FaultStore extends fixtures.MemoryMatchRoomStore {
  Completer<MatchRoom>? pendingCreate;
  Completer<MatchRoom>? pendingClaim;
  final metadata = StreamController<MatchRoomUpdate>.broadcast(sync: true);

  @override
  Future<MatchRoom> create(String uid, MatchConfig config) async =>
      pendingCreate == null ? super.create(uid, config) : pendingCreate!.future;

  @override
  Stream<MatchRoomUpdate> watch(String code) => metadata.stream;

  @override
  Future<MatchRoom> claimRunner(String code, String uid) async =>
      pendingClaim == null ? super.claimRunner(code, uid) : pendingClaim!.future;
}

MatchConfig onlineConfig(BoardShape shape) =>
    MatchConfig.defaults(shape).copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]);

void main() {
  for (final shape in BoardShape.values) {
    test('$shape hosting cannot remain busy after a stalled create', () async {
      final store = FaultStore();
      final config = onlineConfig(shape);
      final allocated = await store.create('host', config);
      store.pendingCreate = Completer<MatchRoom>();
      final host = MatchController(
          storage: fixtures.MemoryMatchStorage(),
          authenticate: () async => 'host',
          store: () => store,
          networkTimeout: const Duration(milliseconds: 20));
      addTearDown(() async {
        host.dispose();
        store.pendingCreate!.complete(allocated);
        await store.metadata.close();
        await store.updates.close();
      });
      await expectLater(
          host.start(config).timeout(const Duration(milliseconds: 200)),
          throwsA(isA<TimeoutException>()));
      expect(host.state.busy, isFalse);
      expect(host.state.error, isNotNull);
    });

    for (final joining in [false, true]) {
      test('$shape shortcut failure cannot block ${joining ? 'joining' : 'hosting'}',
          () async {
        final store = FaultStore();
        final config = onlineConfig(shape);
        if (joining) await store.create('host', config);
        final player = MatchController(
            storage: fixtures.MemoryMatchStorage(),
            authenticate: () async => joining ? 'guest' : 'host',
            store: () => store,
            remember: (room, uid) async => throw StateError('Storage full'));
        addTearDown(() async {
          player.dispose();
          await store.metadata.close();
          await store.updates.close();
        });
        await expectLater(
            joining ? player.join('UABCDEF') : player.start(config), completes);
        expect(player.state.room!.code, 'UABCDEF');
        expect(player.state.game, isNotNull);
        expect(player.state.busy, isFalse);
        await Future<void>.delayed(Duration.zero);
        expect(player.state.shortcutWarning, contains('UABCDEF'));
        store.metadata.add(MatchRoomUpdate(store.room));
        expect(player.state.shortcutWarning, contains('UABCDEF'));
      });
    }

    test('$shape unconfirmed metadata cannot unlock a disconnected board',
        () async {
      final store = FaultStore();
      await store.create('host', onlineConfig(shape));
      await store.join('UABCDEF', 'guest');
      final host = fixtures.controller(fixtures.MemoryMatchStorage(), store);
      addTearDown(() async {
        host.dispose();
        await store.metadata.close();
        await store.updates.close();
      });
      await host.join('UABCDEF', expectedUid: 'host');
      expect(host.state.canPlay, isTrue);
      store.metadata.add(
          const MatchRoomUpdate(null, confirmed: false, connected: false));
      expect(host.state.canPlay, isFalse);
      store.metadata.add(const MatchRoomUpdate(null, confirmed: false));
      expect(host.state.canPlay, isFalse);
      expect(host.state.connected, isFalse);
      store.metadata.add(MatchRoomUpdate(store.room));
      expect(host.state.canPlay, isTrue);
      expect(host.state.game!.ply, 0);
    });
  }

  test('a stalled bookmark cannot block a room and its warning survives updates',
      () async {
    final store = FaultStore();
    final pending = Completer<void>();
    final host = MatchController(
        storage: fixtures.MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => store,
        remember: (room, uid) => pending.future,
        networkTimeout: const Duration(milliseconds: 20));
    await host.start(onlineConfig(BoardShape.square));
    expect(host.state.room, isNotNull);
    expect(host.state.busy, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(host.state.shortcutWarning, contains('UABCDEF'));
    host.dispose();
    pending.complete();
    await store.metadata.close();
    await store.updates.close();
  });

  test('a late bookmark failure cannot contaminate the next match', () async {
    final store = FaultStore();
    final pending = Completer<void>();
    final host = MatchController(
        storage: fixtures.MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => store,
        remember: (room, uid) => pending.future);
    await host.start(onlineConfig(BoardShape.square));
    await host.start(MatchConfig.defaults(BoardShape.hex));
    pending.completeError(StateError('Old shortcut failed'));
    await Future<void>.delayed(Duration.zero);
    expect(host.state.shortcutWarning, isNull);
    expect(host.state.room, isNull);
    expect(host.state.game!.config.shape, BoardShape.hex);
    host.dispose();
    await store.metadata.close();
    await store.updates.close();
  });

  test('disconnecting during AI search keeps manual reconnect available',
      () async {
    final store = FaultStore();
    final pending = Completer<MatchMove?>();
    final config = onlineConfig(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory, control: SeatControl.ai),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]);
    await store.create('host', config);
    await store.join('UABCDEF', 'guest');
    await store.claimRunner('UABCDEF', 'host');
    final host = fixtures.controller(fixtures.MemoryMatchStorage(), store,
        search: (game, level) => pending.future);
    await host.join('UABCDEF', expectedUid: 'host');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(host.state.busy, isTrue);
    store.metadata.add(
        const MatchRoomUpdate(null, confirmed: false, connected: false));
    expect(host.state.busy, isFalse);
    expect(host.state.connected, isFalse);
    pending.complete(null);
    await Future<void>.delayed(Duration.zero);
    expect(host.state.busy, isFalse);
    expect(await host.reconnect(), isTrue);
    host.dispose();
    await store.metadata.close();
    await store.updates.close();
  });

  test('stalled AI lease and recovery reads offer reconnect instead of hanging',
      () async {
    final store = FaultStore();
    final host = MatchController(
        storage: fixtures.MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => store,
        networkTimeout: const Duration(milliseconds: 20));
    await host.start(onlineConfig(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory, control: SeatControl.ai),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]));
    await store.join('UABCDEF', 'guest');
    store.pendingClaim = Completer<MatchRoom>();
    store.pendingRead = Completer<MatchRoom>();
    store.metadata.add(MatchRoomUpdate(store.room));
    for (var attempt = 0; attempt < 60 && host.state.connected; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(host.state.connected, isFalse);
    expect(host.state.error, contains('Reconnect to continue AI'));
    host.dispose();
    store.pendingClaim!.complete(store.room!);
    store.pendingRead!.complete(store.room!);
    await store.metadata.close();
    await store.updates.close();
  });

  for (final joining in [false, true]) {
    test('stalled authentication does not trap ${joining ? 'join' : 'create'}',
        () async {
      final store = FaultStore();
      final pending = Completer<String>();
      final host = MatchController(
          storage: fixtures.MemoryMatchStorage(),
          authenticate: () => pending.future,
          store: () => store,
          networkTimeout: const Duration(milliseconds: 20));
      addTearDown(() async {
        host.dispose();
        pending.complete('host');
        await store.metadata.close();
        await store.updates.close();
      });
      final operation = joining
          ? host.join('UABCDEF')
          : host.start(onlineConfig(BoardShape.square));
      await expectLater(operation.timeout(const Duration(milliseconds: 200)),
          throwsA(isA<TimeoutException>()));
      expect(host.state.busy, isFalse);
      expect(host.state.error, isNotNull);
    });
  }
}
