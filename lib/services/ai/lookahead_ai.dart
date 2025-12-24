import '../../models/models.dart';
import 'ai.dart';
import 'board_analysis.dart';

/// Shared lookahead AI that powers every difficulty level.
/// The only difference between modes is the search depth used here.
class LookaheadStonesAI extends StonesAI {
  LookaheadStonesAI(super.random, {required this.searchDepth});

  /// Number of plies to search (our move + opponent responses, etc.).
  final int searchDepth;

  static const double _winScore = 10000;
  static const int _branchingLimit = 20;

  final AIMoveGenerator _generator = const AIMoveGenerator();

  @override
  Future<AIMove?> selectMove(GameState state) async {
    final moves = _generator.generateMoves(state);
    if (moves.isEmpty) return null;

    final orderedMoves = _orderMoves(state, moves, state.currentPlayer);

    AIMove? bestMove;
    var bestScore = double.negativeInfinity;

    for (final entry in orderedMoves.take(_branchingLimit)) {
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

    for (final entry in orderedMoves.take(_branchingLimit)) {
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
    final opponent = _opponentOf(perspective);

    if (BoardAnalysis.hasRoad(state, perspective)) {
      return _winScore + depth;
    }
    if (BoardAnalysis.hasRoad(state, opponent)) {
      return -_winScore - depth;
    }

    final flatWinner = _flatWinner(state);
    if (flatWinner != null) {
      return flatWinner == perspective ? _winScore / 2 : -_winScore / 2;
    }

    return null;
  }

  double _evaluateState(GameState state, PlayerColor perspective) {
    final opponent = _opponentOf(perspective);

    // Immediate wins/losses dominate the evaluation.
    if (BoardAnalysis.hasRoad(state, perspective)) return _winScore;
    if (BoardAnalysis.hasRoad(state, opponent)) return -_winScore;

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
        random.nextDouble() * 0.01;
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
      final immediateWin = BoardAnalysis.hasRoad(applied, state.currentPlayer);
      final immediateBlock = BoardAnalysis.hasRoad(applied, state.opponent);

      final adjustedScore = score + (immediateWin ? 500 : 0) + (immediateBlock ? 100 : 0);
      scored.add((move, adjustedScore));
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored;
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

    final availablePieces = state.currentPlayerPieces;
    if (!availablePieces.hasPiece(move.pieceType)) return null;

    final piece = Piece(type: move.pieceType, color: state.currentPlayer);
    final newBoard = state.board.placePiece(move.position, piece);

    final updatedPieces = availablePieces.usePiece(move.pieceType);
    return state
        .updatePieces(state.currentPlayer, updatedPieces)
        .copyWith(board: newBoard);
  }

  GameState? _applyStackMove(GameState state, AIStackMove move) {
    final board = state.board;
    final stack = board.stackAt(move.from);
    if (stack.isEmpty || stack.controller != state.currentPlayer) return null;

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

  GameState _advanceTurn(GameState state) {
    return state.nextTurn();
  }

  PlayerColor _opponentOf(PlayerColor color) {
    return color == PlayerColor.white ? PlayerColor.black : PlayerColor.white;
  }

  PlayerColor? _flatWinner(GameState state) {
    var emptySpaces = 0;
    var whiteFlats = 0;
    var blackFlats = 0;

    for (final pos in state.board.allPositions) {
      final top = state.board.stackAt(pos).topPiece;
      if (top == null) {
        emptySpaces++;
        continue;
      }

      if (top.type == PieceType.flat) {
        if (top.color == PlayerColor.white) {
          whiteFlats++;
        } else {
          blackFlats++;
        }
      }
    }

    final whiteOutOfPieces = state.whitePieces.total == 0;
    final blackOutOfPieces = state.blackPieces.total == 0;
    final boardFull = emptySpaces == 0;

    if (boardFull || whiteOutOfPieces || blackOutOfPieces) {
      if (whiteFlats > blackFlats) return PlayerColor.white;
      if (blackFlats > whiteFlats) return PlayerColor.black;
    }

    return null;
  }

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
