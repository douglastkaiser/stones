import 'dart:io';

import 'package:stones/game/board_view.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/match_table_layout.dart';

import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

import 'package:stones/theme/tavern_theme.dart';

class _PositionController extends MatchController {
  _PositionController(MatchState game)
      : super(
            storage: MemoryMatchStorage(),
            authenticate: () async => 'host',
            store: () => MemoryMatchRoomStore()) {
    state = MatchSession(game: game, id: 'layout-fixture');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final font in [('StonesLora', 'Lora'), ('StonesSans', 'Roboto')]) {
      await (FontLoader(font.$1)
            ..addFont(rootBundle.load('assets/fonts/${font.$2}-Regular.ttf')))
          .load();
    }
  });
  for (final shape in BoardShape.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$shape stack actions remain visible at text scale $scale',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final config = MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 8 : 4,
            seats: const [
              SeatConfig(SeatId.ivory),
              SeatConfig(SeatId.charcoal)
            ]);
        final game = MatchState.initial(config).copyWith(ply: 2, board: {
          const Cell(0, 0):
              List.filled(3, const Stone(SeatId.ivory, PieceType.flat)),
          const Cell(2, 0): [const Stone(SeatId.charcoal, PieceType.flat)],
        });
        final controller = _PositionController(game);
        await tester.pumpWidget(ProviderScope(
            overrides: [matchProvider.overrideWith((ref) => controller)],
            child: MaterialApp(
                theme: TavernTheme.build(Brightness.light),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        padding: const EdgeInsets.only(bottom: 34),
                        textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: const MatchScreen())));
        await tester.pumpAndSettle();
        final source = find.byKey(const ValueKey('cell-0-0'));
        await tester.ensureVisible(source);
        await tester.tap(source);
        await tester.pumpAndSettle();
        final confirm = find.widgetWithText(FilledButton, 'Confirm move');
        expect(confirm.hitTestable(), findsOneWidget);
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        final target = find.byKey(const ValueKey('cell-1-0'));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(confirm.hitTestable(), findsOneWidget);
        final remaining = find.text('Drop remaining here');
        await tester.ensureVisible(remaining);
        await tester.tap(remaining);
        await tester.pumpAndSettle();
        expect(confirm.hitTestable(), findsOneWidget);
        expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
        expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(534));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(confirm, findsNothing);
        final opponent = find.byKey(const ValueKey('cell-2-0'));
        await tester.ensureVisible(opponent);
        await tester.tap(opponent);
        await tester.pumpAndSettle();
        expect(find.text('Close inspection').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Close inspection'));
        await tester.pumpAndSettle();
        expect(find.text('Close inspection'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final shape in BoardShape.values) {
    for (final configuredSize in MatchConfig.sizesFor(shape)) {
      for (final count in [2, 3, 4]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          for (final size in [
            const Size(320, 568),
            const Size(390, 844),
            const Size(844, 390),
            const Size(768, 1024),
            const Size(999, 800),
            const Size(1000, 800),
            const Size(1366, 900),
          ]) {
            testWidgets(
              'actual $shape size $configuredSize $count-seat table fits $size at $scale with stable controls',
              (tester) async {
                tester.view.physicalSize = size;
                tester.view.devicePixelRatio = 1;
                addTearDown(tester.view.resetPhysicalSize);
                addTearDown(tester.view.resetDevicePixelRatio);
                addTearDown(tester.view.resetViewInsets);
                final controller = MatchController(
                  storage: MemoryMatchStorage(),
                  authenticate: () async => 'host',
                  store: () => MemoryMatchRoomStore(),
                );
                await controller.start(
                  MatchConfig(
                    shape: shape,
                    size: configuredSize,
                    seats: [
                      for (final id in SeatId.values.take(count))
                        SeatConfig(id),
                    ],
                  ),
                );
                final capture = GlobalKey();
                await tester.pumpWidget(
                  ProviderScope(
                    overrides: [
                      matchProvider.overrideWith((ref) => controller)
                    ],
                    child: RepaintBoundary(
                      key: capture,
                      child: MaterialApp(
                        theme: TavernTheme.build(Brightness.light),
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(scale),
                            padding: const EdgeInsets.only(bottom: 24),
                          ),
                          child: child!,
                        ),
                        home: const MatchScreen(),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                final board = find.byKey(const ValueKey('stable-board'));
                final before = tester.getRect(board);
                if (size.width > 1000 && size.width / scale >= 760) {
                  expect(before.width, greaterThan(680));
                  if (count == 4) {
                    expect(
                      find
                          .textContaining('${SeatId.values.last.label}:')
                          .hitTestable(),
                      findsOneWidget,
                    );
                  }
                }
                {
                  final policy = MatchLayoutPolicy(
                      Size(size.width, size.height - 80),
                      MatchLayoutPolicy.measurePanel(
                          tester.element(find.byType(MatchTableLayout))));
                  expect(before.width, closeTo(policy.boardSide, .01));
                  final view = tester.widget<BoardView>(find.byType(BoardView));
                  final layout = BoardLayout(before.size, view.game.geometry);
                  if (shape == BoardShape.square) {
                    final first = layout.bounds(const Cell(0, 0));
                    final last = layout.bounds(Cell(
                        view.game.config.size - 1, view.game.config.size - 1));
                    expect(last.right - first.left,
                        closeTo(before.width - 24, .01));
                  }
                  for (final cell in view.game.geometry.cells) {
                    final bounds = layout.polygon(cell).getBounds();
                    expect(bounds.left, greaterThanOrEqualTo(0));
                    expect(bounds.top, greaterThanOrEqualTo(0));
                    expect(bounds.right, lessThanOrEqualTo(before.width));
                    expect(bounds.bottom, lessThanOrEqualTo(before.height));
                  }
                }
                final cell = find.byKey(const ValueKey('cell-0-0'));
                await tester.ensureVisible(cell);
                final boardSize = tester.getSize(board);
                await tester.tap(cell);
                await tester.pumpAndSettle();
                expect(tester.getSize(board), boardSize);
                final confirm = find.widgetWithText(FilledButton, 'Confirm');
                expect(confirm.hitTestable(), findsOneWidget);
                expect(
                  tester.getRect(confirm).bottom,
                  lessThanOrEqualTo(size.height - 24),
                );
                expect(find.text('Cancel').hitTestable(), findsOneWidget);
                tester.view.physicalSize = Size(size.height, size.width);
                await tester.pumpAndSettle();
                expect(confirm.hitTestable(), findsOneWidget);
                expect(
                  tester.getRect(confirm).bottom,
                  lessThanOrEqualTo(size.width - 24),
                );
                tester.view.physicalSize = size;
                await tester.pumpAndSettle();
                if (size == const Size(390, 844)) {
                  tester.view.viewInsets = const FakeViewPadding(bottom: 280);
                  await tester.pumpAndSettle();
                  expect(confirm.hitTestable(), findsOneWidget);
                  expect(tester.getRect(confirm).bottom,
                      lessThanOrEqualTo(size.height - 280 - 24));
                  expect(tester.getSize(board), boardSize);
                  tester.view.resetViewInsets();
                  await tester.pumpAndSettle();
                }
                await tester.tap(find.text('Cancel'));
                await tester.pumpAndSettle();
                expect(confirm, findsNothing);
                await tester.ensureVisible(cell);
                await tester.tap(cell);
                await tester.pumpAndSettle();
                await tester.tap(confirm);
                await tester.pumpAndSettle();
                expect(confirm, findsNothing);
                expect(tester.takeException(), isNull);
                if (const bool.fromEnvironment('STONES_CAPTURE_LAYOUT')) {
                  await tester.runAsync(() async {
                    final boundary = capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                    final picture = await boundary.toImage();
                    final data = await picture.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    final output = File(
                      'build/qa/community/${shape.name}-$count-${size.width.toInt()}.png',
                    );
                    await output.parent.create(recursive: true);
                    await output.writeAsBytes(data!.buffer.asUint8List());
                    picture.dispose();
                  });
                }
                await tester.pumpWidget(const SizedBox());
                await tester.pump();
              },
            );
          }
        }
      }
    }
  }
}
