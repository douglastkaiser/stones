import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/design_preview.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    for (final players in [2, 4]) {
      test(
          '${shape.name} $players visual fixtures preserve supplies and real roads',
          () {
        for (final won in [false, true]) {
          final game = previewPosition(shape, players, won: won);
          final expected = game.reserves.values.first.total;
          expect(expected, greaterThan(0));
          expect(game.result?.winner, won ? SeatId.ivory : null);
          for (final id in game.config.ids) {
            final used = game.board.values
                .expand((pieces) => pieces)
                .where((stone) => stone.seat == id)
                .length;
            final fresh = previewPosition(shape, players).config;
            expect(used + game.reserves[id]!.total,
                shape == BoardShape.square ? 22 : 16,
                reason:
                    'Same initial supplies for ${fresh.shape.name} ${id.name}');
          }
          if (won) expect(MatchRules.road(game, SeatId.ivory), isNotEmpty);
        }
      });
    }
  }

  for (final width in [320.0, 390.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      for (final page in PreviewPage.values) {
        testWidgets('$page $width $brightness fits and captures',
            (tester) async {
          final height = width > 1000 ? 1000.0 : 900.0;
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final capture = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
              key: capture,
              child: DesignPreviewApp(
                  initialPage: page,
                  initialPlayers: 4,
                  initialBrightness: brightness)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('STONES_CAPTURE_PREVIEW')) {
            await tester.runAsync(() async {
              final boundary = capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final image = await boundary.toImage();
              try {
                final data =
                    await image.toByteData(format: ui.ImageByteFormat.png);
                final file = File(
                    'build/qa/finishing/${page.name}-${width.toInt()}-${brightness.name}.png');
                await file.parent.create(recursive: true);
                await file.writeAsBytes(data!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
          // The end of each screen remains reachable on a narrow phone.
          await tester.drag(
              find.byType(SingleChildScrollView).first, const Offset(0, -1600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('mobile board stays fixed when move controls change',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(const DesignPreviewApp(initialPage: PreviewPage.table));
    await tester.pumpAndSettle();
    final board = find.byKey(const ValueKey('preview-board'));
    final before = tester.getRect(board);
    await tester.tap(find.byKey(const ValueKey('cell-2-2')));
    await tester.pumpAndSettle();
    expect(tester.getRect(board), before);
    expect(find.textContaining('Carry 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Square and Hex navigation uses the real renderer',
      (tester) async {
    await tester.pumpWidget(const DesignPreviewApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hex', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('A game of Hex'), findsOneWidget);
    await tester.ensureVisible(find.text('Try the table'));
    await tester.tap(find.text('Try the table'));
    await tester.pumpAndSettle();
    expect(tester.widget<BoardView>(find.byType(BoardView)).game.config.shape,
        BoardShape.hex);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text preserves essential controls', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: const DesignPreviewApp(
            initialPage: PreviewPage.table, initialPlayers: 4)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Preview a finished game'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
