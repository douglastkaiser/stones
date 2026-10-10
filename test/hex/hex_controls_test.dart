import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_match_provider.dart';
import 'package:stones/hex/hex_move_selection.dart';
import 'package:stones/hex/hex_screen.dart';
import 'package:stones/hex/hex_room.dart';
import 'package:stones/models/piece.dart';

class _FixtureController extends HexMatchController {
  _FixtureController(HexGame game, {bool busy = false, Set<HexSeat>? controls})
      : super(
            authenticate: () async => 'unused',
            store: () => throw StateError('offline')) {
    state = HexMatchState(
        game: game,
        kinds: List.filled(3, HexSeatKind.localHuman),
        busy: busy,
        controls: controls ?? HexSeat.values.toSet());
  }
}

HexGame position({Map<HexCell, List<HexStone>>? board}) => HexGame(
    radius: 2,
    ply: 3,
    reserves: List.filled(3, const HexReserve(12, 1)),
    board: board ??
        {
          const HexCell(0, 0): [
            const HexStone(HexSeat.charcoal, PieceType.flat),
            const HexStone(HexSeat.copper, PieceType.flat),
            const HexStone(HexSeat.ivory, PieceType.capstone),
          ]
        });

void main() {
  for (final busy in [false, true]) {
    testWidgets(
        'Hex blocks ${busy ? 'pending acknowledgement' : 'remote/AI turn'} gestures',
        (tester) async {
      final controller = _FixtureController(position(),
          busy: busy, controls: busy ? null : {HexSeat.charcoal});
      final container = ProviderContainer(
          overrides: [hexMatchProvider.overrideWith((ref) => controller)]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HexGameScreen())));
      final rect = tester.getRect(find.byType(HexBoard));
      final center = rect.topLeft +
          HexBoardGeometry(rect.size, 2).center(const HexCell(0, 0));
      await tester.tapAt(center);
      await tester.flingFrom(center, const Offset(60, 0), 400);
      await tester.pump();
      expect(find.text('Confirm'), findsNothing);
      expect(controller.state.game!.ply, 3);
      expect(tester.widget<HexBoard>(find.byType(HexBoard)).preview, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }
  test('spread revision preserves bottom-first order and rule validation', () {
    final game = position();
    final selection = HexMoveSelection();
    selection.swipe(game, const HexCell(0, 0), HexDirection.east);
    selection.pendingDrop = 2;
    selection.continueMove(game);
    expect(selection.planned!.drops, [2, 1]);
    final result = HexRules.play(game, selection.planned!)!;
    expect(result.stackAt(const HexCell(1, 0)).map((stone) => stone.seat),
        [HexSeat.charcoal, HexSeat.copper]);
    expect(result.topAt(const HexCell(2, 0))!.type, PieceType.capstone);
    selection.swipe(game, const HexCell(2, 0), HexDirection.northEast);
    expect(selection.planned!.drops, [2, 1]);
    selection.backStep(game);
    expect(selection.planned!.drops, [3]);
    selection.tap(game, const HexCell(-2, 1));
    expect(selection.planned!.drops, [3]);
    expect(game.stackAt(const HexCell(0, 0)).length, 3);
  });

  test('only lone final cap can continue into a wall; caps and edge block', () {
    for (final blocker in [PieceType.standing, PieceType.capstone]) {
      final board = {
        ...position().board,
        const HexCell(2, 0): [HexStone(HexSeat.copper, blocker)]
      };
      final game = position(board: board);
      final selection = HexMoveSelection()
        ..swipe(game, const HexCell(0, 0), HexDirection.east);
      expect(selection.continuation(game), isNull);
      selection.pendingDrop = 2;
      expect(
          selection.continuation(game) != null, blocker == PieceType.standing);
      selection.continueMove(game);
      if (blocker == PieceType.standing) {
        final result = HexRules.play(game, selection.planned!)!;
        expect(result.stackAt(const HexCell(2, 0)).first.type, PieceType.flat);
        expect(selection.continuation(game), isNull);
      }
    }
  });

  for (final direction in HexDirection.values) {
    for (final slow in [false, true]) {
      testWidgets(
          'Hex ${direction.name} ${slow ? 'slow drag' : 'swipe'} is preview only',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = _FixtureController(position());
        final container = ProviderContainer(
            overrides: [hexMatchProvider.overrideWith((ref) => controller)]);
        addTearDown(container.dispose);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: HexGameScreen())));
        final rect = tester.getRect(find.byType(HexBoard));
        final geometry = HexBoardGeometry(rect.size, 2);
        final center = rect.topLeft + geometry.center(const HexCell(0, 0));
        final delta = geometry.center(const HexCell(0, 0).step(direction)) -
            geometry.center(const HexCell(0, 0));
        if (slow) {
          final gesture = await tester.startGesture(center);
          await gesture.moveBy(delta, timeStamp: const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 200));
          await gesture.up(timeStamp: const Duration(milliseconds: 1200));
        } else {
          await tester.flingFrom(center, delta, 400);
        }
        await tester.pump();
        expect(controller.state.game!.ply, 3);
        expect(find.text('Drop 3'), findsOneWidget);
        expect(tester.getRect(find.byType(HexBoard)), rect);
        final confirm = find.widgetWithText(FilledButton, 'Confirm');
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pump();
        expect(controller.state.game!.ply, 4);
        expect(
            controller.state.game!
                .stackAt(const HexCell(0, 0).step(direction))
                .length,
            3);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('two taps place once; opening swipes do nothing', (tester) async {
    final controller = _FixtureController(HexGame.initial());
    final container = ProviderContainer(
        overrides: [hexMatchProvider.overrideWith((ref) => controller)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: HexGameScreen())));
    final rect = tester.getRect(find.byType(HexBoard));
    final geometry = HexBoardGeometry(rect.size, 2);
    final center = rect.topLeft + geometry.center(const HexCell(0, 0));
    await tester.tapAt(center);
    await tester.pump();
    expect(controller.state.game!.ply, 0);
    await tester.tapAt(center);
    await tester.pump();
    expect(controller.state.game!.ply, 1);
    expect(controller.state.game!.topAt(const HexCell(0, 0))!.seat,
        HexSeat.charcoal);
    await tester.flingFrom(center, const Offset(60, 0), 400);
    await tester.pump();
    expect(controller.state.game!.ply, 1);
    expect(find.text('Confirm'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
