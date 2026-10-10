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

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1100, 900),
    const Size(1280, 720),
  ]) {
    for (final radius in [2, 3, 4]) {
      testWidgets('Hex board stays anchored through moves R$radius $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(hexMatchProvider.notifier);
        controller.startLocal(
            radius, List.filled(3, HexSeatKind.localHuman), HexSeat.ivory);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler:
                            TextScaler.linear(size.width == 320 ? 1.5 : 1)),
                    child: child!),
                home: const HexGameScreen())));
        await tester.pump();
        final board = find.byType(HexBoard);
        await Scrollable.ensureVisible(tester.element(board), alignment: .5);
        await tester.pumpAndSettle();
        final outerPosition = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        final scrollOffset = outerPosition.pixels;
        final original = tester.getRect(board);
        final geometry = HexBoardGeometry(original.size, radius);
        void anchored() {
          expect(tester.getRect(board), original);
          expect(tester.takeException(), isNull);
        }

        Future<void> tapCell(HexCell cell) async {
          await tester.tapAt(original.topLeft + geometry.center(cell));
          await tester.pump();
          anchored();
        }

        Future<void> cancel() async {
          final button = find.widgetWithText(TextButton, 'Cancel');
          // Large-text phones need intentional scrolling to reach the dock.
          // Return to the same scroll offset before comparing board geometry.
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pump();
          outerPosition.jumpTo(scrollOffset);
          await tester.pump();
          anchored();
          expect(find.text('Cancel'), findsNothing);
        }

        // Placement previews and cancellation must not resize or recenter cells.
        await tapCell(const HexCell(0, 0));
        expect(
            find.text('Preview — confirm to finish your move'), findsOneWidget);
        await cancel();
        // Build a mixed two-stone stack through real legal moves.
        for (final move in [
          HexMove.place(const HexCell(0, 0), PieceType.flat),
          HexMove.place(const HexCell(1, -1), PieceType.flat),
          HexMove.place(const HexCell(-1, 0), PieceType.flat),
          HexMove.spread(const HexCell(-1, 0), HexDirection.east, [1]),
          HexMove.place(const HexCell(-2, 0), PieceType.flat),
          HexMove.place(const HexCell(2, -1), PieceType.flat),
        ]) {
          expect(await controller.play(move), isTrue);
          await tester.pump();
          anchored();
        }
        await tapCell(const HexCell(0, 0));
        expect(find.text('Carry 2'), findsOneWidget);
        await tapCell(const HexCell(1, 0));
        expect(find.text('Drop 2'), findsOneWidget);
        await cancel();
        controller.togglePause();
        await tester.pump();
        anchored();
        await tester.pumpWidget(const SizedBox());
      });
    }
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
