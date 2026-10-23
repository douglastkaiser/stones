import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/move_selection.dart';
import 'package:stones/models/piece.dart';

const ivory = Stone(SeatId.ivory, PieceType.flat);
const charcoal = Stone(SeatId.charcoal, PieceType.flat);
const cap = Stone(SeatId.ivory, PieceType.capstone);
const wall = Stone(SeatId.charcoal, PieceType.standing);

MatchState position(BoardShape shape,
    {int seats = 2, Map<Cell, List<Stone>>? board}) {
  final config = MatchConfig(
      shape: shape,
      size: shape == BoardShape.square ? 5 : 2,
      seats: SeatId.values.take(seats).map(SeatConfig.new).toList());
  return MatchState.initial(config).copyWith(
      ply: seats,
      board: board ??
          {
            const Cell(0, 0): [charcoal, ivory, ivory]
          });
}

void main() {
  for (final shape in BoardShape.values) {
    for (var seats = 2; seats <= 4; seats++) {
      test(
          '$shape $seats seats stage actual bottom pieces and commit once empty',
          () {
        final game = position(shape, seats: seats);
        final selection = MoveSelection();
        selection.tap(game, const Cell(0, 0));
        expect(selection.carry, 3);
        expect(selection.planned, isNull);
        expect(selection.hand(game), [charcoal, ivory, ivory]);
        expect(selection.preview(game)!.stackAt(const Cell(0, 0)), isEmpty);
        selection.tap(game, const Cell(0, 0));
        expect(selection.carry, 2);
        selection.tap(game, const Cell(0, 0));
        expect(selection.carry, 1);
        selection.tap(game, const Cell(0, 0));
        expect(
          selection.carry,
          3,
          reason: 'Pickup wraps to the carry maximum',
        );
        expect(selection.tap(game, const Cell(1, 0)), isFalse);
        expect(selection.drops, [1]);
        expect(selection.remaining, 2);
        expect(selection.planned, isNull);
        expect(selection.preview(game)!.stackAt(const Cell(1, 0)), [charcoal]);
        expect(selection.hand(game), [ivory, ivory]);
        expect(selection.destinations(game), {const Cell(2, 0)});
        selection.tap(game, const Cell(1, 0));
        expect(selection.drops, [2]);
        expect(selection.tap(game, const Cell(2, 0)), isFalse);
        expect(selection.planned!.drops, [2, 1]);
        expect(selection.remaining, 0);
        expect(selection.hand(game), isEmpty);
        final committed = MatchRules.apply(game, selection.planned!)!;
        expect(committed.stackAt(const Cell(1, 0)), [charcoal, ivory]);
        expect(committed.stackAt(const Cell(2, 0)), [ivory]);
        expect(committed.board, selection.preview(game)!.board);
        expect(game.stackAt(const Cell(0, 0)), [charcoal, ivory, ivory]);
        expect(game.ply, seats);
        selection.undoDrop();
        expect(selection.drops, [2]);
        expect(selection.planned, isNull);
        expect(selection.hand(game), [ivory]);
        selection.undoDrop();
        expect(selection.drops, [1]);
        selection.undoDrop();
        expect(selection.drops, isEmpty);
        expect(selection.direction, isNull);
        expect(selection.carry, 3);
        selection.clear();
        expect(selection.source, isNull);
        expect(selection.preview(game), isNull);
      });
    }

    for (final step in position(shape).geometry.directions) {
      test('$shape $step drag drops one and retains the rest in hand', () {
        final origin =
            shape == BoardShape.square ? const Cell(1, 1) : const Cell(0, 0);
        final game = position(shape, board: {
          origin: [charcoal, ivory, ivory]
        });
        final selection = MoveSelection();
        selection.swipe(game, origin, step);
        expect(selection.drops, [1]);
        expect(selection.hand(game), [ivory, ivory]);
        expect(selection.preview(game)!.stackAt(origin.step(step)), [charcoal]);
        expect(selection.planned, isNull);
        selection.dropRemaining(game);
        expect(selection.planned!.drops, [3]);
        selection.undoDrop();
        expect(selection.drops, [1]);
        expect(selection.remaining, 2);
      });
    }

    test('$shape mixed board and button drops can be revised and undone', () {
      final game = position(shape);
      final selection = MoveSelection()..tap(game, const Cell(0, 0));
      selection.tap(game, const Cell(1, 0));
      selection.adjustDrop(game, 1);
      expect(selection.drops, [2]);
      selection.tap(game, const Cell(2, 0));
      expect(selection.planned, isNotNull);
      expect(selection.canAdjustDrop(game, 1), isFalse);
      selection.adjustDrop(game, -1);
      expect(selection.drops, [2]);
      expect(selection.hand(game), [ivory]);
      selection.adjustDrop(game, -1);
      expect(selection.drops, [1]);
      selection.adjustDrop(game, -1);
      expect(selection.started, isFalse);
      expect(selection.direction, isNull);
      selection.undoDrop();
      expect(selection.drops, [1]);
      expect(selection.direction, Step.east);
      selection.undoDrop();
      expect(selection.drops, [2]);
      selection.undoDrop();
      expect(selection.planned!.drops, [2, 1]);
      expect(game.stackAt(const Cell(0, 0)), [charcoal, ivory, ivory]);
    });

    test('$shape a changed pickup cannot undo drops made with an older hand',
        () {
      final game = position(shape);
      final selection = MoveSelection()..tap(game, const Cell(0, 0));
      selection.tap(game, const Cell(1, 0));
      selection.adjustDrop(game, -1);
      selection.setCarry(1);
      selection.undoDrop();
      expect(selection.started, isFalse);
      expect(selection.hand(game), [ivory]);
      expect(selection.direction, isNull);
    });

    test('$shape undo restores the old direction after restarting a spread',
        () {
      final game = position(shape);
      final selection = MoveSelection()..tap(game, const Cell(0, 0));
      selection.tap(game, const Cell(1, 0));
      selection.adjustDrop(game, -1);
      selection.tap(game, const Cell(0, 1));
      expect(selection.current, const Cell(0, 1));
      selection.undoDrop();
      expect(selection.started, isFalse);
      selection.undoDrop();
      expect(selection.current, const Cell(1, 0));
      expect(selection.direction, Step.east);
      expect(selection.preview(game)!.stackAt(const Cell(1, 0)), [charcoal]);
      expect(selection.preview(game)!.stackAt(const Cell(0, 1)), isEmpty);
      selection.clear();
      expect(selection.canUndoDrop, isFalse);
      expect(selection.source, isNull);
    });

    test('$shape decrement restores a crushed wall and can be undone', () {
      final game = position(
        shape,
        board: {
          const Cell(0, 0): [ivory, cap],
          const Cell(2, 0): [wall],
        },
      );
      final selection = MoveSelection()..tap(game, const Cell(0, 0));
      selection.tap(game, const Cell(1, 0));
      expect(selection.canAdjustDrop(game, 1), isTrue);
      selection.tap(game, const Cell(2, 0));
      selection.adjustDrop(game, -1);
      expect(selection.preview(game)!.topAt(const Cell(2, 0)), wall);
      selection.undoDrop();
      expect(selection.preview(game)!.topAt(const Cell(2, 0)), cap);
      expect(selection.canAdjustDrop(game, 1), isFalse);
    });

    test('$shape partial pickup preserves buried stones and piece identity',
        () {
      final game = position(shape);
      final selection = MoveSelection()..tap(game, const Cell(0, 0));
      selection.setCarry(2);
      expect(selection.preview(game)!.stackAt(const Cell(0, 0)), [charcoal]);
      expect(selection.hand(game), [ivory, ivory]);
      selection.tap(game, const Cell(1, 0));
      selection.setCarry(1);
      expect(selection.carry, 2, reason: 'Undo drops before changing pickup');
      selection.inspect(game, const Cell(0, 0));
      expect(selection.drops, [1]);
    });

    test('$shape blocked steps preserve draft and explain the actual rule', () {
      final game = position(shape, board: {
        const Cell(0, 0): [charcoal, ivory, cap],
        const Cell(1, 0): [wall],
        const Cell(0, 1): [cap],
      });
      final selection = MoveSelection()..tap(game, const Cell(0, 0));
      selection.tap(game, const Cell(1, 0));
      expect(selection.feedback, contains('lone capstone'));
      expect(selection.drops, isEmpty);
      expect(selection.hand(game), [charcoal, ivory, cap]);
      selection.tap(game, const Cell(0, 1));
      expect(selection.feedback, contains('cannot be covered'));
      selection.tap(game, const Cell(-1, 5));
      expect(selection.drops, isEmpty);
      selection.setCarry(1);
      selection.tap(game, const Cell(1, 0));
      expect(selection.planned!.drops, [1]);
      expect(
          selection.preview(game)!.stackAt(const Cell(1, 0)), [charcoal, cap]);
      expect(game.topAt(const Cell(1, 0)), wall);
    });

    test('$shape a cap crush is allowed only after all lower stones drop', () {
      final game = position(shape, board: {
        const Cell(0, 0): [charcoal, ivory, cap],
        const Cell(2, 0): [wall],
      });
      final selection = MoveSelection()..tap(game, const Cell(0, 0));
      selection.tap(game, const Cell(1, 0));
      expect(selection.destinations(game), isEmpty);
      selection.tap(game, const Cell(2, 0));
      expect(selection.drops, [1]);
      selection.tap(game, const Cell(1, 0));
      expect(selection.destinations(game), {const Cell(2, 0)});
      selection.tap(game, const Cell(2, 0));
      expect(selection.planned!.drops, [2, 1]);
      expect(
          selection.preview(game)!.stackAt(const Cell(2, 0)), [charcoal, cap]);
      expect(selection.preview(game)!.result, isNull);
      selection.undoDrop();
      expect(selection.preview(game)!.topAt(const Cell(2, 0)), wall);
      expect(selection.hand(game), [cap]);
    });

    test('$shape inspection and stray taps cannot replace an active draft', () {
      final game = position(shape, board: {
        const Cell(0, 0): [charcoal, ivory, ivory],
        const Cell(0, 1): [charcoal],
      });
      final selection = MoveSelection()..tap(game, const Cell(0, 1));
      expect(selection.source, isNull);
      expect(selection.inspected, const Cell(0, 1));
      selection.tap(game, const Cell(0, 0));
      selection.tap(game, const Cell(1, 0));
      selection.inspect(game, const Cell(0, 1));
      expect(selection.inspected, const Cell(0, 1));
      expect(selection.source, const Cell(0, 0));
      selection.tap(game, const Cell(0, 1));
      expect(selection.drops, [1]);
      expect(selection.feedback, contains('Continue straight'));
      selection.dropRemaining(game);
      expect(selection.planned!.drops, [3]);
    });

    test('$shape tall stacks enforce carry limits and adjacent first drops',
        () {
      final game =
          position(shape, board: {const Cell(0, 0): List.filled(30, ivory)});
      final selection = MoveSelection()..tap(game, const Cell(0, 0));
      expect(selection.carry, game.geometry.carryLimit);
      expect(selection.preview(game)!.stackAt(const Cell(0, 0)), hasLength(25));
      selection.tap(game, const Cell(2, 0));
      expect(selection.started, isFalse);
      expect(selection.feedback, contains('neighbor'));
      selection.tap(game, const Cell(1, 0));
      expect(selection.remaining, 4);
    });
  }

  test('placement still has explicit and same-cell confirmation', () {
    final game = MatchState.initial(MatchConfig.defaults(BoardShape.square));
    final selection = MoveSelection();
    expect(selection.tap(game, const Cell(0, 0)), isFalse);
    expect(selection.tap(game, const Cell(0, 0)), isTrue);
    expect(selection.planned!.type, PieceType.flat);
    expect(game.board, isEmpty);
  });

  test('complete coaching suggestions retain revisable individual drops', () {
    final game = position(BoardShape.square);
    final selection = MoveSelection()
      ..choose(MatchMove.spread(const Cell(0, 0), Step.east, [2, 1]));
    expect(selection.planned!.drops, [2, 1]);
    selection.undoDrop();
    expect(selection.hand(game), [ivory]);
    selection.undoDrop();
    expect(selection.drops, [1]);
  });

  test('invalid drafts and empty moves cannot change the original position',
      () {
    final game = position(BoardShape.square);
    for (final drops in [
      <int>[],
      [0],
      [-1],
      [4]
    ]) {
      expect(
          MatchRules.apply(
              game, MatchMove.spread(const Cell(0, 0), Step.east, drops)),
          isNull);
    }
    expect(
        MatchRules.previewSpread(game, const Cell(0, 0), 3, Step.northEast, [1])
            .position,
        isNull);
    expect(
        MatchRules.previewSpread(game, const Cell(0, 0), 3, Step.west, [1])
            .error,
        contains('leave the board'));
    expect(game.stackAt(const Cell(0, 0)), [charcoal, ivory, ivory]);
  });
}
