import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/hex/hex_board.dart';
import 'package:stones/hex/hex_exercises.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_learning_screen.dart';

void main() {
  testWidgets('Hex lesson uses swipe preview and second destination tap',
      (tester) async {
    final exercise = hexExercises.firstWhere((item) => item.id == 'neighbors');
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: HexExerciseScreen(exercise: exercise))));
    await tester.ensureVisible(find.byType(HexBoard));
    final rect = tester.getRect(find.byType(HexBoard));
    final geometry = HexBoardGeometry(rect.size, 2);
    final center = rect.topLeft + geometry.center(const HexCell(0, 0));
    final target = rect.topLeft + geometry.center(const HexCell(1, 0));
    await tester.flingFrom(center, target - center, 400);
    await tester.pump();
    final board = tester.widget<HexBoard>(find.byType(HexBoard));
    expect(board.preview, isTrue);
    expect(board.inspectionGame!.ply, exercise.initial.ply);
    await tester.tapAt(target);
    await tester.pump();
    expect(find.text('Objective complete'), findsOneWidget);
    expect(tester.widget<HexBoard>(find.byType(HexBoard)).preview, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final exercise in hexExercises) {
    test('${exercise.id} solution is legal and completes its objective', () {
      var game = exercise.initial;
      expect(game.finished, isFalse);
      var humanSteps = 0;
      for (var i = 0; i < exercise.solution.length; i++) {
        if (!exercise.puzzle || game.current == exercise.initial.current) {
          humanSteps++;
        }
        final move = exercise.solution[i];
        expect(exercise.accepts(game, move, i), isTrue);
        final result = HexRules.play(game, move);
        expect(result, isNotNull, reason: exercise.id);
        game = result!;
        if (i < exercise.solution.length - 1) {
          expect(exercise.completed(game, humanSteps), isFalse);
        }
      }
      expect(exercise.completed(game, humanSteps), isTrue);
      if (exercise.puzzle) expect(game.winner, exercise.initial.current);
    });
  }
  test('wrong puzzle moves and draws do not award completion', () {
    for (final exercise in hexExercises.where((item) => item.puzzle)) {
      final move = HexRules.legalMoves(exercise.initial).firstWhere(
          (move) => !HexRules.play(exercise.initial, move)!.finished);
      final result = HexRules.play(exercise.initial, move);
      expect(result, isNotNull);
      expect(exercise.completed(result!, 1), isFalse);
      expect(
          exercise.completed(
              result.copyWith(finished: true, reason: 'Draw'), 1),
          isFalse);
    }
  });
  for (final size in [const Size(320, 568), const Size(1366, 768)]) {
    testWidgets('Hex learning at $size previews, rejects failure and retries',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final exercise =
          hexExercises.firstWhere((item) => item.id == 'hex_v2_study_01');
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(home: HexExerciseScreen(exercise: exercise))));
      Future<void> cell(HexCell pos) async {
        final board = find.byType(HexBoard);
        await tester.ensureVisible(board);
        await tester.pump();
        final rect = tester.getRect(board);
        await tester
            .tapAt(rect.topLeft + HexBoardGeometry(rect.size, 2).center(pos));
        await tester.pump();
      }

      Future<void> button(String text) async {
        final finder = find.text(text);
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      await cell(const HexCell(2, -2));
      expect(find.text('Finish puzzle'), findsNothing);
      await button('Confirm');
      expect(find.textContaining('No win within'), findsOneWidget);
      expect(find.text('Finish puzzle'), findsNothing);
      await button('Retry');
      await cell(const HexCell(-1, 0));
      await cell(const HexCell(0, 0));
      await button('Confirm');
      expect(find.textContaining('Complete!'), findsOneWidget);
      expect(find.text('Finish puzzle'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('completed Hex progress is persisted separately', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HexLearningScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Six directions'));
    await tester.pumpAndSettle();
    var rect = tester.getRect(find.byType(HexBoard));
    await tester.tapAt(rect.topLeft +
        HexBoardGeometry(rect.size, 2).center(const HexCell(0, 0)));
    await tester.pump();
    rect = tester.getRect(find.byType(HexBoard));
    await tester.tapAt(rect.topLeft +
        HexBoardGeometry(rect.size, 2).center(const HexCell(1, 0)));
    await tester.pump();
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.ensureVisible(find.text('Finish lesson'));
    await tester.tap(find.text('Finish lesson'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('hex_learning_completed_v1'), ['neighbors']);
    expect(prefs.getKeys(), {'hex_learning_completed_v1'});
    await tester.pumpWidget(const SizedBox());
  });
}
