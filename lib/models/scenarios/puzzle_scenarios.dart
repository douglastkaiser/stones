part of '../scenario.dart';

final _verifiedPuzzles = [
  for (var i = 0; i < squareStudies.length; i++)
    GameScenario(
      id: squareStudies[i].id,
      title: '${i + 1}. ${squareStudies[i].title}',
      type: ScenarioType.puzzle,
      chapter:
          i < 4 ? ScenarioChapter.puzzleBasics : ScenarioChapter.puzzleAdvanced,
      orderInChapter: i + 1,
      summary:
          '${squareStudies[i].initial.boardSize}×${squareStudies[i].initial.boardSize} · ${squareStudies[i].phase} · Win in ${squareStudies[i].moves}',
      objective:
          'Win as ${squareStudies[i].initial.currentPlayer == PlayerColor.white ? "White (Light)" : "Black (Dark)"} within ${squareStudies[i].moves} of your moves. Opponent turns do not count.',
      dialogue: const [],
      guidedMove: const GuidedMove.anyPlacement(),
      buildInitialState: () => squareStudies[i].initial,
      scriptedResponses: const [],
      completionText: squareStudies[i].explanation,
      puzzleDifficulty: PuzzleDifficulty.values.firstWhere(
          (value) => value.name == squareStudies[i].difficulty.toLowerCase()),
      hintText: squareStudies[i].hints.first,
      puzzleHints: squareStudies[i].hints,
      puzzleMoveLimit: squareStudies[i].moves,
    ),
];
