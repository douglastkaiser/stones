import 'dart:math';

import '../../models/models.dart';
import 'ai.dart';
import 'move_generator.dart';

/// Heuristic-driven AI
class MediumStonesAI extends StonesAI {
  MediumStonesAI(Random random) : super(random);

  final _generator = const AIMoveGenerator();

  @override
  Future<AIMove?> selectMove(GameState state) async {
    final moves = _generator.generateMoves(state);
    if (moves.isEmpty) return null;

    final scored = <(AIMove, double)>[];
    for (final move in moves) {
      scored.add((move, _scoreMove(state, move)));
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final topScore = scored.first.$2;
    final bestMoves = scored.where((entry) => entry.$2 == topScore).toList();
    final choice = bestMoves[random.nextInt(bestMoves.length)].$1;
    return choice;
  }

  double _scoreMove(GameState state, AIMove move) {
    if (move is AIPlacementMove) {
      return _scorePlacement(state, move);
    } else if (move is AIStackMove) {
      return _scoreStackMove(state, move);
    }
    return 0;
  }

  double _scorePlacement(GameState state, AIPlacementMove move) {
    final boardSize = state.boardSize;
    final position = move.position;
    final center = (boardSize - 1) / 2;
    final distanceFromCenter =
        (position.row - center).abs() + (position.col - center).abs();

    double score = -distanceFromCenter; // Center preference

    final friendlyAdjacency = _adjacentControlled(state, position, state.currentPlayer);
    final opponentAdjacency = _adjacentControlled(state, position, state.opponent);

    score += friendlyAdjacency * 2;
    score += opponentAdjacency; // Blocking pressure

    if (_isBlockingEdgeThreat(state, position)) {
      score += 4;
    }

    if (move.pieceType == PieceType.capstone) {
      score += state.turnNumber < 4 ? -6 : 3;
    } else if (move.pieceType == PieceType.standing) {
      score += 1; // Useful for blocking roads
    }

    return score + random.nextDouble() * 0.1;
  }

  double _scoreStackMove(GameState state, AIStackMove move) {
    final board = state.board;
    final stack = board.stackAt(move.from);
    final movingTop = stack.topPiece;
    final destination = _finalPosition(move.from, move.direction, move.drops.length);

    double score = 1;

    if (movingTop?.type == PieceType.capstone) {
      score += 3;
      if (state.turnNumber < 4) {
        score -= 2; // Don't waste capstone too early
      }
    }

    if (destination != null) {
      final friendlyAdjacency =
          _adjacentControlled(state, destination, state.currentPlayer);
      final opponentAdjacency = _adjacentControlled(state, destination, state.opponent);
      score += friendlyAdjacency * 2;
      score += opponentAdjacency * 1.5;

      final targetStack = state.board.stackAt(destination);
      if (targetStack.topPiece?.color == state.opponent) {
        score += 2; // Taking over space
      }
      if (targetStack.topPiece?.type == PieceType.standing &&
          movingTop?.canFlattenWalls == true) {
        score += 4; // Flattening walls blocks roads
      }
    }

    return score + random.nextDouble() * 0.2;
  }

  int _adjacentControlled(GameState state, Position pos, PlayerColor color) {
    var count = 0;
    for (final neighbor in pos.adjacentPositions(state.boardSize)) {
      final top = state.board.stackAt(neighbor).topPiece;
      if (top != null && top.color == color && top.type != PieceType.standing) {
        count++;
      }
    }
    return count;
  }

  bool _isBlockingEdgeThreat(GameState state, Position pos) {
    final opponent = state.opponent;
    final size = state.boardSize;
    final touchesLeft = pos.col == 0 &&
        state.board.stackAt(pos).topPiece?.color != opponent;
    final touchesRight = pos.col == size - 1 &&
        state.board.stackAt(pos).topPiece?.color != opponent;
    final touchesTop = pos.row == 0 &&
        state.board.stackAt(pos).topPiece?.color != opponent;
    final touchesBottom = pos.row == size - 1 &&
        state.board.stackAt(pos).topPiece?.color != opponent;

    final opponentEdgePresence = state.board.allPositions.where((p) {
      final top = state.board.stackAt(p).topPiece;
      return top != null && top.color == opponent && top.type != PieceType.standing;
    });

    final controlsLeft = opponentEdgePresence.any((p) => p.col == 0);
    final controlsRight = opponentEdgePresence.any((p) => p.col == size - 1);
    final controlsTop = opponentEdgePresence.any((p) => p.row == 0);
    final controlsBottom = opponentEdgePresence.any((p) => p.row == size - 1);

    final horizontalThreat = controlsLeft && controlsRight;
    final verticalThreat = controlsTop && controlsBottom;

    return (horizontalThreat && (touchesLeft || touchesRight)) ||
        (verticalThreat && (touchesTop || touchesBottom));
  }

  Position? _finalPosition(Position from, Direction direction, int steps) {
    var current = from;
    for (var i = 0; i < steps; i++) {
      current = direction.apply(current);
    }
    return current;
  }
}
