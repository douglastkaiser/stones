import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

/// Provider for the current game state
final gameStateProvider =
    StateNotifierProvider<GameStateNotifier, GameState>((ref) {
  return GameStateNotifier();
});

/// History stack for undo functionality
final _historyStackProvider = StateProvider<List<GameState>>((ref) => []);

/// Notifier that manages game state mutations
class GameStateNotifier extends StateNotifier<GameState> {
  final List<GameState> _history = [];

  GameStateNotifier() : super(GameState.initial(5)); // Default 5x5

  /// Start a new game with the given board size
  void newGame(int boardSize) {
    _history.clear();
    state = GameState.initial(boardSize);
  }

  /// Undo the last move
  bool undo() {
    if (_history.isEmpty) return false;
    state = _history.removeLast();
    return true;
  }

  /// Check if undo is available
  bool get canUndo => _history.isNotEmpty;

  /// Save current state to history before making a move
  void _saveToHistory() {
    _history.add(state);
    // Limit history to prevent memory issues
    if (_history.length > 100) {
      _history.removeAt(0);
    }
  }

  /// Place a piece at the given position
  /// During opening phase, places opponent's flat stone
  /// Returns true if the move was successful
  bool placePiece(Position pos, PieceType type) {
    if (state.isGameOver) return false;

    final stack = state.board.stackAt(pos);
    if (!stack.canPlaceOn) return false;

    _saveToHistory();

    // During opening phase, can only place flat stones of opponent's color
    if (state.isOpeningPhase) {
      if (type != PieceType.flat) return false;

      final opponentColor = state.opponent;
      final piece = Piece(type: PieceType.flat, color: opponentColor);
      final newBoard = state.board.placePiece(pos, piece);

      // Deduct from opponent's pieces
      final opponentPieces = state.piecesFor(opponentColor);
      final newOpponentPieces = opponentPieces.usePiece(PieceType.flat);

      // Create move record
      final move = PlacementMove(
        position: pos,
        pieceType: type,
        player: opponentColor,
      );
      final record = MoveRecord(
        move: move,
        notation: move.toNotation(state.boardSize),
        turnNumber: state.turnNumber,
        player: state.currentPlayer,
      );

      state = state
          .copyWith(
            board: newBoard,
            moveHistory: [...state.moveHistory, record],
            lastMoveFrom: null,
            lastMoveTo: pos,
          )
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

    // Create move record
    final move = PlacementMove(
      position: pos,
      pieceType: type,
      player: state.currentPlayer,
    );
    final record = MoveRecord(
      move: move,
      notation: move.toNotation(state.boardSize),
      turnNumber: state.turnNumber,
      player: state.currentPlayer,
    );

    state = state
        .copyWith(
          board: newBoard,
          moveHistory: [...state.moveHistory, record],
          lastMoveFrom: null,
          lastMoveTo: pos,
        )
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

    _saveToHistory();

    // Validate the move path
    var currentPos = from;
    final (remaining, pickedUp) = stack.pop(totalPicked);
    var board = state.board.setStack(from, remaining);
    var pieceIndex = 0;
    var flattenedWall = false;
    Position finalPos = from;

    for (final dropCount in drops) {
      currentPos = direction.apply(currentPos);
      finalPos = currentPos;

      if (!board.isValidPosition(currentPos)) {
        // Restore history since move failed
        _history.removeLast();
        return false;
      }

      var targetStack = board.stackAt(currentPos);
      final movingPiece = pickedUp[pieceIndex];

      if (!targetStack.canMoveOnto(movingPiece)) {
        _history.removeLast();
        return false;
      }

      // If capstone flattening a wall
      if (targetStack.topPiece?.type == PieceType.standing &&
          movingPiece.canFlattenWalls) {
        targetStack = targetStack.flattenTop();
        flattenedWall = true;
      }

      // Drop pieces
      final piecesToDrop = pickedUp.sublist(pieceIndex, pieceIndex + dropCount);
      board = board.setStack(currentPos, targetStack.pushAll(piecesToDrop));
      pieceIndex += dropCount;
    }

    // Create move record
    final move = StackMove(
      from: from,
      direction: direction,
      drops: drops,
      piecesPickedUp: totalPicked,
      flattenedWall: flattenedWall,
    );
    final record = MoveRecord(
      move: move,
      notation: move.toNotation(state.boardSize),
      turnNumber: state.turnNumber,
      player: state.currentPlayer,
    );

    state = state.copyWith(
      board: board,
      moveHistory: [...state.moveHistory, record],
      lastMoveFrom: from,
      lastMoveTo: finalPos,
    ).nextTurn();

    _checkWinCondition();
    return true;
  }

  /// Check for win conditions (road win or flat win)
  void _checkWinCondition() {
    // Check road win for both players
    for (final color in PlayerColor.values) {
      final roadPath = _findRoad(color);
      if (roadPath != null) {
        state = state.copyWith(
          phase: GamePhase.finished,
          result: color == PlayerColor.white
              ? GameResult.whiteWins
              : GameResult.blackWins,
          winReason: WinReason.road,
          roadPositions: roadPath,
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
        winReason: WinReason.flats,
      );
    }
  }

  /// Find a winning road for a player, returns the positions or null
  Set<Position>? _findRoad(PlayerColor color) {
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
      final path = _findPathToEdge(start, color, (p) => p.col == size - 1);
      if (path != null) return path;
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
      final path = _findPathToEdge(start, color, (p) => p.row == size - 1);
      if (path != null) return path;
    }

    return null;
  }

  /// Check if position is controlled by player for road purposes
  bool _controlsForRoad(Position pos, PlayerColor color) {
    final top = state.board.stackAt(pos).topPiece;
    if (top == null) return false;
    if (top.color != color) return false;
    return top.type != PieceType.standing;
  }

  /// BFS to find path to target edge, returns path positions or null
  Set<Position>? _findPathToEdge(
    Position start,
    PlayerColor color,
    bool Function(Position) isTargetEdge,
  ) {
    final visited = <Position>{};
    final parent = <Position, Position?>{start: null};
    final queue = [start];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (visited.contains(current)) continue;
      visited.add(current);

      if (isTargetEdge(current)) {
        // Reconstruct path
        final path = <Position>{};
        Position? pos = current;
        while (pos != null) {
          path.add(pos);
          pos = parent[pos];
        }
        return path;
      }

      for (final neighbor in current.adjacentPositions(state.boardSize)) {
        if (!visited.contains(neighbor) && _controlsForRoad(neighbor, color)) {
          parent[neighbor] = current;
          queue.add(neighbor);
        }
      }
    }

    return null;
  }

  /// Get valid moves for a position (for highlighting legal moves)
  Set<Position> getValidMoveTargets(Position from, int piecesToMove) {
    final targets = <Position>{};
    final stack = state.board.stackAt(from);

    if (stack.isEmpty || stack.controller != state.currentPlayer) {
      return targets;
    }

    final topPiece = stack.topPiece!;

    for (final direction in Direction.values) {
      var pos = from;
      for (var step = 0; step < piecesToMove; step++) {
        pos = direction.apply(pos);
        if (!state.board.isValidPosition(pos)) break;

        final targetStack = state.board.stackAt(pos);
        if (!targetStack.canMoveOnto(topPiece)) break;

        targets.add(pos);
      }
    }

    return targets;
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

/// Move history
final moveHistoryProvider = Provider<List<MoveRecord>>((ref) {
  return ref.watch(gameStateProvider.select((s) => s.moveHistory));
});

/// Can undo
final canUndoProvider = Provider<bool>((ref) {
  return ref.read(gameStateProvider.notifier).canUndo;
});
