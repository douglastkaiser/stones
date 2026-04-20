import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/achievements_provider.dart';
import 'package:stones/providers/cosmetics_provider.dart';
import 'package:stones/providers/elo_provider.dart';
import 'package:stones/providers/providers.dart';
import 'package:stones/providers/scenario_provider.dart';
import 'package:stones/providers/settings_provider.dart';
import 'package:stones/screens/main_menu_screen.dart';
import 'package:stones/services/play_games_service.dart';
import 'package:stones/services/sound_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Main menu scenario selector', () {
    testWidgets('opens the Tutorials & Puzzles dialog from main menu', (tester) async {
      final container = await _pumpMainMenu(tester);

      expect(container.read(scenarioStateProvider).activeScenario, isNull);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Tutorials & Puzzles'));
      await tester.pumpAndSettle();

      expect(find.text('Tutorials & Puzzles'), findsOneWidget);
      expect(find.text('Building a Road'), findsOneWidget);
      expect(find.text('Capture and Win'), findsOneWidget);
    });

    testWidgets('tapping a scenario tile starts scenario flow', (tester) async {
      final container = await _pumpMainMenu(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Tutorials & Puzzles'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Building a Road'));
      await tester.pump();

      final scenarioState = container.read(scenarioStateProvider);
      final gameSession = container.read(gameSessionProvider);
      expect(scenarioState.activeScenario?.id, 'tutorial_1');
      expect(gameSession.scenario?.id, 'tutorial_1');
      expect(gameSession.mode, GameMode.vsComputer);
    });

    testWidgets('shows replace confirmation dialog when game is in progress', (tester) async {
      await _pumpMainMenu(
        tester,
        gameState: _inProgressGameState(),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Tutorials & Puzzles'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Building a Road'));
      await tester.pumpAndSettle();

      expect(find.text('Replace current game?'), findsOneWidget);
      expect(
        find.textContaining('will replace the game you are currently playing.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Start Scenario'), findsOneWidget);
    });

    testWidgets('cancel keeps current game, confirm starts selected scenario', (tester) async {
      final initialGame = _inProgressGameState();
      final container = await _pumpMainMenu(
        tester,
        gameState: initialGame,
      );

      // First attempt: cancel replacement.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tutorials & Puzzles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Building a Road'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(container.read(scenarioStateProvider).activeScenario, isNull);
      expect(container.read(gameStateProvider), initialGame);

      // Second attempt: confirm replacement.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tutorials & Puzzles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Building a Road'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Scenario'));
      await tester.pump();

      expect(container.read(scenarioStateProvider).activeScenario?.id, 'tutorial_1');
      expect(container.read(gameSessionProvider).scenario?.id, 'tutorial_1');
      expect(container.read(gameStateProvider), tutorialAndPuzzleLibrary.first.buildInitialState());
    });

    testWidgets('renders completion badges from mocked achievement state', (tester) async {
      await _pumpMainMenu(
        tester,
        achievementState: const AchievementState(
          completedTutorials: {'tutorial_1'},
          completedPuzzles: {'puzzle_6'},
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Tutorials & Puzzles'));
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsNWidgets(2));
      expect(
        find.descendant(
          of: _scenarioTileForTitle('Building a Road'),
          matching: find.text('Completed'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _scenarioTileForTitle('Capture and Win'),
          matching: find.text('Completed'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders locked vs unlocked scenarios based on progression gating', (tester) async {
      // Without tutorial_9 completion, first puzzle should be locked.
      await _pumpMainMenu(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tutorials & Puzzles'));
      await tester.pumpAndSettle();

      final lockedPuzzleTile = _scenarioTileForTitle('Capture and Win');
      expect(
        find.descendant(of: lockedPuzzleTile, matching: find.text('Locked')),
        findsOneWidget,
      );
      final lockedListTile = tester.widget<ListTile>(
        find.descendant(of: lockedPuzzleTile, matching: find.byType(ListTile)),
      );
      expect(lockedListTile.onTap, isNull);

      // Rebuild with progression prerequisite completed; puzzle should unlock.
      final container = await _pumpMainMenu(
        tester,
        achievementState: const AchievementState(completedTutorials: {'tutorial_9'}),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tutorials & Puzzles'));
      await tester.pumpAndSettle();

      final unlockedPuzzleTile = _scenarioTileForTitle('Capture and Win');
      expect(
        find.descendant(of: unlockedPuzzleTile, matching: find.text('Locked')),
        findsNothing,
      );
      final unlockedListTile = tester.widget<ListTile>(
        find.descendant(of: unlockedPuzzleTile, matching: find.byType(ListTile)),
      );
      expect(unlockedListTile.onTap, isNotNull);

      // Confirm unlocked tile can be launched and provider state changes deterministically.
      await tester.tap(find.text('Capture and Win'));
      await tester.pump();
      expect(container.read(scenarioStateProvider).activeScenario?.id, 'puzzle_6');
    });
  });
}

Finder _scenarioTileForTitle(String title) {
  return find.ancestor(
    of: find.text(title),
    matching: find.byType(Container),
  ).first;
}

Future<ProviderContainer> _pumpMainMenu(
  WidgetTester tester, {
  AchievementState achievementState = const AchievementState(),
  GameState? gameState,
  ScenarioState scenarioState = const ScenarioState(),
}) async {
  final container = ProviderContainer(
    overrides: [
      achievementProvider.overrideWith(() => _TestAchievementNotifier(achievementState)),
      gameStateProvider.overrideWith(() => _TestGameStateNotifier(gameState ?? GameState.initial(5))),
      scenarioStateProvider.overrideWith(() => _TestScenarioStateNotifier(scenarioState)),
      appSettingsProvider.overrideWith(() => _TestAppSettingsNotifier()),
      cosmeticsProvider.overrideWith(() => _TestCosmeticsNotifier()),
      eloProvider.overrideWith(() => _TestEloController()),
      playGamesServiceProvider.overrideWith((ref) => _TestPlayGamesService(ref)),
      soundManagerProvider.overrideWithValue(_TestSoundManager()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MainMenuScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

GameState _inProgressGameState() {
  final board = GameState.initial(5).board.placePiece(
    const Position(0, 0),
    const Piece(type: PieceType.flat, color: PlayerColor.white),
  );
  return GameState.initial(5).copyWith(
    board: board,
    turnNumber: 2,
    phase: GamePhase.playing,
  );
}

class _TestAchievementNotifier extends AchievementNotifier {
  _TestAchievementNotifier(AchievementState initial) : super() {
    state = initial;
  }

  @override
  Future<void> load() async {}
}

class _TestGameStateNotifier extends GameStateNotifier {
  _TestGameStateNotifier(GameState initial) : super() {
    state = initial;
  }
}

class _TestScenarioStateNotifier extends ScenarioStateNotifier {
  _TestScenarioStateNotifier(ScenarioState initial) : super() {
    state = initial;
  }
}

class _TestAppSettingsNotifier extends AppSettingsNotifier {
  _TestAppSettingsNotifier() : super() {
    state = const AppSettings(
      boardSize: 5,
      isSoundMuted: false,
      chessClockEnabled: false,
      chessClockDefaults: ChessClockDefaults.baseTimes,
    );
  }

  @override
  Future<void> load() async {}
}

class _TestCosmeticsNotifier extends CosmeticsNotifier {
  _TestCosmeticsNotifier() : super();

  @override
  Future<void> load() async {}
}

class _TestEloController extends EloController {
  _TestEloController() : super();

  @override
  Future<void> initialize() async {}
}

class _TestPlayGamesService extends PlayGamesService {
  _TestPlayGamesService(super.ref);

  @override
  Future<void> initialize() async {
    state = state.copyWith(attemptedSilentSignIn: true);
  }
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
