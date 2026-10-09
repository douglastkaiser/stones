import '../../models/models.dart';
import 'ai.dart';
import 'board_analysis.dart';

/// Shared lookahead AI that powers every difficulty level.
/// The only difference between modes is the search depth used here.
class LookaheadStonesAI extends StonesAI {
  LookaheadStonesAI(
    super.random, {
    required this.searchDepth,
    this.maxBranchingLimit = _defaultMaxBranchingLimit,
    this.midBranchingLimit = _defaultMidBranchingLimit,
    this.deepBranchingLimit = _defaultDeepBranchingLimit,
    this.evaluationJitter = _defaultEvaluationJitter,
  });

  /// Number of plies to search (our move + opponent responses, etc.).
  final int searchDepth;

  final int maxBranchingLimit;
  final int midBranchingLimit;
  final int deepBranchingLimit;
  final double evaluationJitter;

  static const double _winScore = 10000;
  static const int _defaultMaxBranchingLimit = 20;
  static const int _defaultMidBranchingLimit = 14;
  static const int _defaultDeepBranchingLimit = 10;
  static const double _defaultEvaluationJitter = 0.01;

  final AIMoveGenerator _generator = const AIMoveGenerator();

  @override
  Future<AIMove?> selectMove(GameState state) async {
    if (state.isGameOver ||
        _terminalScore(state, state.currentPlayer, searchDepth) != null) {
      return null;
    }
    final moves = _generator.generateMoves(state);
    if (moves.isEmpty) return null;

    // Fast path: take an immediate win if available.
    final immediateWin = _findImmediateWinningMove(state, moves);
    if (immediateWin != null) {
      return immediateWin;
    }

    // Block any opponent winning threats before deeper search.
    final blockingMoves = _findThreatBlockingMoves(state, moves);
    if (blockingMoves.isNotEmpty) {
      final orderedBlocks = _orderMoves(state, blockingMoves, state.currentPlayer);
      return orderedBlocks.first.$1;
    }

    final orderedMoves = _orderMoves(state, moves, state.currentPlayer);

    AIMove? bestMove;
    var bestScore = double.negativeInfinity;

    for (final entry in orderedMoves.take(_branchLimitForDepth(searchDepth))) {
      final move = entry.$1;
      final applied = _applyMove(state, move);
      if (applied == null) continue;

      final nextState = _advanceTurn(applied);
      final score = -_search(
        nextState,
        searchDepth - 1,
        double.negativeInfinity,
        double.infinity,
        state.currentPlayer,
      );

      if (bestMove == null || score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove ?? orderedMoves.first.$1;
  }

  double _search(
    GameState state,
    int depth,
    double alpha,
    double beta,
    PlayerColor perspective,
  ) {
    final terminal = _terminalScore(state, perspective, depth);
    if (terminal != null) return terminal;

    if (depth <= 0) {
      return _evaluateState(state, perspective);
    }

    final moves = _generator.generateMoves(state);
    if (moves.isEmpty) {
      return _evaluateState(state, perspective);
    }

    final orderedMoves = _orderMoves(state, moves, perspective);

    for (final entry in orderedMoves.take(_branchLimitForDepth(depth))) {
      final move = entry.$1;
      final applied = _applyMove(state, move);
      if (applied == null) continue;

      final nextState = _advanceTurn(applied);
      final score = -_search(nextState, depth - 1, -beta, -alpha, perspective);

      if (score > alpha) {
        alpha = score;
      }
      if (alpha >= beta) {
        break;
      }
    }

    return alpha;
  }

  double? _terminalScore(GameState state, PlayerColor perspective, int depth) {
    final roadWinner = BoardAnalysis.getRoadWinner(
      state,
      lastMover: state.opponent,
    );
    if (roadWinner != null) {
      return roadWinner == perspective
          ? _winScore + depth
          : -_winScore - depth;
    }

    final flatResult = _flatResult(state);
    if (flatResult != null) {
      if (flatResult == GameResult.draw) return 0;
      final perspectiveResult = perspective == PlayerColor.white
          ? GameResult.whiteWins
          : GameResult.blackWins;
      return flatResult == perspectiveResult ? _winScore / 2 : -_winScore / 2;
    }

    return null;
  }

  double _evaluateState(GameState state, PlayerColor perspective) {
    final opponent = _opponentOf(perspective);

    // Immediate wins/losses dominate the evaluation.
    final roadWinner = BoardAnalysis.getRoadWinner(
      state,
      lastMover: state.opponent,
    );
    if (roadWinner != null) {
      return roadWinner == perspective ? _winScore : -_winScore;
    }

    final threatCount = BoardAnalysis.countThreats(state, perspective, maxCount: 3);
    final opponentThreats =
        BoardAnalysis.countThreats(state, opponent, maxCount: 3);

    final chainPotential = _chainPotential(state, perspective);
    final opponentChainPotential = _chainPotential(state, opponent);

    final flatAdvantage = _flatCount(state, perspective) - _flatCount(state, opponent);
    final reserveAdvantage = _reserveAdvantage(state, perspective, opponent);
    final controlSwing =
        _controlScore(state, perspective) - _controlScore(state, opponent);

    return threatCount * 12 - opponentThreats * 11 +
        chainPotential * 1.6 - opponentChainPotential * 1.3 +
        flatAdvantage * 3 + reserveAdvantage + controlSwing +
        random.nextDouble() * evaluationJitter;
  }

  List<(AIMove, double)> _orderMoves(
    GameState state,
    List<AIMove> moves,
    PlayerColor perspective,
  ) {
    final scored = <(AIMove, double)>[];

    for (final move in moves) {
      final applied = _applyMove(state, move);
      if (applied == null) continue;

      final postMoveState = _advanceTurn(applied);
      final score = _evaluateState(postMoveState, perspective);

      // Encourage moves that immediately win or block.
      final immediateWin = BoardAnalysis.getRoadWinner(
            applied,
            lastMover: state.currentPlayer,
          ) ==
          state.currentPlayer;
      final immediateBlock = BoardAnalysis.hasRoad(applied, state.opponent);

      final adjustedScore = score + (immediateWin ? 500 : 0) + (immediateBlock ? 100 : 0);
      scored.add((move, adjustedScore));
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored;
  }

  AIMove? _findImmediateWinningMove(GameState state, List<AIMove> moves) {
    for (final move in moves) {
      final applied = _applyMove(state, move);
      if (applied != null &&
          BoardAnalysis.getRoadWinner(
                applied,
                lastMover: state.currentPlayer,
              ) ==
              state.currentPlayer) {
        return move;
      }
    }
    return null;
  }

  List<AIMove> _findThreatBlockingMoves(GameState state, List<AIMove> moves) {
    final opponentState = _switchPlayer(state);
    final opponentMoves = _generator.generateMoves(opponentState);
    final threatenedPositions = <Position>{};

    for (final oppMove in opponentMoves) {
      final afterOpp = _applyMove(opponentState, oppMove);
      if (afterOpp != null && BoardAnalysis.hasRoad(afterOpp, state.opponent)) {
        threatenedPositions.addAll(_getAffectedPositions(oppMove));
      }
    }

    if (threatenedPositions.isEmpty) return const [];

    return moves.where((move) {
      final affected = _getAffectedPositions(move);
      return affected.any(threatenedPositions.contains);
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

  int _branchLimitForDepth(int depth) {
    if (depth >= 3) return deepBranchingLimit;
    if (depth == 2) return midBranchingLimit;
    return maxBranchingLimit;
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
    return GameRules.tryPlacePiece(state, move.position, move.pieceType);
  }

  GameState? _applyStackMove(GameState state, AIStackMove move) {
    return GameRules.tryMoveStack(state, move.from, move.direction, move.drops);
  }

  GameState _advanceTurn(GameState state) {
    return state.nextTurn();
  }

  PlayerColor _opponentOf(PlayerColor color) {
    return color == PlayerColor.white ? PlayerColor.black : PlayerColor.white;
  }

  GameResult? _flatResult(GameState state) => GameRules.flatResult(state);

  double _chainPotential(GameState state, PlayerColor color) {
    double score = 0;
    for (final pos in state.board.allPositions) {
      if (BoardAnalysis.controlsForRoad(state, pos, color)) {
        score += BoardAnalysis.evaluateChainExtension(state, pos, color);
      }
    }
    return score;
  }

  int _flatCount(GameState state, PlayerColor color) {
    var count = 0;
    for (final pos in state.board.allPositions) {
      final top = state.board.stackAt(pos).topPiece;
      if (top != null && top.color == color && top.type == PieceType.flat) {
        count++;
      }
    }
    return count;
  }

  double _reserveAdvantage(GameState state, PlayerColor perspective, PlayerColor opponent) {
    final ourPieces = state.piecesFor(perspective);
    final oppPieces = state.piecesFor(opponent);

    final flatAdvantage = ourPieces.flatStones - oppPieces.flatStones;
    final capAdvantage = ourPieces.capstones - oppPieces.capstones;

    return flatAdvantage * 0.5 + capAdvantage * 1.5;
  }

  double _controlScore(GameState state, PlayerColor color) {
    double score = 0;
    final size = state.boardSize;
    final center = (size - 1) / 2;

    for (final pos in state.board.allPositions) {
      final top = state.board.stackAt(pos).topPiece;
      if (top == null || top.color != color) continue;

      final influence = top.type == PieceType.standing ? 0.6 : 1.0;
      final distanceFromCenter =
          (pos.row - center).abs() + (pos.col - center).abs();
      score += (size - distanceFromCenter) * 0.35 * influence;

      final touchesEdge = pos.row == 0 ||
          pos.row == size - 1 ||
          pos.col == 0 ||
          pos.col == size - 1;
      if (touchesEdge) {
        score += 0.8 * influence;
      }
    }

    return score;
  }
}
