import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Step;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/stack_move_tray.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/theme/tavern_theme.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

const ivory = Stone(SeatId.ivory, PieceType.flat);
const charcoal = Stone(SeatId.charcoal, PieceType.flat);

class PositionController extends MatchController {
  PositionController()
      : super(
            storage: MemoryMatchStorage(),
            authenticate: () async => 'stack-test',
            store: () => MemoryMatchRoomStore());
  void replace(MatchState game) => state = state.copyWith(game: game);
  void connection(bool connected) =>
      state = state.copyWith(connected: connected);
}

Finder cell(Cell cell) => find.byKey(ValueKey('cell-${cell.x}-${cell.y}'));
BoardView board(WidgetTester tester) =>
    tester.widget<BoardView>(find.byType(BoardView));

Future<PositionController> mount(WidgetTester tester, BoardShape shape,
    {Size size = const Size(390, 844),
    double scale = 1,
    Brightness brightness = Brightness.light,
    Map<Cell, List<Stone>>? stones,
    GlobalKey? capture}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = PositionController();
  await controller.start(MatchConfig.defaults(shape).copyWith(
      seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]));
  controller.replace(controller.state.game!.copyWith(
      ply: 2,
      board: stones ??
          {
            const Cell(0, 0): [charcoal, ivory, ivory],
            const Cell(0, 1): [charcoal],
          }));
  await tester.pumpWidget(RepaintBoundary(
      key: capture,
      child: ProviderScope(
          overrides: [matchProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: TavernTheme.build(brightness),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: const MatchScreen()))));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('STONES_CAPTURE_STACKS')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/stacks/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
}

