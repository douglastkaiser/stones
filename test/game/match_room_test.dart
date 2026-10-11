import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/models/piece.dart';

MatchRoom room(MatchConfig config) =>
    MatchRoom(code: 'UABCDEF', host: 'host', config: config, owners: {
      for (final seat in config.seats)
        seat.id: seat.control == SeatControl.localHuman ? 'host' : null
    });

void main() {
  test(
      'every online mixture on both shapes joins, exchanges and cold/incremental replays',
      () {
    for (final shape in BoardShape.values) {
      for (var count = 2; count <= 4; count++) {
        for (var pattern = 0; pattern < pow(3, count); pattern++) {
          final config = MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 5 : 2,
              seats: List.generate(
                  count,
                  (i) => SeatConfig(SeatId.values[i],
                      control:
                          SeatControl.values[(pattern ~/ pow(3, i)) % 3])));
          if (!config.online) continue;
          var current = room(config);
          for (final seat in config.seats
              .where((s) => s.control == SeatControl.onlineHuman)) {
            expect(current.ready, isFalse);
            current = current.join('user-${seat.id.name}', PieceStyle.morocco);
            expect(current.styles[seat.id], PieceStyle.morocco);
            expect(current.join('user-${seat.id.name}', PieceStyle.kyoto),
                same(current));
          }
          expect(current.ready, isTrue);
          expect(
              current.controlledBy('host').length,
              config.seats
                  .where((s) => s.control == SeatControl.localHuman)
                  .length);
          var position = current.replay();
          for (var ply = 0; ply < count; ply++) {
            final uid = current.owners[position.current] ?? 'host';
            final previous = current;
            current = current.append(uid, ply,
                MatchMove.place(position.geometry.cells[ply], PieceType.flat));
            position = current.replayAfter(previous, position);
            final decoded = MatchRoom.fromMap(current.toMap());
            expect(decoded.toMap(), current.toMap());
            expect(position.board, decoded.replay().board);
            expect(position.current, decoded.replay().current);
          }
          expect(
              () => current.append('stranger', count,
                  MatchMove.place(const Cell(1, 1), PieceType.flat)),
              throwsStateError);
          expect(
              () => current.append(
                  'host', 0, MatchMove.place(const Cell(1, 1), PieceType.flat)),
              throwsStateError);
        }
      }
    }
  });

  test(
      'strict prefix and seat identity; resignation survives repeated snapshots',
      () {
    final config = MatchConfig(shape: BoardShape.square, size: 3, seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]);
    final initial = room(config).join('guest', PieceStyle.kyoto);
    final played = initial.append(
        'host', 0, MatchMove.place(const Cell(0, 0), PieceType.flat));
    final changed = {
      ...played.toMap(),
      'moves': [
        {...played.moves.first, 'x': 1}
      ]
    };
    expect(
        () => MatchRoom.fromMap(changed).replayAfter(played, played.replay()),
        throwsFormatException);
    final changedOwner = {
      ...played.toMap(),
      'owners': {'ivory': 'host', 'charcoal': 'stranger'}
    };
    expect(
        () => MatchRoom.fromMap(changedOwner)
            .replayAfter(played, played.replay()),
        throwsFormatException);
    final resigned = played.resign('guest', SeatId.charcoal);
    final result = resigned.replayAfter(played, played.replay());
    expect(result.result!.winner, SeatId.ivory);
    expect(resigned.replayAfter(resigned, result), same(result));
    expect(
        () => resigned.append(
            'guest', 1, MatchMove.place(const Cell(1, 0), PieceType.flat)),
        throwsStateError);
    expect(() => resigned.moves.first['drops'] = [1], throwsUnsupportedError);
  });

  test('multiplayer resignation ends without awarding an arbitrary opponent',
      () {
    final config = MatchConfig.defaults(BoardShape.hex);
    final mixed = config.copyWith(seats: [
      config.seats.first,
      config.seats[1].copyWith(control: SeatControl.onlineHuman),
      config.seats.last
    ]);
    final resigned = room(mixed)
        .join('guest', PieceStyle.standard)
        .resign('host', SeatId.copper);
    expect(resigned.replay().result!.reason, ResultReason.abandoned);
    expect(resigned.replay().result!.winner, isNull);
    expect(resigned.replay().result!.draw, isFalse);
  });
}
