import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_ai.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';

void main() {
  for (final shape in BoardShape.values) {
    for (var count = 2; count <= 4; count++) {
      for (final level in BotLevel.values) {
        test('$shape $count players $level takes the immediate road', () async {
          final config = MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 3 : 2,
              seats: SeatId.values.take(count).map(SeatConfig.new).toList());
          final initial = MatchState.initial(config);
          final game = initial.copyWith(ply: count, board: {
            for (var x = shape == BoardShape.square ? 0 : -2; x < 2; x++)
              Cell(x, 0): const [Stone(SeatId.ivory, PieceType.flat)],
          });
          final move =
              await MatchAI(level, yieldDuringSearch: false).choose(game);
          expect(move, isNotNull);
          expect(MatchRules.play(game, move!)!.result!.winner, SeatId.ivory);
        });
      }
    }
  }
  test('search cancellation returns no move', () async {
    final game = MatchState.initial(MatchConfig.defaults(BoardShape.hex));
    expect(await MatchAI(BotLevel.expert).choose(game, cancelled: () => true),
        isNull);
  });
  test('native isolate returns a legal four-player Hex move', () async {
    final game =
        MatchState.initial(MatchConfig.defaults(BoardShape.hex).addPlayer());
    final move = await selectMatchMove(game, BotLevel.easy);
    expect(move, isNotNull);
    expect(MatchRules.play(game, move!), isNotNull);
  });
}
