import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/theme/tavern_theme.dart';
import 'stack_interaction_test.dart' show PositionController, capture;

void main() {
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
        const Size(844, 390),
        const Size(1366, 900)
      ]) {
        testWidgets('task evidence $shape $count $size', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = PositionController();
          await controller.start(MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 5 : 2,
              seats: [
                for (final seat in SeatId.values.take(count)) SeatConfig(seat)
              ]));
          controller
              .replace(controller.state.game!.copyWith(ply: count, board: {
            const Cell(0, 0): [
              const Stone(SeatId.charcoal, PieceType.flat),
              const Stone(SeatId.ivory, PieceType.flat),
              const Stone(SeatId.ivory, PieceType.flat)
            ],
          }));
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
              key: key,
              child: ProviderScope(
                  overrides: [matchProvider.overrideWith((ref) => controller)],
                  child: MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: TavernTheme.build(Brightness.light),
                      home: const MatchScreen()))));
          await tester.pumpAndSettle();
          final name = 'adaptive-${shape.name}-$count-${size.width.toInt()}';
          var scrolls = 0;
          var taps = 0;
          final evidence = <String, Object>{};
          Future<void> tap(Finder finder) async {
            if (finder.hitTestable().evaluate().isEmpty) {
              scrolls++;
              await tester.ensureVisible(finder);
              await tester.pumpAndSettle();
            }
            await tester.tap(finder);
            taps++;
            await tester.pumpAndSettle();
          }

          Future<void> snapshot(String state) async {
            final board = find.byKey(const ValueKey('stable-board'));
            final rect = tester.getRect(board);
            final scroll =
                find.ancestor(of: board, matching: find.byType(Scrollable));
            final visible = scroll.evaluate().isEmpty
                ? rect
                : rect.intersect(tester.getRect(scroll.first));
            evidence[state] = {
              'boardSide': rect.width,
              'visibleHeight': visible.height.clamp(0, rect.height),
              'taps': taps,
              'scrolls': scrolls
            };
            await capture(tester, key, '$name-$state');
          }

          await snapshot('idle');
          await tap(find.byKey(const ValueKey('cell-0-0')));
          await snapshot('carry');
          await tap(find.byKey(const ValueKey('cell-1-0')));
          await snapshot('staged');
          await tap(find.byTooltip('Undo last drop'));
          await tap(find.byKey(const ValueKey('cell-1-0')));
          await tap(find.text('Drop remaining here'));
          await tap(find.text('Confirm move'));
          expect(controller.state.game!.ply, count + 1);
          expect(controller.state.game!.stackAt(const Cell(1, 0)).length, 3);
          expect(tester.takeException(), isNull);
          await snapshot('confirmed');
          if (const bool.fromEnvironment('STONES_CAPTURE_STACKS')) {
            await tester.runAsync(() async {
              final file = File('build/qa/stacks/$name.json');
              await file.parent.create(recursive: true);
              await file.writeAsString(
                  const JsonEncoder.withIndent('  ').convert(evidence));
            });
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
