// Capture before/after from the actual shared renderer. Run separately:
// flutter test tools/performance_render_parity_test.dart \
//   --dart-define=STONES_PARITY_DIR=build/qa/performance-stage2/before-render
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/models/piece.dart';

void main() {
  testWidgets('capture shared rendering including overlapping dense highlights',
      (tester) async {
    const output = String.fromEnvironment('STONES_PARITY_DIR',
        defaultValue: 'build/qa/performance-stage2/after-render');
    final boundary = GlobalKey();
    for (final shape in BoardShape.values) {
      final config = MatchConfig(
          shape: shape,
          size: shape == BoardShape.square ? 8 : 4,
          seats: SeatId.values.map(SeatConfig.new).toList());
      final initial = MatchState.initial(config);
      final cells = initial.geometry.cells;
      final game = initial.copyWith(ply: 4, board: {
        for (var i = 0; i < 12; i++)
          cells[i + 2]: [
            if (i.isEven) ...SeatId.values.map((s) => Stone(s, PieceType.flat)),
            Stone(SeatId.values[i % 4], PieceType.values[i ~/ 4]),
          ],
      });
      for (final side in [224.0, 380.0, 760.0]) {
        tester.view.physicalSize = Size(side, side);
        tester.view.devicePixelRatio = 1;
        for (final city in BoardTheme.values) {
          for (final style in PieceStyle.values) {
            await tester.pumpWidget(MaterialApp(
                home: RepaintBoundary(
                    key: boundary,
                    child: ColoredBox(
                        color: const Color(0xFFF7F1E4),
                        child: BoardView(
                            game: game,
                            theme: city,
                            styles: {
                              for (final seat in config.ids) seat: style
                            },
                            selected: cells[8],
                            destinations: {cells[7], cells[9]},
                            road: {cells[10], cells[11]},
                            routeSource: shape == BoardShape.square
                                ? const Cell(0, 0)
                                : const Cell(-4, 0),
                            routeDirection: Step.east,
                            drops: const [1, 2, 1])))));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.runAsync(() async {
              final render = boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final image = await render.toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              final file = File(
                  '$output/${shape.name}-${side.toInt()}-${city.name}-${style.name}.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
