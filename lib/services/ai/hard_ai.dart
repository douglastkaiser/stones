import '../../models/models.dart';
import 'ai.dart';
import 'board_analysis.dart';

/// Aggressive AI with 4-ply lookahead and minimax-style evaluation
/// Aware of all win conditions: roads, flat wins, and board control
class HardStonesAI extends StonesAI {
  HardStonesAI(super.random);

  final _generator = const AIMoveGenerator();

  // Pruning parameters - balanced for strong play
  static const _maxTopMoves = 18; // Candidates for deep search
  static const _maxOpponentMoves = 15; // Opponent responses to consider

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
      // Score blocking moves - pick one that also creates threats
      final scored = <(AIMove, double)>[];
      for (final move in blockingMoves) {
        final afterMove = _applyMove(state, move);
        final ourThreats = afterMove != null ? BoardAnalysis.countThreats(afterMove, state.currentPlayer, maxCount: 2) : 0;
        scored.add((move, _scoreMove(state, move) + ourThreats * 5));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.first.$1;
    }

    // Priority 3: Look for fork moves (2+ winning threats)
    final forkMoves = _findForkMoves(state, moves);
    if (forkMoves.isNotEmpty) {
      final scored = <(AIMove, double)>[];
      for (final move in forkMoves) {
        scored.add((move, _scoreMove(state, move) + 20));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.first.$1;
    }

    // Priority 4: Block opponent's fork attempts
    final antiOpponentForkMoves = _findAntiOpponentForkMoves(state, moves);
    if (antiOpponentForkMoves.isNotEmpty) {
      // Pick one that also advances our position
      final scored = <(AIMove, double)>[];
      for (final move in antiOpponentForkMoves) {
        scored.add((move, _scoreMove(state, move) + _evaluateOffensive(state, move) + 10));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.first.$1;
    }

    // Priority 5: Use 3-ply minimax on top candidates
    final quickScored = <(AIMove, double)>[];
    for (final move in moves) {
      quickScored.add((move, _scoreMove(state, move) + _evaluateOffensive(state, move)));
    }
    quickScored.sort((a, b) => b.$2.compareTo(a.$2));

    final topCandidates = quickScored.take(_maxTopMoves).map((e) => e.$1).toList();

    // 3-ply evaluation: our move -> opponent's best -> our best response
    final deepScored = <(AIMove, double)>[];
    for (final move in topCandidates) {
      final score = _evaluateThreePly(state, move);
      deepScored.add((move, score));
    }

    deepScored.sort((a, b) => b.$2.compareTo(a.$2));
    final topScore = deepScored.first.$2;
    final bestMoves = deepScored.where((e) => e.$2 >= topScore - 0.3).toList();
    return bestMoves[random.nextInt(bestMoves.length)].$1;
  }

  /// 3-ply minimax evaluation
  double _evaluateThreePly(GameState state, AIMove move) {
    final afterOurMove = _applyMove(state, move);
    if (afterOurMove == null) return -1000;

    // Check if we win
    if (BoardAnalysis.hasRoad(afterOurMove, state.currentPlayer)) {
      return 1000;
    }

    // Count our threats after this move
    final ourThreatsAfter = BoardAnalysis.countThreats(afterOurMove, state.currentPlayer);

    // Simulate opponent's turn
    final opponentState = _switchPlayer(afterOurMove);
    final opponentMoves = _generator.generateMoves(opponentState);

    // Check if opponent can win immediately - very bad
    for (final oppMove in opponentMoves) {
      final afterOpp = _applyMove(opponentState, oppMove);
      if (afterOpp != null && BoardAnalysis.hasRoad(afterOpp, state.opponent)) {
        return -500; // Losing position
      }
    }

    // Score opponent's best responses
    final oppScored = <(AIMove, double)>[];
    for (final oppMove in opponentMoves) {
      oppScored.add((oppMove, _scoreMove(opponentState, oppMove)));
    }
    oppScored.sort((a, b) => b.$2.compareTo(a.$2));

    // Consider opponent's best moves
    var worstCaseScore = double.infinity;
    final topOppMoves = oppScored.take(_maxOpponentMoves).map((e) => e.$1).toList();

    for (final oppMove in topOppMoves) {
      final afterOpp = _applyMove(opponentState, oppMove);
      if (afterOpp == null) continue;

      // Our response (3rd ply)
      final ourResponseState = _switchPlayer(afterOpp);
      final ourResponses = _generator.generateMoves(ourResponseState);

      // Can we win on our next turn?
      var canWin = false;
      for (final response in ourResponses) {
        final afterResponse = _applyMove(ourResponseState, response);
        if (afterResponse != null && BoardAnalysis.hasRoad(afterResponse, state.currentPlayer)) {
          canWin = true;
          break;
        }
      }

      double positionScore;
      if (canWin) {
        positionScore = 100; // We can force a win
      } else {
        // Evaluate position after opponent's move
        final oppThreats = BoardAnalysis.countThreats(afterOpp, state.opponent);
        final ourThreatsRemaining = BoardAnalysis.countThreats(afterOpp, state.currentPlayer);
        positionScore = (ourThreatsRemaining * 8) - (oppThreats * 6);
        positionScore += _evaluatePosition(afterOpp, state.currentPlayer);
      }

      if (positionScore < worstCaseScore) {
        worstCaseScore = positionScore;
      }
    }

    // Combine immediate evaluation with worst-case 3-ply
    var score = _scoreMove(state, move);
    score += ourThreatsAfter * 10; // Big bonus for creating threats
    score += worstCaseScore * 0.7; // Weight the lookahead
    score += _evaluateOffensive(state, move);

    return score;
  }

  /// Evaluate position strength for a player - aware of all win conditions
  double _evaluatePosition(GameState state, PlayerColor color) {
    double score = 0;
    final size = state.boardSize;

    // Count controlled positions, chain connectivity, and flat counts
    var ourEdgeCount = 0;
    var ourCenterControl = 0;
    var ourFlatCount = 0;
    var oppFlatCount = 0;
    var emptyCount = 0;

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final pos = Position(r, c);
        final top = state.board.stackAt(pos).topPiece;

        if (top == null) {
          emptyCount++;
          continue;
        }

        if (top.color == color) {
          if (top.type == PieceType.flat) {
            ourFlatCount++;
          }
          if (top.type != PieceType.standing) {
            // Edge positions valuable for roads
            if (r == 0 || r == size - 1 || c == 0 || c == size - 1) {
              ourEdgeCount++;
            }
            // Center control
            final distFromCenter = (r - (size - 1) / 2).abs() + (c - (size - 1) / 2).abs();
            if (distFromCenter < size / 2) {
              ourCenterControl++;
            }
          }
        } else if (top.type == PieceType.flat) {
          oppFlatCount++;
        }
      }
    }

