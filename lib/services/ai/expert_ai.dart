import '../../models/models.dart';
import 'ai.dart';
import 'board_analysis.dart';

/// Expert AI with iterative deepening minimax and alpha-beta pruning
/// Thinks up to 3 seconds for deep, strategic play
class ExpertStonesAI extends StonesAI {
  ExpertStonesAI(super.random);

  final _generator = const AIMoveGenerator();

  // Time budget for thinking
  static const _maxThinkingMs = 3000;
  static const _minDepth = 3;
  static const _maxDepth = 8;

  // Pruning parameters
  static const _maxTopMoves = 20;

  // Transposition table for position caching
  final Map<String, _TranspositionEntry> _transpositionTable = {};
  static const _maxTableSize = 50000;

  late DateTime _searchStartTime;
  bool _timeExpired = false;

  @override
  Future<AIMove?> selectMove(GameState state) async {
    final moves = _generator.generateMoves(state);
    if (moves.isEmpty) return null;

    _searchStartTime = DateTime.now();
    _timeExpired = false;
    _transpositionTable.clear();

    // Priority 1: Take a winning move immediately
    for (final move in moves) {
      if (_isWinningMove(state, move)) {
        return move;
      }
    }

    // Priority 2: Block opponent's immediate winning threats
    final blockingMoves = _findBlockingMoves(state, moves);
    if (blockingMoves.isNotEmpty) {
      if (blockingMoves.length == 1) {
        return blockingMoves.first;
      }
      // Multiple blocking options - pick the best one
      final scored = <(AIMove, double)>[];
      for (final move in blockingMoves) {
        final afterMove = _applyMove(state, move);
        final ourThreats = afterMove != null
            ? BoardAnalysis.countThreats(afterMove, state.currentPlayer, maxCount: 3)
            : 0;
        scored.add((move, _quickScore(state, move) + ourThreats * 10));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.first.$1;
    }

    // Priority 3: Look for fork moves (2+ winning threats)
    final forkMoves = _findForkMoves(state, moves);
    if (forkMoves.isNotEmpty) {
      final scored = <(AIMove, double)>[];
      for (final move in forkMoves) {
        scored.add((move, _quickScore(state, move) + 50));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.first.$1;
    }

    // Priority 4: Use iterative deepening search
    // Pre-score moves for move ordering
    final quickScored = <(AIMove, double)>[];
    for (final move in moves) {
      quickScored.add((move, _quickScore(state, move)));
    }
    quickScored.sort((a, b) => b.$2.compareTo(a.$2));

    // Take top candidates for deep search
    final candidates = quickScored.take(_maxTopMoves).map((e) => e.$1).toList();

    AIMove? bestMove;
    var bestScore = double.negativeInfinity;

    // Iterative deepening - start shallow and go deeper until time runs out
    for (var depth = _minDepth; depth <= _maxDepth; depth++) {
      if (_isTimeExpired()) break;

      final depthBest = await _searchAtDepth(state, candidates, depth);
      if (depthBest != null && !_timeExpired) {
        bestMove = depthBest.$1;
        bestScore = depthBest.$2;
      }

      // Allow other operations to run
      await Future.delayed(Duration.zero);
    }

    // Fallback to quick evaluation if search failed
    if (bestMove == null) {
      return candidates.isNotEmpty ? candidates.first : moves.first;
    }

    // Add small random factor among nearly equal moves
    final finalScored = <(AIMove, double)>[];
    for (final move in candidates) {
      final score = _evaluateMove(state, move, _minDepth);
      finalScored.add((move, score));
    }
    finalScored.sort((a, b) => b.$2.compareTo(a.$2));

    final topScore = finalScored.first.$2;
    final nearlyBest = finalScored.where((e) => e.$2 >= topScore - 2).toList();
    if (nearlyBest.length > 1) {
      return nearlyBest[random.nextInt(nearlyBest.length)].$1;
    }

    return bestMove;
  }

  bool _isTimeExpired() {
    if (_timeExpired) return true;
    final elapsed = DateTime.now().difference(_searchStartTime).inMilliseconds;
    if (elapsed >= _maxThinkingMs) {
      _timeExpired = true;
      return true;
    }
    return false;
  }

  Future<(AIMove, double)?> _searchAtDepth(
    GameState state,
    List<AIMove> moves,
    int depth,
  ) async {
    AIMove? bestMove;
    var bestScore = double.negativeInfinity;
    var alpha = double.negativeInfinity;
    const beta = double.infinity;

    for (final move in moves) {
      if (_isTimeExpired()) break;

      final score = _evaluateMove(state, move, depth, alpha: alpha, beta: beta);

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
      if (score > alpha) {
        alpha = score;
      }
    }

    if (bestMove == null) return null;
    return (bestMove, bestScore);
  }

  double _evaluateMove(
    GameState state,
    AIMove move,
    int depth, {
    double alpha = double.negativeInfinity,
    double beta = double.infinity,
  }) {
    final afterOurMove = _applyMove(state, move);
    if (afterOurMove == null) return -10000;

    // Check if we win
    if (BoardAnalysis.hasRoad(afterOurMove, state.currentPlayer)) {
      return 10000 + depth; // Prefer faster wins
    }

    // Check for flat win
    final flatWin = _checkFlatWin(afterOurMove, state.currentPlayer);
    if (flatWin != null) {
      return flatWin == state.currentPlayer ? 9000 + depth : -9000 - depth;
    }

    if (depth <= 0 || _isTimeExpired()) {
      return _evaluatePosition(afterOurMove, state.currentPlayer);
    }

    // Negamax with alpha-beta
    final opponentState = _switchPlayer(afterOurMove);
    return -_negamax(opponentState, state.opponent, depth - 1, -beta, -alpha);
  }

  double _negamax(
    GameState state,
    PlayerColor maximizingPlayer,
    int depth,
    double alpha,
    double beta,
  ) {
    // Check transposition table
    final hash = _getBoardHash(state, maximizingPlayer, depth);
    final cached = _transpositionTable[hash];
    if (cached != null && cached.depth >= depth) {
      if (cached.type == _NodeType.exact) return cached.score;
      if (cached.type == _NodeType.lowerBound && cached.score >= beta) {
        return cached.score;
      }
      if (cached.type == _NodeType.upperBound && cached.score <= alpha) {
        return cached.score;
      }
    }

    // Check for terminal conditions
    if (BoardAnalysis.hasRoad(state, maximizingPlayer)) {
      return 10000 + depth;
    }
    if (BoardAnalysis.hasRoad(state, maximizingPlayer == PlayerColor.white
        ? PlayerColor.black
        : PlayerColor.white)) {
      return -10000 - depth;
    }

    final flatWin = _checkFlatWin(state, maximizingPlayer);
    if (flatWin != null) {
      return flatWin == maximizingPlayer ? 9000 + depth : -9000 - depth;
    }

    if (depth <= 0 || _isTimeExpired()) {
      return _evaluatePosition(state, maximizingPlayer);
    }

    final moves = _generator.generateMoves(state);
    if (moves.isEmpty) {
      return _evaluatePosition(state, maximizingPlayer);
    }

    // Move ordering - quick score for better pruning
    final scoredMoves = <(AIMove, double)>[];
    for (final move in moves) {
      scoredMoves.add((move, _quickScore(state, move)));
    }
    scoredMoves.sort((a, b) => b.$2.compareTo(a.$2));

    // Only consider top moves to stay fast
    final topMoves = scoredMoves.take(15).map((e) => e.$1).toList();

    var bestScore = double.negativeInfinity;
    var nodeType = _NodeType.upperBound;
    var currentAlpha = alpha;

    for (final move in topMoves) {
      if (_isTimeExpired()) break;

      final afterMove = _applyMove(state, move);
      if (afterMove == null) continue;

      final opponent = maximizingPlayer == PlayerColor.white
          ? PlayerColor.black
          : PlayerColor.white;
      final opponentState = _switchPlayer(afterMove);
      final score = -_negamax(opponentState, opponent, depth - 1, -beta, -currentAlpha);

      if (score > bestScore) {
        bestScore = score;
      }

      if (score > currentAlpha) {
        currentAlpha = score;
        nodeType = _NodeType.exact;
      }

      if (currentAlpha >= beta) {
        nodeType = _NodeType.lowerBound;
        break; // Beta cutoff
      }
    }

    // Store in transposition table
    _storeTransposition(hash, depth, bestScore, nodeType);

    return bestScore;
  }

  String _getBoardHash(GameState state, PlayerColor player, int depth) {
    final buffer = StringBuffer();
    buffer.write('${player.name}_${state.boardSize}_${depth}_');
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

  void _storeTransposition(String hash, int depth, double score, _NodeType type) {
    if (_transpositionTable.length > _maxTableSize) {
      _transpositionTable.clear();
    }
    _transpositionTable[hash] = _TranspositionEntry(depth, score, type);
  }

  /// Comprehensive position evaluation
  double _evaluatePosition(GameState state, PlayerColor color) {
    double score = 0;
    final opponent = color == PlayerColor.white ? PlayerColor.black : PlayerColor.white;
    final size = state.boardSize;

    // Threat evaluation - high priority
    final ourThreats = BoardAnalysis.countThreats(state, color, maxCount: 4);
    final oppThreats = BoardAnalysis.countThreats(state, opponent, maxCount: 4);
    score += ourThreats * 25;
    score -= oppThreats * 20;

    // Multiple threats is very strong
    if (ourThreats >= 2) score += 30;
    if (oppThreats >= 2) score -= 25;

    // Board control - count controlled squares
    int ourControl = 0;
    int oppControl = 0;
    int ourEdges = 0;
    int oppEdges = 0;
    double centerScore = 0;

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final pos = Position(r, c);
        final stack = state.board.stackAt(pos);
        final top = stack.topPiece;
        if (top == null) continue;

        final isOurs = top.color == color;
        final countsForRoad = top.type != PieceType.standing;

        if (isOurs && countsForRoad) {
          ourControl++;
          // Edge positions
          if (r == 0 || r == size - 1 || c == 0 || c == size - 1) {
            ourEdges++;
          }
          // Center control (more valuable)
          final distFromCenter =
              (r - (size - 1) / 2).abs() + (c - (size - 1) / 2).abs();
          if (distFromCenter < size / 2) {
            centerScore += 1.5;
          }
        } else if (!isOurs && countsForRoad) {
          oppControl++;
          if (r == 0 || r == size - 1 || c == 0 || c == size - 1) {
            oppEdges++;
          }
          final distFromCenter =
              (r - (size - 1) / 2).abs() + (c - (size - 1) / 2).abs();
          if (distFromCenter < size / 2) {
            centerScore -= 1.5;
          }
        }
      }
    }

    score += (ourControl - oppControl) * 3;
    score += (ourEdges - oppEdges) * 2;
    score += centerScore;

    // Chain connectivity evaluation
    score += _evaluateChainConnectivity(state, color) * 4;
    score -= _evaluateChainConnectivity(state, opponent) * 3;

    // Piece count advantage for flat wins
    final ourPieces = state.getPieces(color);
    final oppPieces = state.getPieces(opponent);
    final flatAdvantage = _countFlatsOnBoard(state, color) - _countFlatsOnBoard(state, opponent);
    score += flatAdvantage * 2;

    // Remaining pieces (having pieces to play is good)
    score += (ourPieces.flatStones + oppPieces.flatStones) > 0
        ? (ourPieces.flatStones - oppPieces.flatStones) * 0.5
        : 0;

    // Capstone usage - value having capstone available
    if (ourPieces.capstones > 0 && state.turnNumber > 6) {
      score += 3;
    }

    return score;
  }

  int _countFlatsOnBoard(GameState state, PlayerColor color) {
    int count = 0;
    final size = state.boardSize;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final top = state.board.stackAt(Position(r, c)).topPiece;
        if (top != null && top.color == color && top.type == PieceType.flat) {
          count++;
        }
      }
    }
    return count;
  }

  double _evaluateChainConnectivity(GameState state, PlayerColor color) {
    double score = 0;
    final size = state.boardSize;

    // Find all controlled positions
    final controlled = <Position>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final pos = Position(r, c);
        if (BoardAnalysis.controlsForRoad(state, pos, color)) {
          controlled.add(pos);
        }
      }
    }

    if (controlled.isEmpty) return 0;

    // Evaluate largest connected chain
    final visited = <Position>{};
    var maxChainSize = 0;
    var bestChainEdges = <String>{};

    for (final start in controlled) {
      if (visited.contains(start)) continue;

      final chain = <Position>{};
      final edges = <String>{};
      final queue = [start];

      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        if (chain.contains(current)) continue;
        chain.add(current);
        visited.add(current);

        // Track edges
        if (current.col == 0) edges.add('left');
        if (current.col == size - 1) edges.add('right');
        if (current.row == 0) edges.add('top');
        if (current.row == size - 1) edges.add('bottom');

        for (final neighbor in current.adjacentPositions(size)) {
          if (!chain.contains(neighbor) &&
              BoardAnalysis.controlsForRoad(state, neighbor, color)) {
            queue.add(neighbor);
          }
        }
      }

      if (chain.length > maxChainSize) {
        maxChainSize = chain.length;
        bestChainEdges = edges;
      }
    }

    score += maxChainSize * 2;

    // Bonus for chains touching opposite edges
    if ((bestChainEdges.contains('left') && bestChainEdges.contains('right')) ||
        (bestChainEdges.contains('top') && bestChainEdges.contains('bottom'))) {
      score += 20;
    } else if (bestChainEdges.length >= 2) {
      score += 8;
    } else if (bestChainEdges.length == 1) {
      score += 3;
    }

    return score;
  }

  PlayerColor? _checkFlatWin(GameState state, PlayerColor currentPlayer) {
    // Check if board is full or pieces exhausted
    final size = state.boardSize;
    var emptySpaces = 0;

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (state.board.stackAt(Position(r, c)).isEmpty) {
          emptySpaces++;
        }
      }
    }

    if (emptySpaces > 0) {
      // Check if any player is out of pieces
      final whitePieces = state.getPieces(PlayerColor.white);
      final blackPieces = state.getPieces(PlayerColor.black);
      if (whitePieces.flatStones > 0 && blackPieces.flatStones > 0) {
        return null; // Game continues
      }
    }

    // Count flats
    final whiteFlats = _countFlatsOnBoard(state, PlayerColor.white);
    final blackFlats = _countFlatsOnBoard(state, PlayerColor.black);

    if (whiteFlats > blackFlats) return PlayerColor.white;
    if (blackFlats > whiteFlats) return PlayerColor.black;
    return null; // Tie or game continues
  }

  double _quickScore(GameState state, AIMove move) {
    double score = 0;

    if (move is AIPlacementMove) {
      final pos = move.position;
      final size = state.boardSize;
      final center = (size - 1) / 2;
      final distFromCenter = (pos.row - center).abs() + (pos.col - center).abs();

      // Slight center preference
      score -= distFromCenter * 0.3;

      // Adjacency to friendly pieces
      for (final neighbor in pos.adjacentPositions(size)) {
        final top = state.board.stackAt(neighbor).topPiece;
        if (top != null && top.color == state.currentPlayer &&
            top.type != PieceType.standing) {
          score += 3;
        }
        if (top != null && top.color == state.opponent) {
          score += 1.5; // Pressure/blocking
        }
      }

      // Edge positions
      if (pos.row == 0 || pos.row == size - 1 ||
          pos.col == 0 || pos.col == size - 1) {
        score += 2;
      }

      // Piece type
      if (move.pieceType == PieceType.capstone) {
        score += state.turnNumber < 8 ? -3 : 4;
      } else if (move.pieceType == PieceType.standing) {
        score -= 4;
      }
    } else if (move is AIStackMove) {
      score += 3; // Base bonus for stack moves

      final dest = _finalPosition(move.from, move.direction, move.drops.length);
      final targetStack = state.board.stackAt(dest);

      // Capturing opponent pieces
      if (targetStack.topPiece?.color == state.opponent) {
        score += 5 + targetStack.height;
      }

      // Flattening walls
      final movingTop = state.board.stackAt(move.from).topPiece;
      if (targetStack.topPiece?.type == PieceType.standing &&
          movingTop?.canFlattenWalls == true) {
        score += 8;
      }
    }

    return score + random.nextDouble() * 0.1;
  }

  List<AIMove> _findForkMoves(GameState state, List<AIMove> moves) {
    final forks = <AIMove>[];

    for (final move in moves) {
      final afterMove = _applyMove(state, move);
      if (afterMove == null) continue;

      final ourThreats = BoardAnalysis.countThreats(
        afterMove,
        state.currentPlayer,
        maxCount: 2,
      );
      if (ourThreats >= 2) {
        forks.add(move);
      }
    }

    return forks;
  }

  bool _isWinningMove(GameState state, AIMove move) {
    final newState = _applyMove(state, move);
    if (newState == null) return false;
    return BoardAnalysis.hasRoad(newState, state.currentPlayer);
  }

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

  GameState _switchPlayer(GameState state) {
    return state.copyWith(currentPlayer: state.opponent);
  }

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

  Position _finalPosition(Position from, Direction direction, int steps) {
    var current = from;
    for (var i = 0; i < steps; i++) {
      current = direction.apply(current);
    }
    return current;
  }
}

/// Node types for transposition table
enum _NodeType { exact, lowerBound, upperBound }

/// Entry in transposition table
class _TranspositionEntry {
  final int depth;
  final double score;
  final _NodeType type;

  _TranspositionEntry(this.depth, this.score, this.type);
}
