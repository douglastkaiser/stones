import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_ai.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';

void main() {
  for (final level in BotLevel.values) {
    for (final shape in BoardShape.values) {
      for (var count = 2; count <= 4; count++) {
        test(
            '$level $shape $count takes a road win regardless of seat identity',
            () async {
          final config = MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 5 : 2,
              seats: SeatId.values.take(count).map(SeatConfig.new).toList(),
              starter: SeatId.values[count - 1]);
          final initial = MatchState.initial(config);
          final player = config.starter;
          final game = initial.copyWith(ply: count, board: {
            if (shape == BoardShape.square)
              for (final x in [0, 1, 3, 4])
                Cell(x, 2): [Stone(player, PieceType.flat)]
            else
              for (final x in [-2, -1, 1, 2])
                Cell(x, 0): [Stone(player, PieceType.flat)],
          });
          final move =
              await MatchAI(level, yieldDuringSearch: false).choose(game);
          expect(move, isNotNull);
          expect(MatchRules.play(game, move!)!.result?.winner, player);
        });
      }
    }
  }
  for (final level in [BotLevel.hard, BotLevel.expert]) {
    test('$level preserves the standard three-by-three forced-fork tactic',
        () async {
      final initial = MatchState.initial(MatchConfig(
          shape: BoardShape.square,
          size: 3,
          seats: const [
            SeatConfig(SeatId.ivory),
            SeatConfig(SeatId.charcoal)
          ]));
      final game = initial.copyWith(ply: 2, board: {
        const Cell(0, 0): const [Stone(SeatId.ivory, PieceType.flat)],
        const Cell(1, 1): const [Stone(SeatId.ivory, PieceType.flat)],
        const Cell(2, 0): const [Stone(SeatId.charcoal, PieceType.flat)],
      });
      final move = await MatchAI(level, yieldDuringSearch: false).choose(game);
      expect(move!.from, const Cell(0, 1));
      expect(move.type, PieceType.flat);
    });
  }
}
