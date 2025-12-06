import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

/// Provider for the current game state
final gameStateProvider =
    StateNotifierProvider<GameStateNotifier, GameState>((ref) {
  return GameStateNotifier();
});

/// Notifier that manages game state mutations
class GameStateNotifier extends StateNotifier<GameState> {
  GameStateNotifier() : super(GameState.initial(5)); // Default 5x5

  /// Start a new game with the given board size
  void newGame(int boardSize) {
    state = GameState.initial(boardSize);
  }

  /// Place a piece at the given position
  /// During opening phase, places opponent's flat stone
  /// Returns true if the move was successful
  bool placePiece(Position pos, PieceType type) {
    if (state.isGameOver) return false;

    final stack = state.board.stackAt(pos);
    if (!stack.canPlaceOn) return false;

    // During opening phase, can only place flat stones of opponent's color
    if (state.isOpeningPhase) {
      if (type != PieceType.flat) return false;

      final opponentColor = state.opponent;
      final piece = Piece(type: PieceType.flat, color: opponentColor);
      final newBoard = state.board.placePiece(pos, piece);

      // Deduct from opponent's pieces
      final opponentPieces = state.piecesFor(opponentColor);
      final newOpponentPieces = opponentPieces.usePiece(PieceType.flat);

      state = state
          .copyWith(board: newBoard)
          .updatePieces(opponentColor, newOpponentPieces)
          .nextTurn();

      return true;
    }

    // Normal placement
    final playerPieces = state.currentPlayerPieces;
    if (!playerPieces.hasPiece(type)) return false;

    final piece = Piece(type: type, color: state.currentPlayer);
    final newBoard = state.board.placePiece(pos, piece);
    final newPieces = playerPieces.usePiece(type);

    state = state
        .copyWith(board: newBoard)
        .updatePieces(state.currentPlayer, newPieces)
        .nextTurn();

    _checkWinCondition();
    return true;
  }

  /// Move a stack from one position in a direction
  /// [drops] is how many pieces to drop at each step
  /// Returns true if the move was successful
  bool moveStack(Position from, Direction direction, List<int> drops) {
    if (state.isGameOver || state.isOpeningPhase) return false;

    final stack = state.board.stackAt(from);
    if (stack.isEmpty) return false;
    if (stack.controller != state.currentPlayer) return false;

    final totalPicked = drops.fold(0, (sum, d) => sum + d);
    if (totalPicked > stack.height) return false;
    if (totalPicked > state.boardSize) return false; // Carry limit

    // Validate the move path
    var currentPos = from;
    final (remaining, pickedUp) = stack.pop(totalPicked);
    var board = state.board.setStack(from, remaining);
    var pieceIndex = 0;

    for (final dropCount in drops) {
      currentPos = direction.apply(currentPos);

      if (!board.isValidPosition(currentPos)) return false;

      var targetStack = board.stackAt(currentPos);
      final movingPiece = pickedUp[pieceIndex];

      if (!targetStack.canMoveOnto(movingPiece)) return false;

      // If capstone flattening a wall
      if (targetStack.topPiece?.type == PieceType.standing &&
          movingPiece.canFlattenWalls) {
        targetStack = targetStack.flattenTop();
      }

      // Drop pieces
      final piecesToDrop = pickedUp.sublist(pieceIndex, pieceIndex + dropCount);
      board = board.setStack(currentPos, targetStack.pushAll(piecesToDrop));
      pieceIndex += dropCount;
    }

    state = state.copyWith(board: board).nextTurn();
    _checkWinCondition();
    return true;
  }

  /// Check for win conditions (road win or flat win)
  void _checkWinCondition() {
    // Check road win for both players
    for (final color in PlayerColor.values) {
      if (_hasRoad(color)) {
        state = state.copyWith(
          phase: GamePhase.finished,
          result: color == PlayerColor.white
              ? GameResult.whiteWins
              : GameResult.blackWins,
        );
        return;
      }
    }

    // Check if board is full or either player is out of pieces
    final boardFull = state.board.allPositions
        .every((pos) => state.board.stackAt(pos).isNotEmpty);
    final whiteDone = state.whitePieces.total == 0;
    final blackDone = state.blackPieces.total == 0;

    if (boardFull || whiteDone || blackDone) {
      // Flat count wins
      var whiteFlats = 0;
      var blackFlats = 0;

      for (final pos in state.board.allPositions) {
        final top = state.board.stackAt(pos).topPiece;
        if (top?.type == PieceType.flat) {
          if (top?.color == PlayerColor.white) {
            whiteFlats++;
          } else {
            blackFlats++;
          }
        }
      }

      GameResult result;
      if (whiteFlats > blackFlats) {
        result = GameResult.whiteWins;
      } else if (blackFlats > whiteFlats) {
        result = GameResult.blackWins;
      } else {
        result = GameResult.draw;
      }

      state = state.copyWith(
        phase: GamePhase.finished,
        result: result,
      );
    }
  }

  /// Check if a player has a road (connected path edge to edge)
  bool _hasRoad(PlayerColor color) {
    final size = state.boardSize;

    // Check horizontal road (left to right)
    final leftEdge = <Position>[];
    for (int r = 0; r < size; r++) {
      final pos = Position(r, 0);
      if (_controlsForRoad(pos, color)) {
        leftEdge.add(pos);
      }
    }

    for (final start in leftEdge) {
      if (_canReachEdge(start, color, (p) => p.col == size - 1)) {
        return true;
      }
    }

    // Check vertical road (top to bottom)
    final topEdge = <Position>[];
    for (int c = 0; c < size; c++) {
      final pos = Position(0, c);
      if (_controlsForRoad(pos, color)) {
        topEdge.add(pos);
      }
    }

    for (final start in topEdge) {
      if (_canReachEdge(start, color, (p) => p.row == size - 1)) {
        return true;
      }
    }

    return false;
  }

  /// Check if position is controlled by player for road purposes
  /// (flat stones and capstones count, standing stones don't)
  bool _controlsForRoad(Position pos, PlayerColor color) {
    final top = state.board.stackAt(pos).topPiece;
    if (top == null) return false;
    if (top.color != color) return false;
    return top.type != PieceType.standing;
  }

  /// BFS to check if we can reach the target edge
  bool _canReachEdge(
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
        if (!visited.contains(neighbor) && _controlsForRoad(neighbor, color)) {
          queue.add(neighbor);
        }
      }
    }

    return false;
  }
}

/// Convenience providers

/// Current player
final currentPlayerProvider = Provider<PlayerColor>((ref) {
  return ref.watch(gameStateProvider.select((s) => s.currentPlayer));
});

/// Board size
final boardSizeProvider = Provider<int>((ref) {
  return ref.watch(gameStateProvider.select((s) => s.boardSize));
});

/// Game phase
final gamePhaseProvider = Provider<GamePhase>((ref) {
  return ref.watch(gameStateProvider.select((s) => s.phase));
});

/// Is game over
final isGameOverProvider = Provider<bool>((ref) {
  return ref.watch(gameStateProvider.select((s) => s.isGameOver));
});

/// Game result (null if not finished)
final gameResultProvider = Provider<GameResult?>((ref) {
  return ref.watch(gameStateProvider.select((s) => s.result));
});

/// White player's remaining pieces
final whitePiecesProvider = Provider<PlayerPieces>((ref) {
  return ref.watch(gameStateProvider.select((s) => s.whitePieces));
});

/// Black player's remaining pieces
final blackPiecesProvider = Provider<PlayerPieces>((ref) {
  return ref.watch(gameStateProvider.select((s) => s.blackPieces));
});
