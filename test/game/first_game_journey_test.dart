import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/fundamentals.dart';
import 'package:stones/game/learning_hub.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_preset.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_setup_screen.dart';
import 'package:stones/game/study_catalog.dart';
import 'package:stones/game/study_controller.dart';
import 'package:stones/game/study_screen.dart';
import 'package:stones/models/achievement.dart';
import 'package:stones/providers/achievements_provider.dart';
import 'match_controller_test.dart' show MemoryMatchStorage;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('progress retry reports saving until the durable write completes',
      () async {
    final study = matchStudies.singleWhere((s) => s.id == 'tutorial_1');
    final write = Completer<void>();
    var attempts = 0;
    final controller = StudyController(study, onSolved: (_) async {
      attempts++;
      if (attempts == 1) throw StateError('Storage unavailable');
      await write.future;
    });
    addTearDown(controller.dispose);
    final solution = MatchRules.legalMoves(controller.state.game!)
        .firstWhere((move) => study.accepts(move, 0));
    await controller.play(solution);
    expect(controller.canRetryProgress, isTrue);
    var savingWasPublished = false;
    final stop = controller.addListener((_) {
      if (controller.savingProgress) savingWasPublished = true;
    }, fireImmediately: false);
    addTearDown(stop);
    final retry = controller.retryProgress();
    expect(savingWasPublished, isTrue);
    expect(controller.savingProgress, isTrue);
    await controller.retryProgress();
    expect(attempts, 2);
    write.complete();
    await retry;
    expect(controller.savingProgress, isFalse);
    expect(controller.canRetryProgress, isFalse);
    expect(controller.state.error, isNull);
  });

  test('presets distinguish practice, ordinary AI, local and online games', () {
    for (final shape in BoardShape.values) {
      final practice = MatchPreset.learn.configuration(shape);
      expect(practice.size, shape == BoardShape.square ? 5 : 2);
      expect(practice.court, isTrue);
      expect(practice.clockSeconds, 0);
      expect(practice.online, isFalse);
      expect(practice.seats.first.control, SeatControl.localHuman);
      expect(
          practice.seats.skip(1).every(
              (s) => s.control == SeatControl.ai && s.level == BotLevel.easy),
          isTrue);
      expect(MatchPreset.computer.configuration(shape).court, isFalse);
      expect(
          MatchPreset.sameDevice
              .configuration(shape)
              .seats
              .every((s) => s.control == SeatControl.localHuman),
          isTrue);
      expect(MatchPreset.online.configuration(shape).online, isTrue);
    }
  });

  test(
      'fundamentals obey prerequisites and unlock Morocco without variant lessons',
      () async {
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    await awards.load();
    final completed = <String>{};
    for (final id in squareFundamentals) {
      final study = matchStudies.singleWhere((s) => s.id == id);
      expect(completed.containsAll(study.prerequisites), isTrue);
      expect(nextFundamental(completed), id);
      await awards.completeTutorial(id);
      completed.add(id);
    }
    expect(nextFundamental(completed), isNull);
    expect(awards.state.isUnlocked(AchievementType.student), isTrue);
    expect(awards.state.allTutorialsCompleted, isFalse);
    final fresh = AchievementNotifier();
    addTearDown(fresh.dispose);
    await fresh.load();
    expect(fresh.state.isUnlocked(AchievementType.student), isTrue);
    expect(fresh.state.completedTutorials, completed);
  });

  test('legacy Morocco ownership survives without new learning evidence',
      () async {
    SharedPreferences.setMockInitialValues({'achievement_student': true});
    final awards = AchievementNotifier();
    addTearDown(awards.dispose);
    await awards.load();
    expect(awards.state.isUnlocked(AchievementType.student), isTrue);
    expect(awards.state.completedTutorials, isEmpty);
  });

  testWidgets(
      'Next and practice leave each lesson sandbox without changing a saved game',
      (tester) async {
    final storage = MemoryMatchStorage()..snapshot = {'id': 'keep-this-game'};
    await tester.pumpWidget(ProviderScope(
        overrides: [localMatchStorageProvider.overrideWithValue(storage)],
        child: const MaterialApp(home: LearningHub())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let’s play'));
    await tester.pumpAndSettle();
    Future<void> solve() async {
      final scope =
          ProviderScope.containerOf(tester.element(find.byType(Scaffold).last));
      final controller = scope.read(matchProvider.notifier) as StudyController;
      final move = MatchRules.legalMoves(controller.state.game!)
          .firstWhere((m) => controller.study.accepts(m, 0));
      await controller.play(move);
      await tester.pumpAndSettle();
    }

    await solve();
    final next = find.text('Next lesson: Standing Stones (Walls)');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(tester.widget<StudyScreen>(find.byType(StudyScreen)).study.id,
        'tutorial_2');
    await tester.tap(find.text('Let’s play'));
    await tester.pumpAndSettle();
    await solve();
    await tester.ensureVisible(find.text('Try a coached game').last);
    await tester.tap(find.text('Try a coached game').last);
    await tester.pumpAndSettle();
    expect(find.byType(MatchSetupScreen), findsOneWidget);
    expect(storage.snapshot, {'id': 'keep-this-game'});
    expect(tester.takeException(), isNull);
  });
}
