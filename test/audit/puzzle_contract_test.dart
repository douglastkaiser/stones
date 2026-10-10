import 'package:flutter_test/flutter_test.dart';
import 'package:stones/models/models.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_studies.dart';
import 'package:stones/puzzles/square_studies.dart';
import 'package:stones/puzzles/square_forcing_position.dart';
import 'package:stones/puzzles/forcing_search.dart';
import 'package:stones/providers/scenario_provider.dart';
import 'package:stones/services/ai/board_analysis.dart';
import 'package:stones/services/ai/ai.dart';

void main() {
  test('square studies conserve inventory and begin before adjudication', () {
    expect(squareStudies.map((s) => s.initial.boardSize).toSet(),
        {3, 4, 5, 6, 7, 8});
    expect(squareStudies.map((s) => s.initial.currentPlayer).toSet(),
        PlayerColor.values.toSet());
    expect(squareStudies.map((s) => s.phase).toSet(),
        {'Early play', 'Middle game', 'Endgame'});
    for (final study in squareStudies) {
      final game = study.initial;
      expect(
          BoardAnalysis.getRoadWinner(game, lastMover: game.opponent), isNull,
          reason: study.id);
      expect(GameRules.flatResult(game), isNull, reason: study.id);
      for (final color in PlayerColor.values) {
        final pieces = [
          for (final cell in game.board.allPositions)
            ...game.board.stackAt(cell).pieces.where((p) => p.color == color)
        ];
        final supply = PlayerPieces.initial(color, game.boardSize);
        expect(
            pieces.where((p) => p.type != PieceType.capstone).length +
                game.piecesFor(color).flatStones,
            supply.flatStones);
        expect(
            pieces.where((p) => p.type == PieceType.capstone).length +
                game.piecesFor(color).capstones,
            supply.capstones);
      }
    }
  });
  test('Hex studies conserve all three supplies and start without roads', () {
    expect(hexStudies.map((s) => s.initial.radius).toSet(), {2, 3, 4});
    expect(hexStudies.map((s) => s.initial.current).toSet(),
        HexSeat.values.toSet());
    expect(hexStudies.map((s) => s.phase).toSet(),
        {'Early play', 'Middle game', 'Endgame'});
    for (final study in hexStudies) {
      final game = study.initial;
      final supply = HexGame.initial(radius: game.radius);
      for (final seat in HexSeat.values) {
        expect(HexRules.road(game, seat), isEmpty, reason: study.id);
        final pieces = [
          for (final stack in game.board.values)
            ...stack.where((p) => p.seat == seat)
        ];
        expect(
            pieces.where((p) => p.type != PieceType.capstone).length +
                game.reserves[seat.index].stones,
            supply.reserves[seat.index].stones);
        expect(
            pieces.where((p) => p.type == PieceType.capstone).length +
                game.reserves[seat.index].caps,
            supply.reserves[seat.index].caps);
        expect(game.reserves[seat.index].total, greaterThan(0));
      }
    }
  });
  test(
      'puzzle success requires a counted in-budget actual win; retry clears state',
      () {
    final scenario = tutorialAndPuzzleLibrary
        .firstWhere((s) => s.type == ScenarioType.puzzle);
    final initial = scenario.buildInitialState();
    final won = initial.copyWith(
        phase: GamePhase.finished, result: GameResult.whiteWins);
    final progress =
        ScenarioState(activeScenario: scenario, guidedStepComplete: true);
    expect(progress.isSuccessful(initial), isFalse);
    expect(progress.isSuccessful(won), isFalse);
    expect(progress.copyWith(puzzleMoves: 1).isSuccessful(won), isTrue);
    expect(progress.copyWith(puzzleMoves: 2).isSuccessful(won), isFalse);
    expect(
        progress
            .copyWith(puzzleMoves: 1, certificateError: true)
            .isSuccessful(won),
        isFalse);
    final controller = ScenarioStateNotifier()..startScenario(scenario);
    addTearDown(controller.dispose);
    controller.recordPuzzleMove(
        const AIPlacementMove(Position(0, 2), PieceType.flat));
    expect(controller.state.isFailed(initial), isTrue);
    controller.startScenario(scenario);
    expect(controller.state.puzzleMoves, 0);
    expect(controller.state.isFailed(initial), isFalse);
    expect(controller.state.nextScriptedMove, isNull);
  });
  test('proof resource limit is an unknown result, never a success', () {
    final search = ForcingSearch(SquareForcingPosition(), 0, nodeLimit: 1);
    expect(() => search.wins(squareStudies.first.initial, 1), throwsStateError);
  });
}
