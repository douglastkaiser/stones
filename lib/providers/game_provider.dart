import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

/// Provider for the current game state
final gameStateProvider =
    StateNotifierProvider<GameStateNotifier, GameState>((ref) {
  return GameStateNotifier();
});

// =============================================================================
// Move History & Notation
// =============================================================================

/// A record of a single move with portable notation
class MoveRecord {
  final String notation;
  final PlayerColor player;
  final int turnNumber;
  final Set<Position> affectedPositions;
  final GameState stateBefore;

  const MoveRecord({
    required this.notation,
    required this.player,
    required this.turnNumber,
    required this.affectedPositions,
    required this.stateBefore,
  });
}

/// Convert a position to algebraic notation (e.g., Position(0, 0) -> "a1")
String positionToNotation(Position pos, int boardSize) {
  final col = String.fromCharCode('a'.codeUnitAt(0) + pos.col);
  final row = (boardSize - pos.row).toString();
  return '$col$row';
}

/// Convert direction to notation symbol
String directionToNotation(Direction dir) {
  return switch (dir) {
    Direction.up => '+',
    Direction.down => '-',
    Direction.left => '<',
    Direction.right => '>',
  };
}

/// Generate notation for a placement move
String placementNotation(Position pos, PieceType type, int boardSize) {
  final posStr = positionToNotation(pos, boardSize);
  return switch (type) {
    PieceType.flat => posStr,
    PieceType.standing => 'S$posStr',
    PieceType.capstone => 'C$posStr',
  };
}

/// Generate notation for a stack move
String stackMoveNotation(
  Position from,
  Direction direction,
  List<int> drops,
  int totalPicked,
  int boardSize,
) {
  final posStr = positionToNotation(from, boardSize);
  final dirStr = directionToNotation(direction);

  // If picking up just 1 piece, omit the count prefix
  final countPrefix = totalPicked > 1 ? totalPicked.toString() : '';

  // If all pieces are dropped at once (single drop), omit the drop sequence
  final dropSequence = drops.length == 1 ? '' : drops.join();

  return '$countPrefix$posStr$dirStr$dropSequence';
}

/// Provider for move history
final moveHistoryProvider = StateNotifierProvider<MoveHistoryNotifier, List<MoveRecord>>((ref) {
  return MoveHistoryNotifier();
});

/// Notifier for move history
class MoveHistoryNotifier extends StateNotifier<List<MoveRecord>> {
  MoveHistoryNotifier() : super([]);

  void addMove(MoveRecord move) {
    state = [...state, move];
  }

  MoveRecord? removeLast() {
    if (state.isEmpty) return null;
    final last = state.last;
    state = state.sublist(0, state.length - 1);
    return last;
  }

  void clear() {
    state = [];
  }

  bool get canUndo => state.isNotEmpty;
}

/// Provider to track last move for highlighting
final lastMoveProvider = StateProvider<Set<Position>?>((ref) => null);

/// Animation event types
class AnimationEvent {
  final DateTime timestamp;
  AnimationEvent() : timestamp = DateTime.now();
}

/// Event when a piece is placed
class PiecePlacedEvent extends AnimationEvent {
  final Position position;
  final PieceType type;
  final PlayerColor color;
  PiecePlacedEvent(this.position, this.type, this.color);
}

/// Event when a stack is moved
class StackMovedEvent extends AnimationEvent {
  final Position from;
  final Direction direction;
  final List<int> drops;
  final List<Position> dropPositions;
  StackMovedEvent(this.from, this.direction, this.drops, this.dropPositions);
}

/// Event when a wall is flattened
class WallFlattenedEvent extends AnimationEvent {
  final Position position;
  WallFlattenedEvent(this.position);
}

/// Event when game is won with a road
class RoadWinEvent extends AnimationEvent {
  final Set<Position> roadPositions;
  final PlayerColor winner;
  RoadWinEvent(this.roadPositions, this.winner);
}

/// Animation state tracking
class AnimationState {
  final AnimationEvent? lastEvent;
  final Set<Position>? winningRoad;

  const AnimationState({this.lastEvent, this.winningRoad});

  AnimationState copyWith({
    AnimationEvent? lastEvent,
    Set<Position>? winningRoad,
    bool clearWinningRoad = false,
  }) {
    return AnimationState(
      lastEvent: lastEvent ?? this.lastEvent,
      winningRoad: clearWinningRoad ? null : (winningRoad ?? this.winningRoad),
    );
  }

