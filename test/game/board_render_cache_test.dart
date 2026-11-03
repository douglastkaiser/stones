import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/models/piece.dart';

BoardMaterialCache materials(WidgetTester tester) {
  final dynamic painter = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .firstWhere((w) => w.painter.runtimeType.toString() == '_BoardPainter')
      .painter;
  return painter.materials as BoardMaterialCache;
}

void main() {
  for (final shape in BoardShape.values) {
    testWidgets(
        '$shape invalidates materials and mutable style values without stale pixels',
        (tester) async {
      final config = MatchConfig.defaults(shape);
      final initial = MatchState.initial(config);
      final cell = initial.geometry.cells.first;
      var game = initial.copyWith(ply: 4, board: {
        cell: const [
          Stone(SeatId.ivory, PieceType.flat),
          Stone(SeatId.charcoal, PieceType.capstone)
        ]
      });
      final styles = <SeatId, PieceStyle>{SeatId.charcoal: PieceStyle.standard};
      var theme = BoardTheme.classicWood;
      var side = 380.0;
      final boundary = GlobalKey();
      var boardKey = UniqueKey();
      Widget screen() => MaterialApp(
          home: Center(
              child: SizedBox(
                  width: side,
                  height: side,
                  child: RepaintBoundary(
                      key: boundary,
                      child: BoardView(
                          key: boardKey,
                          game: game,
                          styles: styles,
                          theme: theme)))));
      Future<List<int>> pixels() async => (await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
            final bytes = await image.toByteData();
            final result = bytes!.buffer.asUint8List().toList();
            image.dispose();
            return result;
          }))!;
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      final first = materials(tester);
      expect(first.recordedCells, game.geometry.cells.length);
      // Updating a caller-owned map must invalidate cached piece visuals.
      styles[SeatId.charcoal] = PieceStyle.celestial;
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(materials(tester), same(first));
      final updated = await pixels();
      boardKey = UniqueKey();
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(await pixels(), updated);
      expect(first.recordedCells, 0,
          reason: 'Disposed board releases all retained pictures');
      final second = materials(tester);
      game = game.copyWith(board: {
        cell: const [
          Stone(SeatId.ivory, PieceType.standing),
          Stone(SeatId.charcoal, PieceType.capstone)
        ]
      });
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      final replaced = await pixels();
      expect(replaced, isNot(updated));
      boardKey = UniqueKey();
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(await pixels(), replaced);
      expect(second.recordedCells, 0);
      final themed = materials(tester);
      theme = BoardTheme.values.last;
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(themed.recordedCells, 0);
      final third = materials(tester);
      side = 224;
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(third.recordedCells, 0);
      final last = materials(tester);
      await tester.pumpWidget(const SizedBox());
      expect(last.recordedCells, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
