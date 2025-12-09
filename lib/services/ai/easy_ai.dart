import 'dart:math';

import '../../models/models.dart';
import 'ai.dart';

/// Random AI with slight placement preference early game
class EasyStonesAI extends StonesAI {
  EasyStonesAI(super.random);

  final _generator = const AIMoveGenerator();

  @override
  Future<AIMove?> selectMove(GameState state) async {
    final moves = _generator.generateMoves(state);
    if (moves.isEmpty) return null;

    final placements = moves.whereType<AIPlacementMove>().toList();
    final stackMoves = moves.whereType<AIStackMove>().toList();

    final isEarlyGame = state.turnNumber <= 3 ||
        state.board.occupiedPositions.length < state.boardSize;

    if (isEarlyGame && placements.isNotEmpty && stackMoves.isNotEmpty) {
      final roll = random.nextDouble();
      if (roll < 0.7) {
        return placements[random.nextInt(placements.length)];
      }
    }

    return moves[random.nextInt(moves.length)];
  }
}
