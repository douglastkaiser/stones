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

  /// Get all valid destination cells when moving a stack
  /// Returns a set of positions that can be reached in each direction
  Set<Position> getValidMoveDestinations(GameState gameState) {
    if (selectedPosition == null) return {};
    if (mode != InteractionMode.movingStack) return {};

    final stack = gameState.board.stackAt(selectedPosition!);
    if (stack.isEmpty) return {};

    final topPiece = stack.topPiece!;
    final validDestinations = <Position>{};

    // Use piecesPickedUp as the max distance (carry limit)
    final maxDistance = piecesPickedUp;

    // Check each direction
    for (final direction in Direction.values) {
      var pos = selectedPosition!;
      var distance = 0;

      while (distance < maxDistance) {
        pos = direction.apply(pos);
        distance++;

        if (!gameState.board.isValidPosition(pos)) break;

        final targetStack = gameState.board.stackAt(pos);

        if (targetStack.canMoveOnto(topPiece)) {
          validDestinations.add(pos);
        } else if (targetStack.topPiece?.type == PieceType.standing &&
            topPiece.canFlattenWalls) {
          // Capstone can flatten a wall as final move
          validDestinations.add(pos);
          break;
        } else {
          break;
        }
      }
    }

    return validDestinations;
  }

  /// Get valid drop positions when in droppingPieces mode
  /// Returns positions we can continue dropping to (next cell in direction)
  Set<Position> getValidDropDestinations(GameState gameState) {
    if (selectedPosition == null || selectedDirection == null) return {};
    if (mode != InteractionMode.droppingPieces) return {};
    if (piecesPickedUp == 0) return {};

    final stack = gameState.board.stackAt(selectedPosition!);
    if (stack.isEmpty && drops.isEmpty) return {};

    // Get the piece that's moving (we need original stack's top piece for canMoveOnto checks)
    final originalStack = gameState.board.stackAt(selectedPosition!);
    final movingPieceType = originalStack.topPiece?.type ??
        (drops.isEmpty ? null : gameState.board.stackAt(getDropPath().first).topPiece?.type);
    if (movingPieceType == null) return {};

    // Create a dummy piece for checking
    final movingPiece = Piece(type: movingPieceType, color: PlayerColor.white);

    final validDestinations = <Position>{};

    // Get current hand position
    final handPos = getCurrentHandPosition();
    if (handPos == null) return {};

    // The current hand position is always valid (already validated when we got here)
    validDestinations.add(handPos);

    // Check if we can continue past current hand position
    if (piecesPickedUp > pendingDropCount) {
      final nextPos = selectedDirection!.apply(handPos);
      if (gameState.board.isValidPosition(nextPos)) {
        final targetStack = gameState.board.stackAt(nextPos);
        if (targetStack.canMoveOnto(movingPiece)) {
          validDestinations.add(nextPos);
        } else if (targetStack.topPiece?.type == PieceType.standing &&
            movingPiece.canFlattenWalls) {
          validDestinations.add(nextPos);
        }
      }
    }

    return validDestinations;
  }

  /// Check if we can continue dropping after dropping at current position
  bool canContinueDropping(GameState gameState) {
    if (selectedPosition == null || selectedDirection == null) return false;
    if (piecesPickedUp <= pendingDropCount) return false;

    final handPos = getCurrentHandPosition();
    if (handPos == null) return false;

    final nextPos = selectedDirection!.apply(handPos);
    if (!gameState.board.isValidPosition(nextPos)) return false;

    final originalStack = gameState.board.stackAt(selectedPosition!);
    if (originalStack.isEmpty) return false;

    final movingPiece = originalStack.topPiece!;
    final targetStack = gameState.board.stackAt(nextPos);

    if (targetStack.canMoveOnto(movingPiece)) {
      return true;
    } else if (targetStack.topPiece?.type == PieceType.standing &&
        movingPiece.canFlattenWalls) {
      return true;
    }

    return false;
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

    // In movingStack mode: show source with picked up pieces as ghosts
    if (mode == InteractionMode.movingStack) {
      // Source position: keep all pieces but mark top N as ghosts
      final piecesToPickUp = piecesPickedUp.clamp(0, sourceStack.height);
      final ghostPieces = sourceStack.pieces
          .sublist(sourceStack.height - piecesToPickUp);
      final remainingPieces = sourceStack.pieces
          .sublist(0, sourceStack.height - piecesToPickUp);

      previews[selectedPosition!] = (
        PieceStack(remainingPieces),
        ghostPieces,
      );
    }

    // In droppingPieces mode: calculate full preview of the move
    if (mode == InteractionMode.droppingPieces &&
        selectedDirection != null) {
      final piecesToPickUp = piecesPickedUp + drops.fold(0, (a, b) => a + b);
      final actualPickup = piecesToPickUp.clamp(0, sourceStack.height);

      // Get the pieces being moved
      final (remaining, pickedUp) = sourceStack.pop(actualPickup);

      // Source position: show remaining pieces, no ghosts
      previews[selectedPosition!] = (remaining, const []);

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
            droppedPieces.isNotEmpty &&
            droppedPieces.last.canFlattenWalls) {
          baseStack = baseStack.flattenTop();
        }

        // Preview shows existing pieces + dropped pieces as ghosts
        previews[currentPos] = (baseStack, droppedPieces);
      }

      // Current hand position: show pending drop as ghost
      if (piecesInHand.isNotEmpty) {
        final handPos = getCurrentHandPosition();
        if (handPos != null) {
          final targetStack = gameState.board.stackAt(handPos);
          final pendingDrop = pendingDropCount.clamp(0, piecesInHand.length);
          final ghostPieces = piecesInHand.sublist(0, pendingDrop);

          // Check if we need to flatten a wall
          PieceStack baseStack = targetStack;
          if (baseStack.topPiece?.type == PieceType.standing &&
              ghostPieces.isNotEmpty &&
              ghostPieces.last.canFlattenWalls) {
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
      selectedPosition: clearSelection ? null : (selectedPosition ?? this.selectedPosition),
      mode: mode ?? this.mode,
      selectedDirection: clearSelection ? null : (selectedDirection ?? this.selectedDirection),
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
  void cycleGhostPieceType({bool hasCapstones = true, bool hasFlatStones = true}) {
    PieceType nextType;
    switch (state.ghostPieceType) {
      case PieceType.flat:
        nextType = hasFlatStones ? PieceType.standing : (hasCapstones ? PieceType.capstone : PieceType.flat);
      case PieceType.standing:
        nextType = hasCapstones ? PieceType.capstone : PieceType.flat;
      case PieceType.capstone:
        nextType = hasFlatStones ? PieceType.flat : (hasCapstones ? PieceType.capstone : PieceType.flat);
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
