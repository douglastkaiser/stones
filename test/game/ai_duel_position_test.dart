import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/ai_duel_position.dart';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_ai_engine.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';

void main() {
  test('search path costs retain canonical scores across board sizes', () {
    for (final shape in BoardShape.values) {
      for (final size in shape == BoardShape.square ? [3, 5, 8] : [2, 3, 4]) {
        for (final seats in [2, 3, 4]) {
          final cfg = MatchConfig(
              shape: shape,
              size: size,
              seats: SeatId.values.take(seats).map(SeatConfig.new).toList());
          var game = MatchState.initial(cfg);
          final random = Random(8710 + size * 10 + seats);
          for (var ply = 0; ply < 28 && !game.finished; ply++) {
            final fast = AiDuelPosition.from(game);
            for (final id in cfg.ids) {
              expect(MatchAI.pathCost(fast, id), MatchAI.pathCost(game, id));
            }
            expect(MatchAI.evaluate(fast), MatchAI.evaluate(game));
            final moves = MatchRules.legalMoves(game).toList();
            game = MatchRules.play(game, moves[random.nextInt(moves.length)])!;
          }
        }
      }
    }
  });

  for (final shape in BoardShape.values) {
    test('$shape search positions preserve every canonical legal transition',
        () {
      for (final seats in [2, 3, 4]) {
        final cfg = MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 5 : 2,
            seats: SeatId.values.take(seats).map(SeatConfig.new).toList());
        for (var seed = 0; seed < 4; seed++) {
          final rng = Random(8100 + seed);
          var game = MatchState.initial(cfg);
          var fast = AiDuelPosition.from(game);
          for (var ply = 0; ply < 60 && !game.finished; ply++) {
            final moves = MatchRules.legalMoves(game).toList();
            expect(
                MatchRules.legalMoves(fast).map((m) => m.toMap(fast.current)),
                moves.map((m) => m.toMap(game.current)));
            for (final move in moves) {
              final expected = MatchRules.play(game, move)!;
              final actual = MatchRules.play(fast, move)!;
              expect(aiDecisionPositionKey(actual),
                  aiDecisionPositionKey(expected));
              expect(actual.config.toMap(), expected.config.toMap());
              expect(identical(actual.geometry, game.geometry), isTrue);
            }
            final chosen = moves[rng.nextInt(moves.length)];
            game = MatchRules.play(game, chosen)!;
            fast = MatchRules.play(fast, chosen)! as AiDuelPosition;
          }
        }
      }
    });
  }
  test('search positions share unchanged stacks and retain deep immutability',
      () {
    final cfg = MatchConfig(
        shape: BoardShape.square,
        size: 5,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    final original = MatchState.initial(cfg).copyWith(ply: 4, board: {
      const Cell(0, 0): const [Stone(SeatId.ivory, PieceType.flat)]
    });
    final fast = AiDuelPosition.from(original);
    final raw = [const Stone(SeatId.charcoal, PieceType.flat)];
    final supplied = {...fast.board, const Cell(1, 1): raw};
    final next = fast.copyWith(board: supplied);
    supplied.clear();
    expect(next.board.length, 2);
    expect(
        identical(next.board[const Cell(0, 0)], fast.board[const Cell(0, 0)]),
        isTrue);
    raw.clear();
    expect(next.stackAt(const Cell(1, 1)).length, 1);
    expect(() => next.board.clear(), throwsUnsupportedError);
    expect(
        () => next.stackAt(const Cell(1, 1)).clear(), throwsUnsupportedError);
    expect(() => next.reserves.clear(), throwsUnsupportedError);
    expect(original.board.length, 1);
    expect(() => fast.copyWith(ply: -1), throwsArgumentError);
    expect(() => fast.copyWith(board: {const Cell(1, 1): []}),
        throwsArgumentError);
    expect(() => fast.copyWith(board: {const Cell(5, 5): raw}),
        throwsArgumentError);
  });
}
