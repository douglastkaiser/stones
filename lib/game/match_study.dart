import '../hex/hex_exercises.dart';
import '../hex/hex_forcing_position.dart';
import '../models/board.dart';
import '../models/scenario.dart';
import '../puzzles/certificates.dart';
import '../puzzles/square_forcing_position.dart';
import '../services/ai/ai.dart';
import 'board_geometry.dart';
import 'legacy_hex_adapter.dart';
import 'legacy_square_adapter.dart';
import 'match_state.dart';

/// Catalog metadata/adapters do not implement placement, spreading or roads.
class MatchStudy {
  const MatchStudy(
      {required this.id,
      required this.title,
      required this.goal,
      required this.initial,
      required this.puzzle,
      required this.moveLimit,
      required this.accepts,
      required this.replies,
      required this.hints,
      required this.explanation,
      this.prerequisites = const [],
      this.lessonSteps = 1,
      this.legacyHex = false});
  final String id, title, goal, explanation;
  final MatchState initial;
  final bool puzzle, legacyHex;
  final int moveLimit, lessonSteps;
  final List<String> hints, prerequisites;
  final bool Function(MatchMove, int) accepts;
  final List<MatchMove>? Function(MatchMove) replies;
  bool success(MatchState game, int steps) => puzzle
      ? steps > 0 &&
          steps <= moveLimit &&
          game.result?.winner == initial.current
      : steps >= lessonSteps;

  factory MatchStudy.square(GameScenario scenario) {
    final guided = scenario.guidedMove;
    final puzzle = scenario.type == ScenarioType.puzzle;
    bool accepts(MatchMove move, int step) {
      if (puzzle) return true;
      final from = Position(move.from.y, move.from.x);
      if (move.type != null) {
        return (guided.type == GuidedMoveType.placement ||
                guided.type == GuidedMoveType.anyPlacement) &&
            (guided.pieceType == null || guided.pieceType == move.type) &&
            (guided.type == GuidedMoveType.anyPlacement ||
                guided.target == from ||
                guided.allowedTargets?.contains(from) == true);
      }
      return (guided.type == GuidedMoveType.stackMove ||
              guided.type == GuidedMoveType.anyStackMove) &&
          guided.from == from &&
          (guided.direction == null ||
              LegacySquareAdapter.direction(guided.direction!) ==
                  move.direction) &&
          (guided.drops == null ||
              (guided.drops!.length == move.drops.length &&
                  List.generate(move.drops.length,
                          (i) => guided.drops![i] == move.drops[i])
                      .every((same) => same)));
    }

    List<MatchMove>? replies(MatchMove move) {
      final key = SquareForcingPosition().moveKey(squareMove(move));
      final keys = (puzzleCertificates[scenario.id]?['replies']
          as Map<String, dynamic>?)?[key] as List?;
      return keys
          ?.cast<String>()
          .map((key) => fromSquareMove(SquareForcingPosition.decode(key)))
          .toList();
    }

    return MatchStudy(
        id: scenario.id,
        title: scenario.title,
        goal: '${scenario.summary}\n${scenario.objective}',
        initial: LegacySquareAdapter.read(scenario.buildInitialState()),
        puzzle: puzzle,
        moveLimit: scenario.puzzleMoveLimit,
        accepts: accepts,
        replies: replies,
        hints: scenario.puzzleHints.isNotEmpty
            ? scenario.puzzleHints
            : [
                if (scenario.hintText != null) scenario.hintText!,
                ...scenario.dialogue
              ],
        prerequisites: scenario.prerequisiteScenarioIds,
        explanation: scenario.completionText);
  }

  factory MatchStudy.hex(HexExercise exercise) => MatchStudy(
      id: exercise.id,
      title: exercise.title,
      goal: '${exercise.metadata}\n${exercise.goal}',
      initial: LegacyHexAdapter.read(exercise.initial),
      puzzle: exercise.puzzle,
      moveLimit: exercise.moveLimit,
      lessonSteps: exercise.solution.length,
      legacyHex: true,
      explanation: exercise.explanation,
      hints: exercise.hints.isEmpty ? [exercise.hint] : exercise.hints,
      accepts: (move, step) =>
          exercise.puzzle ||
          exercise.accepts(
              exercise.initial, LegacyHexAdapter.writeMove(move), step),
      replies: (move) {
        final key =
            HexForcingPosition().moveKey(LegacyHexAdapter.writeMove(move));
        final keys = (puzzleCertificates[exercise.id]?['replies']
            as Map<String, dynamic>?)?[key] as List?;
        return keys
            ?.cast<String>()
            .map((key) => LegacyHexAdapter.move(HexForcingPosition.decode(key)))
            .toList();
      });

  static AIMove squareMove(MatchMove move) => move.type != null
      ? AIPlacementMove(Position(move.from.y, move.from.x), move.type!)
      : AIStackMove(
          Position(move.from.y, move.from.x),
          switch (move.direction!) {
            Step.east => Direction.right,
            Step.west => Direction.left,
            Step.northWest => Direction.up,
            Step.southEast => Direction.down,
            _ => throw StateError('Diagonal square move'),
          },
          move.drops);
  static MatchMove fromSquareMove(AIMove move) => switch (move) {
        AIPlacementMove() => MatchMove.place(
            Cell(move.position.col, move.position.row), move.pieceType),
        AIStackMove() => MatchMove.spread(Cell(move.from.col, move.from.row),
            LegacySquareAdapter.direction(move.direction), move.drops),
      };
}
