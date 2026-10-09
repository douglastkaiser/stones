import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/main.dart';
import 'package:stones/screens/settings_screen.dart';
import 'package:stones/screens/achievements_screen.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/game_provider.dart';
import 'package:stones/providers/game_session_provider.dart';
import 'package:stones/widgets/chess_clock_setup.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 390.0]) {
    testWidgets('clock setup fits $width with enlarged text and invalid input',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: '0');
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 844), textScaler: const TextScaler.linear(1.5)),
        child: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(24),
                child: ChessClockSetup(
                  enabled: true,
                  onEnabledChanged: (_) {},
                  minutesController: controller,
                  onMinutesChanged: (_) {},
                ))),
      )));
      expect(find.text('Enter 1–999'), findsOneWidget);
      expect(find.text('Minutes per player'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final dark in [false, true]) {
    for (final size in [
      const Size(320, 844),
      const Size(844, 390),
      const Size(1366, 768)
    ]) {
      for (final screen in [
        const SettingsScreen(),
        const AchievementsScreen()
      ]) {
        testWidgets(
            '${screen.runtimeType} scrolls at $size with enlarged text, dark=$dark',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final container = ProviderContainer();
          addTearDown(container.dispose);
          await tester.pumpWidget(UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: dark ? ThemeData.dark() : ThemeData.light(),
                home: MediaQuery(
                    data: MediaQueryData(
                        size: size, textScaler: const TextScaler.linear(1.5)),
                    child: screen),
              )));
          expect(tester.takeException(), isNull);
          for (var step = 0; step < 6; step++) {
            await tester.drag(
                find.byType(ListView).first, const Offset(0, -500));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  testWidgets(
      'finished game keeps board visible and exposes replay without terminal undo',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameStateProvider.notifier)
        .loadState(GameState.initial(3).copyWith(
          phase: GamePhase.finished,
          result: GameResult.whiteWins,
        ));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: GameScreen())));
    await tester.pump();
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo))
            .onPressed,
        isNull);
    await tester.tap(find.byTooltip('How to play'));
    await tester.pumpAndSettle();
    expect(find.text('How to play Tak'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('leaving during AI delay safely cancels the departed screen',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(gameStateProvider.notifier).newGame(3);
    container.read(gameSessionProvider.notifier).state =
        const GameSessionConfig(
            mode: GameMode.vsComputer,
            vsComputerPlayerColor: PlayerColor.black);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: GameScreen())));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(container.read(aiThinkingProvider), isFalse);
    expect(container.read(moveHistoryProvider), isEmpty);
  });
}