void main() {
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final font in [('StonesLora', 'Lora'), ('StonesSans', 'Roboto')]) {
      await (FontLoader(font.$1)
            ..addFont(rootBundle.load('assets/fonts/${font.$2}-Regular.ttf')))
          .load();
    }
  });

  for (final shape in BoardShape.values) {
    for (final size in [const Size(390, 844), const Size(1366, 900)]) {
      for (final brightness in Brightness.values) {
        testWidgets(
            '$shape $size $brightness inspect, choose, stage, undo and confirm',
            (tester) async {
          final key = GlobalKey();
          final controller = await mount(tester, shape,
              size: size, brightness: brightness, capture: key);
          final original = controller.state.game!;
          final boardBounds =
              tester.getRect(find.byKey(const ValueKey('stable-board')));
          await tapVisible(tester, cell(const Cell(0, 0)));
          await tester.pumpAndSettle();
          expect(find.byType(StackMoveTray), findsOneWidget);
          expect(find.text('Taking 3 of 3 · 0 stay here'), findsOneWidget);
          expect(find.text('Next to drop: Charcoal flat'), findsOneWidget);
          await capture(tester, key,
              '${shape.name}-${size.width.toInt()}-${brightness.name}-pickup');
          expect(
              tester.getRect(find.byKey(const ValueKey('stable-board'))).size,
              boardBounds.size);
          expect(
              tester
                  .widget<FilledButton>(
                      find.widgetWithText(FilledButton, 'Confirm move'))
                  .onPressed,
              isNull);
          await tapVisible(tester, find.byKey(const ValueKey('take-layer-1')));
          await tester.pumpAndSettle();
          expect(find.text('Taking 1 of 3 · 2 stay here'), findsOneWidget);
          expect(
              board(tester).game.stackAt(const Cell(0, 0)), [charcoal, ivory]);
          await tapVisible(tester, find.byTooltip('Take more stones'));
          await tester.pumpAndSettle();
          await tapVisible(tester, find.byTooltip('Take more stones'));
          await tester.pumpAndSettle();
          await tapVisible(tester, cell(const Cell(1, 0)));
          await tester.pumpAndSettle();
          expect(controller.state.game, same(original));
          expect(board(tester).game.stackAt(const Cell(1, 0)), [charcoal]);
          expect(board(tester).carried, [ivory, ivory]);
          expect(find.text('Carrying 2 · 1 staged'), findsOneWidget);
          await tester.ensureVisible(find.text('Confirm move'));
          await tester.pumpAndSettle();
          final confirmBounds =
              tester.getRect(find.widgetWithText(FilledButton, 'Confirm move'));
          for (final action in [
            find.widgetWithText(TextButton, 'Drop remaining here'),
            find.byTooltip('Undo last drop'),
            find.byTooltip('Inspect another stack')
          ]) {
            expect(action.hitTestable(), findsOneWidget);
            expect(tester.getRect(action).bottom,
                lessThanOrEqualTo(confirmBounds.top),
                reason: 'Draft actions must stay visible above confirmation');
          }

          await capture(tester, key,
              '${shape.name}-${size.width.toInt()}-${brightness.name}-carrying');
          await tester.ensureVisible(find.byTooltip('Inspect another stack'));
          await tapVisible(tester, find.byTooltip('Inspect another stack'));
          await tester.pumpAndSettle();
          await tapVisible(tester, cell(const Cell(0, 1)));
          await tester.pumpAndSettle();
          expect(tester.widget<StackMoveTray>(find.byType(StackMoveTray)).label,
              contains('0,1'));
          expect(find.byType(BottomSheet), findsNothing);
          expect(board(tester).carried, [ivory, ivory]);
          await tapVisible(tester, find.text('Back to carried stones'));
          await tester.pumpAndSettle();
          await tapVisible(tester, cell(const Cell(1, 0)));
          await tester.pumpAndSettle();
          await tapVisible(tester, cell(const Cell(2, 0)));
          await tester.pumpAndSettle();
          expect(controller.state.game, same(original));
          expect(
              board(tester).game.stackAt(const Cell(1, 0)), [charcoal, ivory]);
          expect(board(tester).game.stackAt(const Cell(2, 0)), [ivory]);
          expect(board(tester).carried, isEmpty);
          expect(find.text('Drops along path: 2, 1'), findsOneWidget);
          await tester.ensureVisible(find.byTooltip('Undo last drop'));
          await tapVisible(tester, find.byTooltip('Undo last drop'));
          await tester.pumpAndSettle();
          expect(board(tester).carried, [ivory]);
          expect(board(tester).game.stackAt(const Cell(2, 0)), isEmpty);
          await tester.ensureVisible(find.text('Drop remaining here'));
          await tapVisible(tester, find.text('Drop remaining here'));
          await tester.pumpAndSettle();
          expect(board(tester).game.stackAt(const Cell(1, 0)),
              [charcoal, ivory, ivory]);
          await tapVisible(tester, find.byTooltip('Undo last drop'));
          await tester.pumpAndSettle();
          await tapVisible(tester, cell(const Cell(2, 0)));
          await tester.pumpAndSettle();
          expect(
              tester.getRect(find.byKey(const ValueKey('stable-board'))).size,
              boardBounds.size);
          await capture(tester, key,
              '${shape.name}-${size.width.toInt()}-${brightness.name}-spread');
          await tapVisible(tester, find.text('Confirm move'));
          await tester.pumpAndSettle();
          expect(controller.state.game!.ply, 3);
          expect(controller.state.game!.stackAt(const Cell(1, 0)),
              [charcoal, ivory]);
          expect(controller.state.game!.stackAt(const Cell(2, 0)), [ivory]);
          expect(find.byType(StackMoveTray), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        });
      }
    }

    final geometry = BoardGeometry.forConfig(MatchConfig.defaults(shape));
    for (final direction in geometry.directions) {
      testWidgets(
          '$shape $direction drag follows pointer before staging one stone',
          (tester) async {
        final origin =
            shape == BoardShape.square ? const Cell(2, 2) : const Cell(0, 0);
        final controller = await mount(tester, shape, stones: {
          origin: [charcoal, ivory, ivory]
        });
        final first = tester.getCenter(cell(origin));
        final delta = tester.getCenter(cell(origin.step(direction))) - first;
        final gesture =
            await tester.startGesture(first, kind: PointerDeviceKind.mouse);
        await gesture.moveBy(delta * .5);
        await tester.pump();
        expect(
            find.byKey(const ValueKey('carried-drag-ghost')), findsOneWidget);
        final ghostBefore =
            tester.getTopLeft(find.byKey(const ValueKey('carried-drag-ghost')));
        expect(board(tester).drops, isEmpty);
        await gesture.moveBy(delta * .5);
        await tester.pump(const Duration(milliseconds: 200));
        expect(
            tester.getTopLeft(find.byKey(const ValueKey('carried-drag-ghost'))),
            isNot(ghostBefore));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('carried-drag-ghost')), findsNothing);
        expect(board(tester).drops, [1]);
        expect(board(tester).carried, [ivory, ivory]);
        expect(board(tester).game.stackAt(origin.step(direction)), [charcoal]);
        expect(controller.state.game!.ply, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }

    testWidgets('$shape tall stack expands and remains readable at 200% text',
        (tester) async {
      final key = GlobalKey();
      await mount(tester, shape,
          size: const Size(320, 568),
          scale: 2,
          capture: key,
          stones: {const Cell(0, 0): List.filled(30, ivory)});
      final before = tester.getRect(find.byKey(const ValueKey('stable-board')));
      await tapVisible(tester, cell(const Cell(0, 0)));
      await tester.pumpAndSettle();
      expect(find.text('Taking 5 of 30 · 25 stay here'), findsOneWidget);
      await tester.ensureVisible(find.text('Expand'));
      await tapVisible(tester, find.text('Expand'));
      await tester.pumpAndSettle();
      final layers = find.byKey(const ValueKey('stack-layers-Stack 0,0'));
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('take-layer-30')), 350,
          scrollable:
              find.descendant(of: layers, matching: find.byType(Scrollable)));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<InkWell>(find.byKey(const ValueKey('take-layer-30')))
              .onTap,
          isNull);
      expect(tester.getSize(find.byKey(const ValueKey('stable-board'))),
          before.size);
      await capture(tester, key, '${shape.name}-320-large-text');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets(
      'semantic taps and hold inspect without submitting a single-stone spread',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = await mount(tester, BoardShape.square, stones: {
        const Cell(0, 0): [ivory],
        const Cell(0, 1): [charcoal]
      });
      void tapSemantic(Cell target) {
        final node = tester.getSemantics(cell(target));
        node.owner!.performAction(node.id, SemanticsAction.tap);
      }

      tapSemantic(const Cell(0, 0));
      await tester.pumpAndSettle();
      tapSemantic(const Cell(1, 0));
      await tester.pumpAndSettle();
      expect(board(tester).carried, isEmpty);
      tapSemantic(const Cell(1, 0));
      await tester.pumpAndSettle();
      expect(controller.state.game!.ply, 2);
      await tester.longPress(cell(const Cell(0, 1)));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(board(tester).drops, [1]);
      expect(tester.widget<StackMoveTray>(find.byType(StackMoveTray)).label,
          contains('0,1'));
      await tapVisible(tester, find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(board(tester).game.stackAt(const Cell(0, 0)), [ivory]);
      expect(controller.state.game!.ply, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'position replacement clears stale drafts and finished stacks stay inspectable',
      (tester) async {
    final controller = await mount(tester, BoardShape.square);
    await tapVisible(tester, cell(const Cell(0, 0)));
    await tester.pumpAndSettle();
    await tapVisible(tester, cell(const Cell(1, 0)));
    await tester.pumpAndSettle();
    controller.connection(false);
    await tester.pumpAndSettle();
    await tapVisible(tester, cell(const Cell(2, 0)));
    await tester.pumpAndSettle();
    expect(board(tester).drops, [1]);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm move'))
            .onPressed,
        isNull);
    controller.replace(controller.state.game!.copyWith(board: {
      const Cell(0, 0): [charcoal]
    }));
    await tester.pumpAndSettle();
    expect(board(tester).drops, isEmpty);
    expect(find.byType(StackMoveTray), findsNothing);
    controller.replace(controller.state.game!.copyWith(
        result: const MatchResult(SeatId.charcoal, ResultReason.resignation)));
    await tester.pumpAndSettle();
    await tapVisible(tester, cell(const Cell(0, 0)));
    await tester.pumpAndSettle();
    expect(tester.widget<StackMoveTray>(find.byType(StackMoveTray)).onCarry,
        isNull);
    expect(find.text('Confirm move'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
