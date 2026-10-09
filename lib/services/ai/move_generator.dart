import '../../models/models.dart';
import 'ai.dart';

/// Generates legal moves for the current player
class MoveGenerator {
  MoveGenerator(this.state);

  final GameState state;

  List<AIPlacementMove> generatePlacements() {
    if (state.isGameOver) return const [];
    final placements = <AIPlacementMove>[];
    final board = state.board;
    final pieces = state.currentPlayerPieces;

    for (final pos in board.allPositions) {
      if (!board.stackAt(pos).canPlaceOn) continue;

      if (state.isOpeningPhase) {
        if (state.piecesFor(state.opponent).hasPiece(PieceType.flat)) {
          placements.add(AIPlacementMove(pos, PieceType.flat));
        }
        continue;
      }

      if (pieces.hasPiece(PieceType.flat)) {
        placements.add(AIPlacementMove(pos, PieceType.flat));
      }
      if (pieces.hasPiece(PieceType.standing)) {
        placements.add(AIPlacementMove(pos, PieceType.standing));
      }
      if (pieces.hasPiece(PieceType.capstone)) {
        placements.add(AIPlacementMove(pos, PieceType.capstone));
      }
    }

    return placements;
  }

  List<AIStackMove> generateStackMoves() {
    if (state.isGameOver || state.isOpeningPhase) return const [];
    final moves = <AIStackMove>[];
    for (final from in state.board.allPositions) {
      final stack = state.board.stackAt(from);
      if (stack.isEmpty || stack.controller != state.currentPlayer) continue;
      final maxCarry = stack.height > state.boardSize
          ? state.boardSize
          : stack.height;
      for (final direction in Direction.values) {
        for (var count = 1; count <= maxCarry; count++) {
          for (final drops in GameRules.legalStackDrops(
            state, from, direction, count,
          )) {
            moves.add(AIStackMove(from, direction, drops));
          }
        }
      }
    }
    return moves;
  }
}
