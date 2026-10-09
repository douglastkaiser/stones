import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

enum InteractionMode {
  /// No selection active
  idle,

  /// Ghost piece showing on empty cell, tap again to place
  /// Bottom bar shows piece type toggle
  placingPiece,

  /// Stack selected, valid destinations highlighted
  /// Tap same stack to cycle piece count
  /// Tap valid cell to start moving
  movingStack,

  /// Movement started, tap cells to drop pieces
  /// Tap same cell to cycle drop count, auto-confirms when all dropped
  droppingPieces,
}

class UIState {
  final Position? selectedPosition;
  final InteractionMode mode;
  final Direction? selectedDirection;
  final List<int> drops;
  final int piecesPickedUp;

  /// For placingPiece mode: the type of ghost piece to show
  final PieceType ghostPieceType;

  /// For droppingPieces mode: pending drop count for current position
  /// This is what will be dropped when tapping next cell or confirming
  final int pendingDropCount;

  const UIState({
    this.selectedPosition,
    this.mode = InteractionMode.idle,
    this.selectedDirection,
    this.drops = const [],
    this.piecesPickedUp = 0,
    this.ghostPieceType = PieceType.flat,
    this.pendingDropCount = 1,
  });

  /// Get the positions where pieces have been dropped so far
  List<Position> getDropPath() {
    if (selectedPosition == null || selectedDirection == null) return [];

    final path = <Position>[];
    var pos = selectedPosition!;
    for (var i = 0; i < drops.length; i++) {
      pos = selectedDirection!.apply(pos);
      path.add(pos);
    }
    return path;
  }

  /// Get the current "hand" position (where pieces are being held/will be dropped)
  /// This is the position AFTER all committed drops, where pendingDropCount will be dropped
  Position? getCurrentHandPosition() {
    if (selectedPosition == null || selectedDirection == null) return null;
    if (piecesPickedUp == 0) return null;

    var pos = selectedPosition!;
    // Move past each committed drop
    for (var i = 0; i < drops.length; i++) {
      pos = selectedDirection!.apply(pos);
    }
    // The hand position is one step past the last drop (or first step if no drops yet)
    return selectedDirection!.apply(pos);
  }

  /// Destinations reachable with the exact selected pickup count.
  Set<Position> getValidMoveDestinations(GameState gameState) {
    if (selectedPosition == null || mode != InteractionMode.movingStack) {
      return {};
    }
    final destinations = <Position>{};
    for (final direction in Direction.values) {
      if (GameRules.legalStackDrops(
        gameState,
        selectedPosition!,
        direction,
        piecesPickedUp,
      ).isNotEmpty) {
        // Selecting a direction always previews the adjacent square first.
        destinations.add(_positionAfter(direction, 1));
      }
    }
    return destinations;
  }

  /// Legal completion squares for the current spread, respecting pending drops.
  Set<Position> getValidDropDestinations(GameState gameState) {
    if (selectedPosition == null ||
        selectedDirection == null ||
        mode != InteractionMode.droppingPieces ||
        piecesPickedUp <= 0) {
      return {};
    }
    final direction = selectedDirection!;
    final pickup =
        piecesPickedUp + drops.fold<int>(0, (sum, drop) => sum + drop);
    final destinations = <Position>{};
    for (final pattern in GameRules.legalStackDrops(
      gameState,
      selectedPosition!,
      direction,
      pickup,
    )) {
      if (pattern.length <= drops.length) continue;
      if (!List.generate(drops.length, (i) => pattern[i] == drops[i])
          .every((matches) => matches)) {
        continue;
      }
      // The hand square can be a legal finish after cycling its drop count.
      destinations.add(_positionAfter(direction, drops.length + 1));
      if (pattern.length > drops.length + 1 &&
          pattern[drops.length] == pendingDropCount) {
        // Advancing visits one square, even when finishing requires more steps.
        destinations.add(_positionAfter(direction, drops.length + 2));
      }
    }
    return destinations;
  }

  bool canContinueDropping(GameState gameState) {
    final hand = getCurrentHandPosition();
    if (hand == null ||
        selectedDirection == null ||
        pendingDropCount <= 0 ||
        piecesPickedUp <= pendingDropCount) {
      return false;
    }
    return getValidDropDestinations(gameState)
        .contains(selectedDirection!.apply(hand));
  }

  Position _positionAfter(Direction direction, int steps) {
    var position = selectedPosition!;
    for (var i = 0; i < steps; i++) {
      position = direction.apply(position);
    }
    return position;
  }

