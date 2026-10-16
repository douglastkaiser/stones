import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/study_catalog.dart';
import 'package:stones/game/study_controller.dart';
import 'package:stones/providers/achievements_provider.dart';
import 'package:stones/screens/achievements_screen.dart';
import '../fixtures/achievement_matches.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(320, 700), const Size(1366, 900)]) {
    for (final dark in [false, true]) {
      testWidgets('achievement gallery fits $size dark=$dark at enlarged text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final awards = container.read(achievementProvider.notifier);
        await awards.recordMatch(roadMatch());
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                theme: dark ? ThemeData.dark() : ThemeData.light(),
                home: MediaQuery(
                    data: MediaQueryData(
                        size: size, textScaler: const TextScaler.linear(2)),
                    child: const AchievementsScreen()))));
        await tester.pumpAndSettle();
        expect(find.text('0 points'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Seasoned Rival'), 700,
            maxScrolls: 100);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Seasoned Rival'));
        await tester.pumpAndSettle();
        expect(find.text('0 / 10 human opponents'), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.text('0 / 10 human opponents'))).pop();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('filters distinguish earned, progressing and untouched goals',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final awards = container.read(achievementProvider.notifier);
    for (var i = 0; i < 3; i++) {
      await awards.recordMatch(roadMatch(id: 'easy-$i', level: BotLevel.easy));
    }
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AchievementsScreen())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Earned'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Earned'));
    await tester.pumpAndSettle();
    expect(find.text('1 challenges'), findsOneWidget);
    await tester.ensureVisible(find.text('First Steps'));
    expect(find.text('Previously earned · retained'), findsNothing);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'In progress'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'In progress'));
    await tester.pumpAndSettle();
    expect(find.text('2 challenges'), findsOneWidget);
    expect(find.text('Dedicated'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Earned'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Learning'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Learning'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No achievements in this view'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'earning rules explain attribution, local saving and both board shapes',
      (tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AchievementsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Earning rules'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Square and Hex both count.'), findsOneWidget);
    expect(find.textContaining('Signing in does not synchronize it.'),
        findsOneWidget);
    expect(find.textContaining('Hex matches do not count'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test(
      'hint disclosure survives Retry and progress storage failures are recoverable',
      () async {
    final study = matchStudies
        .firstWhere((s) => s.id.startsWith('unified_v1_') && s.puzzle);
    var writes = 0;
    final controller = StudyController(study, onSolved: (study) async {
      writes++;
      if (writes == 1) {
        throw StateError('Storage failed');
      }
    });
    addTearDown(controller.dispose);
    controller.markHintUsed();
    controller.reset();
    expect(controller.hintsUsed, isTrue);
    final solution = MatchRules.legalMoves(study.initial).firstWhere((move) =>
        MatchRules.play(study.initial, move)?.result?.winner ==
        study.initial.current);
    expect(await controller.play(solution), isTrue);
    expect(controller.solved, isTrue);
    expect(controller.canRetryProgress, isTrue);
    expect(controller.state.error, contains('progress could not be saved'));
    await controller.retryProgress();
    expect(controller.canRetryProgress, isFalse);
    await controller.retryProgress();
    expect(writes, 2);
  });
}
