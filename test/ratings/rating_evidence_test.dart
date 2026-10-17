import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/rating_evidence.dart';
import 'package:stones/models/piece.dart';

void main() {
  MatchConfig config({bool online = false, bool court = false, int clock = 0}) => MatchConfig(
    shape: BoardShape.square, size: 3, court: court, clockSeconds: clock,
    seats: [const SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal,
      control: online ? SeatControl.onlineHuman : SeatControl.ai)]);
  (MatchState, List<Map<String, dynamic>>) finish(MatchConfig c) {
    var game = MatchState.initial(c);
    final moves = <Map<String, dynamic>>[];
    for (final cell in [const Cell(2, 2), const Cell(0, 0), const Cell(0, 1), const Cell(2, 1), const Cell(0, 2)]) {
      final move = MatchMove.place(cell, PieceType.flat);
      moves.add(move.toMap(game.current));
      game = MatchRules.play(game, move)!;
    }
    expect(game.result!.winner, SeatId.ivory);
    return (game, moves);
  }
  test('local AI evidence is replayed without network or an assumed AI rating', () {
    final (game, moves) = finish(config());
    final evidence = RatingEvidence.verify(MatchSession(game: game, id: 'local-1'), moves, 'alice');
    expect(evidence!.winner, 0);
    expect(evidence.humans, ['alice']);
    expect(evidence.pool, 'square-3-2-standardTak-open');
    final forged = moves.map((m) => Map<String, dynamic>.from(m)).toList();
    forged[2]['x'] = 2; forged[2]['y'] = 2;
    expect(RatingEvidence.verify(MatchSession(game: game), forged, 'alice'), isNull);
    expect(RatingEvidence.verify(MatchSession(game: game), moves.sublist(1), 'alice'), isNull);
  });
  test('Court, timed AI and fabricated terminal flags do not produce samples', () {
    for (final c in [config(court: true), config(clock: 60)]) {
      final (game, moves) = finish(c);
      expect(RatingEvidence.verify(MatchSession(game: game), moves, 'alice'), isNull);
    }
    final (game, moves) = finish(config());
    final forged = game.copyWith(result: const MatchResult(SeatId.charcoal, ResultReason.road));
    expect(RatingEvidence.verify(MatchSession(game: forged), moves, 'alice'), isNull);
    final extra = [...moves, moves.last];
    expect(RatingEvidence.verify(MatchSession(game: game.copyWith(ply: 6)), extra, 'alice'), isNull);
  });
  test('independent human seats must own the same replayed room and outcome', () {
    final c = config(online: true);
    final (game, moves) = finish(c);
    final room = MatchRoom(code: 'UAAAAAA', host: 'alice', config: c,
      owners: {SeatId.ivory: 'alice', SeatId.charcoal: 'bob'}, moves: moves);
    final session = MatchSession(game: game, room: room, id: room.code, uid: 'bob');
    expect(RatingEvidence.verify(session, moves, 'bob')!.humans, ['alice', 'bob']);
    expect(RatingEvidence.verify(session, moves, 'stranger'), isNull);
    expect(RatingEvidence.verify(session, moves.reversed.toList(), 'bob'), isNull);
    final bad = MatchSession(game: game.copyWith(result: const MatchResult(null, ResultReason.flats)), room: room);
    expect(RatingEvidence.verify(bad, moves, 'bob'), isNull);
  });
  test('map field ordering is irrelevant but any changed record is detected', () {
    expect(RatingEvidence.same({'x': 1, 'drops': [1, 2]}, {'drops': [1, 2], 'x': 1}), isTrue);
    expect(RatingEvidence.same({'drops': [1, 2]}, {'drops': [2, 1]}), isFalse);
  });
}
