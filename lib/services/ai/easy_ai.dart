import '../../models/models.dart';
import 'ai.dart';
import 'board_analysis.dart';

/// Strategic AI with win/threat detection and road-building awareness
/// (Previously Medium difficulty, now Easy)
class EasyStonesAI extends StonesAI {
  EasyStonesAI(super.random);

  final _generator = const AIMoveGenerator();

  @override
  Future<AIMove?> selectMove(GameState state) async {
    final moves = _generator.generateMoves(state);
    if (moves.isEmpty) return null;

    // Priority 1: Take a winning move
    for (final move in moves) {
      if (_isWinningMove(state, move)) {
        return move;
      }
    }

    // Priority 2: Block opponent's winning threats
    final blockingMoves = _findBlockingMoves(state, moves);
    if (blockingMoves.isNotEmpty) {
      // Score blocking moves and pick the best one
      final scored = <(AIMove, double)>[];
      for (final move in blockingMoves) {
        scored.add((move, _scoreMove(state, move)));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.first.$1;
    }

    // Priority 3: Score all moves and pick from the best
    final scored = <(AIMove, double)>[];
    for (final move in moves) {
      scored.add((move, _scoreMove(state, move)));
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final topScore = scored.first.$2;
    final bestMoves = scored.where((e) => e.$2 >= topScore - 0.5).toList();
    return bestMoves[random.nextInt(bestMoves.length)].$1;
  }

  /// Check if a move results in a road win
  bool _isWinningMove(GameState state, AIMove move) {
    final newState = _applyMove(state, move);
    if (newState == null) return false;
    return BoardAnalysis.hasRoad(newState, state.currentPlayer);
  }

  /// Find moves that block opponent's immediate winning threats
  List<AIMove> _findBlockingMoves(GameState state, List<AIMove> moves) {
    // Simulate opponent having a turn and see if they could win
    final opponentWinningPositions = <Position>{};

    // Generate opponent's potential moves
    final opponentState = _switchPlayer(state);
    final opponentMoves = _generator.generateMoves(opponentState);

    for (final opponentMove in opponentMoves) {
      final afterOpponent = _applyMove(opponentState, opponentMove);
      if (afterOpponent != null && BoardAnalysis.hasRoad(afterOpponent, state.opponent)) {
        // This opponent move would win - find what positions matter
        opponentWinningPositions.addAll(_getAffectedPositions(opponentMove));
      }
    }

    if (opponentWinningPositions.isEmpty) return [];

    // Find our moves that affect those critical positions
    return moves.where((move) {
      final affected = _getAffectedPositions(move);
      return affected.any((p) => opponentWinningPositions.contains(p));
    }).toList();
  }

  /// Get positions affected by a move
  Set<Position> _getAffectedPositions(AIMove move) {
    if (move is AIPlacementMove) {
      return {move.position};
    } else if (move is AIStackMove) {
      final positions = <Position>{move.from};
      var pos = move.from;
      for (var i = 0; i < move.drops.length; i++) {
        pos = move.direction.apply(pos);
        positions.add(pos);
      }
      return positions;
    }
    return {};
  }

  /// Create a state with swapped current player (for threat analysis)
  GameState _switchPlayer(GameState state) {
    return state.copyWith(
      currentPlayer: state.opponent,
    );
  }

  /// Apply a move and return the resulting state (or null if invalid)
  GameState? _applyMove(GameState state, AIMove move) {
    if (move is AIPlacementMove) {
      return _applyPlacement(state, move);
    } else if (move is AIStackMove) {
      return _applyStackMove(state, move);
    }
    return null;
  }

  GameState? _applyPlacement(GameState state, AIPlacementMove move) {
    final stack = state.board.stackAt(move.position);
    if (!stack.canPlaceOn) return null;

    final piece = Piece(type: move.pieceType, color: state.currentPlayer);
    final newBoard = state.board.placePiece(move.position, piece);
    return state.copyWith(board: newBoard);
  }

  GameState? _applyStackMove(GameState state, AIStackMove move) {
    final board = state.board;
    final stack = board.stackAt(move.from);
    if (stack.isEmpty) return null;

    final totalPicked = move.drops.fold(0, (sum, d) => sum + d);
    if (totalPicked > stack.height || totalPicked > state.boardSize) return null;

    var currentPos = move.from;
    final (remaining, pickedUp) = stack.pop(totalPicked);
    var boardState = board.setStack(move.from, remaining);
    var pieceIndex = 0;

    for (final dropCount in move.drops) {
      currentPos = move.direction.apply(currentPos);
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

    return state.copyWith(board: boardState);
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

    double score = -distanceFromCenter * 0.5;

    // Chain connectivity - big bonus for extending connected groups
    final chainBonus = _evaluateChainExtension(state, position, state.currentPlayer);
    score += chainBonus * 4;

    // Adjacency scoring
    final friendlyAdjacency = _adjacentControlled(state, position, state.currentPlayer);
    final opponentAdjacency = _adjacentControlled(state, position, state.opponent);
    score += friendlyAdjacency * 2;
    score += opponentAdjacency * 1.5; // Blocking/pressure

    // Edge connectivity bonus
    if (_touchesEdge(position, boardSize)) {
      score += 2;
    }

    // Piece type considerations
    if (move.pieceType == PieceType.capstone) {
      score += state.turnNumber < 6 ? -4 : 4;
    } else if (move.pieceType == PieceType.standing) {
      // Standing stones for blocking key positions
      final blockValue = _standingBlockValue(state, position);
      score += blockValue;
    }

    return score + random.nextDouble() * 0.1;
  }

  double _scoreStackMove(GameState state, AIStackMove move) {
    final board = state.board;
    final stack = board.stackAt(move.from);
    final movingTop = stack.topPiece;
    final destination = _finalPosition(move.from, move.direction, move.drops.length);

    double score = 2;

    if (movingTop?.type == PieceType.capstone) {
      score += 4;
    }

    // Chain extension bonus for stack moves
    final chainBonus = _evaluateChainExtension(state, destination, state.currentPlayer);
    score += chainBonus * 3;

    final friendlyAdjacency =
        _adjacentControlled(state, destination, state.currentPlayer);
    final opponentAdjacency =
        _adjacentControlled(state, destination, state.opponent);
    score += friendlyAdjacency * 2;
    score += opponentAdjacency * 2;

    // Taking control of opponent space
    final targetStack = board.stackAt(destination);
    if (targetStack.topPiece?.color == state.opponent) {
      score += 3;
    }

    // Flattening walls
    if (targetStack.topPiece?.type == PieceType.standing &&
        movingTop?.canFlattenWalls == true) {
      score += 5;
    }

    // Edge bonus
    if (_touchesEdge(destination, state.boardSize)) {
      score += 2;
    }

    return score + random.nextDouble() * 0.2;
  }

  /// Evaluate how well a position extends road-building chains
  double _evaluateChainExtension(GameState state, Position pos, PlayerColor color) {
    // Use shared optimized implementation with single BFS per neighbor
    final baseScore = BoardAnalysis.evaluateChainExtension(state, pos, color);
    // Easy AI uses lower multipliers for less aggressive play
    return baseScore * 0.6;
  }

  /// Evaluate standing stone placement for blocking
  double _standingBlockValue(GameState state, Position pos) {
    final opponent = state.opponent;
    var blockValue = 0.0;

    // Higher value if it disrupts opponent chains
    final neighbors = pos.adjacentPositions(state.boardSize);
    for (final neighbor in neighbors) {
      if (BoardAnalysis.controlsForRoad(state, neighbor, opponent)) {
        blockValue += 1.5;
      }
    }

    return blockValue;
  }

  bool _touchesEdge(Position pos, int boardSize) {
    return pos.row == 0 ||
        pos.row == boardSize - 1 ||
        pos.col == 0 ||
        pos.col == boardSize - 1;
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

  Position _finalPosition(Position from, Direction direction, int steps) {
    var current = from;
    for (var i = 0; i < steps; i++) {
      current = direction.apply(current);
    }
    return current;
  }
}