    // Road building score
    score += ourEdgeCount * 2.5;
    score += ourCenterControl * 2;

    // Flat count advantage - important for flat wins
    final flatAdvantage = ourFlatCount - oppFlatCount;
    score += flatAdvantage * 3;

    // Bonus when board is getting full (flat win becomes more likely)
    final boardFillRatio = 1.0 - (emptyCount / (size * size));
    if (boardFillRatio > 0.6) {
      score += flatAdvantage * boardFillRatio * 4;
    }

    // Chain connectivity bonus
    score += _evaluateChainConnectivity(state, color) * 3;

    return score;
  }

  /// Evaluate how well chains connect across the board
  double _evaluateChainConnectivity(GameState state, PlayerColor color) {
    double score = 0;
    final size = state.boardSize;

    // Find connected components and their edge reach
    final visited = <Position>{};

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final pos = Position(r, c);
        if (visited.contains(pos)) continue;
        if (!BoardAnalysis.controlsForRoad(state, pos, color)) continue;

        // BFS to find connected chain
        final chain = <Position>{};
        final edges = <String>{};
        final queue = [pos];

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

        // Score based on chain size and edge connectivity
        score += chain.length * 0.5;
        if (edges.contains('left') && edges.contains('right')) {
          score += 8;
        } else if (edges.contains('top') && edges.contains('bottom')) {
          score += 8;
        } else if (edges.length >= 2) {
          score += 4;
        }
      }
    }

    return score;
  }

  /// Extra offensive evaluation
  double _evaluateOffensive(GameState state, AIMove move) {
    double bonus = 0;

    final afterMove = _applyMove(state, move);
    if (afterMove == null) return 0;

    // Bonus for creating threats
    final threatsBefore = BoardAnalysis.countThreats(state, state.currentPlayer);
    final threatsAfter = BoardAnalysis.countThreats(afterMove, state.currentPlayer);
    bonus += (threatsAfter - threatsBefore) * 8;

    // Bonus for reducing opponent's threats
    final oppThreatsBefore = BoardAnalysis.countThreats(state, state.opponent);
    final oppThreatsAfter = BoardAnalysis.countThreats(afterMove, state.opponent);
    bonus += (oppThreatsBefore - oppThreatsAfter) * 4;

    if (move is AIPlacementMove) {
      final chainBonus = _evaluateChainExtension(state, move.position, state.currentPlayer);
      bonus += chainBonus * 3;

      // Penalty for standing stones unless critical
      if (move.pieceType == PieceType.standing) {
        bonus -= 5;
      }
    } else if (move is AIStackMove) {
      // Aggressive stack moves
      final dest = _finalPosition(move.from, move.direction, move.drops.length);
      final targetStack = state.board.stackAt(dest);

      if (targetStack.topPiece?.color == state.opponent) {
        bonus += 6; // Capturing is aggressive
        bonus += targetStack.height * 2; // Bigger captures are better
      }
    }

    return bonus;
  }

  /// Find moves that create 2+ winning threats
  List<AIMove> _findForkMoves(GameState state, List<AIMove> moves) {
    final forks = <AIMove>[];

    for (final move in moves) {
      final afterMove = _applyMove(state, move);
      if (afterMove == null) continue;

      final ourThreats = BoardAnalysis.countThreats(afterMove, state.currentPlayer, maxCount: 2);
      if (ourThreats >= 2) {
        forks.add(move);
      }
    }

    return forks;
  }

  /// Find moves that prevent opponent forks
  List<AIMove> _findAntiOpponentForkMoves(GameState state, List<AIMove> moves) {
    final opponentState = _switchPlayer(state);
    final opponentMoves = _generator.generateMoves(opponentState);

    final opponentForkPositions = <Position>{};
    for (final oppMove in opponentMoves) {
      final afterOpp = _applyMove(opponentState, oppMove);
      if (afterOpp == null) continue;

      final oppThreats = BoardAnalysis.countThreats(afterOpp, state.opponent, maxCount: 2);
      if (oppThreats >= 2) {
        opponentForkPositions.addAll(_getAffectedPositions(oppMove));
      }
    }

    if (opponentForkPositions.isEmpty) return [];

    return moves.where((move) {
      final affected = _getAffectedPositions(move);
      return affected.any((p) => opponentForkPositions.contains(p));
    }).toList();
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

    double score = -distanceFromCenter * 0.2; // Less center preference

    // Chain connectivity - very important for offense
    final chainBonus = _evaluateChainExtension(state, position, state.currentPlayer);
    score += chainBonus * 7;

    // Adjacency scoring - favor our pieces
    final friendlyAdjacency = _adjacentControlled(state, position, state.currentPlayer);
    final opponentAdjacency = _adjacentControlled(state, position, state.opponent);
    score += friendlyAdjacency * 4;
    score += opponentAdjacency * 1;

    // Edge connectivity
    if (_touchesEdge(position, boardSize)) {
      score += 4;
    }

    // Piece type - strongly prefer flats
    if (move.pieceType == PieceType.capstone) {
      score += state.turnNumber < 10 ? -2 : 6;
    } else if (move.pieceType == PieceType.standing) {
      score -= 6; // Heavy penalty - only when absolutely needed
    }

    return score + random.nextDouble() * 0.05;
  }

  double _scoreStackMove(GameState state, AIStackMove move) {
    final board = state.board;
    final stack = board.stackAt(move.from);
    final movingTop = stack.topPiece;
    final destination = _finalPosition(move.from, move.direction, move.drops.length);

    double score = 4;

    if (movingTop?.type == PieceType.capstone) {
      score += 6;
    }

    // Chain extension - primary goal
    final chainBonus = _evaluateChainExtension(state, destination, state.currentPlayer);
    score += chainBonus * 6;

    final friendlyAdjacency =
        _adjacentControlled(state, destination, state.currentPlayer);
    final opponentAdjacency =
        _adjacentControlled(state, destination, state.opponent);
    score += friendlyAdjacency * 4;
    score += opponentAdjacency * 2;

    // Capturing - very aggressive
    final targetStack = board.stackAt(destination);
    if (targetStack.topPiece?.color == state.opponent) {
      score += 7 + targetStack.height;
    }

    // Flattening walls - opens our paths
    if (targetStack.topPiece?.type == PieceType.standing &&
        movingTop?.canFlattenWalls == true) {
      score += 10;
    }

    // Edge bonus
    if (_touchesEdge(destination, state.boardSize)) {
      score += 4;
    }

    return score + random.nextDouble() * 0.1;
  }

  double _evaluateChainExtension(GameState state, Position pos, PlayerColor color) {
    return BoardAnalysis.evaluateChainExtension(state, pos, color);
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
