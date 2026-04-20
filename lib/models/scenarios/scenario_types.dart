part of '../scenario.dart';

/// Type of structured experience shown in the tutorial hub.
enum ScenarioType { tutorial, puzzle }

/// Chapters used to guide players through a progressive learning path.
enum ScenarioChapter {
  fundamentals,
  puzzleBasics,
  puzzleAdvanced,
}

/// Difficulty level for puzzles.
enum PuzzleDifficulty { easy, medium, hard, expert }

/// Describes a prebuilt scenario for tutorials or puzzles.
class GameScenario {
  final String id;
  final String title;
  final ScenarioType type;
  final ScenarioChapter chapter;
  final int orderInChapter;
  final List<String> prerequisiteScenarioIds;
  final String summary;
  final String objective;
  final List<String> dialogue;
  final GuidedMove guidedMove;
  final GameState Function() buildInitialState;
  final List<AIMove> scriptedResponses;
  final String completionText;
  final AIDifficulty aiDifficulty;
  final PuzzleDifficulty? puzzleDifficulty;
  final String? hintText;
  final Duration? hintDelay;

  const GameScenario({
    required this.id,
    required this.title,
    required this.type,
    required this.chapter,
    required this.orderInChapter,
    this.prerequisiteScenarioIds = const [],
    required this.summary,
    required this.objective,
    required this.dialogue,
    required this.guidedMove,
    required this.buildInitialState,
    required this.scriptedResponses,
    required this.completionText,
    this.aiDifficulty = AIDifficulty.easy,
    this.puzzleDifficulty,
    this.hintText,
    this.hintDelay,
  });
}

/// Grouped chapter data for building scenario selectors.
class ScenarioChapterGroup {
  final ScenarioChapter chapter;
  final List<GameScenario> scenarios;

  const ScenarioChapterGroup({
    required this.chapter,
    required this.scenarios,
  });
}

/// Derives chapter groups from the single source-of-truth scenario list.
List<ScenarioChapterGroup> buildScenarioChapterGroups() {
  final grouped = <ScenarioChapter, List<GameScenario>>{};
  for (final scenario in tutorialAndPuzzleLibrary) {
    grouped.putIfAbsent(scenario.chapter, () => <GameScenario>[]).add(scenario);
  }

  return grouped.entries
      .map(
        (entry) => ScenarioChapterGroup(
          chapter: entry.key,
          scenarios: [...entry.value]
            ..sort((a, b) => a.orderInChapter.compareTo(b.orderInChapter)),
        ),
      )
      .toList()
    ..sort((a, b) => a.chapter.index.compareTo(b.chapter.index));
}

extension ScenarioChapterPresentation on ScenarioChapter {
  String get title {
    return switch (this) {
      ScenarioChapter.fundamentals => 'Chapter 1 · Fundamentals',
      ScenarioChapter.puzzleBasics => 'Chapter 2 · Puzzle Basics',
      ScenarioChapter.puzzleAdvanced => 'Chapter 3 · Advanced Puzzles',
    };
  }
}

/// Type of action the user is being guided toward.
enum GuidedMoveType {
  placement,
  stackMove,
  anyPlacement,
  anyStackMove,
}

/// Structured hint for the exact move we expect during a scenario.
class GuidedMove {
  final GuidedMoveType type;

  /// For placement moves, the required destination (null for anyPlacement).
  final Position? target;

  /// For placement moves, the expected piece type (optional).
  final PieceType? pieceType;

  /// For stack moves, the origin position.
  final Position? from;

  /// For stack moves, the direction of travel (null for anyStackMove).
  final Direction? direction;

  /// For stack moves, the planned drop pattern.
  final List<int>? drops;

  /// Multiple valid target positions (for flexible solutions).
  final Set<Position>? allowedTargets;

  const GuidedMove.placement({required this.target, this.pieceType})
      : type = GuidedMoveType.placement,
        from = null,
        direction = null,
        drops = null,
        allowedTargets = null;

  const GuidedMove.stackMove({
    required this.from,
    required this.direction,
    required this.drops,
  })  : type = GuidedMoveType.stackMove,
        target = from,
        pieceType = null,
        allowedTargets = null;

  /// Allows placing a piece anywhere on the board.
  const GuidedMove.anyPlacement({this.pieceType})
      : type = GuidedMoveType.anyPlacement,
        target = null,
        from = null,
        direction = null,
        drops = null,
        allowedTargets = null;

  /// Allows moving a stack from a specific position in any direction.
  const GuidedMove.anyStackMove({required this.from})
      : type = GuidedMoveType.anyStackMove,
        target = from,
        pieceType = null,
        direction = null,
        drops = null,
        allowedTargets = null;

  /// Allows placement on any of the specified positions.
  const GuidedMove.multipleTargets({
    required this.allowedTargets,
    this.pieceType,
  })  : type = GuidedMoveType.placement,
        target = null,
        from = null,
        direction = null,
        drops = null;

  /// Cells to highlight so the user knows where to interact.
  Set<Position> highlightedCells(int boardSize) {
    if (type == GuidedMoveType.anyPlacement) {
      // Highlight all empty cells (handled by UI)
      return {};
    }

    if (type == GuidedMoveType.anyStackMove) {
      return {from!};
    }

    if (allowedTargets != null) {
      return allowedTargets!;
    }

    if (type == GuidedMoveType.placement) {
      return {target!};
    }

    final start = from!;
    final dir = direction!;
    final steps = drops?.length ?? 0;
    final highlights = <Position>{start};
    var current = start;
    for (var i = 0; i < steps; i++) {
      current = dir.apply(current);
      if (current.row < 0 ||
          current.col < 0 ||
          current.row >= boardSize ||
          current.col >= boardSize) {
        break;
      }
      highlights.add(current);
    }
    return highlights;
  }

}

