import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/main.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/game_provider.dart';
import 'package:stones/providers/ui_state_provider.dart';

const _flat = Piece(type: PieceType.flat, color: PlayerColor.white);
const _cap = Piece(type: PieceType.capstone, color: PlayerColor.white);
const _wall = Piece(type: PieceType.standing, color: PlayerColor.black);

Future<ProviderContainer> _showBoard(WidgetTester tester, Board board,
    {Size size = const Size(1100, 900), double textScale = 1}) async {
  final container = ProviderContainer();
  container.read(gameStateProvider.notifier).loadState(
        GameState.initial(5).copyWith(board: board, phase: GamePhase.playing),
      );
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    container.dispose();
  });
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: const GameScreen()),
  ));
  await tester.pump();
  return container;
}

// Board cells are built in row-major order; coordinates below target the
// rendered board rather than calling its private gesture handlers directly.
Finder _cell(int row, int col) => find
    .byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_BoardCell')
    .at(row * 5 + col);

void main() {
  testWidgets('holding a selected square stack preserves its carry preview',
      (tester) async {
    final board = Board.empty(5).setStack(
        const Position(2, 2),
        const PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          _flat,
          _cap
        ]));
    final container =
        await _showBoard(tester, board, size: const Size(320, 568));
    await tester.tap(_cell(2, 2));
    await tester.pump();
    await tester.tap(find.byTooltip('Decrease Carry'));
    await tester.pump();
    final pickup = container.read(uiStateProvider).piecesPickedUp;
    await tester.longPress(_cell(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('Light capstone'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dark flat'), 100,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Bottom'), findsOneWidget);
    await tester.tap(find.byTooltip('Close stack inspection'));
    await tester.pumpAndSettle();
    expect(container.read(gameStateProvider).board, board);
    expect(container.read(uiStateProvider).piecesPickedUp, pickup);
    expect(container.read(uiStateProvider).mode, InteractionMode.movingStack);
    await tester.tap(find.byTooltip('Increase Carry'));
    await tester.pump();
    expect(container.read(uiStateProvider).piecesPickedUp, 3);
    await tester.longPress(_cell(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('Light capstone'), findsOneWidget);
    expect(find.textContaining('before move'), findsOneWidget);
    await tester.tap(find.byTooltip('Close stack inspection'));
    await tester.pumpAndSettle();
    expect(container.read(gameStateProvider).board, board);
    expect(container.read(uiStateProvider).piecesPickedUp, 3);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(320, 568), const Size(1100, 900)]) {
    testWidgets('explicit carry, drops, back and confirm work at $size',
        (tester) async {
      final board = Board.empty(5).setStack(
          const Position(2, 0), const PieceStack([_flat, _flat, _flat, _cap]));
      final container =
          await _showBoard(tester, board, size: size, textScale: 1.5);
      Future<void> press(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      await press(_cell(2, 0));
      await press(find.byTooltip('Decrease Carry'));
      expect(container.read(uiStateProvider).piecesPickedUp, 3);
      await press(_cell(2, 1));
      expect(find.widgetWithText(ElevatedButton, 'Confirm'), findsOneWidget);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Confirm'))
              .onPressed,
          isNull);
      await press(find.byTooltip('Increase Drop'));
      expect(container.read(uiStateProvider).pendingDropCount, 2);
      await press(find.text('Drop & next'));
      expect(container.read(uiStateProvider).drops, [2]);
      expect(container.read(gameStateProvider).board, board);
      await press(find.text('Back step'));
      expect(container.read(uiStateProvider).drops, isEmpty);
      expect(container.read(uiStateProvider).piecesPickedUp, 3);
      await press(_cell(0, 4));
      expect(
          container.read(uiStateProvider).mode, InteractionMode.droppingPieces);
      await press(find.text('All here'));
      await press(find.widgetWithText(ElevatedButton, 'Confirm'));
      final result = container.read(gameStateProvider);
      expect(result.board.stackAt(const Position(2, 0)).pieces, [_flat]);
      expect(result.board.stackAt(const Position(2, 1)).pieces,
          [_flat, _flat, _cap]);
      expect(result.currentPlayer, PlayerColor.black);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final delta in [
    const Offset(70, 0),
    const Offset(0, -70),
    const Offset(0, 70)
  ]) {
    testWidgets('a slow drag $delta starts a reversible preview on mobile',
        (tester) async {
      final board = Board.empty(5)
          .setStack(const Position(2, 2), const PieceStack([_flat, _cap]));
      final container =
          await _showBoard(tester, board, size: const Size(390, 844));
      final gesture = await tester.startGesture(tester.getCenter(_cell(2, 2)));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(delta * 0.45);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(delta * 0.55);
      // Release at zero velocity, after establishing a drag rather than a hold.
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pump();
      final preview = container.read(uiStateProvider);
      expect(preview.mode, InteractionMode.droppingPieces);
      expect(
          preview.selectedDirection,
          delta.dx > 0
              ? Direction.right
              : delta.dy < 0
                  ? Direction.up
                  : Direction.down);
      expect(container.read(gameStateProvider).board, board);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(container.read(uiStateProvider).mode, InteractionMode.idle);
      expect(container.read(gameStateProvider).board, board);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('swiping a capstone stack onto an adjacent wall is rejected',
      (tester) async {
    final board = Board.empty(5)
        .setStack(const Position(2, 0), const PieceStack([_flat, _cap]))
        .placePiece(const Position(2, 1), _wall);
    final container = await _showBoard(tester, board);

    await tester.fling(_cell(2, 0), const Offset(50, 0), 1000);
    await tester.pump();
    expect(container.read(uiStateProvider).mode, InteractionMode.idle);
    expect(container.read(gameStateProvider).board, board);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('swiping the hand square continues a legal capstone spread',
      (tester) async {
    final board = Board.empty(5)
        .setStack(const Position(2, 0), const PieceStack([_flat, _flat, _cap]))
        .placePiece(const Position(2, 2), _wall);
    final container = await _showBoard(tester, board);

    await tester.tap(_cell(2, 0));
    await tester.pump();
    await tester.tap(_cell(2, 1));
    await tester.pump();
    await tester.tap(_cell(2, 1));
    await tester.pump();
    expect(container.read(uiStateProvider).pendingDropCount, 2);

    await tester.fling(_cell(2, 1), const Offset(50, 0), 1000);
    await tester.pump();
    final preview = container.read(uiStateProvider);
    expect(preview.drops, [2]);
    expect(preview.piecesPickedUp, 1);
    expect(preview.getCurrentHandPosition(), const Position(2, 2));
    expect(container.read(gameStateProvider).board, board);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
    await tester.pump();
    final result = container.read(gameStateProvider);
    expect(result.board.stackAt(const Position(2, 0)).isEmpty, isTrue);
    expect(result.board.stackAt(const Position(2, 1)).pieces, [_flat, _flat]);
    expect(result.board.stackAt(const Position(2, 2)).pieces, [
      const Piece(type: PieceType.flat, color: PlayerColor.black),
      _cap,
    ]);
    expect(result.currentPlayer, PlayerColor.black);
    await tester.pumpWidget(const SizedBox());
  });
}
