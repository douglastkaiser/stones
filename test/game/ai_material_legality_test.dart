import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/ai_material.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';

void main() {
  for (final shape in BoardShape.values) {
    for (final size in shape == BoardShape.square ? [3, 5, 8] : [2, 3, 4]) {
      test('$shape/$size allocation-free probes equal canonical application',
          () {
        for (final seats in [2, 3, 4]) {
          final cfg = MatchConfig(
              shape: shape,
              size: size,
              seats: SeatId.values.take(seats).map(SeatConfig.new).toList());
          for (var seed = 0; seed < 2; seed++) {
            final random = Random(830000 + seed);
            var game = MatchState.initial(cfg);
            for (var ply = 0; ply < 24 && !game.finished; ply++) {
              if (ply % 6 == 0) {
                for (final cell in game.geometry.cells) {
                  for (final direction in Step.values) {
                    expect(
                        MatchRules.canSpreadOne(game, cell, direction),
                        MatchRules.apply(game,
                                MatchMove.spread(cell, direction, const [1])) !=
                            null);
                  }
                }
                for (final seat in cfg.ids) {
                  for (final weights in [
                    const AiMaterialWeights(),
                    const AiMaterialWeights(mobility: 4),
                    const AiMaterialWeights(crush: 0, exposure: 12, access: 0),
                  ]) {
                    expect(
                        aiMaterialScore(game, seat, weights,
                            fastLegalProbes: true),
                        aiMaterialScore(game, seat, weights));
                  }
                }
              }
              final legal = MatchRules.legalMoves(game).toList();
              game =
                  MatchRules.play(game, legal[random.nextInt(legal.length)])!;
            }
          }
        }
      });
    }
  }
  test('single-stone probes preserve flattening, ownership and lifecycle rules',
      () {
    final cfg = MatchConfig(
        shape: BoardShape.square,
        size: 5,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    for (final moving in PieceType.values) {
      for (final covered in PieceType.values) {
        final game = MatchState.initial(cfg).copyWith(ply: 2, board: {
          const Cell(1, 1): [Stone(SeatId.ivory, moving)],
          const Cell(2, 1): [Stone(SeatId.charcoal, covered)],
        });
        final expected = MatchRules.apply(game,
                MatchMove.spread(const Cell(1, 1), Step.east, const [1])) !=
            null;
        expect(MatchRules.canSpreadOne(game, const Cell(1, 1), Step.east),
            expected);
        expect(
            MatchRules.canSpreadOne(
                game.copyWith(ply: 3), const Cell(1, 1), Step.east),
            isFalse);
        expect(
            MatchRules.canSpreadOne(
                game.copyWith(ply: 0), const Cell(1, 1), Step.east),
            isFalse);
        expect(
            MatchRules.canSpreadOne(
                game.copyWith(
                    result: const MatchResult(SeatId.ivory, ResultReason.road)),
                const Cell(1, 1),
                Step.east),
            isFalse);
      }
    }
  });
}