  /// Calculate preview stacks for all positions during move operations.
  /// Returns a map of Position -> (previewStack, ghostPieces) where:
  /// - previewStack: what the stack at this position would look like after the move
  /// - ghostPieces: pieces that are "ghost" (being moved, shown semi-transparent)
  /// Returns null if not in a move preview state.
  Map<Position, (PieceStack previewStack, List<Piece> ghostPieces)>?
      getPreviewStacks(GameState gameState) {
    // Only calculate previews during stack movement modes
    if (mode != InteractionMode.movingStack &&
        mode != InteractionMode.droppingPieces) {
      return null;
    }

    if (selectedPosition == null || piecesPickedUp <= 0) return null;

    final sourceStack = gameState.board.stackAt(selectedPosition!);
    if (sourceStack.isEmpty) return null;

    final previews = <Position, (PieceStack, List<Piece>)>{};

    // In movingStack mode: show entire source stack as ghosts (move not confirmed)
    if (mode == InteractionMode.movingStack) {
      // ALL pieces at source are ghosts since the move is unconfirmed
      // The pickup count badge shows which ones will be picked up
      previews[selectedPosition!] = (
        PieceStack.empty, // no solid pieces - everything is part of the plan
        sourceStack.pieces, // entire stack as ghosts
      );
    }

    // In droppingPieces mode: calculate full preview of the move
    if (mode == InteractionMode.droppingPieces && selectedDirection != null) {
      final piecesToPickUp = piecesPickedUp + drops.fold(0, (a, b) => a + b);
      final actualPickup = piecesToPickUp.clamp(0, sourceStack.height).toInt();

      // Get the pieces being moved
      final (remaining, pickedUp) = sourceStack.pop(actualPickup);

      // Source position: remaining pieces are ghosts (move not confirmed)
      previews[selectedPosition!] = (PieceStack.empty, remaining.pieces);

      // Calculate drops along the path
      var currentPos = selectedPosition!;
      var piecesInHand = List<Piece>.from(pickedUp);

      // Process committed drops
      for (final dropCount in drops) {
        currentPos = selectedDirection!.apply(currentPos);
        final targetStack = gameState.board.stackAt(currentPos);

        // Get pieces to drop at this position
        final droppedPieces = piecesInHand.sublist(0, dropCount);
        piecesInHand = piecesInHand.sublist(dropCount);

        // Check if we need to flatten a wall (capstone moving onto standing stone)
        PieceStack baseStack = targetStack;
        if (baseStack.topPiece?.type == PieceType.standing &&
            droppedPieces.length == 1 &&
            droppedPieces.single.canFlattenWalls) {
          baseStack = baseStack.flattenTop();
        }

        // Preview shows existing pieces + dropped pieces as ghosts
        previews[currentPos] = (baseStack, droppedPieces);
      }

      // Current hand position: show ALL remaining pieces as ghosts
      // This gives the user a full preview of what will land there
      if (piecesInHand.isNotEmpty) {
        final handPos = getCurrentHandPosition();
        if (handPos != null) {
          final targetStack = gameState.board.stackAt(handPos);
          // Show all pieces still in hand as ghosts at the current position
          final ghostPieces = piecesInHand;

          // Check if we need to flatten a wall
          PieceStack baseStack = targetStack;
          if (baseStack.topPiece?.type == PieceType.standing &&
              ghostPieces.length == 1 &&
              ghostPieces.single.canFlattenWalls) {
            baseStack = baseStack.flattenTop();
          }

          previews[handPos] = (baseStack, ghostPieces);
        }
      }
    }

    return previews;
  }

  UIState copyWith({
    Position? selectedPosition,
    InteractionMode? mode,
    Direction? selectedDirection,
    List<int>? drops,
    int? piecesPickedUp,
    PieceType? ghostPieceType,
    int? pendingDropCount,
    bool clearSelection = false,
  }) {
    return UIState(
      selectedPosition:
          clearSelection ? null : (selectedPosition ?? this.selectedPosition),
      mode: mode ?? this.mode,
      selectedDirection:
          clearSelection ? null : (selectedDirection ?? this.selectedDirection),
      drops: drops ?? this.drops,
      piecesPickedUp: piecesPickedUp ?? this.piecesPickedUp,
      ghostPieceType: ghostPieceType ?? this.ghostPieceType,
      pendingDropCount: pendingDropCount ?? this.pendingDropCount,
    );
  }

  static const initial = UIState();
}

class UIStateNotifier extends StateNotifier<UIState> {
  UIStateNotifier() : super(UIState.initial);

  /// Select an empty cell for piece placement - shows ghost piece
  void selectCellForPlacement(Position pos, {PieceType type = PieceType.flat}) {
    state = UIState(
      selectedPosition: pos,
      mode: InteractionMode.placingPiece,
      ghostPieceType: type,
    );
  }

