import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('StonesSans')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf')))
        .load();
  });
  for (final shape in BoardShape.values) {
    for (final size in shape == BoardShape.square ? [3, 5, 8] : [2, 3, 4]) {
      for (final side in [240.0, 800.0]) {
        testWidgets('$shape $size $side keeps metadata inside the clipped cell',
            (tester) async {
          tester.view.physicalSize = const Size(960, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final config = MatchConfig(shape: shape, size: size, seats: const [
            SeatConfig(SeatId.ivory),
            SeatConfig(SeatId.charcoal)
          ]);
          final original = MatchState.initial(config).copyWith(ply: 2, board: {
            const Cell(0, 0): const [
              Stone(SeatId.charcoal, PieceType.flat),
              Stone(SeatId.ivory, PieceType.flat),
              Stone(SeatId.ivory, PieceType.flat)
            ],
            const Cell(0, 1): const [Stone(SeatId.charcoal, PieceType.flat)],
          });
          final draft = MatchRules.previewSpread(
              original, const Cell(0, 0), 3, Step.east, [1]);
          await tester.pumpWidget(MaterialApp(
              theme: ThemeData(fontFamily: 'StonesSans'),
              home: Scaffold(
                  body: SizedBox.square(
                      dimension: side,
                      child: BoardView(
                          game: draft.position!,
                          original: original,
                          selected: const Cell(0, 0),
                          routeSource: const Cell(0, 0),
                          routeDirection: Step.east,
                          drops: const [1],
                          carried: draft.hand,
                          handCell: const Cell(1, 0),
                          destinations: {const Cell(2, 0)})))));
          await tester.pumpAndSettle();
          final board = tester.getRect(find.byType(BoardView));
          final layout = BoardLayout(board.size, original.geometry);
          final badges = {
            'staged-count-1,0': const Cell(1, 0),
            'stack-owner-0,1': const Cell(0, 1),
            if (layout.unit >= 20) ...{
              'carry-count-1,0': const Cell(1, 0),
              'drop-target-2,0': const Cell(2, 0),
            },
          };
          for (final badge in badges.entries) {
            final bounds =
                tester.getRect(find.byKey(ValueKey(badge.key))).deflate(.1);
            final polygon = layout.polygon(badge.value);
            for (final corner in [
              bounds.topLeft,
              bounds.topRight,
              bounds.bottomLeft,
              bounds.bottomRight
            ]) {
              expect(polygon.contains(corner - board.topLeft), isTrue,
                  reason:
                      '${badge.key} must fit completely inside its cell at $bounds');
            }
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
