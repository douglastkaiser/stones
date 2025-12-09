import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

enum InteractionMode {
  idle,
  selectingPieceType,
  selectingMoveDirection,
  selectingDrops,
}

class UIState {
  final Position? selectedPosition;
  final InteractionMode mode;
  final Direction? selectedDirection;
  final List<int> drops;
  final int piecesPickedUp;

  const UIState({
    this.selectedPosition,
    this.mode = InteractionMode.idle,
    this.selectedDirection,
    this.drops = const [],
    this.piecesPickedUp = 0,
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

  /// Get the current "hand" position (where next drop would go)
  Position? getCurrentHandPosition() {
    if (selectedPosition == null || selectedDirection == null) return null;
    if (piecesPickedUp == 0) return null;

    var pos = selectedPosition!;
    for (var i = 0; i < drops.length; i++) {
      pos = selectedDirection!.apply(pos);
    }
    return selectedDirection!.apply(pos);
  }

  /// Get all valid destination cells when selecting move direction
  /// Returns a set of positions that can be reached in each direction
  /// Limited by the number of pieces that can be picked up (min of stack height and board size)
  Set<Position> getValidMoveDestinations(GameState gameState) {
    if (selectedPosition == null) return {};
    if (mode != InteractionMode.selectingMoveDirection) return {};

    final stack = gameState.board.stackAt(selectedPosition!);
    if (stack.isEmpty) return {};

    final topPiece = stack.topPiece!;
    final validDestinations = <Position>{};

    // Maximum distance is limited by pieces we can pick up (carry limit)
    final maxDistance = stack.height > gameState.boardSize
        ? gameState.boardSize
        : stack.height;

    // Check each direction
    for (final direction in Direction.values) {
      var pos = selectedPosition!;
      var distance = 0;

      // Keep checking positions in this direction until we can't move further
      // or we've reached the maximum distance based on pieces we can pick up
      while (distance < maxDistance) {
        pos = direction.apply(pos);
        distance++;

        if (!gameState.board.isValidPosition(pos)) break;

        final targetStack = gameState.board.stackAt(pos);

        // Check if we can move onto this cell
        if (targetStack.canMoveOnto(topPiece)) {
          validDestinations.add(pos);
          // Continue checking further in this direction
        } else if (targetStack.topPiece?.type == PieceType.standing &&
            topPiece.canFlattenWalls) {
          // Capstone can flatten a wall as final move
          validDestinations.add(pos);
          break; // Can't continue past a wall even after flattening
        } else {
          break; // Can't move onto this cell
        }
      }
    }

    return validDestinations;
  }

  UIState copyWith({
    Position? selectedPosition,
    InteractionMode? mode,
    Direction? selectedDirection,
    List<int>? drops,
    int? piecesPickedUp,
    bool clearSelection = false,
  }) {
    return UIState(
      selectedPosition: clearSelection ? null : (selectedPosition ?? this.selectedPosition),
      mode: mode ?? this.mode,
      selectedDirection: clearSelection ? null : (selectedDirection ?? this.selectedDirection),
      drops: drops ?? this.drops,
      piecesPickedUp: piecesPickedUp ?? this.piecesPickedUp,
    );
  }

  static const initial = UIState();
}

class UIStateNotifier extends StateNotifier<UIState> {
  UIStateNotifier() : super(UIState.initial);

  void selectCell(Position pos) {
    state = UIState(selectedPosition: pos, mode: InteractionMode.selectingPieceType);
  }

  void selectStack(Position pos, int maxPieces) {
    state = UIState(
      selectedPosition: pos,
      mode: InteractionMode.selectingMoveDirection,
      piecesPickedUp: maxPieces,
    );
  }

  void selectDirection(Direction dir) {
    state = state.copyWith(
      selectedDirection: dir,
      mode: InteractionMode.selectingDrops,
      drops: [],
    );
  }

  void addDrop(int count) {
    state = state.copyWith(
      drops: [...state.drops, count],
      piecesPickedUp: state.piecesPickedUp - count,
    );
  }

  void setPiecesPickedUp(int count) {
    state = state.copyWith(piecesPickedUp: count);
  }

  void reset() {
    state = UIState.initial;
  }
}

final uiStateProvider = StateNotifierProvider<UIStateNotifier, UIState>((ref) {
  return UIStateNotifier();
});
