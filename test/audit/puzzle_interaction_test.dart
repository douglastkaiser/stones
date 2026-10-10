import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/main.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/providers.dart';
import 'package:stones/hex/hex_exercises.dart';
import 'package:stones/hex/hex_learning_screen.dart';
import 'package:stones/hex/hex_board.dart';
import 'package:stones/hex/hex_game.dart';

Future<void> cell(WidgetTester tester, String coordinate) async {
  final finder = find.byWidgetPredicate((widget) =>
      widget is Semantics &&
      (widget.properties.label?.startsWith('$coordinate,') ?? false));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(320, 568), const Size(1366, 768)]) {
    testWidgets(
        'square puzzle accepts an alternate root, defends, and retries at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final scenario =
          tutorialAndPuzzleLibrary.firstWhere((s) => s.id == 'square_study_04');
      container.read(scenarioStateProvider.notifier).startScenario(scenario);
      container.read(gameSessionProvider.notifier).state =
          GameSessionConfig(mode: GameMode.vsComputer, scenario: scenario);
      container
          .read(gameStateProvider.notifier)
          .loadState(scenario.buildInitialState());
      await container
          .read(appSettingsProvider.notifier)
          .setChessClockEnabled(true);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const MaterialApp(home: GameScreen())));
      await tester.pump();
      // The second proven root differs from the authored hint at a2.
      await cell(tester, 'b1');
      await cell(tester, 'b1');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(container.read(scenarioStateProvider).puzzleMoves, 1);
      expect(
          container.read(gameStateProvider).currentPlayer, PlayerColor.white);
      expect(container.read(moveHistoryProvider).length, 2);
      expect(container.read(chessClockProvider).isRunning, isFalse);
      expect(container.read(achievementProvider).completedPuzzles, isEmpty);
      final retry = find.text('Retry puzzle');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      expect(container.read(scenarioStateProvider).puzzleMoves, 0);
      expect(container.read(moveHistoryProvider), isEmpty);
      // This legal attempt is refuted rather than rejected by a hidden guide.
      await cell(tester, 'c1');
      await cell(tester, 'c1');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(container.read(scenarioStateProvider).puzzleMoves, 1);
      expect(
          container
              .read(gameStateProvider)
              .board
              .stackAt(const Position(2, 2))
              .isNotEmpty,
          isTrue);
      expect(container.read(achievementProvider).completedPuzzles, isEmpty);
      await cell(tester, 'b1');
      await cell(tester, 'b1');
      expect(container.read(scenarioStateProvider).puzzleMoves, 2);
      expect(
          container
              .read(scenarioStateProvider)
              .isFailed(container.read(gameStateProvider)),
          isTrue);
      expect(find.textContaining('Move limit reached'), findsOneWidget);
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      await cell(tester, 'b1');
      await cell(tester, 'b1');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await cell(tester, 'a2');
      await cell(tester, 'a2');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(
          container
              .read(scenarioStateProvider)
              .isSuccessful(container.read(gameStateProvider)),
          isTrue);
      expect(
          container.read(achievementProvider).completedPuzzles, {scenario.id});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
        'Hex two-move study actually defends with both opponents at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final exercise = hexExercises.firstWhere((e) => e.id == 'hex_study_05');
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(home: HexExerciseScreen(exercise: exercise))));
      Future<void> place(HexCell pos) async {
        final board = find.byType(HexBoard);
        await tester.ensureVisible(board);
        await tester.pump();
        final rect = tester.getRect(board);
        await tester.tapAt(rect.topLeft +
            HexBoardGeometry(rect.size, exercise.initial.radius).center(pos));
        await tester.pump();
        final button = find.text('Confirm');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
      }

      await place(exercise.solution.first.from);
      expect(find.textContaining('1 / 2 moves used'), findsOneWidget);
      expect(find.textContaining('Copper:'), findsOneWidget);
      expect(find.textContaining('Ivory:'), findsOneWidget);
      expect(find.text('Finish puzzle'), findsNothing);
      await place(exercise.solution.last.from);
      expect(find.text('Finish puzzle'), findsOneWidget);
      expect(find.textContaining('Complete!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    for (final exercise in hexExercises.where((e) => e.puzzle)) {
      testWidgets('${exercise.id} fits $size at enlarged text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: child!),
                home: HexExerciseScreen(exercise: exercise))));
        await tester.pump();
        await tester.ensureVisible(find.text('Retry'));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