  static const initial = AnimationState();
}

/// Animation state notifier
class AnimationStateNotifier extends StateNotifier<AnimationState> {
  AnimationStateNotifier() : super(AnimationState.initial);

  void piecePlaced(Position pos, PieceType type, PlayerColor color) {
    state = state.copyWith(lastEvent: PiecePlacedEvent(pos, type, color));
  }

  void stackMoved(Position from, Direction dir, List<int> drops, List<Position> dropPositions) {
    state = state.copyWith(lastEvent: StackMovedEvent(from, dir, drops, dropPositions));
  }

  void wallFlattened(Position pos) {
    state = state.copyWith(lastEvent: WallFlattenedEvent(pos));
  }

  void roadWin(Set<Position> roadPositions, PlayerColor winner) {
    state = state.copyWith(
      lastEvent: RoadWinEvent(roadPositions, winner),
      winningRoad: roadPositions,
    );
  }

  void reset() {
    state = AnimationState.initial;
  }
}

/// Provider for animation state
final animationStateProvider = StateNotifierProvider<AnimationStateNotifier, AnimationState>((ref) {
  return AnimationStateNotifier();
});

/// Notifier that manages game state mutations
class GameStateNotifier extends StateNotifier<GameState> {
  GameStateNotifier() : super(GameState.initial(5)); // Default 5x5

  /// History of game states for undo functionality (stores state before each move)
  final List<GameState> _history = [];

  /// Maximum history depth (unlimited by default, can be set to limit memory)
  int maxHistoryDepth = -1; // -1 = unlimited

  /// Callback for when history changes (for undo button state)
  void Function(bool canUndo)? onHistoryChanged;

  /// Information about the last move for history tracking
  MoveRecord? _lastMoveRecord;
  MoveRecord? get lastMoveRecord => _lastMoveRecord;

  /// Check if undo is available
  bool get canUndo => _history.isNotEmpty;

  /// Start a new game with the given board size
  void newGame(int boardSize) {
    _history.clear();
    _lastMoveRecord = null;
    state = GameState.initial(boardSize);
    onHistoryChanged?.call(false);
  }

  /// Load a game state (used for cloud saves)
  void loadState(GameState loadedState) {
    _history.clear();
    _lastMoveRecord = null;
    state = loadedState;
    onHistoryChanged?.call(_history.isNotEmpty);
  }

  /// Undo the last move
  bool undo() {
    if (_history.isEmpty) return false;

    state = _history.removeLast();
    _lastMoveRecord = null;
    onHistoryChanged?.call(_history.isNotEmpty);
    return true;
  }

  /// Save current state to history before making a move
  void _saveToHistory() {
    _history.add(state);

    // Limit history depth if configured
    if (maxHistoryDepth > 0 && _history.length > maxHistoryDepth) {
      _history.removeAt(0);
    }

    onHistoryChanged?.call(true);
  }