  /// Move ghost piece to different cell
  void moveGhostPiece(Position pos) {
    state = state.copyWith(
      selectedPosition: pos,
    );
  }

  /// Cycle the ghost piece type (flat -> wall -> capstone -> flat)
  void cycleGhostPieceType(
      {bool hasCapstones = true, bool hasFlatStones = true}) {
    PieceType nextType;
    switch (state.ghostPieceType) {
      case PieceType.flat:
        nextType = hasFlatStones
            ? PieceType.standing
            : (hasCapstones ? PieceType.capstone : PieceType.flat);
      case PieceType.standing:
        nextType = hasCapstones ? PieceType.capstone : PieceType.flat;
      case PieceType.capstone:
        nextType = hasFlatStones
            ? PieceType.flat
            : (hasCapstones ? PieceType.capstone : PieceType.flat);
    }
    state = state.copyWith(ghostPieceType: nextType);
  }

  /// Set a specific ghost piece type
  void setGhostPieceType(PieceType type) {
    state = state.copyWith(ghostPieceType: type);
  }

  /// Select a stack for movement
  void selectStack(Position pos, int maxPieces) {
    state = UIState(
      selectedPosition: pos,
      mode: InteractionMode.movingStack,
      piecesPickedUp: maxPieces,
    );
  }

  /// Cycle the number of pieces to pick up (max, max-1, ..., 1, max, ...)
  void cyclePiecesPickedUp(int maxPieces) {
    final current = state.piecesPickedUp;
    // Cycle down: max → max-1 → ... → 1 → max
    final next = current <= 1 ? maxPieces : current - 1;
    state = state.copyWith(piecesPickedUp: next);
  }

  /// Start moving in a direction - enters dropping mode without committing any drops yet
  void startMoving(Direction dir) {
    state = UIState(
      selectedPosition: state.selectedPosition,
      mode: InteractionMode.droppingPieces,
      selectedDirection: dir,
      piecesPickedUp: state.piecesPickedUp,
    );
  }

  /// Add a drop at the current hand position and move forward
  void addDrop(int count) {
    state = state.copyWith(
      drops: [...state.drops, count],
      piecesPickedUp: state.piecesPickedUp - count,
      pendingDropCount: 1, // Reset to 1 for next position
    );
  }

  /// Cycle the pending drop count for the current position
  void cyclePendingDropCount(int maxDrop) {
    final current = state.pendingDropCount;
    final next = current >= maxDrop ? 1 : current + 1;
    state = state.copyWith(pendingDropCount: next);
  }

  /// Set pending drop count directly
  void setPendingDropCount(int count) {
    state = state.copyWith(pendingDropCount: count);
  }

  void setPiecesPickedUp(int count) {
    state = state.copyWith(piecesPickedUp: count);
  }

  /// Undo drops FROM a specific position in the drop path.
  /// Clicking on drop position X means "I want my hand at position X".
  /// This undoes the drop at pathIndex AND all drops after it.
  /// Returns true if undo was performed.
  bool undoDropsTo(int pathIndex) {
    if (state.mode != InteractionMode.droppingPieces) return false;
    if (pathIndex < 0 || pathIndex >= state.drops.length) return false;

    // Calculate pieces to restore (sum of drops FROM pathIndex onwards)
    final dropsToUndo = state.drops.sublist(pathIndex);
    final piecesToRestore = dropsToUndo.fold(0, (sum, drop) => sum + drop);

    // Keep only drops BEFORE pathIndex
    final newDrops = state.drops.sublist(0, pathIndex);

    state = state.copyWith(
      drops: newDrops,
      piecesPickedUp: state.piecesPickedUp + piecesToRestore,
      pendingDropCount: 1,
    );
    return true;
  }

  /// Undo all drops and go back to the first drop position.
  /// Returns true if undo was performed.
  bool undoAllDrops() {
    if (state.mode != InteractionMode.droppingPieces) return false;
    if (state.drops.isEmpty) return false;

    // Calculate all pieces to restore
    final piecesToRestore = state.drops.fold(0, (sum, drop) => sum + drop);

    state = state.copyWith(
      drops: const [],
      piecesPickedUp: state.piecesPickedUp + piecesToRestore,
      pendingDropCount: 1,
    );
    return true;
  }

  void reset() {
    state = UIState.initial;
  }

  // Legacy methods for backwards compatibility
  void selectCell(Position pos) {
    selectCellForPlacement(pos);
  }

  void selectDirection(Direction dir) {
    startMoving(dir);
  }
}

final uiStateProvider = StateNotifierProvider<UIStateNotifier, UIState>((ref) {
  return UIStateNotifier();
});
