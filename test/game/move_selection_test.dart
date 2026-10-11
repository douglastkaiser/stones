import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/move_selection.dart';
import 'package:stones/models/piece.dart';

void main() {
  for (final shape in BoardShape.values) {
    for (var count = 2; count <= 4; count++) {
      test('$shape $count players share placement, spread, revision and cancel',
          () {
        final config = MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 5 : 2,
            seats: SeatId.values.take(count).map(SeatConfig.new).toList());
        final initial = MatchState.initial(config);
        final selection = MoveSelection();
        expect(selection.tap(initial, const Cell(0, 0)), isFalse);
        expect(selection.tap(initial, const Cell(0, 0)), isTrue);
        expect(initial.board, isEmpty);
        final exchanged = MatchRules.play(initial, selection.planned!)!;
        expect(exchanged.topAt(const Cell(0, 0))!.seat, SeatId.charcoal);
        selection.clear();
        final game = initial.copyWith(ply: count, board: {
          const Cell(0, 0): const [
            Stone(SeatId.charcoal, PieceType.flat),
            Stone(SeatId.ivory, PieceType.flat)
          ]
        });
        selection.swipe(game, const Cell(0, 0), Step.east);
        expect(selection.planned!.drops, [2]);
        expect(selection.destinations(game), {const Cell(2, 0)});
        selection.tap(game, const Cell(2, 0));
        expect(selection.planned!.drops, [1, 1]);
        final result = MatchRules.apply(game, selection.planned!)!;
        expect(result.topAt(const Cell(1, 0))!.seat, SeatId.charcoal);
        expect(result.topAt(const Cell(2, 0))!.seat, SeatId.ivory);
        selection.tap(game, const Cell(-10, 20));
        expect(selection.planned!.drops, [1, 1]);
        selection.backStep(game);
        expect(selection.planned!.drops, [2]);
        selection.clear();
        expect(selection.planned, isNull);
        expect(game.stackAt(const Cell(0, 0)).length, 2);
      });
    }
  }
  test('square rejects diagonal swipe through common planner', () {
    final initial = MatchState.initial(MatchConfig.defaults(BoardShape.square));
    final game = initial.copyWith(ply: 2, board: {
      const Cell(1, 1): const [Stone(SeatId.ivory, PieceType.flat)]
    });
    final selection = MoveSelection();
    selection.swipe(game, const Cell(1, 1), Step.northEast);
    expect(selection.planned, isNull);
  });
}
