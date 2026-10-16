import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_room_store.dart';
import 'match_controller_test.dart' as fixtures;

class FaultStore extends fixtures.MemoryMatchRoomStore {
  Completer<MatchRoom>? pendingCreate;
  final metadata = StreamController<MatchRoomUpdate>.broadcast(sync: true);

  @override
  Future<MatchRoom> create(String uid, MatchConfig config) async =>
      pendingCreate == null ? super.create(uid, config) : pendingCreate!.future;

  @override
  Stream<MatchRoomUpdate> watch(String code) => metadata.stream;
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
