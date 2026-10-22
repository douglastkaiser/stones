import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/board_viewport.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/match_table_layout.dart';

void main() {
  test('layout uses capacity and retains full-width portrait boards', () {
    for (final width in [320.0, 390.0, 768.0]) {
      final layout = MatchLayoutPolicy(Size(width, 1024), 280);
      expect(layout.beside, isFalse);
      expect(layout.boardSide, math.min(width, 760));
    }
    expect(const MatchLayoutPolicy(Size(568, 264), 280).beside, isTrue);
    expect(const MatchLayoutPolicy(Size(568, 264), 400).beside, isFalse);
    expect(const MatchLayoutPolicy(Size(844, 334), 280).boardSide, 310);
  });

  test('precision zoom follows actual polygons including future board sizes',
      () {
    for (final geometry in <BoardGeometry>[
      for (final size in [2, 3, 8, 12, 16, 80]) SquareGeometry(size),
      for (final radius in [1, 2, 4, 5, 8, 20]) HexGeometry(radius),
    ]) {
      final controller = BoardViewportController();
      for (final side in [224.0, 320.0, 760.0]) {
        controller.configure(Size.square(side), geometry);
        final layout = BoardLayout(Size.square(side), geometry);
        final diameter = geometry is HexGeometry
            ? math.sqrt(3) * .94 * layout.unit
            : 1.92 * layout.unit;
        expect(diameter * controller.precisionZoom,
            greaterThanOrEqualTo(48 - 1e-8));
        expect(
            controller.maxZoom, greaterThanOrEqualTo(controller.precisionZoom));
        for (final cell in geometry.cells) {
          final rect = layout.polygon(cell).getBounds();
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(side));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(side));
        }
      }
      controller.dispose();
    }
  });

  test('resizing retains zoom and a bounded board-space focus', () {
    final controller = BoardViewportController();
    controller.configure(const Size.square(320), SquareGeometry(8));
    controller.magnify(true);
    controller.reveal(const Cell(6, 6), SquareGeometry(8));
    final zoom = controller.zoom;
    final center = controller.center;
    controller.configure(const Size.square(224), SquareGeometry(8));
    expect(controller.zoom, zoom);
    expect(controller.center, center);
    controller.fit();
    expect(controller.zoom, 1);
    expect(controller.center, const Offset(.5, .5));
    controller.dispose();
  });

  for (final shape in BoardShape.values) {
    testWidgets('$shape pinch and explicit pan cannot place or spread',
        (tester) async {
      final controller = BoardViewportController();
      final game = MatchState.initial(MatchConfig.defaults(shape));
      var taps = 0;
      var drags = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
        child: SizedBox.square(
            dimension: 320,
            child: BoardViewport(
              controller: controller,
              geometry: game.geometry,
              child: BoardView(
                  game: game,
                  onCell: (_) {
                    if (!controller.blocksMoves) taps++;
                  },
                  onSwipe: (_, __) {
                    if (!controller.blocksMoves) drags++;
                  }),
            )),
      ))));
      final rect = tester.getRect(find.byType(BoardViewport));
      final first = await tester.startGesture(rect.center - const Offset(25, 0),
          pointer: 1);
      final second = await tester
          .startGesture(rect.center + const Offset(25, 0), pointer: 2);
      await first.moveBy(const Offset(-40, 0));
      await second.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(controller.zoom, greaterThan(1));
      await first.up();
      await second.up();
      await tester.pump();
      expect(taps, 0);
      expect(drags, 0);
      controller.togglePan();
      await tester.pump();
      final beforePan = controller.center;
      await tester.drag(find.byType(BoardViewport), const Offset(40, 30));
      await tester.pump();
      expect(taps, 0);
      expect(drags, 0);
      expect(controller.center, isNot(beforePan));
      controller.togglePan();
      controller.fit();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cell-0-0')));
      await tester.pump();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
