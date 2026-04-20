import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/providers.dart';
import 'package:stones/screens/main_menu_screen.dart';
import 'package:stones/services/play_games_service.dart';
import 'package:stones/services/sound_manager.dart';

class _TestAchievementNotifier extends AchievementNotifier {
  _TestAchievementNotifier(AchievementState initial) {
    state = initial;
  }

  @override
  Future<void> load() async {}
}

class _TestGameStateNotifier extends GameStateNotifier {
  _TestGameStateNotifier(GameState initial) {
    state = initial;
  }
}

class _TestScenarioStateNotifier extends ScenarioStateNotifier {
  _TestScenarioStateNotifier(ScenarioState initial) {
    state = initial;
  }
}

class _TestEloController extends EloController {
  @override
  Future<void> initialize() async {}
}

class _TestSoundManager extends SoundManager {
  bool _muted = false;

  @override
  bool get isMuted => _muted;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setMuted(bool muted) async {
    _muted = muted;
  }

  @override
  Future<void> dispose() async {}
}

Widget _buildTestApp({
  required ProviderContainer container,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: MainMenuScreen(),
    ),
  );
}

ProviderContainer _makeContainer({
  AchievementState achievementState = const AchievementState(),
  GameState? gameState,
  ScenarioState scenarioState = const ScenarioState(),
}) {
  return ProviderContainer(
    overrides: [
      achievementProvider.overrideWith(
        () => _TestAchievementNotifier(achievementState),
      ),
      gameStateProvider.overrideWith(
        () => _TestGameStateNotifier(gameState ?? GameState.initial(5)),
      ),
      scenarioStateProvider.overrideWith(
        () => _TestScenarioStateNotifier(scenarioState),
      ),
      soundManagerProvider.overrideWithValue(_TestSoundManager()),
      eloProvider.overrideWith(() => _TestEloController()),
      // Keep this deterministic so scenario flow writes a stable value.
      gameSessionProvider.overrideWith((ref) => const GameSessionConfig()),
      // Keep Play Games inert in tests.
      playGamesServiceProvider.overrideWith((ref) => PlayGamesService(ref)),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> _openScenarioDialog(WidgetTester tester) async {
    await tester.tap(find.text('Tutorials & Puzzles'));
    await tester.pumpAndSettle();
  }

  group('Main menu scenario selector', () {
    testWidgets('opens the Tutorials & Puzzles dialog', (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildTestApp(container: container));
      await tester.pumpAndSettle();

      await _openScenarioDialog(tester);

      expect(find.text('Tutorials & Puzzles'), findsOneWidget);
      expect(find.text('Building a Road'), findsOneWidget);
    });

    testWidgets('tapping a scenario tile launches scenario flow', (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildTestApp(container: container));
      await tester.pumpAndSettle();

      await _openScenarioDialog(tester);
      await tester.tap(find.text('Building a Road'));
      await tester.pumpAndSettle();

      final scenario = container.read(scenarioStateProvider).activeScenario;
      final sessionScenario = container.read(gameSessionProvider).scenario;

      expect(scenario?.id, 'tutorial_1');
      expect(sessionScenario?.id, 'tutorial_1');
    });

    testWidgets('shows replace-confirmation when game is already in progress', (tester) async {
      final inProgressGame = GameState.initial(5).copyWith(
        turnNumber: 2,
        phase: GamePhase.playing,
      );
      final container = _makeContainer(gameState: inProgressGame);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildTestApp(container: container));
      await tester.pumpAndSettle();

      await _openScenarioDialog(tester);
      await tester.tap(find.text('Building a Road'));
      await tester.pumpAndSettle();

      expect(find.text('Replace current game?'), findsOneWidget);
      expect(
        find.textContaining('will replace the game you are currently playing.'),
        findsOneWidget,
      );
    });

    testWidgets('cancel keeps current game, confirm starts selected scenario', (tester) async {
      final inProgressGame = GameState.initial(5).copyWith(
        turnNumber: 2,
        phase: GamePhase.playing,
      );
      final container = _makeContainer(gameState: inProgressGame);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildTestApp(container: container));
      await tester.pumpAndSettle();

      await _openScenarioDialog(tester);
      await tester.tap(find.text('Building a Road'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(container.read(scenarioStateProvider).activeScenario, isNull);
      expect(container.read(gameStateProvider).boardSize, 5);
      expect(container.read(gameStateProvider).turnNumber, 2);

      await _openScenarioDialog(tester);
      await tester.tap(find.text('Building a Road'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Scenario'));
      await tester.pumpAndSettle();

      expect(container.read(scenarioStateProvider).activeScenario?.id, 'tutorial_1');
      expect(container.read(gameSessionProvider).scenario?.id, 'tutorial_1');
      expect(container.read(gameStateProvider).boardSize, 4);
    });

    testWidgets('renders completion badges based on achievement state', (tester) async {
      final container = _makeContainer(
        achievementState: const AchievementState(
          completedTutorials: {'tutorial_1'},
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildTestApp(container: container));
      await tester.pumpAndSettle();

      await _openScenarioDialog(tester);

      final tutorial1Tile = find.ancestor(
        of: find.text('Building a Road'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: tutorial1Tile, matching: find.text('Completed')),
        findsOneWidget,
      );
    });

    testWidgets('renders locked vs unlocked scenarios based on progression gating',
        (tester) async {
      final lockedContainer = _makeContainer();
      addTearDown(lockedContainer.dispose);

      await tester.pumpWidget(_buildTestApp(container: lockedContainer));
      await tester.pumpAndSettle();
      await _openScenarioDialog(tester);

      final tutorial2TileLocked = find.ancestor(
        of: find.text('Standing Stones (Walls)'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: tutorial2TileLocked, matching: find.text('Locked')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tutorial2TileLocked,
          matching: find.text('Complete previous scenarios to unlock.'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      final unlockedContainer = _makeContainer(
        achievementState: const AchievementState(
          completedTutorials: {'tutorial_1'},
        ),
      );
      addTearDown(unlockedContainer.dispose);

      await tester.pumpWidget(_buildTestApp(container: unlockedContainer));
      await tester.pumpAndSettle();
      await _openScenarioDialog(tester);

      final tutorial2TileUnlocked = find.ancestor(
        of: find.text('Standing Stones (Walls)'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: tutorial2TileUnlocked, matching: find.text('Locked')),
        findsNothing,
      );
      expect(
        find.descendant(of: tutorial2TileUnlocked, matching: find.text('Tutorial')),
        findsOneWidget,
      );
    });
  });
}
