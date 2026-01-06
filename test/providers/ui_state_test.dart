import 'package:flutter_test/flutter_test.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/ui_state_provider.dart';

void main() {
  group('UIState drop path calculations', () {
    test('getDropPath returns correct positions after drops', () {
      // Origin at (2,2), moving right, dropped at (2,3) and (2,4)
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        drops: [1, 1],
      );

      final path = state.getDropPath();
      expect(path.length, 2);
      expect(path[0], const Position(2, 3)); // First drop position
      expect(path[1], const Position(2, 4)); // Second drop position
    });

    test('getCurrentHandPosition returns position after all drops', () {
      // Origin at (2,2), moving right, dropped 1 at (2,3), 1 remaining
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        drops: [1],
        piecesPickedUp: 1,
      );

      final handPos = state.getCurrentHandPosition();
      expect(handPos, const Position(2, 4)); // Hand is at next position
    });

    test('getCurrentHandPosition returns first position when no drops yet', () {
      // Origin at (2,2), moving right, no drops yet, 2 in hand
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        piecesPickedUp: 2,
      );

      final handPos = state.getCurrentHandPosition();
      expect(handPos, const Position(2, 3)); // First position after origin
    });

    test('getCurrentHandPosition returns null when no pieces in hand', () {
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        drops: [2],
      );

      expect(state.getCurrentHandPosition(), isNull);
    });
  });

  group('UIStateNotifier undo functionality', () {
    test('undoDropsTo should undo FROM the clicked position (not keep it)', () {
      // Scenario: picked up 3, dropped 1 at pos1, 1 at pos2, 1 remaining at pos3
      // User clicks pos1 -> should undo back to pos1, restoring 2 pieces
      final notifier = UIStateNotifier();

      // Setup: select stack and start moving
      notifier.selectStack(const Position(2, 2), 3);
      notifier.startMoving(Direction.right);

      // Drop 1 at first position
      notifier.addDrop(1); // drops = [1], remaining = 2
      // Drop 1 at second position
      notifier.addDrop(1); // drops = [1, 1], remaining = 1

      // Verify state before undo
      expect(notifier.state.drops, [1, 1]);
      expect(notifier.state.piecesPickedUp, 1);

      // Click on first drop position (pathIndex 0) should undo FROM there
      // Expected: hand should be at first position, ready to drop
      notifier.undoDropsTo(0);

      // After undoing FROM position 0, we should have:
      // - drops = [] (undid the drop at index 0 and everything after)
      // - piecesPickedUp = 3 (restored all pieces)
      expect(notifier.state.drops, isEmpty,
          reason: 'Clicking on drop position should undo that drop and all after');
      expect(notifier.state.piecesPickedUp, 3,
          reason: 'All pieces should be restored when undoing to first position');
    });

    test('undoDropsTo on second position keeps first drop', () {
      final notifier = UIStateNotifier();
      notifier.selectStack(const Position(2, 2), 3);
      notifier.startMoving(Direction.right);

      notifier.addDrop(1); // drops = [1], remaining = 2
      notifier.addDrop(1); // drops = [1, 1], remaining = 1

      // Click on second drop position (pathIndex 1)
      notifier.undoDropsTo(1);

      // Should keep first drop, undo second
      expect(notifier.state.drops, [1]);
      expect(notifier.state.piecesPickedUp, 2);
    });

    test('undoAllDrops restores all pieces', () {
      final notifier = UIStateNotifier();
      notifier.selectStack(const Position(2, 2), 3);
      notifier.startMoving(Direction.right);
      notifier.addDrop(1);
      notifier.addDrop(1);

      expect(notifier.state.drops, [1, 1]);
      expect(notifier.state.piecesPickedUp, 1);

      notifier.undoAllDrops();

      expect(notifier.state.drops, isEmpty);
      expect(notifier.state.piecesPickedUp, 3);
    });

    test('selectStack returns to movingStack mode with all pieces', () {
      final notifier = UIStateNotifier();
      notifier.selectStack(const Position(2, 2), 3);
      notifier.startMoving(Direction.right);
      notifier.addDrop(1);
      notifier.addDrop(1);

      // Clicking origin should restore all pieces and return to movingStack
      notifier.selectStack(const Position(2, 2), 3);

      expect(notifier.state.mode, InteractionMode.movingStack);
      expect(notifier.state.piecesPickedUp, 3);
      expect(notifier.state.drops, isEmpty);
    });
  });

  group('Confirm button visibility logic', () {
    // Helper to compute canConfirm matching _buildDroppingPiecesControls logic
    bool canConfirm(UIState state) {
      final remaining = state.piecesPickedUp;
      final drops = state.drops;
      final totalPieces = remaining + drops.fold<int>(0, (a, b) => a + b);
      final isStackMove = totalPieces > 1;
      final pendingDrop = state.pendingDropCount;

      final allPiecesCommitted = remaining == 0 && drops.isNotEmpty;
      final allPiecesSelected = remaining > 0 && pendingDrop == remaining;
      return isStackMove && (allPiecesCommitted || allPiecesSelected);
    }

    test('canConfirm when all pieces committed (remaining == 0)', () {
      const state = UIState(
        mode: InteractionMode.droppingPieces,
        drops: [1, 1],
        // piecesPickedUp defaults to 0
      );

      expect(canConfirm(state), isTrue,
          reason: 'Can confirm when all pieces are committed as drops');
    });

    test('canConfirm when all remaining pieces selected (pendingDrop == remaining)', () {
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        drops: [1], // One drop committed
        piecesPickedUp: 2, // 2 pieces in hand
        pendingDropCount: 2, // All 2 selected to drop
      );

      expect(canConfirm(state), isTrue,
          reason: 'Can confirm when pendingDrop == remaining (all pieces selected)');
    });

    test('cannot confirm when only some pieces selected', () {
      // pendingDropCount defaults to 1, so only 1 of 3 pieces is selected
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        drops: [1], // One drop committed
        piecesPickedUp: 3, // 3 pieces in hand, only 1 selected (default)
      );

      expect(canConfirm(state), isFalse,
          reason: 'Cannot confirm when only some pieces selected');
    });

    test('canConfirm for stack move with single piece remaining', () {
      // Single piece remaining from a larger 3-piece stack move
      // pendingDropCount defaults to 1, which equals remaining (1 piece)
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        drops: [1, 1], // Two drops committed
        piecesPickedUp: 1, // 1 piece in hand, 1 selected (default)
      );

      final totalPieces = state.piecesPickedUp + state.drops.fold<int>(0, (a, b) => a + b);
      expect(totalPieces, 3, reason: 'Total pieces in move is 3');
      expect(canConfirm(state), isTrue,
          reason: 'Even 1 remaining piece from larger stack needs confirm button');
    });

    test('cannot confirm single-piece moves via button (they auto-confirm)', () {
      const state = UIState(
        mode: InteractionMode.droppingPieces,
        drops: [1], // Single piece dropped
        // piecesPickedUp defaults to 0
      );

      final totalPieces = state.piecesPickedUp + state.drops.fold<int>(0, (a, b) => a + b);
      expect(totalPieces, 1, reason: 'This is a single-piece move');
      expect(canConfirm(state), isFalse,
          reason: 'Single-piece moves use tap-to-confirm, not confirm button');
    });

    test('canConfirm with no drops yet but all pieces selected', () {
      // 2-piece stack, no drops yet, pendingDrop == 2 (all selected)
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        piecesPickedUp: 2,
        pendingDropCount: 2, // All pieces selected
      );

      expect(canConfirm(state), isTrue,
          reason: 'Can confirm even with no drops if all pieces are selected');
    });
  });

  group('Cycling behavior', () {
    test('cyclePendingDropCount cycles through drop options', () {
      final notifier = UIStateNotifier();
      notifier.selectStack(const Position(2, 2), 3);
      notifier.startMoving(Direction.right);

      // Initially pendingDropCount should be 1
      expect(notifier.state.pendingDropCount, 1);

      // Cycle: 1 -> 2
      notifier.cyclePendingDropCount(3);
      expect(notifier.state.pendingDropCount, 2);

      // Cycle: 2 -> 3
      notifier.cyclePendingDropCount(3);
      expect(notifier.state.pendingDropCount, 3);

      // Cycle: 3 -> 1 (wrap around)
      notifier.cyclePendingDropCount(3);
      expect(notifier.state.pendingDropCount, 1);
    });

    test('single piece remaining does not need cycling', () {
      final notifier = UIStateNotifier();
      notifier.selectStack(const Position(2, 2), 3);
      notifier.startMoving(Direction.right);

      // Drop 2, leaving 1 in hand
      notifier.addDrop(2);
      expect(notifier.state.piecesPickedUp, 1);
      expect(notifier.state.pendingDropCount, 1);

      // Cycling with 1 piece just stays at 1
      notifier.cyclePendingDropCount(1);
      expect(notifier.state.pendingDropCount, 1,
          reason: 'With single piece, cycling wraps to 1');
    });
  });

  group('addDrop behavior', () {
    test('addDrop commits pending drop and moves hand', () {
      final notifier = UIStateNotifier();
      notifier.selectStack(const Position(2, 2), 3);
      notifier.startMoving(Direction.right);

      notifier.addDrop(1);

      expect(notifier.state.drops, [1]);
      expect(notifier.state.piecesPickedUp, 2);
      expect(notifier.state.pendingDropCount, 1,
          reason: 'pendingDropCount resets to 1 after drop');
    });

    test('addDrop with all remaining pieces leaves no pieces in hand', () {
      final notifier = UIStateNotifier();
      notifier.selectStack(const Position(2, 2), 2);
      notifier.startMoving(Direction.right);

      notifier.addDrop(2);

      expect(notifier.state.drops, [2]);
      expect(notifier.state.piecesPickedUp, 0);
    });
  });

  group('Stack move confirmation requirements', () {
    // Helper to check if continuing to next cell is allowed
    // This mirrors the logic in _handleDroppingPiecesTap
    bool canContinueToNextCell(UIState state) {
      final totalPieces = state.piecesPickedUp + state.drops.fold<int>(0, (a, b) => a + b);
      final isSinglePieceMove = totalPieces == 1;
      final allPiecesSelected = state.pendingDropCount == state.piecesPickedUp;

      // Can only continue if:
      // - Not a single-piece move
      // - Has pieces in hand
      // - NOT all pieces selected (must use confirm button for that)
      return !isSinglePieceMove &&
          state.piecesPickedUp > 0 &&
          !allPiecesSelected;
    }

    test('cannot continue to next cell when all pieces selected', () {
      // 3-piece stack, no drops yet, pendingDrop cycled to 3 (all selected)
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        piecesPickedUp: 3,
        pendingDropCount: 3, // All pieces selected
      );

      expect(canContinueToNextCell(state), isFalse,
          reason: 'When all pieces selected, must use confirm button, not tap next cell');
    });

    test('can continue to next cell when only some pieces selected', () {
      // 3-piece stack, no drops, pendingDrop = 1 (not all selected)
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        piecesPickedUp: 3,
        // pendingDropCount defaults to 1
      );

      expect(canContinueToNextCell(state), isTrue,
          reason: 'Can continue when only some pieces selected');
    });

    test('cannot continue when single piece remaining from larger stack', () {
      // Started with 3, dropped 2, 1 remaining with pendingDrop = 1
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        drops: [1, 1],
        piecesPickedUp: 1,
        // pendingDropCount defaults to 1, equals remaining
      );

      expect(canContinueToNextCell(state), isFalse,
          reason: 'Single piece remaining means all pieces selected, must use confirm');
    });
  });
}
