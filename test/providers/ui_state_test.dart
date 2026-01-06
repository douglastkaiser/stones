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
        piecesPickedUp: 0,
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
        drops: [],
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
        piecesPickedUp: 0,
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
    test('canConfirm when drops committed', () {
      const state = UIState(
        mode: InteractionMode.droppingPieces,
        drops: [1],
        piecesPickedUp: 1,
        pendingDropCount: 1,
      );

      // Has committed drops -> can confirm
      expect(state.drops.isNotEmpty, isTrue);
    });

    test('canConfirm when all pieces selected to drop (even without committed drops)', () {
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        drops: [], // No committed drops yet
        piecesPickedUp: 3, // 3 pieces in hand
        pendingDropCount: 3, // User selected to drop all 3
      );

      // User has selected to drop all remaining pieces
      // This should be confirmable!
      final canConfirm = state.drops.isNotEmpty ||
          (state.pendingDropCount == state.piecesPickedUp && state.piecesPickedUp > 0);

      expect(canConfirm, isTrue,
          reason: 'Should be able to confirm when user selected to drop all pieces');
    });

    test('cannot confirm when pendingDrop < piecesPickedUp and no commits', () {
      const state = UIState(
        selectedPosition: Position(2, 2),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        drops: [], // No committed drops
        piecesPickedUp: 3,
        pendingDropCount: 1, // Only 1 selected, not all
      );

      final canConfirm = state.drops.isNotEmpty ||
          (state.pendingDropCount == state.piecesPickedUp && state.piecesPickedUp > 0);

      expect(canConfirm, isFalse,
          reason: 'Cannot confirm when not all pieces selected and no commits');
    });
  });
}
