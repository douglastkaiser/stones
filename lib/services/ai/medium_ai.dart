import '../../models/models.dart';
import 'ai.dart';
import 'board_analysis.dart';

/// Advanced AI with 2-ply lookahead, fork detection, and strategic planning
class MediumStonesAI extends StonesAI {
  MediumStonesAI(super.random);

  final _generator = const AIMoveGenerator();

  // Limit how many moves we fully analyze for 2-ply to stay snappy
  static const _maxMovesToAnalyze = 20;

  @override
  Future<AIMove?> selectMove(GameState state) async {
    final moves = _generator.generateMoves(state);
    if (moves.isEmpty) return null;

    // Priority 1: Take a winning move immediately
    for (final move in moves) {
      if (_isWinningMove(state, move)) {
        return move;
      }
    }

    // Priority 2: Block opponent's immediate winning threats
    final blockingMoves = _findBlockingMoves(state, moves);
    if (blockingMoves.isNotEmpty) {
      // If there are multiple blocking moves needed, we might be in trouble
      // Pick the best one that also advances our position
      final scored = <(AIMove, double)>[];
      for (final move in blockingMoves) {
        scored.add((move, _scoreMove(state, move) + _evaluateMoveStrategically(state, move)));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.first.$1;
    }

    // Priority 3: Look for moves that create fork threats (2+ ways to win)
    final forkMoves = _findForkMoves(state, moves);
    if (forkMoves.isNotEmpty) {
      // Pick the fork move with the best overall score
      final scored = <(AIMove, double)>[];
      for (final move in forkMoves) {
        scored.add((move, _scoreMove(state, move) + 15)); // Big bonus for forks
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.first.$1;
    }

    // Priority 4: Block opponent's potential fork attempts (2-ply defense)
    final antiOpponentForkMoves = _findAntiOpponentForkMoves(state, moves);
    if (antiOpponentForkMoves.isNotEmpty) {
      final scored = <(AIMove, double)>[];
      for (final move in antiOpponentForkMoves) {
        scored.add((move, _scoreMove(state, move) + 8)); // Bonus for preventing forks
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.first.$1;
    }

    // Priority 5: Use 2-ply evaluation on top candidates
    // Score all moves quickly first
    final quickScored = <(AIMove, double)>[];
    for (final move in moves) {
      quickScored.add((move, _scoreMove(state, move)));
    }
    quickScored.sort((a, b) => b.$2.compareTo(a.$2));

    // Take top candidates for deeper analysis
    final topCandidates = quickScored.take(_maxMovesToAnalyze).map((e) => e.$1).toList();

    // Do 2-ply evaluation on top candidates
    final deepScored = <(AIMove, double)>[];
    for (final move in topCandidates) {
      final score = _evaluateTwoPly(state, move);
      deepScored.add((move, score));
    }

    deepScored.sort((a, b) => b.$2.compareTo(a.$2));
    final topScore = deepScored.first.$2;
    final bestMoves = deepScored.where((e) => e.$2 >= topScore - 0.5).toList();
    return bestMoves[random.nextInt(bestMoves.length)].$1;
  }

  /// Evaluate a move considering opponent's best response (2-ply)
  double _evaluateTwoPly(GameState state, AIMove move) {
    // Base score from heuristics
    var score = _scoreMove(state, move);

    // Apply our move
    final afterOurMove = _applyMove(state, move);
    if (afterOurMove == null) return score;

    // Check if we won (shouldn't happen as we check this earlier, but just in case)
    if (BoardAnalysis.hasRoad(afterOurMove, state.currentPlayer)) {
      return 1000; // Winning move
    }

    // Simulate opponent's turn
    final opponentState = _switchPlayer(afterOurMove);
    final opponentMoves = _generator.generateMoves(opponentState);

    // Check opponent's threats after our move
    var opponentWinningMoves = 0;
    var opponentBestThreats = 0;

    for (final oppMove in opponentMoves) {
      final afterOpp = _applyMove(opponentState, oppMove);
      if (afterOpp != null && BoardAnalysis.hasRoad(afterOpp, state.opponent)) {
        opponentWinningMoves++;
      }
    }

    // If opponent can win after our move, penalize heavily
    if (opponentWinningMoves > 0) {
      score -= 20 * opponentWinningMoves;
    }

    // Count how many threats opponent has after this
    opponentBestThreats = BoardAnalysis.countThreats(opponentState, state.opponent);
    score -= opponentBestThreats * 2;

    // Bonus for creating our own threats
    final ourThreats = BoardAnalysis.countThreats(afterOurMove, state.currentPlayer);
    score += ourThreats * 3;

    // Strategic position evaluation
    score += _evaluateMoveStrategically(state, move);

    return score;
  }

  /// Find moves that create multiple winning threats (forks)
  List<AIMove> _findForkMoves(GameState state, List<AIMove> moves) {
    final forks = <AIMove>[];

    for (final move in moves) {
      final afterMove = _applyMove(state, move);
      if (afterMove == null) continue;

      // Count how many winning moves we'd have after this move
      final ourThreats = BoardAnalysis.countThreats(afterMove, state.currentPlayer, maxCount: 2);
      if (ourThreats >= 2) {
        // This creates a fork - 2+ ways to win!
        forks.add(move);
      }
    }

    return forks;
  }

  /// Find moves that prevent opponent from creating forks on their next turn
  List<AIMove> _findAntiOpponentForkMoves(GameState state, List<AIMove> moves) {
    // First, check if opponent could create a fork if we make a neutral move
    final opponentState = _switchPlayer(state);
    final opponentMoves = _generator.generateMoves(opponentState);

    // Find opponent moves that would create forks
    final opponentForkPositions = <Position>{};
    for (final oppMove in opponentMoves) {
      final afterOpp = _applyMove(opponentState, oppMove);
      if (afterOpp == null) continue;

      final oppThreats = BoardAnalysis.countThreats(afterOpp, state.opponent, maxCount: 2);
      if (oppThreats >= 2) {
        // This opponent move creates a fork
        opponentForkPositions.addAll(_getAffectedPositions(oppMove));
      }
    }

    if (opponentForkPositions.isEmpty) return [];

    // Find our moves that interfere with opponent's fork attempts
    return moves.where((move) {
      final affected = _getAffectedPositions(move);
      return affected.any((p) => opponentForkPositions.contains(p));
    }).toList();
  }

  /// Additional strategic evaluation for a move
  double _evaluateMoveStrategically(GameState state, AIMove move) {
    double bonus = 0;

    if (move is AIPlacementMove) {
      // Bonus for controlling key positions
      final pos = move.position;

      // Strong bonus for bridge positions (connect two of our chains)
      final chainBonus = _evaluateChainExtension(state, pos, state.currentPlayer);
      bonus += chainBonus * 2;

      // Extra bonus for positions that extend toward both edges
      if (_extendsToBothEdges(state, pos, state.currentPlayer)) {
        bonus += 4;
      }
    } else if (move is AIStackMove) {
      // Bonus for capturing stacks that give us control
      final dest = _finalPosition(move.from, move.direction, move.drops.length);
      final targetStack = state.board.stackAt(dest);

      // Big bonus for capturing tall opponent stacks
      if (targetStack.topPiece?.color == state.opponent) {
        bonus += targetStack.height * 1.5;
      }

      // Bonus for using stack moves to extend chains
      final chainBonus = _evaluateChainExtension(state, dest, state.currentPlayer);
      bonus += chainBonus * 1.5;
    }

    return bonus;
  }

  /// Check if placing at this position would extend chains toward both edges
  bool _extendsToBothEdges(GameState state, Position pos, PlayerColor color) {
    final size = state.boardSize;

    // Check horizontal direction
    var connectsLeft = pos.col == 0;
    var connectsRight = pos.col == size - 1;

    // Check vertical direction
    var connectsTop = pos.row == 0;
    var connectsBottom = pos.row == size - 1;

    // Check what our adjacent pieces connect to (optimized with single BFS per neighbor)
    for (final neighbor in pos.adjacentPositions(size)) {
      if (BoardAnalysis.controlsForRoad(state, neighbor, color)) {
        final edges = BoardAnalysis.getReachableEdges(state, neighbor, color);
        if (edges.contains('left')) connectsLeft = true;
        if (edges.contains('right')) connectsRight = true;
        if (edges.contains('top')) connectsTop = true;
        if (edges.contains('bottom')) connectsBottom = true;
      }
    }

    return (connectsLeft && connectsRight) || (connectsTop && connectsBottom);
  }

  /// Check if a move results in a road win
  bool _isWinningMove(GameState state, AIMove move) {
    final newState = _applyMove(state, move);
    if (newState == null) return false;
    return BoardAnalysis.hasRoad(newState, state.currentPlayer);
  }

  /// Find moves that block opponent's immediate winning threats
  List<AIMove> _findBlockingMoves(GameState state, List<AIMove> moves) {
    final opponentWinningPositions = <Position>{};

    final opponentState = _switchPlayer(state);
    final opponentMoves = _generator.generateMoves(opponentState);

    for (final opponentMove in opponentMoves) {
      final afterOpponent = _applyMove(opponentState, opponentMove);
      if (afterOpponent != null && BoardAnalysis.hasRoad(afterOpponent, state.opponent)) {
        opponentWinningPositions.addAll(_getAffectedPositions(opponentMove));
      }
    }

    if (opponentWinningPositions.isEmpty) return [];

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

  /// Create a state with swapped current player
  GameState _switchPlayer(GameState state) {
    return state.copyWith(currentPlayer: state.opponent);
  }

  /// Apply a move and return the resulting state
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

    double score = -distanceFromCenter * 0.3;

    // Chain connectivity - primary offensive driver
    final chainBonus = _evaluateChainExtension(state, position, state.currentPlayer);
    score += chainBonus * 6; // Increased weight on chain building

    // Adjacency scoring
    final friendlyAdjacency = _adjacentControlled(state, position, state.currentPlayer);
    final opponentAdjacency = _adjacentControlled(state, position, state.opponent);
    score += friendlyAdjacency * 3; // Higher bonus for extending our road
    score += opponentAdjacency * 1.5; // Reduced blocking pressure

    // Edge connectivity - important for roads
    if (_touchesEdge(position, boardSize)) {
      score += 3;
    }

    // Piece type considerations
    if (move.pieceType == PieceType.capstone) {
      score += state.turnNumber < 8 ? -3 : 5;
    } else if (move.pieceType == PieceType.standing) {
      // Standing stones don't build roads - only use when tactically necessary
      score -= 3; // Base penalty - prefer flat stones
      final blockValue = _standingBlockValue(state, position);
      // Only worth it if blocking a real threat
      if (blockValue > 3) {
        score += blockValue * 0.8;
      }
    }

    return score + random.nextDouble() * 0.1;
  }

  double _scoreStackMove(GameState state, AIStackMove move) {
    final board = state.board;
    final stack = board.stackAt(move.from);
    final movingTop = stack.topPiece;
    final destination = _finalPosition(move.from, move.direction, move.drops.length);

    double score = 3;

    if (movingTop?.type == PieceType.capstone) {
      score += 5;
    }

    // Chain extension bonus - primary offensive consideration
    final chainBonus = _evaluateChainExtension(state, destination, state.currentPlayer);
    score += chainBonus * 5; // Increased for offense

    final friendlyAdjacency =
        _adjacentControlled(state, destination, state.currentPlayer);
    final opponentAdjacency =
        _adjacentControlled(state, destination, state.opponent);
    score += friendlyAdjacency * 3; // Higher for road building
    score += opponentAdjacency * 2;

    // Taking control of opponent space - offensive move
    final targetStack = board.stackAt(destination);
    if (targetStack.topPiece?.color == state.opponent) {
      score += 5; // Increased - capturing is offensive
    }

    // Flattening walls - very offensive, opens paths
    if (targetStack.topPiece?.type == PieceType.standing &&
        movingTop?.canFlattenWalls == true) {
      score += 7; // Increased - breaking walls is aggressive
    }

    // Edge bonus - roads need edges
    if (_touchesEdge(destination, state.boardSize)) {
      score += 3;
    }

    return score + random.nextDouble() * 0.2;
  }

  /// Evaluate how well a position extends road-building chains
  double _evaluateChainExtension(GameState state, Position pos, PlayerColor color) {
    // Use shared optimized implementation with single BFS per neighbor
    final baseScore = BoardAnalysis.evaluateChainExtension(state, pos, color);
    // Medium AI uses slightly lower multipliers than Hard AI
    return baseScore * 0.8;
  }

  /// Evaluate standing stone placement for blocking
  double _standingBlockValue(GameState state, Position pos) {
    final opponent = state.opponent;
    var blockValue = 0.0;

    final neighbors = pos.adjacentPositions(state.boardSize);
    for (final neighbor in neighbors) {
      if (BoardAnalysis.controlsForRoad(state, neighbor, opponent)) {
        blockValue += 2;
      }
    }

    // Extra value if it blocks a critical path
    if (_blocksChainExtension(state, pos, opponent)) {
      blockValue += 3;
    }

    return blockValue;
  }

  /// Check if placing here would block an opponent's chain extension
  bool _blocksChainExtension(GameState state, Position pos, PlayerColor opponent) {
    final size = state.boardSize;
    var blocksHorizontal = false;
    var blocksVertical = false;

    // Check if this position is between opponent pieces extending toward opposite edges
    for (final neighbor in pos.adjacentPositions(size)) {
      if (BoardAnalysis.controlsForRoad(state, neighbor, opponent)) {
        // Check what edges this connects to (optimized with single BFS)
        final edges = BoardAnalysis.getReachableEdges(state, neighbor, opponent);
        final reachesLeft = edges.contains('left');
        final reachesRight = edges.contains('right');
        final reachesTop = edges.contains('top');
        final reachesBottom = edges.contains('bottom');

        if (reachesLeft && !reachesRight) blocksHorizontal = true;
        if (reachesRight && !reachesLeft) blocksHorizontal = true;
        if (reachesTop && !reachesBottom) blocksVertical = true;
        if (reachesBottom && !reachesTop) blocksVertical = true;
      }
    }

    return blocksHorizontal || blocksVertical;
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
