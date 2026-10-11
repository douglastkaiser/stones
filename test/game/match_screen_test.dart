import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/study_catalog.dart';
import 'package:stones/game/study_screen.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/widgets/piece_stack_view.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

void main() {
  testWidgets('completed learning shows feedback and Done in stable controls',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final study = matchStudies
        .firstWhere((study) => study.id == 'unified_v1_hex_exchange_4');
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: StudyScreen(study: study, onSolved: (study) async {}))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let’s play'));
    await tester.pumpAndSettle();
    final board = find.byKey(const ValueKey('stable-board'));
    final before = tester.getRect(board);
    for (final cell in study.initial.geometry.cells.take(4)) {
      final target = find.byKey(ValueKey('cell-${cell.x}-${cell.y}'));
      await tester.tap(target);
      await tester.pump();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }
    expect(find.text('Practice finished'), findsOneWidget);
    expect(find.text('Waiting for the current player.'), findsNothing);
    expect(find.text('Ivory to play'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.getRect(board), before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('backgrounding pauses a local clock until explicit resume',
      (tester) async {
    final storage = MemoryMatchStorage();
    final store = MemoryMatchRoomStore();
    final controller = MatchController(
        storage: storage, authenticate: () async => 'host', store: () => store);
    await controller.start(
        MatchConfig.defaults(BoardShape.square).copyWith(clockSeconds: 60));
    await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    await tester.pumpWidget(ProviderScope(
        overrides: [matchProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: MatchScreen())));
    await tester.pump();
    expect(controller.state.clock!.started[SeatId.charcoal], isNotNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(controller.state.paused, isTrue);
    expect(
        controller.state.clock!.started.values.every((v) => v == null), isTrue);
    expect(controller.state.canPlay, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.state.paused, isTrue);
    await tester.tap(find.byTooltip('Resume match'));
    await tester.pump();
    expect(controller.state.canPlay, isTrue);
    expect(controller.state.clock!.started[SeatId.charcoal], isNotNull);
    expect(storage.snapshot!['moves'], hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await store.updates.close();
  });

  for (final shape in BoardShape.values) {
    for (var count = 2; count <= 4; count++) {
      for (final size in [const Size(390, 844), const Size(1366, 900)]) {
        testWidgets('$shape $count players stable shared gestures at $size',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = MemoryMatchRoomStore();
          final controller = MatchController(
              storage: MemoryMatchStorage(),
              authenticate: () async => 'host',
              store: () => store);
          final config = MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 5 : 2,
              seats: SeatId.values.take(count).map(SeatConfig.new).toList());
          await controller.start(config);
          await tester.pumpWidget(ProviderScope(
              overrides: [matchProvider.overrideWith((ref) => controller)],
              child: const MaterialApp(home: MatchScreen())));
          await tester.pumpAndSettle();
          final board = find.byKey(const ValueKey('stable-board'));
          final before = tester.getRect(board);
          final cell = controller.state.game!.geometry.cells.first;
          final cellFinder = find.byKey(ValueKey('cell-${cell.x}-${cell.y}'));
          await tester.tap(cellFinder);
          await tester.pumpAndSettle();
          expect(controller.state.game!.board, isEmpty);
          expect(find.text('Confirm'), findsOneWidget);
          expect(tester.getRect(board), before);
          await tester.tap(cellFinder);
          await tester.pumpAndSettle();
          expect(controller.state.game!.ply, 1);
          expect(controller.state.game!.topAt(cell)!.seat, SeatId.charcoal);
          expect(tester.getRect(board), before);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await store.updates.close();
        });
      }
    }
  }

  for (final style in PieceStyle.values) {
    testWidgets(
        'both shapes render all four $style seats and buried inspector layers',
        (tester) async {
      for (final shape in BoardShape.values) {
        final config = MatchConfig.defaults(shape).addPlayer();
        final four = config.seats.length < 4 ? config.addPlayer() : config;
        final initial = MatchState.initial(four);
        final cell = initial.geometry.cells.first;
        final game = initial.copyWith(ply: 4, board: {
          cell: SeatId.values
              .map((id) => Stone(
                  id, id == SeatId.jade ? PieceType.capstone : PieceType.flat))
              .toList(),
        });
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: SizedBox.square(
                    dimension: 390,
                    child: BoardView(
                        game: game,
                        styles: {for (final id in SeatId.values) id: style},
                        theme: BoardTheme.values[style.index])))));
        await tester.pumpAndSettle();
        final stack = tester
            .widgetList<PieceStackView>(find.byType(PieceStackView))
            .firstWhere((v) => v.pieces.isNotEmpty);
        expect(stack.pieces.length, 4);
        expect(stack.pieces.last.owner, 'Jade');
        expect(stack.pieces.every((p) => p.style == style), isTrue);
        final inspector = tester
            .widgetList<StackInspection>(find.byType(StackInspection))
            .firstWhere((v) => v.pieces.isNotEmpty);
        expect(inspector.pieces.map((p) => p.owner),
            ['Ivory', 'Charcoal', 'Copper', 'Jade']);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
      'four players and large text fit narrow screen without control-induced board shift',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryMatchRoomStore();
    final controller = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => store);
    await controller.start(MatchConfig.defaults(BoardShape.hex).addPlayer());
    await tester.pumpWidget(ProviderScope(
        overrides: [matchProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: const MatchScreen())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await store.updates.close();
  });
}