  /// Place a piece at the given position
  /// During opening phase, places opponent's flat stone
  /// Returns true if the move was successful
  bool placePiece(Position pos, PieceType type) {
    if (state.isGameOver) return false;

    final stack = state.board.stackAt(pos);
    if (!stack.canPlaceOn) return false;

    // Save state before making the move
    final stateBefore = state;
    _saveToHistory();

    // During opening phase, can only place flat stones of opponent's color
    if (state.isOpeningPhase) {
      if (type != PieceType.flat) {
        _history.removeLast(); // Rollback history save
        onHistoryChanged?.call(_history.isNotEmpty);
        return false;
      }

      final opponentColor = state.opponent;
      final piece = Piece(type: PieceType.flat, color: opponentColor);
      final newBoard = state.board.placePiece(pos, piece);

      // Deduct from opponent's pieces
      final opponentPieces = state.piecesFor(opponentColor);
      final newOpponentPieces = opponentPieces.usePiece(PieceType.flat);

      // Record move notation
      final notation = placementNotation(pos, type, state.boardSize);
      _lastMoveRecord = MoveRecord(
        notation: notation,
        player: state.currentPlayer,
        turnNumber: state.turnNumber,
        affectedPositions: {pos},
        stateBefore: stateBefore,
      );

      state = state
          .copyWith(board: newBoard)
          .updatePieces(opponentColor, newOpponentPieces)
          .nextTurn();

      return true;
    }

    // Normal placement
    final playerPieces = state.currentPlayerPieces;
    if (!playerPieces.hasPiece(type)) {
      _history.removeLast(); // Rollback history save
      onHistoryChanged?.call(_history.isNotEmpty);
      return false;
    }

    final piece = Piece(type: type, color: state.currentPlayer);
    final newBoard = state.board.placePiece(pos, piece);
    final newPieces = playerPieces.usePiece(type);

    // Record move notation
    final notation = placementNotation(pos, type, state.boardSize);
    _lastMoveRecord = MoveRecord(
      notation: notation,
      player: state.currentPlayer,
      turnNumber: state.turnNumber,
      affectedPositions: {pos},
      stateBefore: stateBefore,
    );

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

    // Save state before making the move
    final stateBefore = state;
    _saveToHistory();

    // Validate the move path and collect affected positions
    final affectedPositions = <Position>{from};
    var currentPos = from;
    final (remaining, pickedUp) = stack.pop(totalPicked);
    var board = state.board.setStack(from, remaining);
    var pieceIndex = 0;

    for (final dropCount in drops) {
      currentPos = direction.apply(currentPos);
      affectedPositions.add(currentPos);

      if (!board.isValidPosition(currentPos)) {
        _history.removeLast(); // Rollback history save
        onHistoryChanged?.call(_history.isNotEmpty);
        return false;
      }

      var targetStack = board.stackAt(currentPos);
      final movingPiece = pickedUp[pieceIndex];

      if (!targetStack.canMoveOnto(movingPiece)) {
        _history.removeLast(); // Rollback history save
        onHistoryChanged?.call(_history.isNotEmpty);
        return false;
      }

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

    // Record move notation
    final notation = stackMoveNotation(from, direction, drops, totalPicked, state.boardSize);
    _lastMoveRecord = MoveRecord(
      notation: notation,
      player: state.currentPlayer,
      turnNumber: state.turnNumber,
      affectedPositions: affectedPositions,
      stateBefore: stateBefore,
    );

    state = state.copyWith(board: board).nextTurn();
    _checkWinCondition();
    return true;
  }

  /// Callback for when a road win is detected (for animations)
  void Function(Set<Position> roadPositions, PlayerColor winner)? onRoadWin;

  /// End the game due to time expiration
  void setTimeExpired(PlayerColor loser) {
    if (state.isGameOver) return;

    final winner = loser == PlayerColor.white
        ? GameResult.blackWins
        : GameResult.whiteWins;

    state = state.copyWith(
      phase: GamePhase.finished,
      result: winner,
      winReason: WinReason.time,
    );
  }

  /// Check for win conditions (road win or flat win)
  void _checkWinCondition() {
    // Check road win for both players
    for (final color in PlayerColor.values) {
      final roadPositions = _findRoad(color);
      if (roadPositions != null) {
        state = state.copyWith(
          phase: GamePhase.finished,
          result: color == PlayerColor.white
              ? GameResult.whiteWins
              : GameResult.blackWins,
          winReason: WinReason.road,
        );
        onRoadWin?.call(roadPositions, color);
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

  /// Find a winning road for a player, returns the positions or null if no road
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
      if (path != null) {
        return path;
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
      final path = _findPathToEdge(start, color, (p) => p.row == size - 1);
      if (path != null) {
        return path;
      }
    }

    return null;
  }

  /// Check if position is controlled by player for road purposes
  /// (flat stones and capstones count, standing stones don't)
  bool _controlsForRoad(Position pos, PlayerColor color) {
    final top = state.board.stackAt(pos).topPiece;
    if (top == null) return false;
    if (top.color != color) return false;
    return top.type != PieceType.standing;
  }

  /// BFS to find a path to the target edge, returns positions in path or null
  Set<Position>? _findPathToEdge(
    Position start,
    PlayerColor color,
    bool Function(Position) isTargetEdge,
  ) {
    final visited = <Position>{};
    final parent = <Position, Position?>{};
    final queue = [start];
    parent[start] = null;

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
          queue.add(neighbor);
          parent[neighbor] ??= current;
        }
      }
    }

    return null;
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
