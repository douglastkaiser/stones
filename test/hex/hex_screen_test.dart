import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_match_provider.dart';
import 'package:stones/hex/hex_room.dart';
import 'package:stones/hex/hex_screen.dart';
import 'package:stones/models/piece.dart' show PieceType;

void main() {
  for (final size in [const Size(390, 844), const Size(1100, 900)]) {
    testWidgets(
        'hex board confirms opening placement at ${size.width.toInt()} width',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(hexMatchProvider.notifier);
      controller.startLocal(
          2, List.filled(3, HexSeatKind.localHuman), HexSeat.ivory);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HexGameScreen())));
      await tester.pump();
      final board = find.byType(HexBoard);
      final rect = tester.getRect(board);
      final geometry = HexBoardGeometry(rect.size, 2);
      await tester.tapAt(rect.topLeft + geometry.center(const HexCell(0, 0)));
      await tester.pump();
      expect(container.read(hexMatchProvider).game!.ply, 0);
      expect(
          find.text('Preview — confirm to finish your move'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();
      final game = container.read(hexMatchProvider).game!;
      expect(game.ply, 1);
      expect(game.current, HexSeat.charcoal);
      expect(game.topAt(const HexCell(0, 0))!.seat, HexSeat.charcoal);
      expect(game.topAt(const HexCell(0, 0))!.type, PieceType.flat);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('setup exposes three independent seat choices and mobile layout',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HexSetupScreen())));
    expect(find.byType(DropdownButtonFormField<HexSeatKind>), findsNWidgets(3));
    expect(find.text('19 cells'), findsOneWidget);
    expect(find.text('37 cells'), findsOneWidget);
    expect(find.text('61 cells'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('hex hit testing uses polygons and rejects gaps/outside corners', () {
    final geometry = HexBoardGeometry(const Size(700, 700), 2);
    final cells = HexGame.initial().cells;
    for (final cell in cells) {
      expect(geometry.hit(geometry.center(cell), cells), cell);
    }
    expect(geometry.hit(Offset.zero, cells), isNull);
    expect(geometry.hit(const Offset(699, 0), cells), isNull);
  });
}
