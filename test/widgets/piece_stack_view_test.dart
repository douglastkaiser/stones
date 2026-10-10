import 'dart:ui' show PointerDeviceKind, SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/hex/hex_board.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/widgets/piece_stack_view.dart';
import 'package:stones/widgets/procedural_painters.dart';

void main() {
  StackVisualPiece visual(PieceType type,
          {PieceStyle style = PieceStyle.standard}) =>
      StackVisualPiece(
          type: type,
          style: style,
          colors: PieceStyleData.forStyle(style).colorsForPlayer(true),
          owner: 'Ivory');

  test(
      'stack layouts fit every layer across sizes, orientations and tall previews',
      () {
    for (final size in [
      const Size(8, 8),
      const Size(36, 36),
      const Size(100, 40),
      const Size(40, 100)
    ]) {
      for (final count in [1, 2, 3, 5, 50]) {
        for (final type in PieceType.values) {
          final pieces = List.generate(
              count, (i) => visual(i.isEven ? type : PieceType.flat));
          for (final expanded in [false, true]) {
            final layout = StackLayerLayout(size, pieces, expanded: expanded);
            expect(layout.layers.last.index, count - 1);
            for (final layer in layout.layers) {
              expect(layer.rect.left, greaterThanOrEqualTo(0));
              expect(layer.rect.top, greaterThanOrEqualTo(0));
              expect(layer.rect.right, lessThanOrEqualTo(size.width));
              expect(layer.rect.bottom, lessThanOrEqualTo(size.height));
            }
          }
        }
      }
    }
    expect(
        StackLayerLayout(Size.zero, [visual(PieceType.flat)], expanded: true)
            .layers,
        isEmpty);
  });

  testWidgets('hover restarts on changed contents, never fans an emptied stack',
      (tester) async {
    var pieces = [visual(PieceType.flat), visual(PieceType.capstone)];
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 80,
                height: 80,
                child: StatefulBuilder(builder: (context, setState) {
                  update = setState;
                  return StackInspection(
                      label: 'Lifecycle',
                      pieces: pieces,
                      builder: (expanded) =>
                          PieceStackView(pieces: pieces, expanded: expanded));
                })))));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(PieceStackView)));
    await tester.pump(const Duration(milliseconds: 200));
    update(() => pieces = [
          visual(PieceType.flat, style: PieceStyle.morocco),
          visual(PieceType.capstone)
        ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<PieceStackView>(find.byType(PieceStackView)).expanded,
        isFalse);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<PieceStackView>(find.byType(PieceStackView)).expanded,
        isTrue);
    update(() => pieces.clear()); // Defensive against mutable caller lists.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<PieceStackView>(find.byType(PieceStackView)).expanded,
        isFalse);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated inspection requests open just one snapshot',
      (tester) async {
    final pieces = [visual(PieceType.flat), visual(PieceType.capstone)];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 80,
                    height: 80,
                    child: StackInspection(
                        label: 'Snapshot',
                        pieces: pieces,
                        builder: (expanded) => PieceStackView(
                            pieces: pieces, expanded: expanded)))))));
    final semantics = tester.widget<Semantics>(find
        .descendant(
            of: find.byType(StackInspection), matching: find.byType(Semantics))
        .first);
    semantics.properties.onLongPress!();
    semantics.properties.onLongPress!();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Snapshot · 2 pieces'), findsOneWidget);
    pieces.clear();
    await tester.pump();
    expect(find.text('Ivory capstone'), findsOneWidget);
    await tester.tap(find.byTooltip('Close stack inspection'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Hex lifted source remains inspectable and incoming stones are previews',
      (tester) async {
    const source = HexCell(0, 0);
    final original = HexGame(
        radius: 2,
        ply: 6,
        reserves: HexGame.initial().reserves,
        board: {
          source: const [
            HexStone(HexSeat.charcoal, PieceType.flat),
            HexStone(HexSeat.ivory, PieceType.capstone)
          ]
        });
    final preview = HexRules.play(
        original, HexMove.spread(source, HexDirection.east, [2]))!;
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Scaffold(
                body: HexBoard(
                    game: preview,
                    inspectionGame: original,
                    preview: true,
                    selected: source)))));
    final rect = tester.getRect(find.byType(HexBoard));
    final geometry = HexBoardGeometry(rect.size, 2);
    await tester.longPressAt(rect.topLeft + geometry.center(source));
    await tester.pumpAndSettle();
    expect(find.text('Stack 0, 0 · before move · 2 pieces'), findsOneWidget);
    expect(find.text('Ivory capstone'), findsOneWidget);
    expect(find.text('Charcoal flat'), findsOneWidget);
    await tester.tap(find.byTooltip('Close stack inspection'));
    await tester.pumpAndSettle();
    await tester
        .longPressAt(rect.topLeft + geometry.center(const HexCell(1, 0)));
    await tester.pumpAndSettle();
    expect(find.text('Ivory capstone (preview)'), findsOneWidget);
    expect(find.text('Charcoal flat (preview)'), findsOneWidget);
    expect(original.stackAt(source), hasLength(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('occupied Hex cell exposes one label and one tap action',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    final game =
        HexGame(radius: 2, reserves: HexGame.initial().reserves, board: {
      const HexCell(0, 0): const [HexStone(HexSeat.ivory, PieceType.flat)]
    });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home:
                Scaffold(body: HexBoard(game: game, onCell: (_) => taps++)))));
    const label = 'Cell 0, 0, Ivory flat, 1 pieces';
    final cell = find.bySemanticsLabel(label);
    expect(cell, findsOneWidget);
    var node = tester.getSemantics(cell);
    while (node.isMergedIntoParent) {
      node = node.parent!;
    }
    var children = 0;
    node.visitChildren((child) {
      if (!child.isMergedIntoParent) {
        children++;
      }
      return true;
    });
    expect(children, 0,
        reason: 'Decorative pieces must not create nested buttons');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
        reason: node.toStringDeep());
    tester
        .element(cell)
        .findRenderObject()!
        .owner!
        .semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(taps, 1);
    await tester.tap(cell);
    await tester.pump();
    expect(taps, 2);
    await tester.longPress(cell);
    await tester.pumpAndSettle();
    expect(find.text('Ivory flat'), findsOneWidget);
    expect(taps, 2);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'quick hover cancels, clicking a fanned stack still moves, disposal cancels timers',
      (tester) async {
    final style = PieceStyleData.forStyle(PieceStyle.standard);
    final pieces = List.generate(
        3,
        (_) => StackVisualPiece(
            type: PieceType.flat,
            style: style.style,
            colors: style.colorsForPlayer(true),
            owner: 'Ivory'));
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 80,
                height: 80,
                child: StackInspection(
                    pieces: pieces,
                    label: 'Test stack',
                    builder: (expanded) => GestureDetector(
                        onTap: () => taps++,
                        child: PieceStackView(
                            pieces: pieces, expanded: expanded)))))));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    final center = tester.getCenter(find.byType(PieceStackView));
    await mouse.moveTo(center);
    await tester.pump(const Duration(milliseconds: 100));
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<PieceStackView>(find.byType(PieceStackView)).expanded,
        isFalse);
    await mouse.moveTo(center);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<PieceStackView>(find.byType(PieceStackView)).expanded,
        isTrue);
    await tester.tap(find.byType(PieceStackView));
    await tester.pump();
    expect(taps, 1);
    expect(find.byTooltip('Close stack inspection'), findsNothing);
    expect(tester.widget<PieceStackView>(find.byType(PieceStackView)).expanded,
        isFalse);
    await mouse.moveTo(Offset.zero);
    await mouse.moveTo(center);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 568), const Size(1100, 900)]) {
    for (final radius in [2, 3, 4]) {
      testWidgets('Hex mixed stack is inspectable at $size, radius $radius',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const cell = HexCell(0, 0);
        final game = HexGame(
            radius: radius,
            reserves: HexGame.initial(radius: radius).reserves,
            finished: true,
            board: {
              cell: const [
                HexStone(HexSeat.ivory, PieceType.flat),
                HexStone(HexSeat.charcoal, PieceType.flat),
                HexStone(HexSeat.copper, PieceType.capstone),
              ]
            });
        await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: child!),
                home: Scaffold(
                    body: HexBoard(game: game, pieceStyles: const [
                  PieceStyle.morocco,
                  PieceStyle.kyoto,
                  PieceStyle.stone
                ])))));
        final semantics = tester.ensureSemantics();
        await tester.pump();
        expect(
            find.bySemanticsLabel(
                RegExp('^Cell 0, 0, Copper capstone, 3 pieces')),
            findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'^Cu$')), findsNothing);
        expect(find.bySemanticsLabel(RegExp(r'^Ch$')), findsNothing);
        final paints = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<ThemedPiecePainter>()
            .toList();
        expect(
            paints.map((p) => p.style),
            containsAll(
                [PieceStyle.morocco, PieceStyle.kyoto, PieceStyle.stone]));
        final rect = tester.getRect(find.byType(HexBoard));
        final point =
            rect.topLeft + HexBoardGeometry(rect.size, radius).center(cell);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(point);
        await tester.pump(const Duration(milliseconds: 250));
        expect(
            tester
                .widgetList<PieceStackView>(find.byType(PieceStackView))
                .where((w) => w.expanded),
            hasLength(1));
        await mouse.moveTo(Offset.zero);
        await tester.pump();
        expect(
            tester
                .widgetList<PieceStackView>(find.byType(PieceStackView))
                .any((w) => w.expanded),
            isFalse);
        await mouse.removePointer();
        await tester.longPressAt(point);
        await tester.pumpAndSettle();
        expect(find.text('Copper capstone'), findsOneWidget);
        expect(find.text('Top · controls this stack'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Charcoal flat'), 100,
            scrollable: find.byType(Scrollable).last);
        await tester.scrollUntilVisible(find.text('Bottom'), 100,
            scrollable: find.byType(Scrollable).last);
        expect(find.text('Ivory flat'), findsOneWidget);
        expect(find.text('Bottom'), findsOneWidget);
        await tester.tap(find.byTooltip('Close stack inspection'));
        await tester.pumpAndSettle();
        expect(game.stackAt(cell), hasLength(3));
        expect(tester.takeException(), isNull);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('tall stacks and ghosts stay bounded; full inspector scrolls',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final style = PieceStyleData.forStyle(PieceStyle.morocco);
    final pieces = List.generate(
        50,
        (i) => StackVisualPiece(
            type: i == 49 ? PieceType.standing : PieceType.flat,
            style: style.style,
            colors: style.colorsForPlayer(i.isEven),
            owner: i.isEven ? 'Ivory' : 'Charcoal',
            isLight: i.isEven,
            preview: i >= 47));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 36,
                    height: 36,
                    child: StackInspection(
                        pieces: pieces,
                        label: 'Tall stack',
                        builder: (expanded) => PieceStackView(
                            pieces: pieces, expanded: expanded)))))));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(PieceStackView)));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    final cell = tester.getRect(find.byType(PieceStackView));
    final paints = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter is ThemedPiecePainter);
    expect(paints, hasLength(5));
    for (final paint in paints) {
      final rect = tester.getRect(find.byWidget(paint));
      expect(cell.contains(rect.topLeft), isTrue);
      expect(cell.contains(rect.bottomRight - const Offset(.01, .01)), isTrue);
    }
    await tester.longPress(find.byType(PieceStackView));
    await tester.pumpAndSettle();
    expect(find.text('Charcoal wall (preview)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Bottom'), 180,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Bottom'), findsOneWidget);
    expect(find.text('Ivory flat'), findsWidgets);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });
}
