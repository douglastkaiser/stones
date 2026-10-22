import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/board_viewport.dart';
import 'package:stones/game/match_config.dart';
import 'stack_interaction_test.dart' show mount, board, cell, tapVisible;

void main() {
  for (final shape in BoardShape.values) {
    testWidgets('$shape audio access does not overlay landscape actions',
        (tester) async {
      await mount(tester, shape,
          size: const Size(568, 320), audioOverlay: true);
      expect(find.byTooltip('Audio settings'), findsNothing);
      await tester.tap(find.byTooltip('Match options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio settings'));
      await tester.pumpAndSettle();
      expect(find.text('Background music'), findsOneWidget);
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.pop();
      await tester.pumpAndSettle();
      navigator.pushReplacement(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Outside match'))));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Audio settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('$shape draft survives zoom, pan, rotation and keyboard focus',
        (tester) async {
      final match = await mount(tester, shape);
      await tester.tap(cell(const Cell(0, 0)));
      await tester.pumpAndSettle();
      await tester.tap(cell(const Cell(1, 0)));
      await tester.pumpAndSettle();
      final before = match.state.game;
      final drops = List<int>.of(board(tester).drops);
      final viewport =
          tester.widget<BoardViewport>(find.byType(BoardViewport)).controller;
      viewport.magnify(true);
      await tester.pumpAndSettle();
      final zoom = viewport.zoom;
      final center = viewport.center;
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(
          tester.widget<BoardViewport>(find.byType(BoardViewport)).controller,
          same(viewport));
      expect(viewport.zoom, zoom);
      expect(viewport.center, center);
      expect(board(tester).drops, drops);
      expect(find.text('Confirm move').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Undo last drop').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Board view'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.widgetWithText(CheckedPopupMenuItem<String>, 'Pan board'));
      await tester.pumpAndSettle();
      expect(viewport.panMode, isTrue);
      await tester.drag(find.byType(BoardViewport), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(board(tester).drops, drops);
      expect(match.state.game, same(before));
      await tester.tap(find.byTooltip('Board view'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fit board').last);
      await tester.pumpAndSettle();
      expect(viewport.zoom, 1);
      expect(viewport.panMode, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(match.state.game, same(before));
      expect(board(tester).drops, drops);
      await tester.tap(find.byTooltip('Undo last drop'));
      await tester.pumpAndSettle();
      expect(board(tester).drops, isEmpty);
      await tapVisible(tester, find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(board(tester).routeSource, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('$shape adding a second finger cancels an active stack drag',
        (tester) async {
      final match = await mount(tester, shape);
      await tester.tap(cell(const Cell(0, 0)));
      await tester.pumpAndSettle();
      final game = match.state.game;
      final origin = tester.getCenter(cell(const Cell(0, 0)));
      final first = await tester.startGesture(origin, pointer: 1);
      await first.moveBy(const Offset(30, 0));
      await tester.pump();
      final second =
          await tester.startGesture(origin + const Offset(80, 0), pointer: 2);
      await tester.pump();
      await second.moveBy(const Offset(40, 0));
      await tester.pump();
      final viewport =
          tester.widget<BoardViewport>(find.byType(BoardViewport)).controller;
      expect(viewport.zoom, greaterThan(1));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(board(tester).drops, isEmpty);
      expect(board(tester).onSwipe, isNotNull);
      expect(match.state.game, same(game));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('$shape safe insets and keyboard retain pinned actions at 200%',
        (tester) async {
      tester.view.padding =
          const FakeViewPadding(left: 34, right: 24, bottom: 21);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);
      await mount(tester, shape, size: const Size(320, 568), scale: 2);
      final boardSize =
          tester.getSize(find.byKey(const ValueKey('stable-board')));
      expect(boardSize.width, 262);
      await tapVisible(tester, cell(const Cell(0, 0)));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      final confirm = find.text('Confirm move');
      expect(confirm.hitTestable(), findsOneWidget);
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(568 - 280));
      expect(tester.getSize(find.byKey(const ValueKey('stable-board'))),
          boardSize);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
