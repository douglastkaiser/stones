import 'dart:io';
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
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;
import 'package:stones/theme/tavern_theme.dart';

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
    for (final count in [2, 4]) {
      for (final size in [
        const Size(320, 568),
        const Size(390, 844),
        const Size(1366, 900)
      ]) {
        testWidgets(
            'actual $shape $count-seat table fits $size with stable controls',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = MatchController(
              storage: MemoryMatchStorage(),
              authenticate: () async => 'host',
              store: () => MemoryMatchRoomStore());
          await controller.start(MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 5 : 2,
              seats: [
                for (final id in SeatId.values.take(count)) SeatConfig(id)
              ]));
          final capture = GlobalKey();
          await tester.pumpWidget(ProviderScope(
              overrides: [matchProvider.overrideWith((ref) => controller)],
              child: RepaintBoundary(
                  key: capture,
                  child: MaterialApp(
                      theme: TavernTheme.build(Brightness.light),
                      home: const MatchScreen()))));
          await tester.pumpAndSettle();
          final board = find.byKey(const ValueKey('stable-board'));
          final before = tester.getRect(board);
          if (size.width > 1000) {
            expect(before.width, greaterThan(680));
            if (count == 4) {
              expect(
                  find
                      .textContaining('${SeatId.values.last.label}:')
                      .hitTestable(),
                  findsOneWidget);
            }
          }
          if (shape == BoardShape.square && size.width == 390 && count == 2) {
            final outer =
                tester.state<ScrollableState>(find.byType(Scrollable).first);
            expect(outer.position.maxScrollExtent, 0);
          }
          final cell = find.byKey(const ValueKey('cell-0-0'));
          await tester.tap(cell);
          await tester.pumpAndSettle();
          expect(tester.getRect(board), before);
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('STONES_CAPTURE_LAYOUT')) {
            await tester.runAsync(() async {
              final boundary = capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final picture = await boundary.toImage();
              final data =
                  await picture.toByteData(format: ui.ImageByteFormat.png);
              final output = File(
                  'build/qa/community/${shape.name}-$count-${size.width.toInt()}.png');
              await output.parent.create(recursive: true);
              await output.writeAsBytes(data!.buffer.asUint8List());
              picture.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        });
      }
    }
  }
}
