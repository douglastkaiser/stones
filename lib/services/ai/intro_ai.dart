import '../../models/models.dart';
import 'ai.dart';

/// Random AI with slight placement preference early game
class IntroStonesAI extends StonesAI {
  IntroStonesAI(super.random);

  final _generator = const AIMoveGenerator();

  @override
  Future<AIMove?> selectMove(GameState state) async {
    final moves = _generator.generateMoves(state);
    if (moves.isEmpty) return null;

    final isEarlyGame = state.turnNumber <= 3 ||
        state.board.occupiedPositions.length < state.boardSize;

    // Early game preference for placements (70% chance)
    if (isEarlyGame && random.nextDouble() < 0.7) {
      // Only create list if we're actually preferring placements
      final placements = moves.whereType<AIPlacementMove>().toList();
      if (placements.isNotEmpty) {
        return placements[random.nextInt(placements.length)];
      }
    }

    return moves[random.nextInt(moves.length)];
  }
}
