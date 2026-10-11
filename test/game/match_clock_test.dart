import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_clock.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

void main() {
  for (final shape in BoardShape.values) {
    for (var count = 2; count <= 4; count++) {
      test('$shape $count clock banks debit only a seat’s completed runs', () {
        final config = MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 5 : 2,
            seats: SeatId.values.take(count).map(SeatConfig.new).toList(),
            clockSeconds: 10);
        final now = DateTime.utc(2026, 10, 10);
        var clock = MatchClock.initial(config);
        expect(clock.expired(config.starter, now.add(const Duration(days: 1))),
            isFalse);
        for (var ply = 0; ply < count * 2; ply++) {
          final time = now.add(Duration(seconds: ply));
          clock =
              clock.advance(config.turnAt(ply), config.turnAt(ply + 1), time);
          expect(clock.remaining(config.turnAt(ply + 1), time),
              ply >= count ? 9000 : 10000);
        }
        expect(MatchClock.fromMap(clock.toMap()).toMap(), clock.toMap());
        final frozen = clock.frozen(now.add(Duration(seconds: count * 2 - 1)));
        expect(
            frozen.remaining(
                config.turnAt(count * 2), now.add(const Duration(days: 1))),
            frozen.bank[config.turnAt(count * 2)]);
      });
      test('$shape $count room timeout survives replay with the correct ending',
          () {
        final config = MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 5 : 2,
            seats: [
              const SeatConfig(SeatId.ivory),
              for (final id in SeatId.values.skip(1).take(count - 1))
                SeatConfig(id, control: SeatControl.onlineHuman)
            ],
            clockSeconds: 1);
        var room =
            MatchRoom(code: 'UABCDEF', host: 'host', config: config, owners: {
          for (final id in config.ids)
            id: id == SeatId.ivory ? 'host' : 'guest-${id.name}'
        });
        final now = DateTime.utc(2026, 10, 10);
        room = room.append(
            'host', 0, MatchMove.place(const Cell(0, 0), PieceType.flat),
            now: now);
        expect(() => room.expire('host', now), throwsStateError);
        final later = now.add(const Duration(seconds: 2));
        expect(
            () => room.append('guest-charcoal', 1,
                MatchMove.place(const Cell(1, 0), PieceType.flat),
                now: later),
            throwsStateError);
        final expired = room.expire('host', later);
        final decoded = MatchRoom.fromMap(expired.toMap());
        expect(decoded.replay().result!.reason,
            count == 2 ? ResultReason.time : ResultReason.abandoned);
        expect(
            decoded.replay().result!.winner, count == 2 ? SeatId.ivory : null);
        expect(expired.replayAfter(room, room.replay()).finished, isTrue);
        expect(expired.replayAfter(expired, expired.replay()).finished, isTrue);
      });
    }
  }
  test('local clocks pause, resume and persist a timeout result', () async {
    final storage = MemoryMatchStorage();
    final store = MemoryMatchRoomStore();
    MatchController make() => MatchController(
        storage: storage, authenticate: () async => 'host', store: () => store);
    final first = make();
    await first.start(
        MatchConfig.defaults(BoardShape.square).copyWith(clockSeconds: 1));
    expect(await first.play(MatchMove.place(const Cell(0, 0), PieceType.flat)),
        isTrue);
    first.pause(true);
    final remaining = first.state.clock!.bank[SeatId.charcoal];
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(first.state.game!.finished, isFalse);
    expect(first.state.clock!.bank[SeatId.charcoal], remaining);
    first.dispose();
    final resumed = make();
    expect(await resumed.resumeLocal(), isTrue);
    resumed.pause(false);
    await Future<void>.delayed(const Duration(milliseconds: 1350));
    expect(resumed.state.game!.result!.winner, SeatId.ivory);
    resumed.dispose();
    final terminal = make();
    expect(await terminal.resumeLocal(), isTrue);
    expect(terminal.state.game!.result!.reason, ResultReason.time);
    terminal.dispose();
    await store.updates.close();
  });
  test('timed recovery rejects missing clocks and incorrect seat banks',
      () async {
    final storage = MemoryMatchStorage();
    final store = MemoryMatchRoomStore();
    final host = MatchController(
        storage: storage, authenticate: () async => 'host', store: () => store);
    final config =
        MatchConfig.defaults(BoardShape.square).copyWith(clockSeconds: 60);
    await host.start(config);
    storage.snapshot!.remove('clock');
    await expectLater(host.resumeLocal(), throwsFormatException);
    storage.snapshot!['clock'] = MatchClock.initial(config.copyWith(seats: [
      const SeatConfig(SeatId.ivory),
      const SeatConfig(SeatId.jade)
    ])).toMap();
    await expectLater(host.resumeLocal(), throwsFormatException);
    host.pause(false);
    expect(host.state.game, isNull);
    final online = config.copyWith(seats: [
      const SeatConfig(SeatId.ivory),
      const SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]);
    final room = MatchRoom(
        code: 'UABCDEF',
        host: 'host',
        config: online,
        owners: const {SeatId.ivory: 'host', SeatId.charcoal: 'guest'});
    final missing = room.toMap()..remove('clock');
    expect(() => MatchRoom.fromMap(missing), throwsFormatException);
    host.dispose();
    await store.updates.close();
  });
}
