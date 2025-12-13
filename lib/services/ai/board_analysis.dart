import '../../models/models.dart';

/// Shared board analysis utilities for AI with caching
class BoardAnalysis {
  // Cache for road detection results
  static final Map<String, bool> _roadCache = {};
  static final Map<String, Set<Position>> _edgeReachabilityCache = {};
  static const int _maxCacheSize = 1000;

  /// Generate a hash key for the board state
  static String _getBoardHash(GameState state, PlayerColor color) {
    final buffer = StringBuffer();
    buffer.write('${color.name}_${state.boardSize}_');

    final board = state.board;
    for (int r = 0; r < state.boardSize; r++) {
      for (int c = 0; c < state.boardSize; c++) {
        final stack = board.stackAt(Position(r, c));
        final top = stack.topPiece;
        if (top != null) {
          buffer.write('${r}_${c}_${top.color.name}_${top.type.name}_');
        }
      }
    }
    return buffer.toString();
  }

  /// Clear caches (call when cache gets too large or between games)
  static void clearCaches() {
    _roadCache.clear();
    _edgeReachabilityCache.clear();
  }

  /// Manage cache size
  static void _manageCacheSize() {
    if (_roadCache.length > _maxCacheSize) {
      _roadCache.clear();
    }
    if (_edgeReachabilityCache.length > _maxCacheSize) {
      _edgeReachabilityCache.clear();
    }
  }

  /// Check if a position is controlled by a color for road-building purposes
  static bool controlsForRoad(GameState state, Position pos, PlayerColor color) {
    final top = state.board.stackAt(pos).topPiece;
    if (top == null) return false;
    if (top.color != color) return false;
    return top.type != PieceType.standing;
  }

  /// Check if player has a winning road (with caching)
  static bool hasRoad(GameState state, PlayerColor color) {
    final hash = _getBoardHash(state, color);

    if (_roadCache.containsKey(hash)) {
      return _roadCache[hash]!;
    }

    _manageCacheSize();

    final size = state.boardSize;

    // Check horizontal roads (left to right)
    for (int r = 0; r < size; r++) {
      final start = Position(r, 0);
      if (controlsForRoad(state, start, color)) {
        if (_canReachEdge(state, start, color, (p) => p.col == size - 1)) {
          _roadCache[hash] = true;
          return true;
        }
      }
    }

    // Check vertical roads (top to bottom)
    for (int c = 0; c < size; c++) {
      final start = Position(0, c);
      if (controlsForRoad(state, start, color)) {
        if (_canReachEdge(state, start, color, (p) => p.row == size - 1)) {
          _roadCache[hash] = true;
          return true;
        }
      }
    }

    _roadCache[hash] = false;
    return false;
  }

  /// BFS to check if a position can reach a specific edge
  static bool _canReachEdge(
    GameState state,
    Position start,
    PlayerColor color,
    bool Function(Position) isTargetEdge,
  ) {
    final visited = <Position>{};
    final queue = [start];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (visited.contains(current)) continue;
      visited.add(current);

      if (isTargetEdge(current)) return true;

      for (final neighbor in current.adjacentPositions(state.boardSize)) {
        if (!visited.contains(neighbor) &&
            controlsForRoad(state, neighbor, color)) {
          queue.add(neighbor);
        }
      }
    }
    return false;
  }

  /// Get all edges reachable from a position (optimized to avoid multiple BFS)
  static Set<String> getReachableEdges(
    GameState state,
    Position start,
    PlayerColor color,
  ) {
    final size = state.boardSize;
    final edges = <String>{};
    final visited = <Position>{};
    final queue = [start];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (visited.contains(current)) continue;
      visited.add(current);

      // Check which edges this position is on
      if (current.col == 0) edges.add('left');
      if (current.col == size - 1) edges.add('right');
      if (current.row == 0) edges.add('top');
      if (current.row == size - 1) edges.add('bottom');

      for (final neighbor in current.adjacentPositions(size)) {
        if (!visited.contains(neighbor) &&
            controlsForRoad(state, neighbor, color)) {
          queue.add(neighbor);
        }
      }
    }

    return edges;
  }

  /// Check if both players have roads (returns winner or null)
  static PlayerColor? getRoadWinner(GameState state) {
    // Check current player first (they moved last)
    if (hasRoad(state, state.currentPlayer)) {
      return state.currentPlayer;
    }
    // Check opponent
    if (hasRoad(state, state.opponent)) {
      return state.opponent;
    }
    return null;
  }

  /// Count winning threat positions for a player (with early termination)
  static int countThreats(
    GameState state,
    PlayerColor color, {
    int maxCount = 999,
  }) {
    var threats = 0;
    final board = state.board;
    final size = state.boardSize;

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final pos = Position(r, c);
        if (board.stackAt(pos).isEmpty) {
          final piece = Piece(type: PieceType.flat, color: color);
          final newBoard = board.placePiece(pos, piece);
          final testState = state.copyWith(board: newBoard);
          if (hasRoad(testState, color)) {
            threats++;
            // Early termination for fork detection (only need to know if >= 2)
            if (threats >= maxCount) {
              return threats;
            }
          }
        }
      }
    }
    return threats;
  }

  /// Evaluate if a position extends a chain toward completing a road
  /// Returns score based on connectivity to edges
  static double evaluateChainExtension(
    GameState state,
    Position pos,
    PlayerColor color,
  ) {
    if (!controlsForRoad(state, pos, color)) return 0;

    final size = state.boardSize;
    final neighbors = pos.adjacentPositions(size).where(
      (n) => controlsForRoad(state, n, color),
    ).toList();

    if (neighbors.isEmpty) return 0;

    double score = 0;

    // Use single BFS to find all reachable edges
    final edges = getReachableEdges(state, pos, color);

    // Score based on edge connectivity
    final connectsHorizontal = edges.contains('left') && edges.contains('right');
    final connectsVertical = edges.contains('top') && edges.contains('bottom');

    if (connectsHorizontal || connectsVertical) {
      score += 10; // Bridge position - extremely valuable
    } else if (edges.length >= 2) {
      score += 5; // Connects to multiple edges
    } else if (edges.length == 1) {
      score += 2; // Connects to one edge
    }

    // Bonus for being on edge
    if (pos.col == 0 || pos.row == 0 ||
        pos.col == size - 1 || pos.row == size - 1) {
      score += 2.5;
    }

    return score;
  }
}
