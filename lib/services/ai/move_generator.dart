import '../../models/models.dart';
import 'ai.dart';

/// Generates legal moves for the current player
class MoveGenerator {
  MoveGenerator(this.state);

  final GameState state;

  List<AIPlacementMove> generatePlacements() {
    final placements = <AIPlacementMove>[];
    final board = state.board;
    final pieces = state.currentPlayerPieces;

    for (final pos in board.allPositions) {
      if (!board.stackAt(pos).canPlaceOn) continue;

      if (state.isOpeningPhase) {
        placements.add(AIPlacementMove(pos, PieceType.flat));
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
    if (state.isOpeningPhase) return const [];

    final moves = <AIStackMove>[];
    final board = state.board;
    final boardSize = state.boardSize;

    for (final pos in board.allPositions) {
      final stack = board.stackAt(pos);
      if (stack.isEmpty || stack.controller != state.currentPlayer) continue;

      final maxCarry = stack.height > boardSize ? boardSize : stack.height;

      for (final direction in Direction.values) {
        final maxReach = _maxReachableDistance(pos, direction, board, boardSize);
        final maxDistance = maxReach > maxCarry ? maxCarry : maxReach;

        for (var distance = 1; distance <= maxDistance; distance++) {
          for (var pieces = distance; pieces <= maxCarry; pieces++) {
            final distributions = _distributePieces(pieces, distance);
            for (final dropPattern in distributions) {
              if (_simulateStackMove(board, pos, direction, dropPattern) != null) {
                moves.add(AIStackMove(pos, direction, dropPattern));
              }
            }
          }
        }
      }
    }

    return moves;
  }

  int _maxReachableDistance(
    Position from,
    Direction direction,
    Board board,
    int boardSize,
  ) {
    var distance = 0;
    var pos = from;

    while (distance < boardSize) {
      pos = direction.apply(pos);
      if (!board.isValidPosition(pos)) break;
      final targetStack = board.stackAt(pos);
      if (targetStack.topPiece?.type == PieceType.capstone) break;
      distance++;
      if (targetStack.topPiece?.type == PieceType.standing) break;
    }

    return distance;
  }

  List<List<int>> _distributePieces(int pieces, int drops) {
    final results = <List<int>>[];

    void helper(int remaining, int slots, List<int> current) {
      if (slots == 1) {
        if (remaining >= 1) {
          results.add([...current, remaining]);
        }
        return;
      }

      for (var i = 1; i <= remaining - slots + 1; i++) {
        helper(remaining - i, slots - 1, [...current, i]);
      }
    }

    helper(pieces, drops, []);
    return results;
  }

  Board? _simulateStackMove(
    Board board,
    Position from,
    Direction direction,
    List<int> drops,
  ) {
    final boardSize = state.boardSize;
    final stack = board.stackAt(from);
    if (stack.isEmpty || stack.controller != state.currentPlayer) return null;

    final totalPicked = drops.fold(0, (sum, d) => sum + d);
    if (totalPicked > stack.height || totalPicked > boardSize) return null;

    var currentPos = from;
    final (remaining, pickedUp) = stack.pop(totalPicked);
    var boardState = board.setStack(from, remaining);
    var pieceIndex = 0;

    for (final dropCount in drops) {
      currentPos = direction.apply(currentPos);
      if (!boardState.isValidPosition(currentPos)) return null;

      var targetStack = boardState.stackAt(currentPos);
      final movingPiece = pickedUp[pieceIndex];
      if (!targetStack.canMoveOnto(movingPiece)) return null;

      if (targetStack.topPiece?.type == PieceType.standing &&
          movingPiece.canFlattenWalls) {
        targetStack = targetStack.flattenTop();
      }

      final piecesToDrop = pickedUp.sublist(pieceIndex, pieceIndex + dropCount);
      targetStack = targetStack.pushAll(piecesToDrop);
      boardState = boardState.setStack(currentPos, targetStack);
      pieceIndex += dropCount;
    }

    return boardState;
  }
}
