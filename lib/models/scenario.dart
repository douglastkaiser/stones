import 'board.dart';
import 'game_state.dart';
import 'piece.dart';
import 'player.dart';
import '../services/ai/ai.dart';

part 'scenarios/scenario_types.dart';
part 'scenarios/_scenario_builders.dart';
part 'scenarios/tutorial_scenarios.dart';
part 'scenarios/puzzle_scenarios.dart';

/// Library of scenarios shown in the tutorial/puzzle selector.
final List<GameScenario> tutorialAndPuzzleLibrary = [
  // Tutorials (9)
  _tutorial1BuildingRoad,
  _tutorial2StandingStones,
  _tutorial3Capstone,
  _tutorial4MovingSinglePiece,
  _tutorial5StacksAndControl,
  _tutorial6StackMovement,
  _tutorial7OpeningRule,
  _tutorial8FlatCount,
  _tutorial9PieceSupply,
  // Puzzles (6)
  _puzzle6CaptureAndWin,
  _puzzle7TheSpread,
  _puzzle9CapstoneTactics,
  _puzzle10TheFork,
  _puzzle11TheCrucible,
  _puzzle12IronCauseway,
];
