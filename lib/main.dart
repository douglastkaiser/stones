import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/web_back_button_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'providers/providers.dart';
import 'models/models.dart';
import 'services/services.dart';
import 'theme/theme.dart';
import 'version.dart';
import 'widgets/chess_clock_setup.dart';
import 'widgets/procedural_painters.dart';
import 'screens/main_menu_screen.dart';
import 'firebase_options.dart';

void _debugLog(String message) {
  developer.log('[GAME] $message', name: 'game');
  // ignore: avoid_print
  print('[GAME] $message');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: StonesApp()));
}

class StonesApp extends ConsumerStatefulWidget {
  const StonesApp({super.key});

  @override
  ConsumerState<StonesApp> createState() => _StonesAppState();
}

class _StonesAppState extends ConsumerState<StonesApp> {
  @override
  void initState() {
    super.initState();
    // Load settings on app start
    ref.read(appSettingsProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      title: 'Stones',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: GameColors.themeSeed),
        useMaterial3: true,
        textTheme: GoogleFonts.loraTextTheme(),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: GameColors.themeSeed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.loraTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),
      themeMode: settings.themeMode,
      home: const MainMenuScreen(),
    );
  }
}

/// Home screen with settings and start game
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize sound manager
    _initializeSounds();
  }

  Future<void> _initializeSounds() async {
    final soundManager = ref.read(soundManagerProvider);
    await soundManager.initialize();
    // Sync mute state with provider
    ref.read(isMutedProvider.notifier).state = soundManager.isMuted;
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = ref.watch(isMutedProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Sound toggle in top right
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    color: GameColors.subtitleColor,
                  ),
                  tooltip: isMuted ? 'Unmute sounds' : 'Mute sounds',
                  onPressed: () async {
                    final soundManager = ref.read(soundManagerProvider);
                    await soundManager.toggleMute();
                    ref.read(isMutedProvider.notifier).state = soundManager.isMuted;
                  },
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        'STONES',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: GameColors.titleColor,
                              letterSpacing: 8,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A game of roads and flats',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: GameColors.subtitleColor,
                            ),
                      ),
                      const SizedBox(height: 64),

                      // Board size selector
                      Text(
                        'Select Board Size',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          for (int size = 3; size <= 8; size++)
                            _BoardSizeButton(size: size),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // Continue current game button
                      Consumer(
                        builder: (context, ref, _) {
                          final hasGameInProgress = ref.watch(gameStateProvider.select(
                            (s) => s.turnNumber > 1 || s.board.occupiedPositions.isNotEmpty
                          ));
                          if (!hasGameInProgress) {
                            return const SizedBox();
                          }
                          return TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GameScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Continue Game'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const VersionFooter(),
          ],
        ),
      ),
    );
  }
}

class _BoardSizeButton extends ConsumerWidget {
  final int size;

  const _BoardSizeButton({required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = PieceCounts.forBoardSize(size);
    return SizedBox(
      width: 100,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        ),
        onPressed: () => _startNewGame(context, ref),
        child: Column(
          children: [
            Text(
              '${size}x$size',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${counts.flatStones}F ${counts.capstones}C',
              style: const TextStyle(
                fontSize: 12,
                color: GameColors.subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startNewGame(BuildContext context, WidgetRef ref) {
    final gameState = ref.read(gameStateProvider);
    final isGameInProgress = !gameState.isGameOver &&
        (gameState.turnNumber > 1 || gameState.board.occupiedPositions.isNotEmpty);

    if (isGameInProgress) {
      // Show confirmation dialog
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Start New Game?'),
          content: const Text(
            'You have a game in progress. Starting a new game will discard your current game.\n\nAre you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _doStartNewGame(context, ref);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start New Game'),
            ),
          ],
        ),
      );
    } else {
      _doStartNewGame(context, ref);
    }
  }

  void _doStartNewGame(BuildContext context, WidgetRef ref) {
    ref.read(scenarioStateProvider.notifier).clearScenario();
    ref.read(gameSessionProvider.notifier).state =
        const GameSessionConfig();
    ref.read(gameStateProvider.notifier).newGame(size);
    ref.read(uiStateProvider.notifier).reset();
    ref.read(animationStateProvider.notifier).reset();
    ref.read(moveHistoryProvider.notifier).clear();
    ref.read(lastMoveProvider.notifier).state = null;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }
}

/// Main game screen
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _showHistory = false;

  // Long press stack view state
  Position? _longPressedPosition;
  PieceStack? _longPressedStack;
  bool _allowNavigationPop = false;

  void _startStackView(Position pos, PieceStack stack) {
    if (_longPressedPosition == pos && _longPressedStack == stack) return;

    final soundManager = ref.read(soundManagerProvider);
    soundManager.playStackMove();

    setState(() {
      _longPressedPosition = pos;
      _longPressedStack = stack;
    });
  }

  void _endStackView() {
    setState(() {
      _longPressedPosition = null;
      _longPressedStack = null;
    });
  }

  void _navigateHome() {
    setState(() => _allowNavigationPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Set up road win callback
    ref.read(gameStateProvider.notifier).onRoadWin = (roadPositions, winner) {
      ref.read(animationStateProvider.notifier).roadWin(roadPositions, winner);
    };

    // Trigger initial AI turn if needed
    unawaited(_maybeTriggerAiTurn(ref.read(gameStateProvider)));

    // Set up web back button handler
    if (kIsWeb) {
      initWebBackButtonHandler(_handleWebBackButton);
    }
  }

  /// Handle web back button press.
  /// Returns true if undo was performed (push new history state to stay on screen),
  /// false to allow normal browser/Flutter navigation back to menu.
  bool _handleWebBackButton() {
    if (_canPerformUndo()) {
      _undo();
      return true; // Undo performed - push history state to stay on game screen
    } else {
      // No moves to undo - let browser/Flutter handle navigation
      // PopScope will allow the pop (canPop: true when canUndo is false)
      return false;
    }
  }

  /// Check if undo can be performed in current game state
  bool _canPerformUndo() {
    if (ref.read(aiThinkingProvider)) return false;

    final session = ref.read(gameSessionProvider);
    final gameState = ref.read(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    if (!gameNotifier.canUndo) return false;

    // Disable undo when chess clock is enabled (would allow time manipulation)
    final settings = ref.read(appSettingsProvider);
    if (settings.chessClockEnabled) return false;

    // Online mode: can only undo if it's opponent's turn (we just moved)
    if (session.mode == GameMode.online) {
      final onlineState = ref.read(onlineGameProvider);
      // Also check if online game has chess clock enabled
      if (onlineState.session?.chessClockEnabled == true) return false;
      final isOpponentTurn = onlineState.localColor != null &&
          gameState.currentPlayer != onlineState.localColor;
      return isOpponentTurn;
    }

    // VS Computer: can undo if it's player's turn
    if (session.mode == GameMode.vsComputer) {
      return !_isAiTurn(session, gameState);
    }

    // Local mode: can always undo if there are moves
    return true;
  }

  void _showAchievementNotification(AchievementType type) {
    final achievement = GameAchievement.forType(type);

    // Play unlock sound
    ref.read(soundManagerProvider).playAchievementUnlock();

    // Show the notification dialog
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => _AchievementUnlockDialog(achievement: achievement),
    );
  }

  @override
  void dispose() {
    ref.read(gameStateProvider.notifier).onRoadWin = null;
    if (kIsWeb) {
      disposeWebBackButtonHandler();
    }
    super.dispose();
  }

  PlayerColor _aiPlayerColor(GameSessionConfig session) {
    return session.vsComputerPlayerColor == PlayerColor.white
        ? PlayerColor.black
        : PlayerColor.white;
  }

  bool _isAiTurn(GameSessionConfig session, GameState gameState) {
    return session.mode == GameMode.vsComputer &&
        gameState.currentPlayer == _aiPlayerColor(session);
  }

  Future<void> _checkAchievements(GameState gameState) async {
    final session = ref.read(gameSessionProvider);
    final scenarioState = ref.read(scenarioStateProvider);
    final isScenarioGame = session.scenario != null || scenarioState.hasScenario;
    final achievementNotifier = ref.read(achievementProvider.notifier);

    // Debug logging
    _debugLog('_checkAchievements called');
    _debugLog('  gameState.result: ${gameState.result}');
    _debugLog('  gameState.isGameOver: ${gameState.isGameOver}');
    _debugLog('  session.mode: ${session.mode}');
    _debugLog('  session.aiDifficulty: ${session.aiDifficulty}');
    _debugLog('  isScenarioGame: $isScenarioGame');
    _debugLog('  session.vsComputerPlayerColor: ${session.vsComputerPlayerColor}');

    // Check if it's a win (not a draw)
    final isWhiteWin = gameState.result == GameResult.whiteWins;
    final isBlackWin = gameState.result == GameResult.blackWins;

    // For vs computer mode, check if the human player won
    final playerColor = session.vsComputerPlayerColor;
    final playerWon = session.mode == GameMode.vsComputer &&
        ((playerColor == PlayerColor.white && isWhiteWin) ||
         (playerColor == PlayerColor.black && isBlackWin));

    // For online mode, check if local player won
    final onlineState = ref.read(onlineGameProvider);
    final onlinePlayerWon = session.mode == GameMode.online &&
        ((onlineState.localColor == PlayerColor.white && isWhiteWin) ||
         (onlineState.localColor == PlayerColor.black && isBlackWin));

    // For local mode, any win counts
    final localPlayerWon = session.mode == GameMode.local && (isWhiteWin || isBlackWin);

    _debugLog('  isWhiteWin: $isWhiteWin, isBlackWin: $isBlackWin');
    _debugLog('  playerWon: $playerWon, onlinePlayerWon: $onlinePlayerWon, localPlayerWon: $localPlayerWon');

    // Record the win and show notifications for any unlocked achievements
    if (playerWon || onlinePlayerWon || localPlayerWon) {
      _debugLog('  Recording win with aiDifficulty: ${session.aiDifficulty}');
      final unlockedAchievements = await achievementNotifier.recordWin(
        isOnline: session.mode == GameMode.online,
        aiDifficulty: session.mode == GameMode.vsComputer && !isScenarioGame
            ? session.aiDifficulty
            : null,
        byTime: gameState.winReason == WinReason.time,
        byFlats: gameState.winReason == WinReason.flats,
      );

      _debugLog('  Unlocked ${unlockedAchievements.length} achievements: $unlockedAchievements');

      // Show notification for each unlocked achievement
      for (final achievementType in unlockedAchievements) {
        _debugLog('  Showing notification for: $achievementType, mounted: $mounted');
        if (mounted) {
          _showAchievementNotification(achievementType);
          // Wait a bit before showing the next one if there are multiple
          if (unlockedAchievements.length > 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
    } else {
      _debugLog('  No win detected, skipping achievement check');
    }

    // Check for scenario completion
    final activeScenario = session.scenario ?? scenarioState.activeScenario;
    if (activeScenario != null && (gameState.isGameOver || scenarioState.guidedStepComplete)) {
      List<AchievementType> scenarioUnlocks = [];
      if (activeScenario.type == ScenarioType.tutorial) {
        scenarioUnlocks = await achievementNotifier.completeTutorial(activeScenario.id);
      } else if (activeScenario.type == ScenarioType.puzzle) {
        scenarioUnlocks = await achievementNotifier.completePuzzle(activeScenario.id);
      }

      // Show notification for scenario achievements
      for (final achievementType in scenarioUnlocks) {
        if (mounted) {
          _showAchievementNotification(achievementType);
        }
      }
    }
  }

  void _undo() {
    if (ref.read(aiThinkingProvider)) return;
    final session = ref.read(gameSessionProvider);
    final gameState = ref.read(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    // Online mode: only allow undo of your own move before opponent responds
    if (session.mode == GameMode.online) {
      final onlineState = ref.read(onlineGameProvider);
      // Can only undo if:
      // 1. It's currently opponent's turn (we just moved)
      // 2. We have moves to undo
      // 3. The last move was ours (check move count)
      final isOpponentTurn = onlineState.localColor != null &&
          gameState.currentPlayer != onlineState.localColor;
      if (!isOpponentTurn || !gameNotifier.canUndo) {
        return;
      }
      // Undo our last move
      _performSingleUndo();
      return;
    }

    // Don't undo during AI's turn
    if (_isAiTurn(session, gameState)) {
      return;
    }

    if (!gameNotifier.canUndo) return;

    // VS Computer mode: undo both computer's move AND player's move
    if (session.mode == GameMode.vsComputer) {
      // First undo: the computer's last move (if any)
      // The current turn should be player's turn, so the last move was computer's
      if (gameNotifier.canUndo) {
        _performSingleUndo();
      }
      // Second undo: the player's previous move
      if (gameNotifier.canUndo) {
        _performSingleUndo();
      }
      return;
    }

    // Local mode: undo single move
    _performSingleUndo();
  }

  /// Performs a single undo operation
  void _performSingleUndo() {
    final gameNotifier = ref.read(gameStateProvider.notifier);
    if (!gameNotifier.canUndo) return;

    // Remove from move history
    ref.read(moveHistoryProvider.notifier).removeLast();
    // Undo game state
    gameNotifier.undo();
    // Reset UI state
    ref.read(uiStateProvider.notifier).reset();
    // Update last move highlight
    final history = ref.read(moveHistoryProvider);
    if (history.isNotEmpty) {
      ref.read(lastMoveProvider.notifier).state = history.last.affectedPositions;
    } else {
      ref.read(lastMoveProvider.notifier).state = null;
    }
    // Reset animation state
    ref.read(animationStateProvider.notifier).reset();
  }

  /// Start the next scenario without the "Replace current game" prompt
  void _startNextScenario(GameScenario scenario) {
    ref.read(scenarioStateProvider.notifier).startScenario(scenario);
    ref.read(gameSessionProvider.notifier).state = GameSessionConfig(
      mode: GameMode.vsComputer,
      aiDifficulty: scenario.aiDifficulty,
      scenario: scenario,
    );
    ref.read(gameStateProvider.notifier).loadState(scenario.buildInitialState());
    ref.read(uiStateProvider.notifier).reset();
    ref.read(animationStateProvider.notifier).reset();
    ref.read(moveHistoryProvider.notifier).clear();
    ref.read(lastMoveProvider.notifier).state = null;
    ref.read(chessClockProvider.notifier).stop();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final uiState = ref.watch(uiStateProvider);
    final animationState = ref.watch(animationStateProvider);
    final isMuted = ref.watch(isMutedProvider);
    final moveHistory = ref.watch(moveHistoryProvider);
    final lastMovePositions = ref.watch(lastMoveProvider);
    final session = ref.watch(gameSessionProvider);
    final scenarioState = ref.watch(scenarioStateProvider);
    final isAiThinking = ref.watch(aiThinkingProvider);
    final isAiThinkingVisible = ref.watch(aiThinkingVisibleProvider);
    final isAiTurn = _isAiTurn(session, gameState);
    final pieceStyleData = ref.watch(currentPieceStyleProvider);
    final boardThemeData = ref.watch(currentBoardThemeProvider);
    final onlineState = ref.watch(onlineGameProvider);
    final isOnline = session.mode == GameMode.online;
    final activeScenario = session.scenario ?? scenarioState.activeScenario;
    final guidedMove =
        scenarioState.guidedStepComplete ? null : activeScenario?.guidedMove;
    // Only show highlights for tutorials, not puzzles (puzzles should be ambiguous)
    final isPuzzleScenario = activeScenario?.type == ScenarioType.puzzle;
    final scenarioHighlights = (guidedMove != null && !isPuzzleScenario)
        ? guidedMove.highlightedCells(gameState.boardSize)
        : <Position>{};
    // FIX: Use LOCAL game state for turn enforcement instead of Firestore session
    // This prevents race condition where creator can play multiple moves before
    // Firestore listener updates session.currentTurn
    final isMyTurnLocally = isOnline && onlineState.localColor != null &&
        gameState.currentPlayer == onlineState.localColor;
    final isRemoteTurn = isOnline && !isMyTurnLocally;
    final waitingForOpponent = isOnline && onlineState.waitingForOpponent;
    final canUndo = _canPerformUndo();
    final inputLocked = isAiTurn || isAiThinking || isRemoteTurn || waitingForOpponent;

    // Listen for chess clock expiration to trigger game end
    ref.listen<ChessClockState>(chessClockProvider, (previous, next) {
      if (next.isExpired && next.expiredPlayer != null && !gameState.isGameOver) {
        ref.read(gameStateProvider.notifier).setTimeExpired(next.expiredPlayer!);
      }
    });

    // Listen for game state changes (AI turns, achievements, etc.)
    ref.listen<GameState>(gameStateProvider, (previous, next) {
      _debugLog('GameState listener fired: prev.isGameOver=${previous?.isGameOver}, next.isGameOver=${next.isGameOver}');

      unawaited(_maybeTriggerAiTurn(next));
      final moveCount = ref.read(moveHistoryProvider).length;
      unawaited(
        ref.read(playGamesServiceProvider.notifier).onGameStateChanged(
              next,
              previous: previous,
              moveCount: moveCount,
            ),
      );
      // Check for achievements when game ends
      if (next.isGameOver && (previous == null || !previous.isGameOver)) {
        _debugLog('Game just ended! Calling _checkAchievements');
        unawaited(_checkAchievements(next));
      }
    });

    // Listen for online game events (opponent moves/joins)
    ref.listen<OnlineGameState>(onlineGameProvider, (previous, next) {
      final soundManager = ref.read(soundManagerProvider);
      if (next.opponentJustJoined) {
        soundManager.playPiecePlace();
      }
      if (next.opponentJustMoved) {
        soundManager.playStackMove();
      }
    });

    // Debug logging for turn enforcement
    if (isOnline) {
      _debugLog('>>> GAME SCREEN BUILD (ONLINE MODE) <<<');
      _debugLog('localColor=${onlineState.localColor}, roomCode=${onlineState.roomCode}');
      _debugLog('session.currentTurn=${onlineState.session?.currentTurn}, session.moves=${onlineState.session?.moves.length ?? 0}');
      _debugLog('LOCAL gameState: currentPlayer=${gameState.currentPlayer}, turnNumber=${gameState.turnNumber}');
      _debugLog('LOCAL board: occupiedCells=${gameState.board.occupiedPositions.length}');
      _debugLog('appliedMoveCount=${onlineState.appliedMoveCount}');
      _debugLog('isMyTurnLocally=$isMyTurnLocally, isRemoteTurn=$isRemoteTurn');
      _debugLog('waitingForOpponent=$waitingForOpponent, inputLocked=$inputLocked');
      _debugLog('>>> END GAME SCREEN BUILD <<<');
    }

    // Mark intro as shown immediately since text is displayed in the card
    if (activeScenario != null && !scenarioState.introShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(scenarioStateProvider.notifier).markIntroShown();
      });
    }

    if (activeScenario != null &&
        !scenarioState.completionShown &&
        (gameState.isGameOver || scenarioState.guidedStepComplete)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(scenarioStateProvider.notifier).markCompletionShown();

        // Mark the scenario as complete in achievements
        if (activeScenario.type == ScenarioType.tutorial) {
          ref.read(achievementProvider.notifier).completeTutorial(activeScenario.id);
        } else {
          ref.read(achievementProvider.notifier).completePuzzle(activeScenario.id);
        }

        // Find next uncompleted scenario (smart logic)
        final achievements = ref.read(achievementProvider);
        GameScenario? nextScenario;
        String nextButtonText = 'Next';

        // Helper to check if scenario is completed
        bool isCompleted(GameScenario s) {
          return s.type == ScenarioType.tutorial
              ? achievements.completedTutorials.contains(s.id)
              : achievements.completedPuzzles.contains(s.id);
        }

        // First, look for next uncompleted of same type
        final currentIndex = tutorialAndPuzzleLibrary.indexOf(activeScenario);
        for (var i = currentIndex + 1; i < tutorialAndPuzzleLibrary.length; i++) {
          final s = tutorialAndPuzzleLibrary[i];
          if (s.type == activeScenario.type && !isCompleted(s)) {
            nextScenario = s;
            nextButtonText = s.type == ScenarioType.tutorial ? 'Next Tutorial' : 'Next Puzzle';
            break;
          }
        }

        // If none found, wrap around to start of same type
        if (nextScenario == null) {
          for (var i = 0; i < currentIndex; i++) {
            final s = tutorialAndPuzzleLibrary[i];
            if (s.type == activeScenario.type && !isCompleted(s)) {
              nextScenario = s;
              nextButtonText = s.type == ScenarioType.tutorial ? 'Next Tutorial' : 'Next Puzzle';
              break;
            }
          }
        }

        // If all of same type complete, try the other type (tutorials -> puzzles)
        if (nextScenario == null && activeScenario.type == ScenarioType.tutorial) {
          for (final s in tutorialAndPuzzleLibrary) {
            if (s.type == ScenarioType.puzzle && !isCompleted(s)) {
              nextScenario = s;
              nextButtonText = 'Start Puzzles';
              break;
            }
          }
        }

        // If all puzzles complete, try tutorials
        if (nextScenario == null && activeScenario.type == ScenarioType.puzzle) {
          for (final s in tutorialAndPuzzleLibrary) {
            if (s.type == ScenarioType.tutorial && !isCompleted(s)) {
              nextScenario = s;
              nextButtonText = 'Back to Tutorials';
              break;
            }
          }
        }

        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('${activeScenario.title} Complete!'),
            content: Text(activeScenario.completionText),
            actions: [
              if (nextScenario != null) ...[
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _startNextScenario(activeScenario);
                  },
                  child: const Text('Replay'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _startNextScenario(nextScenario!);
                  },
                  child: Text(nextButtonText),
                ),
              ] else ...[
                // Last puzzle completed - show Home button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    ref.read(scenarioStateProvider.notifier).clearScenario();
                    _navigateHome();
                  },
                  child: const Text('Home'),
                ),
              ],
            ],
          ),
        );
      });
    }

    return PopScope(
      // Block navigation when there are moves to undo (both web and mobile)
      // On web, PopScope blocks Flutter navigation but doesn't trigger undo
      // (the web popstate handler does the undo)
      canPop: _allowNavigationPop || !canUndo,
      onPopInvokedWithResult: (didPop, result) {
        if (_allowNavigationPop) {
          if (!didPop) {
            setState(() => _allowNavigationPop = false);
          }
          return;
        }
        // Only handle undo on mobile - web uses the popstate handler
        if (!kIsWeb && !didPop && canUndo) {
          // Back button pressed with moves to undo - undo instead of navigating
          _undo();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stones'),
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: _navigateHome,
          ),
        actions: [
          // Undo button
          IconButton(
            icon: Icon(
              Icons.undo,
              color: canUndo ? null : Colors.grey.shade400,
            ),
            tooltip: canUndo ? 'Undo last move' : 'No moves to undo',
            onPressed: canUndo ? _undo : null,
          ),
          // History toggle button
          IconButton(
            icon: Icon(_showHistory ? Icons.history_toggle_off : Icons.history),
            tooltip: _showHistory ? 'Hide move history' : 'Show move history',
            onPressed: () => setState(() => _showHistory = !_showHistory),
          ),
          if (session.mode == GameMode.online)
            IconButton(
              icon: const Icon(Icons.flag),
              tooltip: 'Resign',
              onPressed: () => _confirmResign(context),
            ),
          IconButton(
            icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
            tooltip: isMuted ? 'Unmute sounds' : 'Mute sounds',
            onPressed: () async {
              final soundManager = ref.read(soundManagerProvider);
              await soundManager.toggleMute();
              ref.read(isMutedProvider.notifier).state = soundManager.isMuted;
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Game',
            onPressed: session.mode == GameMode.online
                ? null
                : () => _showNewGameDialog(context, ref),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 700;
          final showClockEnabled = ref.watch(appSettingsProvider).chessClockEnabled;

          // Board widget (reused in both layouts)
          final boardWidget = Container(
            decoration: BoxDecoration(
              // Frame gradient using board theme
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  boardThemeData.frameInner,
                  boardThemeData.frameOuter,
                  boardThemeData.frameInner,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: boardThemeData.frameOuter,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                ),
                BoxShadow(
                  color: boardThemeData.frameInner.withValues(alpha: 0.5),
                  blurRadius: 2,
                  offset: const Offset(-1, -1),
                ),
              ],
            ),
            child: IgnorePointer(
              ignoring: inputLocked,
              child: _GameBoard(
                gameState: gameState,
                uiState: uiState,
                animationState: animationState,
                lastMovePositions: lastMovePositions,
                explodedPosition: _longPressedPosition,
                explodedStack: _longPressedStack,
                highlightedPositions: scenarioHighlights,
                pieceStyleData: pieceStyleData,
                boardThemeData: boardThemeData,
                onCellTap: (pos) =>
                    _handleCellTap(context, ref, pos, guidedMove),
                onCellSwipe: (pos, dir) =>
                    _handleCellSwipe(context, ref, pos, dir, guidedMove),
                onLongPressStart: _startStackView,
                onLongPressEnd: _endStackView,
                onBoardFrameTap: () => _handleBoardFrameTap(ref),
              ),
            ),
          );

          // Bottom controls
          final bottomControls = IgnorePointer(
            ignoring: inputLocked,
            child: _BottomControls(
              gameState: gameState,
              uiState: uiState,
              onPieceTypeChanged: (type) =>
                  ref.read(uiStateProvider.notifier).setGhostPieceType(type),
              onConfirmMove: () => _confirmMove(ref),
              onCancel: () => ref.read(uiStateProvider.notifier).reset(),
              isWideScreen: isWideScreen,
            ),
          );

          return Stack(
            children: [
              if (isWideScreen)
                // Wide screen: side panels layout
                Row(
                  children: [
                    // Left side panel (Light player)
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Column(
                        children: [
                          _PlayerSidePanel(
                            player: PlayerColor.white,
                            pieces: gameState.whitePieces,
                            isCurrentTurn: gameState.currentPlayer == PlayerColor.white,
                            isGameOver: gameState.isGameOver,
                            showClock: showClockEnabled,
                          ),
                          // Piece selector for light player when placing
                          if (uiState.mode == InteractionMode.placingPiece &&
                              gameState.currentPlayer == PlayerColor.white &&
                              !gameState.isOpeningPhase) ...[
                            const SizedBox(height: 12),
                            _SidePanelPieceSelector(
                              pieces: gameState.whitePieces,
                              currentType: uiState.ghostPieceType,
                              onTypeChanged: (type) =>
                                  ref.read(uiStateProvider.notifier).setGhostPieceType(type),
                            ),
                          ],
                          const Spacer(),
                        ],
                      ),
                    ),
                    // Center: game area
                    Expanded(
                      child: Column(
                        children: [
                          // Win banner or compact turn indicator
                          if (activeScenario != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _ScenarioInfoCard(scenario: activeScenario),
                            ),
                          if (gameState.isGameOver && gameState.result != null)
                            _WinBanner(result: gameState.result!, winReason: gameState.winReason)
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _CompactTurnIndicator(
                                gameState: gameState,
                                isThinking: isAiThinkingVisible,
                                onlineState: isOnline ? onlineState : null,
                              ),
                            ),
                          // Board
                          Expanded(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: boardWidget,
                                ),
                              ),
                            ),
                          ),
                          // Bottom controls
                          bottomControls,
                        ],
                      ),
                    ),
                    // Right side panel (Dark player)
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Column(
                        children: [
                          _PlayerSidePanel(
                            player: PlayerColor.black,
                            pieces: gameState.blackPieces,
                            isCurrentTurn: gameState.currentPlayer == PlayerColor.black,
                            isGameOver: gameState.isGameOver,
                            showClock: showClockEnabled,
                          ),
                          // Piece selector for dark player when placing
                          if (uiState.mode == InteractionMode.placingPiece &&
                              gameState.currentPlayer == PlayerColor.black &&
                              !gameState.isOpeningPhase) ...[
                            const SizedBox(height: 12),
                            _SidePanelPieceSelector(
                              pieces: gameState.blackPieces,
                              currentType: uiState.ghostPieceType,
                              onTypeChanged: (type) =>
                                  ref.read(uiStateProvider.notifier).setGhostPieceType(type),
                            ),
                          ],
                          const Spacer(),
                        ],
                      ),
                    ),
                    // Move history panel (collapsible sidebar)
                    if (_showHistory)
                      _MoveHistoryPanel(
                        moveHistory: moveHistory,
                        boardSize: gameState.boardSize,
                        onClose: () => setState(() => _showHistory = false),
                      ),
                  ],
                )
              else
                // Narrow screen: compact layout with overlays
                Column(
                  children: [
                    if (activeScenario != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: _ScenarioInfoCard(scenario: activeScenario),
                      ),
                    // Win banner (if game over)
                    if (gameState.isGameOver && gameState.result != null)
                      _WinBanner(result: gameState.result!, winReason: gameState.winReason),
                    // Board area with overlays
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none, // Allow tall stacks to overflow
                        children: [
                          // Board
                          Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: boardWidget,
                              ),
                            ),
                          ),
                          // Turn indicator overlay (top center)
                          if (!gameState.isGameOver)
                            Positioned(
                              top: 4,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: _CompactTurnIndicator(
                                  gameState: gameState,
                                  isThinking: isAiThinkingVisible,
                                  onlineState: isOnline ? onlineState : null,
                                ),
                              ),
                            ),
                          // Player info overlays (bottom corners)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: _PlayerSidePanel(
                              player: PlayerColor.white,
                              pieces: gameState.whitePieces,
                              isCurrentTurn: gameState.currentPlayer == PlayerColor.white,
                              isGameOver: gameState.isGameOver,
                              showClock: showClockEnabled,
                              isVertical: false,
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: _PlayerSidePanel(
                              player: PlayerColor.black,
                              pieces: gameState.blackPieces,
                              isCurrentTurn: gameState.currentPlayer == PlayerColor.black,
                              isGameOver: gameState.isGameOver,
                              showClock: showClockEnabled,
                              isVertical: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom controls
                    bottomControls,
                    // Move history panel (appears below on narrow screens)
                    if (_showHistory)
                      SizedBox(
                        height: 200,
                        child: _MoveHistoryPanel(
                          moveHistory: moveHistory,
                          boardSize: gameState.boardSize,
                          onClose: () => setState(() => _showHistory = false),
                        ),
                      ),
                  ],
                ),

              // Online status banners
              if (session.mode == GameMode.online && waitingForOpponent)
                _OnlineStatusBanner(
                  message:
                      'Waiting for opponent... Room code: ${onlineState.roomCode ?? '---'}',
                  icon: Icons.hourglass_empty,
                ),
              if (session.mode == GameMode.online &&
                  onlineState.opponentDisconnected &&
                  !onlineState.opponentInactive)
                const _OnlineStatusBanner(
                  message: 'Opponent may have disconnected (no activity for 60s)',
                  icon: Icons.wifi_off,
                  color: Colors.orange,
                ),
              if (session.mode == GameMode.online && onlineState.opponentInactive)
                const _OnlineStatusBanner(
                  message: 'Opponent disconnected (no activity for 2+ minutes)',
                  icon: Icons.error_outline,
                  color: Colors.red,
                ),
            ],
          );
        },
      ),
      ),
    );
  }

  /// Handle tap on the board frame (outside cells) - cancels stack movement
  void _handleBoardFrameTap(WidgetRef ref) {
    final uiState = ref.read(uiStateProvider);
    // Cancel movement modes when tapping on board frame
    if (uiState.mode == InteractionMode.movingStack ||
        uiState.mode == InteractionMode.droppingPieces) {
      ref.read(uiStateProvider.notifier).reset();
    }
  }

  void _handleCellTap(
      BuildContext context, WidgetRef ref, Position pos, GuidedMove? guidedMove) {
    _debugLog('_handleCellTap: pos=$pos');
    final gameState = ref.read(gameStateProvider);
    final uiState = ref.read(uiStateProvider);
    final uiNotifier = ref.read(uiStateProvider.notifier);
    final session = ref.read(gameSessionProvider);

    // Online turn check
    if (session.mode == GameMode.online) {
      final onlineState = ref.read(onlineGameProvider);
      final isMyTurnLocally = onlineState.localColor != null &&
          gameState.currentPlayer == onlineState.localColor;
      _debugLog('_handleCellTap: ONLINE check - localColor=${onlineState.localColor}, '
          'localGameTurn=${gameState.currentPlayer}, '
          'isMyTurnLocally=$isMyTurnLocally, '
          'waitingForOpponent=${onlineState.waitingForOpponent}');
      if (!isMyTurnLocally || onlineState.waitingForOpponent) {
        _debugLog('_handleCellTap: BLOCKED - not local turn or waiting for opponent');
        uiNotifier.reset();
        return;
      }
      _debugLog('_handleCellTap: ALLOWED - is local turn');
    }

    // AI turn check
    final isAiTurn = _isAiTurn(session, gameState);
    if (gameState.isGameOver || isAiTurn || ref.read(aiThinkingProvider)) {
      uiNotifier.reset();
      return;
    }

    final stack = gameState.board.stackAt(pos);

    // Handle based on current interaction mode
    switch (uiState.mode) {
      case InteractionMode.idle:
        _handleIdleTap(ref, pos, stack, gameState, guidedMove);

      case InteractionMode.placingPiece:
        _handlePlacingPieceTap(
            ref, pos, stack, gameState, uiState, guidedMove);

      case InteractionMode.movingStack:
        _handleMovingStackTap(ref, pos, stack, gameState, uiState, guidedMove);

      case InteractionMode.droppingPieces:
        _handleDroppingPiecesTap(ref, pos, stack, gameState, uiState);
    }
  }

  /// Handle swipe gesture on a cell - selects stack and starts movement
  void _handleCellSwipe(
      BuildContext context, WidgetRef ref, Position pos, Direction direction, GuidedMove? guidedMove) {
    _debugLog('_handleCellSwipe: pos=$pos, direction=$direction');
    final gameState = ref.read(gameStateProvider);
    final uiState = ref.read(uiStateProvider);
    final uiNotifier = ref.read(uiStateProvider.notifier);
    final session = ref.read(gameSessionProvider);

    // Online turn check
    if (session.mode == GameMode.online) {
      final onlineState = ref.read(onlineGameProvider);
      final isMyTurnLocally = onlineState.localColor != null &&
          gameState.currentPlayer == onlineState.localColor;
      if (!isMyTurnLocally || onlineState.waitingForOpponent) {
        return;
      }
    }

    // AI turn check
    final isAiTurn = _isAiTurn(session, gameState);
    if (gameState.isGameOver || isAiTurn || ref.read(aiThinkingProvider)) {
      return;
    }

    // Can't move stacks during opening phase
    if (gameState.isOpeningPhase) {
      return;
    }

    final stack = gameState.board.stackAt(pos);

    // Must have a stack to move
    if (stack.isEmpty) {
      return;
    }

    // Must be current player's stack
    if (stack.controller != gameState.currentPlayer) {
      return;
    }

    // Check if swipe direction leads to a valid move
    final targetPos = direction.apply(pos);
    if (!gameState.board.isValidPosition(targetPos)) {
      return;
    }

    // Check if target can be moved onto
    final targetStack = gameState.board.stackAt(targetPos);
    final topPiece = stack.topPiece!;
    final canMove = targetStack.canMoveOnto(topPiece) ||
        (targetStack.topPiece?.type == PieceType.standing && topPiece.canFlattenWalls);

    if (!canMove) {
      return;
    }

    // Handle guided move constraints if applicable
    if (guidedMove != null &&
        (guidedMove.type == GuidedMoveType.stackMove ||
         guidedMove.type == GuidedMoveType.anyStackMove)) {
      if (pos != guidedMove.from) {
        return;
      }
    }

    // If currently in idle or movingStack mode on a different cell, select this stack
    // Calculate max pieces that can be picked up
    final maxPieces = stack.height > gameState.boardSize
        ? gameState.boardSize
        : stack.height;

    // Based on current mode, handle the swipe
    switch (uiState.mode) {
      case InteractionMode.idle:
        // Select stack and immediately start moving
        uiNotifier.selectStack(pos, maxPieces);
        uiNotifier.startMoving(direction);

      case InteractionMode.placingPiece:
        // Cancel placement and start stack move
        uiNotifier.selectStack(pos, maxPieces);
        uiNotifier.startMoving(direction);

      case InteractionMode.movingStack:
        if (uiState.selectedPosition == pos) {
          // Same stack selected - start moving in swipe direction
          uiNotifier.startMoving(direction);
        } else {
          // Different stack - select new one and start moving
          uiNotifier.selectStack(pos, maxPieces);
          uiNotifier.startMoving(direction);
        }

      case InteractionMode.droppingPieces:
        // Handle swipe to continue movement
        _handleDroppingPiecesSwipe(ref, pos, direction, gameState, uiState);
    }
  }

  /// Handle swipe gesture when in droppingPieces mode
  void _handleDroppingPiecesSwipe(WidgetRef ref, Position pos, Direction direction,
      GameState gameState, UIState uiState) {
    final uiNotifier = ref.read(uiStateProvider.notifier);
    final handPos = uiState.getCurrentHandPosition();
    final currentDir = uiState.selectedDirection;

    if (handPos == null || currentDir == null) {
      return;
    }

    // Only respond to swipes on the current hand position (where ghost pieces are)
    if (pos != handPos) {
      return;
    }

    // Only respond to swipes in the same direction as current movement
    if (direction != currentDir) {
      return;
    }

    // Check if we can continue to the next cell
    final originalStack = gameState.board.stackAt(uiState.selectedPosition!);
    final movingPiece = originalStack.topPiece;
    if (movingPiece == null) {
      return;
    }

    final nextPos = currentDir.apply(handPos);
    if (!gameState.board.isValidPosition(nextPos)) {
      return;
    }

    final targetStack = gameState.board.stackAt(nextPos);
    final canContinue = targetStack.canMoveOnto(movingPiece) ||
        (targetStack.topPiece?.type == PieceType.standing && movingPiece.canFlattenWalls);

    if (!canContinue) {
      return;
    }

    // Drop pending pieces at current position and move to next
    final dropCount = uiState.pendingDropCount;
    uiNotifier.addDrop(dropCount);
    // Stack moves require explicit confirm button (no auto-confirm)
  }

  /// Handle tap when in idle mode
  void _handleIdleTap(WidgetRef ref, Position pos, PieceStack stack,
      GameState gameState, GuidedMove? guidedMove) {
    final uiNotifier = ref.read(uiStateProvider.notifier);

    if (guidedMove != null) {
      if (guidedMove.type == GuidedMoveType.placement) {
        // Specific target required
        if (guidedMove.allowedTargets != null) {
          if (stack.isEmpty && !guidedMove.allowedTargets!.contains(pos)) {
            return;
          }
        } else if (guidedMove.target != null) {
          if (stack.isEmpty && pos != guidedMove.target) {
            return;
          }
        }
        if (stack.isNotEmpty) {
          return;
        }
      } else if (guidedMove.type == GuidedMoveType.anyPlacement) {
        // Any empty cell is valid
        if (stack.isNotEmpty) {
          return;
        }
      } else if (guidedMove.type == GuidedMoveType.stackMove &&
          pos != guidedMove.from) {
        return;
      } else if (guidedMove.type == GuidedMoveType.anyStackMove &&
          pos != guidedMove.from) {
        return;
      }
    }

    if (stack.isEmpty) {
      // Tap empty cell: show ghost piece for placement
      uiNotifier.selectCellForPlacement(pos);
      return;
    }

    // Tap own stack: select for movement
    if (!gameState.isOpeningPhase && stack.controller == gameState.currentPlayer) {
      final maxPieces = stack.height > gameState.boardSize
          ? gameState.boardSize
          : stack.height;
      uiNotifier.selectStack(pos, maxPieces);
      return;
    }

    // Tap opponent's stack: do nothing
  }

  /// Handle tap when placing a piece (ghost piece showing)
  void _handlePlacingPieceTap(WidgetRef ref, Position pos, PieceStack stack,
      GameState gameState, UIState uiState, GuidedMove? guidedMove) {
    final uiNotifier = ref.read(uiStateProvider.notifier);

    if (guidedMove != null && guidedMove.type == GuidedMoveType.placement) {
      if (guidedMove.allowedTargets != null) {
        if (!guidedMove.allowedTargets!.contains(pos)) {
          return;
        }
      } else if (guidedMove.target != null && pos != guidedMove.target) {
        return;
      }
    }
    // anyPlacement allows any position, no check needed

    if (uiState.selectedPosition == pos) {
      // Tap same cell: place the piece
      final type = uiState.ghostPieceType;
      _performPlacementMove(pos, type, ref);
      uiNotifier.reset();
      return;
    }

    if (stack.isEmpty) {
      // Tap different empty cell: move ghost there
      uiNotifier.moveGhostPiece(pos);
      return;
    }

    // Tap on a stack: cancel placement and handle like idle
    uiNotifier.reset();
    _handleIdleTap(ref, pos, stack, gameState, guidedMove);
  }

  /// Handle tap when moving a stack (stack selected, waiting for direction)
  void _handleMovingStackTap(WidgetRef ref, Position pos, PieceStack stack,
      GameState gameState, UIState uiState, GuidedMove? guidedMove) {
    final uiNotifier = ref.read(uiStateProvider.notifier);
    final selectedPos = uiState.selectedPosition!;

    if (guidedMove != null &&
        (guidedMove.type == GuidedMoveType.stackMove ||
         guidedMove.type == GuidedMoveType.anyStackMove)) {
      final allowedPositions = guidedMove.highlightedCells(gameState.boardSize);
      // For anyStackMove, we only highlight the from position, not restrict movement
      if (guidedMove.type == GuidedMoveType.stackMove && !allowedPositions.contains(pos)) {
        return;
      }
    }

    if (pos == selectedPos) {
      // Tap same stack: cycle piece count
      final stackHeight = gameState.board.stackAt(pos).height;
      final maxPieces = stackHeight > gameState.boardSize
          ? gameState.boardSize
          : stackHeight;
      uiNotifier.cyclePiecesPickedUp(maxPieces);
      return;
    }

    // Check if tapped position is a valid destination (adjacent cell in any valid direction)
    final validDestinations = uiState.getValidMoveDestinations(gameState);
    if (validDestinations.contains(pos)) {
      // Determine direction from selected position to tapped position
      final dir = _getDirectionBetween(selectedPos, pos);
      if (dir != null) {
        // Enter dropping mode - shows ghost piece preview
        uiNotifier.startMoving(dir);
        return;
      }
    }

    // Tap on different own stack: switch selection
    if (!gameState.isOpeningPhase && stack.controller == gameState.currentPlayer && stack.isNotEmpty) {
      final maxPieces = stack.height > gameState.boardSize
          ? gameState.boardSize
          : stack.height;
      uiNotifier.selectStack(pos, maxPieces);
      return;
    }

    // Tap on empty cell that's not a valid destination: cancel and handle as new placement
    if (stack.isEmpty) {
      uiNotifier.selectCellForPlacement(pos);
      return;
    }

    // Otherwise cancel
    uiNotifier.reset();
  }

  /// Handle tap when dropping pieces (movement in progress)
  void _handleDroppingPiecesTap(WidgetRef ref, Position pos, PieceStack stack,
      GameState gameState, UIState uiState) {
    final uiNotifier = ref.read(uiStateProvider.notifier);
    final handPos = uiState.getCurrentHandPosition();
    final dir = uiState.selectedDirection!;
    final dropPath = uiState.getDropPath();

    // Calculate total pieces in this move
    final totalPiecesInMove = uiState.piecesPickedUp + uiState.drops.fold<int>(0, (a, b) => a + b);

    // If all pieces are dropped (handPos is null), any click cancels
    if (handPos == null) {
      uiNotifier.reset();
      return;
    }

    // Get info about what we're moving
    final originalStack = gameState.board.stackAt(uiState.selectedPosition!);
    final movingPiece = originalStack.topPiece;
    if (movingPiece == null) {
      uiNotifier.reset();
      return;
    }

    // Check if we can continue to the next cell after current hand position
    final nextPos = dir.apply(handPos);
    final canContinue = gameState.board.isValidPosition(nextPos) && (() {
      final targetStack = gameState.board.stackAt(nextPos);
      return targetStack.canMoveOnto(movingPiece) ||
          (targetStack.topPiece?.type == PieceType.standing && movingPiece.canFlattenWalls);
    })();

    // Tapping on origin position: go back to movingStack mode (direction selection)
    if (pos == uiState.selectedPosition) {
      // Restore all pieces and return to movingStack mode
      uiNotifier.selectStack(pos, totalPiecesInMove);
      return;
    }

    // Tapping on a position in the drop path: undo to that position
    if (dropPath.contains(pos)) {
      final pathIndex = dropPath.indexOf(pos);
      uiNotifier.undoDropsTo(pathIndex);
      return;
    }

    if (pos == handPos) {
      // Tap current hand position
      final piecesInHand = uiState.piecesPickedUp;
      final pendingDrop = uiState.pendingDropCount;
      final isSinglePieceMove = totalPiecesInMove == 1;

      // For single-piece moves, tapping confirms immediately (no cycling needed)
      if (isSinglePieceMove) {
        uiNotifier.addDrop(1);
        _confirmMove(ref);
        return;
      }

      // For stack moves (2+ pieces)
      if (pendingDrop == piecesInHand) {
        // All pieces selected to drop here - commit the drop
        // User can then either confirm with button or continue by tapping next cell
        uiNotifier.addDrop(pendingDrop);
        return;
      } else {
        // Not all pieces selected, cycle up
        uiNotifier.cyclePendingDropCount(piecesInHand);
        return;
      }
    }

    // Check if tapping the next cell in the movement direction
    // Only allow continuing for stack moves that still have pieces in hand
    final isSinglePieceMove = totalPiecesInMove == 1;
    if (pos == nextPos && canContinue && !isSinglePieceMove && uiState.piecesPickedUp > 0) {
      // Drop current pending at hand position and move to next
      final dropCount = uiState.pendingDropCount;
      uiNotifier.addDrop(dropCount);
      return;
    }

    // Tapping elsewhere on the board (not on path, origin, hand, or valid next cell): cancel completely
    uiNotifier.reset();
  }

  /// Get the direction from one position to an adjacent position
  Direction? _getDirectionBetween(Position from, Position to) {
    final rowDiff = to.row - from.row;
    final colDiff = to.col - from.col;

    // Must be in a straight line
    if (rowDiff != 0 && colDiff != 0) return null;
    if (rowDiff == 0 && colDiff == 0) return null;

    if (rowDiff < 0 && colDiff == 0) return Direction.up;
    if (rowDiff > 0 && colDiff == 0) return Direction.down;
    if (rowDiff == 0 && colDiff < 0) return Direction.left;
    if (rowDiff == 0 && colDiff > 0) return Direction.right;

    return null;
  }

  void _confirmMove(WidgetRef ref) {
    final uiState = ref.read(uiStateProvider);
    final pos = uiState.selectedPosition;
    final dir = uiState.selectedDirection;
    final drops = uiState.drops;

    if (pos == null || dir == null || drops.isEmpty) return;
    _performStackMove(pos, dir, drops, ref);
    ref.read(uiStateProvider.notifier).reset();
  }

  bool _performPlacementMove(Position pos, PieceType type, WidgetRef ref) {
    final gameState = ref.read(gameStateProvider);
    final session = ref.read(gameSessionProvider);
    final scenarioState = ref.read(scenarioStateProvider);
    final scenario = session.scenario ?? scenarioState.activeScenario;
    final guidanceActive =
        scenario != null && !scenarioState.guidedStepComplete;
    final color = gameState.isOpeningPhase ? gameState.opponent : gameState.currentPlayer;
    final soundManager = ref.read(soundManagerProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    if (scenario != null &&
        guidanceActive &&
        (scenario.guidedMove.type == GuidedMoveType.placement ||
         scenario.guidedMove.type == GuidedMoveType.anyPlacement) &&
        !_isAiTurn(session, gameState)) {
      final expected = scenario.guidedMove;
      // Check piece type if specified
      if (expected.pieceType != null && expected.pieceType != type) {
        soundManager.playIllegalMove();
        return false;
      }
      // Check position for non-any placements
      if (expected.type == GuidedMoveType.placement) {
        if (expected.allowedTargets != null) {
          if (!expected.allowedTargets!.contains(pos)) {
            soundManager.playIllegalMove();
            return false;
          }
        } else if (expected.target != null && pos != expected.target) {
          soundManager.playIllegalMove();
          return false;
        }
      }
      // anyPlacement allows any position
    }

    _debugLog('_performPlacementMove: pos=$pos, type=$type, currentPlayer=${gameState.currentPlayer}, turn=${gameState.turnNumber}');
    final success = gameNotifier.placePiece(pos, type);
    _debugLog('_performPlacementMove: placePiece result=$success');
      if (success) {
        if (scenario != null &&
            guidanceActive &&
            (scenario.guidedMove.type == GuidedMoveType.placement ||
             scenario.guidedMove.type == GuidedMoveType.anyPlacement)) {
        ref.read(scenarioStateProvider.notifier).markGuidedStepComplete();
      }
      final moveRecord = gameNotifier.lastMoveRecord;
      if (moveRecord != null) {
        ref.read(moveHistoryProvider.notifier).addMove(moveRecord);
        ref.read(lastMoveProvider.notifier).state = moveRecord.affectedPositions;
        _syncOnlineMove(moveRecord);
      }

      ref.read(animationStateProvider.notifier).piecePlaced(pos, type, color);
      soundManager.playPiecePlace();

      // Switch chess clock to next player when enabled
      _switchChessClock(ref);

      if (ref.read(isGameOverProvider)) {
        soundManager.playWin();
        // Stop the clock when game is over
        ref.read(chessClockProvider.notifier).stop();
      }

      unawaited(_maybeTriggerAiTurn(ref.read(gameStateProvider)));
    } else {
      soundManager.playIllegalMove();
    }

    return success;
  }

  bool _performStackMove(
    Position from,
    Direction dir,
    List<int> drops,
    WidgetRef ref,
  ) {
    final dropPositions = _calculateDropPositions(from, dir, drops.length);

    final gameState = ref.read(gameStateProvider);
    final session = ref.read(gameSessionProvider);
    final scenarioState = ref.read(scenarioStateProvider);
    final scenario = session.scenario ?? scenarioState.activeScenario;
    final guidanceActive =
        scenario != null && !scenarioState.guidedStepComplete;
    final stack = gameState.board.stackAt(from);
    final topPiece = stack.topPiece;
    Position? flattenedWallPos;
    if (topPiece != null && topPiece.canFlattenWalls && dropPositions.isNotEmpty) {
      final targetStack = gameState.board.stackAt(dropPositions.last);
      if (targetStack.topPiece?.type == PieceType.standing) {
        flattenedWallPos = dropPositions.last;
      }
    }

    final soundManager = ref.read(soundManagerProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    if (scenario != null &&
        guidanceActive &&
        !_isAiTurn(session, gameState)) {
      final guided = scenario.guidedMove;
      if (guided.type == GuidedMoveType.stackMove) {
        // Strict validation for specific stack moves
        final expectedDrops = guided.drops ?? const [];
        final dropsMatch = expectedDrops.length == drops.length &&
            List.generate(expectedDrops.length, (i) => expectedDrops[i] == drops[i])
                .every((e) => e);
        if (guided.from != from ||
            guided.direction != dir ||
            !dropsMatch) {
          soundManager.playIllegalMove();
          return false;
        }
      } else if (guided.type == GuidedMoveType.anyStackMove) {
        // Only validate from position for any stack move
        if (guided.from != from) {
          soundManager.playIllegalMove();
          return false;
        }
      }
    }

    final success = gameNotifier.moveStack(from, dir, drops);
    if (success) {
      if (scenario != null &&
          guidanceActive &&
          (scenario.guidedMove.type == GuidedMoveType.stackMove ||
           scenario.guidedMove.type == GuidedMoveType.anyStackMove)) {
        ref.read(scenarioStateProvider.notifier).markGuidedStepComplete();
      }
      final moveRecord = gameNotifier.lastMoveRecord;
      if (moveRecord != null) {
        ref.read(moveHistoryProvider.notifier).addMove(moveRecord);
        ref.read(lastMoveProvider.notifier).state = moveRecord.affectedPositions;
        _syncOnlineMove(moveRecord);
      }

      ref.read(animationStateProvider.notifier).stackMoved(from, dir, drops, dropPositions);
      if (flattenedWallPos != null) {
        ref.read(animationStateProvider.notifier).wallFlattened(flattenedWallPos);
        soundManager.playWallFlatten();
      } else {
        soundManager.playStackMove();
      }

      // Switch chess clock to next player when enabled
      _switchChessClock(ref);

      if (ref.read(isGameOverProvider)) {
        soundManager.playWin();
        // Stop the clock when game is over
        ref.read(chessClockProvider.notifier).stop();
      }

      unawaited(_maybeTriggerAiTurn(ref.read(gameStateProvider)));
    } else {
      soundManager.playIllegalMove();
    }

    return success;
  }

  void _switchChessClock(WidgetRef ref) {
    final settings = ref.read(appSettingsProvider);
    if (!settings.chessClockEnabled) return;

    final gameState = ref.read(gameStateProvider);
    // The game state has already switched to the next player, so start their clock
    ref.read(chessClockProvider.notifier).start(gameState.currentPlayer);
  }

  List<Position> _calculateDropPositions(Position start, Direction dir, int steps) {
    final dropPositions = <Position>[];
    var currentPos = start;
    for (var i = 0; i < steps; i++) {
      currentPos = dir.apply(currentPos);
      dropPositions.add(currentPos);
    }
    return dropPositions;
  }

  Future<void> _maybeTriggerAiTurn(GameState state) async {
    final session = ref.read(gameSessionProvider);
    if (session.mode != GameMode.vsComputer || state.isGameOver) return;
    if (state.currentPlayer != _aiPlayerColor(session)) return;
    if (ref.read(aiThinkingProvider)) return;

    ref.read(uiStateProvider.notifier).reset();
    ref.read(aiThinkingProvider.notifier).state = true;

    // Start a timer to show the thinking indicator after 500ms
    // This avoids showing a spinner for quick moves
    Future.delayed(const Duration(milliseconds: 500), () {
      if (ref.read(aiThinkingProvider)) {
        ref.read(aiThinkingVisibleProvider.notifier).state = true;
      }
    });

    try {
      // Small delay before AI starts for better UX
      await Future.delayed(const Duration(milliseconds: 200));

      final latestState = ref.read(gameStateProvider);
      final latestSession = ref.read(gameSessionProvider);
      if (latestSession.mode != GameMode.vsComputer ||
          latestState.isGameOver ||
          latestState.currentPlayer != _aiPlayerColor(latestSession)) {
        return;
      }

      final scenarioMove = ref.read(scenarioStateProvider).nextScriptedMove;
      if (scenarioMove != null) {
        final applied = _applyAiMove(scenarioMove, ref);
        if (applied) {
          ref.read(scenarioStateProvider.notifier).advanceScript();
          ref.read(uiStateProvider.notifier).reset();
          return;
        }
      }

      final ai = StonesAI.forDifficulty(latestSession.aiDifficulty);
      final move = await ai.selectMove(latestState);

      _applyAiMove(move, ref);
      ref.read(uiStateProvider.notifier).reset();
    } finally {
      ref.read(aiThinkingProvider.notifier).state = false;
      ref.read(aiThinkingVisibleProvider.notifier).state = false;
    }
  }

  bool _applyAiMove(AIMove? move, WidgetRef ref) {
    if (move is AIPlacementMove) {
      return _performPlacementMove(move.position, move.pieceType, ref);
    } else if (move is AIStackMove) {
      return _performStackMove(move.from, move.direction, move.drops, ref);
    }
    return false;
  }

  void _syncOnlineMove(MoveRecord? moveRecord) {
    if (moveRecord == null) return;
    final session = ref.read(gameSessionProvider);
    if (session.mode != GameMode.online) return;
    final latestState = ref.read(gameStateProvider);
    _debugLog('_syncOnlineMove: Recording move ${moveRecord.notation} to Firestore, '
        'nextTurn=${latestState.currentPlayer}');
    unawaited(
      ref.read(onlineGameProvider.notifier).recordLocalMove(moveRecord, latestState),
    );
  }

  Future<void> _confirmResign(BuildContext context) async {
    final session = ref.read(gameSessionProvider);
    if (session.mode != GameMode.online) return;
    final shouldResign = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Resign game?'),
            content: const Text(
              'Are you sure you want to resign this online match? Your opponent will be marked as the winner.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Resign'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldResign) {
      await ref.read(onlineGameProvider.notifier).resign();
    }
  }

  void _showNewGameDialog(BuildContext context, WidgetRef ref) {
    final gameState = ref.read(gameStateProvider);
    final session = ref.read(gameSessionProvider);
    final isGameInProgress = !gameState.isGameOver &&
        (gameState.turnNumber > 1 || gameState.board.occupiedPositions.isNotEmpty);
    final showSetup = session.mode == GameMode.vsComputer
        ? () => _showVsComputerSetupDialog(context, ref)
        : () => _showBoardSizeDialog(context, ref);

    if (isGameInProgress) {
      // Show confirmation dialog first
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start New Game?'),
          content: const Text(
            'You have a game in progress. Starting a new game will discard your current game.\n\nAre you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                showSetup();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start New Game'),
            ),
          ],
        ),
      );
    } else {
      showSetup();
    }
  }

  void _showBoardSizeDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appSettingsProvider);
    final session = ref.read(gameSessionProvider);
    int selectedSize = settings.boardSize;
    bool chessClockEnabled = settings.chessClockEnabled;
    int chessClockSeconds = settings.chessClockSecondsForSize(selectedSize);
    bool chessClockOverridden = false;
    final clockMinutesController = TextEditingController(
      text: (chessClockSeconds ~/ 60).toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Game'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select board size:'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int size = 3; size <= 8; size++)
                    ChoiceChip(
                      label: Text('$size×$size'),
                      selected: selectedSize == size,
                      onSelected: (_) => setState(() {
                        selectedSize = size;
                        if (!chessClockOverridden) {
                          chessClockSeconds = settings.chessClockSecondsForSize(size);
                          clockMinutesController.text =
                              (chessClockSeconds ~/ 60).toString();
                        }
                      }),
                      selectedColor: GameColors.boardFrameInner.withValues(alpha: 0.2),
                      checkmarkColor: GameColors.boardFrameInner,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ChessClockSetup(
                enabled: chessClockEnabled,
                onEnabledChanged: (value) => setState(() => chessClockEnabled = value),
                minutesController: clockMinutesController,
                onMinutesChanged: (value) {
                  chessClockOverridden = true;
                  final minutes = int.tryParse(value);
                  if (minutes != null && minutes > 0) {
                    chessClockSeconds = minutes * 60;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Save chess clock preference
                ref.read(appSettingsProvider.notifier).setChessClockEnabled(chessClockEnabled);
                ref.read(gameSessionProvider.notifier).state = session.copyWith(
                  chessClockSecondsOverride: chessClockEnabled && chessClockOverridden
                      ? chessClockSeconds
                      : null,
                );

                ref.read(gameStateProvider.notifier).newGame(selectedSize);
                ref.read(uiStateProvider.notifier).reset();
                ref.read(animationStateProvider.notifier).reset();
                ref.read(moveHistoryProvider.notifier).clear();
                ref.read(lastMoveProvider.notifier).state = null;

                // Reset chess clock for new game
                if (chessClockEnabled) {
                  ref.read(chessClockProvider.notifier).initialize(
                        selectedSize,
                        secondsOverride:
                            chessClockOverridden ? chessClockSeconds : null,
                      );
                } else {
                  ref.read(chessClockProvider.notifier).stop();
                }

                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GameColors.boardFrameInner,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Game'),
            ),
          ],
        ),
      ),
    );
  }

  String _getBoardSizeDescription(int size) {
    final counts = PieceCounts.forBoardSize(size);
    return '${counts.flatStones} flat stones, ${counts.capstones} capstone${counts.capstones == 1 ? '' : 's'} per player';
  }

  void _showVsComputerSetupDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appSettingsProvider);
    final session = ref.read(gameSessionProvider);
    int selectedSize = settings.boardSize;
    AIDifficulty selectedDifficulty = session.aiDifficulty;
    PlayerColor selectedPlayerColor = session.vsComputerPlayerColor;
    bool chessClockEnabled = settings.chessClockEnabled;
    int chessClockSeconds = settings.chessClockSecondsForSize(selectedSize);
    bool chessClockOverridden = false;
    final clockMinutesController = TextEditingController(
      text: (chessClockSeconds ~/ 60).toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          Widget buildDifficultyOption(String title, AIDifficulty difficulty) {
            final isSelected = selectedDifficulty == difficulty;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final borderColor = isSelected
                ? GameColors.boardFrameInner
                : isDark
                    ? Colors.grey.shade600
                    : Colors.grey.shade300;

            return InkWell(
              onTap: () => setState(() => selectedDifficulty = difficulty),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? GameColors.boardFrameInner.withValues(alpha: isDark ? 0.2 : 0.1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? GameColors.boardFrameInner
                              : isDark
                                  ? Colors.white
                                  : null,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: GameColors.boardFrameInner,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }

          Widget buildColorOption(String title, PlayerColor color) {
            final isSelected = selectedPlayerColor == color;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final borderColor = isSelected
                ? GameColors.boardFrameInner
                : isDark
                    ? Colors.grey.shade600
                    : Colors.grey.shade300;
            final chipColor =
                color == PlayerColor.white ? GameColors.lightPiece : GameColors.darkPiece;

            return InkWell(
              onTap: () => setState(() => selectedPlayerColor = color),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? GameColors.boardFrameInner.withValues(alpha: isDark ? 0.2 : 0.1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: chipColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? GameColors.boardFrameInner
                            : isDark
                                ? Colors.white
                                : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Play vs Computer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Text(
                        'Board Size',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : GameColors.titleColor,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int size = 3; size <= 8; size++)
                        ChoiceChip(
                          label: Text('$size×$size'),
                          selected: selectedSize == size,
                          onSelected: (_) => setState(() {
                            selectedSize = size;
                            if (!chessClockOverridden) {
                              chessClockSeconds = settings.chessClockSecondsForSize(size);
                              clockMinutesController.text =
                                  (chessClockSeconds ~/ 60).toString();
                            }
                          }),
                          selectedColor: GameColors.boardFrameInner.withValues(alpha: 0.2),
                          checkmarkColor: GameColors.boardFrameInner,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getBoardSizeDescription(selectedSize),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ChessClockSetup(
                    enabled: chessClockEnabled,
                    onEnabledChanged: (value) =>
                        setState(() => chessClockEnabled = value),
                    minutesController: clockMinutesController,
                    onMinutesChanged: (value) {
                      chessClockOverridden = true;
                      final minutes = int.tryParse(value);
                      if (minutes != null && minutes > 0) {
                        chessClockSeconds = minutes * 60;
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Text(
                        'Your Color',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : GameColors.titleColor,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: buildColorOption('White', PlayerColor.white)),
                      const SizedBox(width: 8),
                      Expanded(child: buildColorOption('Black', PlayerColor.black)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Text(
                        'Difficulty',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : GameColors.titleColor,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  buildDifficultyOption('Easy', AIDifficulty.easy),
                  buildDifficultyOption('Medium', AIDifficulty.medium),
                  buildDifficultyOption('Hard', AIDifficulty.hard),
                  buildDifficultyOption('Expert', AIDifficulty.expert),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(appSettingsProvider.notifier)
                      .setChessClockEnabled(chessClockEnabled);
                  ref.read(gameSessionProvider.notifier).state = GameSessionConfig(
                    mode: GameMode.vsComputer,
                    aiDifficulty: selectedDifficulty,
                    vsComputerPlayerColor: selectedPlayerColor,
                    chessClockSecondsOverride:
                        chessClockEnabled && chessClockOverridden ? chessClockSeconds : null,
                  );

                  ref.read(gameStateProvider.notifier).newGame(selectedSize);
                  ref.read(uiStateProvider.notifier).reset();
                  ref.read(animationStateProvider.notifier).reset();
                  ref.read(moveHistoryProvider.notifier).clear();
                  ref.read(lastMoveProvider.notifier).state = null;

                  if (chessClockEnabled) {
                    ref.read(chessClockProvider.notifier).initialize(
                          selectedSize,
                          secondsOverride:
                              chessClockOverridden ? chessClockSeconds : null,
                        );
                  } else {
                    ref.read(chessClockProvider.notifier).stop();
                  }

                  Navigator.pop(dialogContext);
                  unawaited(_maybeTriggerAiTurn(ref.read(gameStateProvider)));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameColors.boardFrameInner,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Start Game'),
              ),
            ],
          );
        },
      ),
    );
  }

}

/// Compact player side panel showing clock and pieces together
class _PlayerSidePanel extends ConsumerWidget {
  final PlayerColor player;
  final PlayerPieces pieces;
  final bool isCurrentTurn;
  final bool isGameOver;
  final bool showClock;
  final bool isVertical;

  const _PlayerSidePanel({
    required this.player,
    required this.pieces,
    required this.isCurrentTurn,
    required this.isGameOver,
    required this.showClock,
    this.isVertical = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLightPlayer = player == PlayerColor.white;
    final pieceColors = GameColors.forPlayer(isLightPlayer);
    final clockState = ref.watch(chessClockProvider);

    final time = isLightPlayer ? clockState.whiteTimeFormatted : clockState.blackTimeFormatted;
    final timeRemaining = isLightPlayer ? clockState.whiteTimeRemaining : clockState.blackTimeRemaining;
    final isLow = timeRemaining < 30;
    final isExpired = clockState.isExpired && clockState.expiredPlayer == player;
    final isClockActive = isCurrentTurn && !isGameOver && clockState.isRunning;

    final clockColor = isExpired
        ? Colors.red
        : isLow
            ? Colors.orange
            : isClockActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface;

    final bgColor = isCurrentTurn
        ? (isDark
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : pieceColors.primary.withValues(alpha: 0.15))
        : (isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.grey.shade100);

    final borderColor = isCurrentTurn ? pieceColors.border : Colors.transparent;

    final content = isVertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Player indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: pieceColors.gradientColors),
                  border: Border.all(color: pieceColors.border, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isLightPlayer ? 'Light' : 'Dark',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              if (showClock) ...[
                const SizedBox(height: 8),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: clockColor,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Piece counts
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: pieceColors.gradientColors),
                      border: Border.all(color: pieceColors.border),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${pieces.flatStones}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(12, 12),
                    painter: _SmallHexagonPainter(colors: pieceColors),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${pieces.capstones}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Player indicator
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: pieceColors.gradientColors),
                  border: Border.all(color: pieceColors.border, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              if (showClock) ...[
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: clockColor,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Compact piece counts
              Container(
                width: 12,
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: pieceColors.gradientColors),
                  border: Border.all(color: pieceColors.border, width: 0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Text(
                '${pieces.flatStones}',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(width: 4),
              CustomPaint(
                size: const Size(10, 10),
                painter: _SmallHexagonPainter(colors: pieceColors),
              ),
              Text(
                '${pieces.capstones}',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
              ),
            ],
          );

    return Container(
      padding: EdgeInsets.all(isVertical ? 8 : 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: isCurrentTurn ? 2 : 0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: content,
    );
  }
}

/// Compact turn indicator for narrow screens - overlays on the board
class _CompactTurnIndicator extends StatelessWidget {
  final GameState gameState;
  final bool isThinking;
  final OnlineGameState? onlineState;

  const _CompactTurnIndicator({
    required this.gameState,
    this.isThinking = false,
    this.onlineState,
  });

  @override
  Widget build(BuildContext context) {
    if (gameState.isGameOver) return const SizedBox.shrink();

    final isWhite = gameState.currentPlayer == PlayerColor.white;
    final pieceColors = GameColors.forPlayer(isWhite);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String turnText = '${isWhite ? 'Light' : 'Dark'} · Turn ${gameState.turnNumber}';
    if (onlineState?.localColor != null) {
      final isMyTurn = gameState.currentPlayer == onlineState!.localColor;
      turnText = isMyTurn ? 'Your turn · ${gameState.turnNumber}' : 'Waiting...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pieceColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: pieceColors.gradientColors),
              border: Border.all(color: pieceColors.border),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            turnText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (isThinking) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Side panel piece type selector for wide screens
class _SidePanelPieceSelector extends StatelessWidget {
  final PlayerPieces pieces;
  final PieceType currentType;
  final Function(PieceType) onTypeChanged;

  const _SidePanelPieceSelector({
    required this.pieces,
    required this.currentType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.grey.shade100;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: GameColors.cellSelectedBorder.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Place',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          _SidePieceButton(
            type: PieceType.flat,
            label: 'Flat',
            isSelected: currentType == PieceType.flat,
            isEnabled: pieces.flatStones > 0,
            onTap: pieces.flatStones > 0 ? () => onTypeChanged(PieceType.flat) : null,
          ),
          const SizedBox(height: 4),
          _SidePieceButton(
            type: PieceType.standing,
            label: 'Wall',
            isSelected: currentType == PieceType.standing,
            isEnabled: pieces.flatStones > 0,
            onTap: pieces.flatStones > 0 ? () => onTypeChanged(PieceType.standing) : null,
          ),
          const SizedBox(height: 4),
          _SidePieceButton(
            type: PieceType.capstone,
            label: 'Cap',
            isSelected: currentType == PieceType.capstone,
            isEnabled: pieces.capstones > 0,
            onTap: pieces.capstones > 0 ? () => onTypeChanged(PieceType.capstone) : null,
          ),
        ],
      ),
    );
  }
}

/// Individual piece button for side panel
class _SidePieceButton extends StatelessWidget {
  final PieceType type;
  final String label;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _SidePieceButton({
    required this.type,
    required this.label,
    required this.isSelected,
    required this.isEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? GameColors.cellSelectedGlow.withValues(alpha: 0.4)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? GameColors.cellSelectedBorder
                  : GameColors.controlPanelBorder.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PieceIcon(type: type, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? GameColors.cellSelectedBorder : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScenarioInfoCard extends StatelessWidget {
  final GameScenario scenario;

  const _ScenarioInfoCard({required this.scenario});

  @override
  Widget build(BuildContext context) {
    final isPuzzle = scenario.type == ScenarioType.puzzle;
    final accent = isPuzzle ? Colors.deepPurple : GameColors.boardFrameInner;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPuzzle ? Icons.extension : Icons.menu_book,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  scenario.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : GameColors.titleColor,
                  ),
                ),
              ),
            ],
          ),
          // Only show dialogue/instructions for tutorials, not puzzles
          if (!isPuzzle && scenario.dialogue.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final line in scenario.dialogue)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Win banner - shows game result prominently without blocking the board
class _WinBanner extends StatelessWidget {
  final GameResult result;
  final WinReason? winReason;

  const _WinBanner({
    required this.result,
    this.winReason,
  });

  @override
  Widget build(BuildContext context) {
    final winIcon = switch (winReason) {
      WinReason.road => Icons.route,
      WinReason.flats => Icons.emoji_events,
      WinReason.time => Icons.timer_off,
      null => Icons.emoji_events,
    };

    final (title, pieceColors, icon) = switch (result) {
      GameResult.whiteWins => (
          'Light Wins!',
          GameColors.lightPlayerColors,
          winIcon,
        ),
      GameResult.blackWins => (
          'Dark Wins!',
          GameColors.darkPlayerColors,
          winIcon,
        ),
      GameResult.draw => (
          'Draw!',
          const PieceColors(
            primary: Colors.grey,
            secondary: Colors.grey,
            border: Color(0xFF757575),
          ),
          Icons.handshake,
        ),
    };

    final reasonText = switch (winReason) {
      WinReason.road => 'by road',
      WinReason.flats => 'by flat count',
      WinReason.time => 'on time',
      null => '',
    };

    final textColor = result == GameResult.blackWins ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pieceColors.gradientColors,
        ),
        border: Border(
          bottom: BorderSide(
            color: pieceColors.border,
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: pieceColors.border.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: textColor,
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: 1,
                ),
              ),
              if (reasonText.isNotEmpty)
                Text(
                  reasonText,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Icon(
            icon,
            size: 32,
            color: textColor,
          ),
        ],
      ),
    );
  }
}

/// The game board grid with wooden inset styling
class _GameBoard extends StatelessWidget {
  final GameState gameState;
  final UIState uiState;
  final AnimationState animationState;
  final Set<Position>? lastMovePositions;
  final Set<Position> highlightedPositions;
  final Position? explodedPosition;
  final PieceStack? explodedStack;
  final Function(Position) onCellTap;
  final Function(Position, Direction) onCellSwipe;
  final Function(Position, PieceStack) onLongPressStart;
  final VoidCallback onLongPressEnd;
  final VoidCallback? onBoardFrameTap;
  final PieceStyleData pieceStyleData;
  final BoardThemeData boardThemeData;

  const _GameBoard({
    required this.gameState,
    required this.uiState,
    required this.animationState,
    required this.onCellTap,
    required this.onCellSwipe,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.pieceStyleData,
    required this.boardThemeData,
    this.onBoardFrameTap,
    this.highlightedPositions = const {},
    this.explodedPosition,
    this.explodedStack,
    this.lastMovePositions,
  });

  /// Get ghost piece info for a position (for placement mode)
  (PieceType?, PlayerColor?) _getGhostPieceInfo(Position pos) {
    if (uiState.mode != InteractionMode.placingPiece) return (null, null);
    if (uiState.selectedPosition != pos) return (null, null);

    // During opening phase, ghost is opponent's color
    final color = gameState.isOpeningPhase
        ? gameState.opponent
        : gameState.currentPlayer;

    return (uiState.ghostPieceType, color);
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging for board state
    final occupiedCount = gameState.board.occupiedPositions.length;
    _debugLog('BOARD BUILD: currentTurn=${gameState.currentPlayer}, '
        'turnNumber=${gameState.turnNumber}, '
        'phase=${gameState.phase}, '
        'occupiedCells=$occupiedCount, '
        'isGameOver=${gameState.isGameOver}');

    final dropPath = uiState.getDropPath();
    final nextDropPos = uiState.getCurrentHandPosition();
    // Get valid destinations for both movingStack and droppingPieces modes
    final validMoveDestinations = uiState.mode == InteractionMode.movingStack
        ? uiState.getValidMoveDestinations(gameState)
        : uiState.mode == InteractionMode.droppingPieces
            ? uiState.getValidDropDestinations(gameState)
            : <Position>{};
    final boardSize = gameState.boardSize;

    // Calculate preview stacks for move operations
    final previewStacks = uiState.getPreviewStacks(gameState);

    // Calculate responsive spacing based on board size
    // Larger boards get smaller spacing to fit well
    final spacing = boardSize <= 4 ? 6.0 : (boardSize <= 6 ? 5.0 : 4.0);
    final padding = boardSize <= 4 ? 10.0 : (boardSize <= 6 ? 8.0 : 6.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate cell size for decoration painter
        final availableWidth = constraints.maxWidth - padding * 2 - spacing * 2;
        final cellSize = (availableWidth - spacing * (boardSize - 1)) / boardSize;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onBoardFrameTap,
          child: Container(
            // Inner board area with inset shadow effect
            margin: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: GameColors.gridLine,
              borderRadius: BorderRadius.circular(6),
              // Inset shadow effect for the grid area
              boxShadow: [
                // Inner shadow (dark)
                BoxShadow(
                  color: GameColors.gridLineShadow.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                  offset: const Offset(2, 2),
                ),
                // Highlight edge
                BoxShadow(
                  color: GameColors.gridLineHighlight.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(-1, -1),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none, // Allow pieces to overflow the board
              children: [
                // Main grid
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.all(spacing),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: boardSize,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                    ),
                    itemCount: boardSize * boardSize,
                    itemBuilder: (context, index) {
                      final row = index ~/ boardSize;
                      final col = index % boardSize;
                      final pos = Position(row, col);
                      final actualStack = gameState.board.stackAt(pos);
                      final isSelected = uiState.selectedPosition == pos;
                      final isInDropPath = dropPath.contains(pos);
                      final isNextDrop = nextDropPos == pos;

                      // Get preview stack and ghost pieces for this position
                      final preview = previewStacks?[pos];
                      final displayStack = preview?.$1 ?? actualStack;
                      final ghostStackPieces = preview?.$2 ?? const <Piece>[];

                      // Check for animation events on this position
                      final lastEvent = animationState.lastEvent;
                      final isNewlyPlaced = lastEvent is PiecePlacedEvent && lastEvent.position == pos;
                      final isInWinningRoad = animationState.winningRoad?.contains(pos) ?? false;

                      // Check if this cell received pieces from a stack move
                      bool isStackDropTarget = false;
                      if (lastEvent is StackMovedEvent) {
                        isStackDropTarget = lastEvent.dropPositions.contains(pos);
                      }

                      // Check for wall flattening
                      bool wasWallFlattened = false;
                      if (lastEvent is WallFlattenedEvent && lastEvent.position == pos) {
                        wasWallFlattened = true;
                      }

                      // Check if this is part of the last move
                      final isLastMove = lastMovePositions?.contains(pos) ?? false;

                      final isExploded = explodedPosition == pos && explodedStack != null;
                      final stackForExplosion = isExploded ? explodedStack : null;

                      // Check if this is a valid move destination (legal move hint)
                      final isLegalMoveHint = validMoveDestinations.contains(pos);
                      final isScenarioHint = highlightedPositions.contains(pos);

                      // Ghost piece info for placement mode
                      final (ghostPieceType, ghostPieceColor) = _getGhostPieceInfo(pos);

                      // For stack movement mode, show pieces being picked up count
                      final showPickupCount = uiState.mode == InteractionMode.movingStack &&
                          uiState.selectedPosition == pos;

                      // Show pending drop count when in droppingPieces mode at hand position
                      // but only for stack moves (2+ pieces), not single-piece moves
                      final totalPiecesInMove = uiState.piecesPickedUp +
                          uiState.drops.fold<int>(0, (a, b) => a + b);
                      final showPendingDrop = uiState.mode == InteractionMode.droppingPieces &&
                          nextDropPos == pos &&
                          totalPiecesInMove > 1;

                      return _CellInteractionLayer(
                        position: pos,
                        stack: displayStack,
                        ghostStackPieces: ghostStackPieces,
                        onTap: () => onCellTap(pos),
                        onSwipe: (dir) => onCellSwipe(pos, dir),
                        onStackViewStart: onLongPressStart,
                        onStackViewEnd: onLongPressEnd,
                        child: _BoardCell(
                          key: ValueKey('cell_${pos.row}_${pos.col}_${displayStack.height}_${ghostStackPieces.length}_${ghostPieceType?.name ?? ''}_${isSelected}_$isInDropPath'),
                          stack: displayStack,
                          isSelected: isSelected,
                          isInDropPath: isInDropPath,
                          isNextDrop: isNextDrop,
                          canSelect: !gameState.isGameOver,
                          boardSize: boardSize,
                          pieceStyleData: pieceStyleData,
                          boardThemeData: boardThemeData,
                          isNewlyPlaced: isNewlyPlaced,
                          isInWinningRoad: isInWinningRoad,
                          isStackDropTarget: isStackDropTarget,
                          wasWallFlattened: wasWallFlattened,
                          isLastMove: isLastMove,
                          isLegalMoveHint: isLegalMoveHint,
                          isScenarioHint: isScenarioHint,
                          ghostPieceType: ghostPieceType,
                          ghostPieceColor: ghostPieceColor,
                          ghostStackPieces: ghostStackPieces,
                          pickupCount: showPickupCount ? uiState.piecesPickedUp : null,
                          pendingDropCount: showPendingDrop ? uiState.pendingDropCount : null,
                          piecesInHand: showPendingDrop ? uiState.piecesPickedUp : null,
                          showExploded: isExploded,
                          explodedStack: stackForExplosion,
                        ),
                      );
                    },
                  ),
                ),
                // Overlay decorations - filigree on top of grid lines (visible above cells)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: BoardDecorationPainter(
                        boardSize: boardSize,
                        spacing: spacing,
                        padding: spacing,
                        cellSize: cellSize,
                        theme: boardThemeData.theme,
                        decorColor: boardThemeData.gridLineHighlight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Interaction wrapper to support taps, long press, right-click, hover hold, and swipe for stack view
class _CellInteractionLayer extends StatefulWidget {
  final Position position;
  final PieceStack stack;
  final VoidCallback onTap;
  final Function(Position, PieceStack) onStackViewStart;
  final VoidCallback onStackViewEnd;
  final Widget child;

  /// Ghost pieces that would be added to the stack (for hover preview)
  final List<Piece> ghostStackPieces;

  /// Called when user swipes on the cell with a direction
  final Function(Direction)? onSwipe;

  const _CellInteractionLayer({
    required this.position,
    required this.stack,
    required this.onTap,
    required this.onStackViewStart,
    required this.onStackViewEnd,
    required this.child,
    this.ghostStackPieces = const [],
    this.onSwipe,
  });

  @override
  State<_CellInteractionLayer> createState() => _CellInteractionLayerState();
}

class _CellInteractionLayerState extends State<_CellInteractionLayer> {
  Timer? _hoverTimer;
  bool _isViewing = false;

  /// Minimum velocity in pixels/second to recognize as a swipe
  static const double _swipeVelocityThreshold = 100.0;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  /// Get the stack to show in the exploded view (real stack + ghost pieces)
  PieceStack _getPreviewStack() {
    if (widget.ghostStackPieces.isEmpty) {
      return widget.stack;
    }
    // Combine actual stack with ghost pieces for preview
    return widget.stack.pushAll(widget.ghostStackPieces);
  }

  /// Check if we have content to display in hover (stack or ghosts)
  bool get _hasContent =>
      widget.stack.isNotEmpty || widget.ghostStackPieces.isNotEmpty;

  void _activateView() {
    if (_isViewing || !_hasContent) return;
    widget.onStackViewStart(widget.position, _getPreviewStack());
    _isViewing = true;
  }

  void _deactivateView() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    if (!_isViewing) return;
    widget.onStackViewEnd();
    _isViewing = false;
  }

  void _scheduleHover() {
    if (!_hasContent) return;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 280), _activateView);
  }

  /// Convert velocity to a Direction based on swipe gesture
  Direction? _getSwipeDirection(Offset velocity) {
    final dx = velocity.dx;
    final dy = velocity.dy;

    // Check if the swipe velocity is fast enough
    if (dx.abs() < _swipeVelocityThreshold && dy.abs() < _swipeVelocityThreshold) {
      return null;
    }

    // Determine primary direction based on which axis has greater velocity
    if (dx.abs() > dy.abs()) {
      // Horizontal swipe
      return dx > 0 ? Direction.right : Direction.left;
    } else {
      // Vertical swipe - note: in screen coordinates, positive Y is down
      return dy > 0 ? Direction.down : Direction.up;
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (widget.onSwipe == null) {
      return;
    }

    // Use the velocity to determine swipe direction for better UX
    final velocity = details.velocity.pixelsPerSecond;
    final direction = _getSwipeDirection(velocity);

    if (direction != null) {
      _deactivateView();
      widget.onSwipe!(direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _scheduleHover(),
      onExit: (_) => _deactivateView(),
      child: GestureDetector(
        onTap: () {
          _deactivateView();
          widget.onTap();
        },
        onPanEnd: widget.onSwipe != null ? _handlePanEnd : null,
        onLongPressStart: _hasContent ? (_) => _activateView() : null,
        onLongPressEnd: _hasContent ? (_) => _deactivateView() : null,
        onLongPressCancel: _hasContent ? _deactivateView : null,
        onSecondaryTapDown: _hasContent ? (_) => _activateView() : null,
        onSecondaryTapUp: _hasContent ? (_) => _deactivateView() : null,
        onSecondaryTapCancel: _hasContent ? _deactivateView : null,
        child: widget.child,
      ),
    );
  }
}

/// A single cell on the board with wooden style and glow effects
class _BoardCell extends StatefulWidget {
  final PieceStack stack;
  final bool isSelected;
  final bool isInDropPath;
  final bool isNextDrop;
  final bool canSelect;
  final int boardSize;
  final bool isNewlyPlaced;
  final bool isInWinningRoad;
  final bool isStackDropTarget;
  final bool wasWallFlattened;
  final bool isLastMove;
  final bool isLegalMoveHint;
  final bool isScenarioHint;
  final bool showExploded;
  final PieceStack? explodedStack;
  final PieceStyleData pieceStyleData;
  final BoardThemeData boardThemeData;

  /// Ghost piece to show (for placement preview)
  final PieceType? ghostPieceType;
  final PlayerColor? ghostPieceColor;

  /// Ghost pieces to show on top of stack (for move preview)
  /// These are pieces being moved that will land on this cell
  final List<Piece> ghostStackPieces;

  /// Number of pieces being picked up (for stack movement)
  final int? pickupCount;

  /// Pending drop count at this position
  final int? pendingDropCount;

  /// Total pieces in hand (for drop preview)
  final int? piecesInHand;

  const _BoardCell({
    super.key,
    required this.stack,
    required this.isSelected,
    required this.pieceStyleData,
    required this.boardThemeData,
    this.isInDropPath = false,
    this.isNextDrop = false,
    required this.canSelect,
    required this.boardSize,
    this.isNewlyPlaced = false,
    this.isInWinningRoad = false,
    this.ghostPieceType,
    this.ghostPieceColor,
    this.ghostStackPieces = const [],
    this.pickupCount,
    this.pendingDropCount,
    this.piecesInHand,
    this.isStackDropTarget = false,
    this.wasWallFlattened = false,
    this.isLastMove = false,
    this.isLegalMoveHint = false,
    this.isScenarioHint = false,
    this.showExploded = false,
    this.explodedStack,
  });

  @override
  State<_BoardCell> createState() => _BoardCellState();
}

class _BoardCellState extends State<_BoardCell> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _placementController;
  late AnimationController _slideController;
  late AnimationController _flattenController;
  late AnimationController _winPulseController;
  late AnimationController _stackRevealController;

  // Animations
  late Animation<double> _placementScale;
  late Animation<double> _slideScale;
  late Animation<double> _flattenScale;
  late Animation<double> _winPulse;
  late Animation<double> _stackReveal;

  @override
  void initState() {
    super.initState();

    // Placement animation: scale with bounce (200ms)
    _placementController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _placementScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _placementController,
        curve: Curves.elasticOut,
      ),
    );

    // Slide animation: scale in from direction (150ms)
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _slideScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      ),
    );

    // Flatten animation: quick squash (150ms)
    _flattenController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _flattenScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _flattenController,
      curve: Curves.easeInOut,
    ));

    // Win pulse animation: continuous glow (800ms loop)
    _winPulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _winPulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _winPulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Stack reveal animation: fan upward with a quick snap
    _stackRevealController = AnimationController(
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _stackReveal = CurvedAnimation(
      parent: _stackRevealController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );

    if (widget.showExploded) {
      _stackRevealController.value = 1.0;
    }

    // Start animations based on initial state
    if (widget.isNewlyPlaced) {
      _placementController.forward();
    }
    if (widget.isStackDropTarget) {
      _slideController.forward();
    }
    if (widget.wasWallFlattened) {
      _flattenController.forward();
    }
    if (widget.isInWinningRoad) {
      _winPulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_BoardCell oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger placement animation
    if (widget.isNewlyPlaced && !oldWidget.isNewlyPlaced) {
      _placementController.forward(from: 0);
    }

    // Trigger slide animation
    if (widget.isStackDropTarget && !oldWidget.isStackDropTarget) {
      _slideController.forward(from: 0);
    }

    // Trigger flatten animation
    if (widget.wasWallFlattened && !oldWidget.wasWallFlattened) {
      _flattenController.forward(from: 0);
    }

    if (widget.showExploded && !oldWidget.showExploded) {
      _stackRevealController.forward(from: 0);
    } else if (!widget.showExploded && oldWidget.showExploded) {
      _stackRevealController.reverse();
    }

    // Start/stop win pulse
    if (widget.isInWinningRoad && !oldWidget.isInWinningRoad) {
      _winPulseController.repeat(reverse: true);
    } else if (!widget.isInWinningRoad && oldWidget.isInWinningRoad) {
      _winPulseController.stop();
      _winPulseController.reset();
    }
  }

  @override
  void dispose() {
    _placementController.dispose();
    _slideController.dispose();
    _flattenController.dispose();
    _winPulseController.dispose();
    _stackRevealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate responsive border radius based on board size
    final borderRadius = widget.boardSize <= 4 ? 6.0 : (widget.boardSize <= 6 ? 5.0 : 4.0);
    final borderWidth = widget.boardSize <= 4 ? 2.5 : (widget.boardSize <= 6 ? 2.0 : 1.5);

    // Build decoration based on state
    BoxDecoration decoration;

    if (widget.isSelected) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GameColors.cellSelected,
            GameColors.cellSelectedGlow,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: GameColors.cellSelectedBorder, width: borderWidth),
        boxShadow: [
          // Glow effect
          BoxShadow(
            color: GameColors.cellSelectedGlow.withValues(alpha: 0.6),
            blurRadius: 8,
            spreadRadius: 1,
          ),
          // Inner highlight
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(-1, -1),
          ),
        ],
      );
    } else if (widget.isNextDrop) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GameColors.cellNextDrop,
            GameColors.cellNextDropGlow,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: GameColors.cellNextDropBorder, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: GameColors.cellNextDropGlow.withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      );
    } else if (widget.isInDropPath) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GameColors.cellDropPath,
            GameColors.cellDropPathGlow,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: GameColors.cellDropPathBorder, width: borderWidth * 0.8),
        boxShadow: [
          BoxShadow(
            color: GameColors.cellDropPathGlow.withValues(alpha: 0.4),
            blurRadius: 4,
          ),
        ],
      );
    } else if (widget.isScenarioHint) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFECF4FF),
            Color(0xFFD2E2FF),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: GameColors.boardFrameInner,
          width: borderWidth * 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: GameColors.boardFrameInner.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      );
    } else if (widget.isLegalMoveHint) {
      // Legal move destination hint (cyan/teal highlight)
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GameColors.cellLegalMove,
            GameColors.cellLegalMoveGlow,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: GameColors.cellLegalMoveBorder, width: borderWidth * 0.8),
        boxShadow: [
          BoxShadow(
            color: GameColors.cellLegalMoveGlow.withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      );
    } else {
      // Default cell look - uses board theme colors
      final theme = widget.boardThemeData;
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.cellBackgroundLight,
            theme.cellBackground,
            theme.cellBackgroundDark,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        // Subtle inset effect
        boxShadow: [
          BoxShadow(
            color: theme.gridLineShadow.withValues(alpha: 0.3),
            blurRadius: 1,
            offset: const Offset(1, 1),
          ),
          BoxShadow(
            color: theme.gridLineHighlight.withValues(alpha: 0.5),
            blurRadius: 1,
            offset: const Offset(-0.5, -0.5),
          ),
        ],
      );
    }

    // Add winning road glow effect
    Widget cellContent = Container(
      decoration: decoration,
      child: Center(
        child: _buildCellContent(),
      ),
    );

    // Wrap with win pulse animation if part of winning road
    if (widget.isInWinningRoad) {
      cellContent = AnimatedBuilder(
        animation: _winPulse,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: _winPulse.value * 0.8),
                  blurRadius: 12 * _winPulse.value,
                  spreadRadius: 2 * _winPulse.value,
                ),
              ],
            ),
            child: child,
          );
        },
        child: cellContent,
      );
    }

    if (widget.showExploded) {
      cellContent = AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.22),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: cellContent,
      );
    }

    // Add last move highlighting (subtle outline)
    // Only show if not already highlighted by another state
    if (widget.isLastMove && !widget.isSelected && !widget.isInDropPath && !widget.isNextDrop && !widget.isInWinningRoad) {
      cellContent = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: GameColors.lastMoveBorder,
            width: borderWidth * 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: GameColors.lastMoveGlow.withValues(alpha: 0.3),
              blurRadius: 4,
            ),
          ],
        ),
        child: cellContent,
      );
    }

    return cellContent;
  }

  /// Build the cell content - handles ghost pieces, stacks, and overlay badges
  Widget _buildCellContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth;
        final pieceSize = cellSize * 0.7;
        final badgeFontSize = widget.boardSize <= 4 ? 10.0 : (widget.boardSize <= 6 ? 9.0 : 8.0);
        final badgePadding = widget.boardSize <= 4 ? 4.0 : (widget.boardSize <= 6 ? 3.0 : 2.5);

        // If showing ghost piece (empty cell with placement preview)
        if (widget.ghostPieceType != null && widget.ghostPieceColor != null && widget.stack.isEmpty) {
          final isLightPlayer = widget.ghostPieceColor == PlayerColor.white;
          final pieceColors = widget.pieceStyleData.colorsForPlayer(isLightPlayer);

          return Opacity(
            opacity: 0.5,
            child: _buildPiece(widget.ghostPieceType!, pieceSize, pieceColors, isLightPlayer),
          );
        }

        // If empty cell and no ghost stack pieces, show nothing
        if (widget.stack.isEmpty && widget.ghostStackPieces.isEmpty) {
          // But if this is the next drop position, show pending drop indicator
          if (widget.pendingDropCount != null && widget.piecesInHand != null) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Show pending drop count badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: badgePadding * 1.5,
                    vertical: badgePadding,
                  ),
                  decoration: BoxDecoration(
                    color: GameColors.cellNextDropBorder.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(badgePadding * 2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '${widget.pendingDropCount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: badgeFontSize * 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          }
          return const SizedBox();
        }

        final stackForDisplay = widget.explodedStack ?? widget.stack;
        final hasGhostPieces = widget.ghostStackPieces.isNotEmpty;
        final isExplodedView = widget.showExploded &&
            (stackForDisplay.isNotEmpty || hasGhostPieces);

        // For exploded view, combine real stack with ghost pieces
        // BUT: if explodedStack is set, it already contains ghosts (from _getPreviewStack)
        final bool explodedStackAlreadyCombined = widget.explodedStack != null;
        final combinedStack = explodedStackAlreadyCombined
            ? stackForDisplay  // Already has ghosts included
            : (hasGhostPieces
                ? widget.stack.pushAll(widget.ghostStackPieces)
                : widget.stack);
        // Ghost pieces start after the original display stack
        final ghostStartIndex = widget.stack.height;

        // Build stack display (exploded fan-out or normal depth view)
        Widget content;
        if (isExplodedView) {
          content = _buildExplodedStackViewWithGhosts(
            combinedStack,
            cellSize,
            ghostStartIndex,
          );
        } else if (stackForDisplay.isEmpty && hasGhostPieces) {
          // Only ghost pieces, no actual stack
          content = _buildGhostOnlyStack(widget.ghostStackPieces, pieceSize);
        } else if (hasGhostPieces) {
          // Has both real stack and ghost pieces
          content = _buildStackWithGhosts(
            stackForDisplay,
            widget.ghostStackPieces,
            cellSize,
            pieceSize,
          );
        } else {
          // Normal stack display (no ghosts)
          content = _buildStackDisplay(stackForDisplay);
        }

        // Add pickup count overlay for stack movement
        if (widget.pickupCount != null) {
          content = Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              content,
              // Pickup count badge at top
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: badgePadding,
                    vertical: badgePadding * 0.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1565C0),
                        Color(0xFF0D47A1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(badgePadding),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 2,
                        offset: const Offset(0.5, 0.5),
                      ),
                    ],
                  ),
                  child: Text(
                    '${widget.pickupCount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Add pending drop count overlay for dropping mode
        if (widget.pendingDropCount != null && widget.piecesInHand != null) {
          content = Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              content,
              // Pending drop badge
              Positioned(
                top: -2,
                left: -2,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: badgePadding,
                    vertical: badgePadding * 0.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE65100),
                        Color(0xFFBF360C),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(badgePadding),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 2,
                        offset: const Offset(0.5, 0.5),
                      ),
                    ],
                  ),
                  child: Text(
                    '+${widget.pendingDropCount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        if (isExplodedView) {
          content = AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.only(bottom: cellSize * 0.02),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: content,
          );
        }

        return content;
      },
    );
  }

  Widget _buildStackDisplay(PieceStack stack) {
    if (stack.isEmpty) return const SizedBox();

    final top = stack.topPiece!;
    final isLightPlayer = top.color == PlayerColor.white;
    final pieceColors = widget.pieceStyleData.colorsForPlayer(isLightPlayer);
    final height = stack.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth;
        final pieceSize = cellSize * 0.7;

        Widget content;
        // For stacks, show depth visualization
        if (height > 1) {
          content = _buildStackWithDepth(stack, cellSize, pieceSize, pieceColors, isLightPlayer);
        } else {
          // Single piece - just show it centered
          content = _buildPiece(top.type, pieceSize, pieceColors, isLightPlayer);
        }

        // Apply placement animation (scale with bounce)
        if (widget.isNewlyPlaced) {
          content = ScaleTransition(
            scale: _placementScale,
            child: content,
          );
        }

        // Apply slide animation for stack drops
        if (widget.isStackDropTarget) {
          content = ScaleTransition(
            scale: _slideScale,
            child: content,
          );
        }

        // Apply flatten animation
        if (widget.wasWallFlattened) {
          content = AnimatedBuilder(
            animation: _flattenScale,
            builder: (context, child) {
              return Transform.scale(
                scaleY: _flattenScale.value,
                child: child,
              );
            },
            child: content,
          );
        }

        return content;
      },
    );
  }

  /// Build a stack display with ghost pieces on top (semi-transparent)
  Widget _buildStackWithGhosts(
    PieceStack stack,
    List<Piece> ghostPieces,
    double cellSize,
    double pieceSize,
  ) {
    if (stack.isEmpty && ghostPieces.isEmpty) return const SizedBox();

    final baseFootprint = _pieceFootprintHeight(PieceType.flat, pieceSize);
    final naturalOffset = baseFootprint * 0.32;
    final minOffset = baseFootprint * 0.2;
    final availableHeight = cellSize * 0.9;

    // Calculate total pieces to display
    final totalRealPieces = stack.height;
    const maxVisiblePieces = 3;
    final visibleRealCount = totalRealPieces > maxVisiblePieces ? maxVisiblePieces : totalRealPieces;

    // Always show all ghost pieces
    final visibleCount = visibleRealCount + ghostPieces.length;
    final visibleOffset = visibleCount > 1
        ? (availableHeight - baseFootprint) / (visibleCount - 1)
        : naturalOffset;
    final verticalOffset = math.max(minOffset, math.min(naturalOffset, visibleOffset));

    final badgeFontSize = widget.boardSize <= 4 ? 10.0 : (widget.boardSize <= 6 ? 9.0 : 8.0);
    final badgePadding = widget.boardSize <= 4 ? 4.0 : (widget.boardSize <= 6 ? 3.0 : 2.5);

    // Start index for real pieces (skip bottom hidden pieces)
    final startIndex = totalRealPieces - visibleRealCount;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Render real pieces
        for (int i = 0; i < visibleRealCount; i++)
          Transform.translate(
            offset: Offset(0, -i * verticalOffset),
            child: _buildStackPiece(
              stack.pieces[startIndex + i],
              pieceSize,
              1.0,  // All confirmed pieces are solid (no depth fade)
            ),
          ),

        // Render ghost pieces on top with semi-transparency
        for (int i = 0; i < ghostPieces.length; i++)
          Transform.translate(
            offset: Offset(0, -(visibleRealCount + i) * verticalOffset),
            child: Opacity(
              opacity: 0.5,
              child: _buildStackPiece(ghostPieces[i], pieceSize, 1.0),
            ),
          ),

        // Stack height badge showing total (real + ghost)
        Positioned(
          bottom: 1,
          right: 1,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: badgePadding,
              vertical: badgePadding * 0.5,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6D4C41),
                  GameColors.stackBadge,
                ],
              ),
              borderRadius: BorderRadius.circular(badgePadding),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(0.5, 0.5),
                ),
              ],
            ),
            child: Text(
              '${totalRealPieces + ghostPieces.length}',
              style: TextStyle(
                color: GameColors.stackBadgeText,
                fontSize: badgeFontSize,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 1,
                    offset: const Offset(0.5, 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build ghost-only stack display (no actual pieces, just ghosts)
  Widget _buildGhostOnlyStack(List<Piece> ghostPieces, double pieceSize) {
    if (ghostPieces.isEmpty) return const SizedBox();

    if (ghostPieces.length == 1) {
      // Single ghost piece
      final piece = ghostPieces.first;
      final isLightPlayer = piece.color == PlayerColor.white;
      final pieceColors = widget.pieceStyleData.colorsForPlayer(isLightPlayer);
      return Opacity(
        opacity: 0.5,
        child: _buildPiece(piece.type, pieceSize, pieceColors, isLightPlayer),
      );
    }

    // Multiple ghost pieces - show as stack
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth;
        final baseFootprint = _pieceFootprintHeight(PieceType.flat, pieceSize);
        final naturalOffset = baseFootprint * 0.32;
        final minOffset = baseFootprint * 0.2;
        final availableHeight = cellSize * 0.9;

        final visibleCount = ghostPieces.length > 3 ? 3 : ghostPieces.length;
        final visibleOffset = visibleCount > 1
            ? (availableHeight - baseFootprint) / (visibleCount - 1)
            : naturalOffset;
        final verticalOffset = math.max(minOffset, math.min(naturalOffset, visibleOffset));

        final badgeFontSize = widget.boardSize <= 4 ? 10.0 : (widget.boardSize <= 6 ? 9.0 : 8.0);
        final badgePadding = widget.boardSize <= 4 ? 4.0 : (widget.boardSize <= 6 ? 3.0 : 2.5);

        final startIndex = ghostPieces.length - visibleCount;

        return Opacity(
          opacity: 0.5,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < visibleCount; i++)
                Transform.translate(
                  offset: Offset(0, -i * verticalOffset),
                  child: _buildStackPiece(
                    ghostPieces[startIndex + i],
                    pieceSize,
                    1.0,  // No depth fade (ghost opacity already applied by wrapper)
                  ),
                ),

              // Ghost stack badge
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: badgePadding,
                    vertical: badgePadding * 0.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF6D4C41),
                        GameColors.stackBadge,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(badgePadding),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 2,
                        offset: const Offset(0.5, 0.5),
                      ),
                    ],
                  ),
                  child: Text(
                    '${ghostPieces.length}',
                    style: TextStyle(
                      color: GameColors.stackBadgeText,
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 1,
                          offset: const Offset(0.5, 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build exploded stack view with ghost pieces shown semi-transparent
  Widget _buildExplodedStackViewWithGhosts(
    PieceStack stack,
    double cellSize,
    int ghostStartIndex,
  ) {
    final pieceSize = cellSize * 0.7;
    final baseFootprint = _pieceFootprintHeight(PieceType.flat, pieceSize);
    final baseLift = baseFootprint * 0.25;
    final naturalSpacing = baseFootprint * 0.6;
    final minSpacing = baseFootprint * 0.28;

    // Compress spacing when the vertical stack would overflow the cell area
    final availableHeight = cellSize * 1.2;
    final adjustedSpacing = stack.height > 1
        ? (availableHeight - baseFootprint) / (stack.height - 1)
        : naturalSpacing;
    final liftStep = math.max(minSpacing, math.min(naturalSpacing, adjustedSpacing));

    return AnimatedBuilder(
      animation: _stackReveal,
      builder: (context, child) {
        final progress = _stackReveal.value;
        final height = stack.height;
        final children = <Widget>[
          // Soft glow at the base of the stack
          Positioned(
            bottom: cellSize * 0.06,
            child: Opacity(
              opacity: progress * 0.45,
              child: Container(
                width: cellSize * (0.65 + (0.25 * progress)),
                height: cellSize * 0.16,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.25 * progress),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(cellSize),
                ),
              ),
            ),
          ),
        ];

        // Don't fan single pieces - just lift slightly for clarity
        if (height <= 1) {
          final piece = stack.topPiece;
          if (piece != null) {
            final isLightPlayer = piece.color == PlayerColor.white;
            final pieceColors = widget.pieceStyleData.colorsForPlayer(isLightPlayer);
            final isGhost = ghostStartIndex == 0;

            children.add(
              Transform.translate(
                offset: Offset(0, -progress * baseLift),
                child: Opacity(
                  opacity: isGhost ? 0.5 : 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: pieceColors.border.withValues(alpha: 0.35 * progress + 0.1),
                          blurRadius: 10 * progress + 2,
                          spreadRadius: 0.6 * progress,
                          offset: Offset(0, 2 - (progress)),
                        ),
                      ],
                    ),
                    child: _buildPiece(piece.type, pieceSize, pieceColors, isLightPlayer),
                  ),
                ),
              ),
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: children,
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            ...children,
            for (int i = 0; i < stack.height; i++)
              _buildExplodedPieceWithGhost(
                stack.pieces[i],
                i,
                stack.height,
                pieceSize,
                baseLift,
                liftStep,
                progress,
                i >= ghostStartIndex, // isGhost
              ),
          ],
        );
      },
    );
  }

  /// Build an individual exploded piece, with ghost support
  Widget _buildExplodedPieceWithGhost(
    Piece piece,
    int index,
    int totalPieces,
    double pieceSize,
    double baseLift,
    double liftStep,
    double progress,
    bool isGhost,
  ) {
    final fromBottom = index;
    final verticalOffset = -progress * (baseLift + (fromBottom * liftStep));
    double horizontalOffset = 0;

    if (totalPieces > 1) {
      final t = fromBottom / (totalPieces - 1);
      final fanCurve = math.sin((t - 0.5) * math.pi);
      horizontalOffset = progress * pieceSize * 0.08 * fanCurve;
    }

    final isLightPlayer = piece.color == PlayerColor.white;
    final pieceColors = widget.pieceStyleData.colorsForPlayer(isLightPlayer);

    return Transform.translate(
      offset: Offset(horizontalOffset, verticalOffset),
      child: Opacity(
        opacity: isGhost ? 0.5 : 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: pieceColors.border.withValues(alpha: 0.35 * progress + 0.1),
                blurRadius: 12 * progress + 3,
                spreadRadius: 0.8 * progress,
                offset: Offset(0, 3 - (progress * 1.5)),
              ),
            ],
          ),
          child: Transform.scale(
            scale: 1.0 + (0.02 * progress),
            child: _buildPiece(piece.type, pieceSize, pieceColors, isLightPlayer),
          ),
        ),
      ),
    );
  }

  double _pieceFootprintHeight(PieceType type, double pieceSize) {
    switch (type) {
      case PieceType.flat:
        return pieceSize * 0.55;
      case PieceType.standing:
        return pieceSize;
      case PieceType.capstone:
        return pieceSize * 0.85;
    }
  }

  /// Build a stack visualization showing actual pieces stacked with depth
  Widget _buildStackWithDepth(
    PieceStack stack,
    double cellSize,
    double pieceSize,
    PieceColors topColors,
    bool isLightPlayer,
  ) {
    final height = stack.height;

    // Calculate responsive values based on board size
    final baseFootprint = _pieceFootprintHeight(PieceType.flat, pieceSize);
    final naturalOffset = baseFootprint * 0.32;
    final minOffset = baseFootprint * 0.2;
    final availableHeight = cellSize * 0.9;

    // Show up to 3 pieces visually, use badge for taller stacks
    const maxVisiblePieces = 3;
    final int visibleCount = height > maxVisiblePieces ? maxVisiblePieces : height;

    final visibleOffset = visibleCount > 1
        ? (availableHeight - baseFootprint) / (visibleCount - 1)
        : naturalOffset;
    final verticalOffset = math.max(minOffset, math.min(naturalOffset, visibleOffset));
    final badgeFontSize = widget.boardSize <= 4 ? 10.0 : (widget.boardSize <= 6 ? 9.0 : 8.0);
    final badgePadding = widget.boardSize <= 4 ? 4.0 : (widget.boardSize <= 6 ? 3.0 : 2.5);

    // Get the pieces to display (top N pieces of the stack)
    // pieces[0] is bottom, pieces[height-1] is top
    final startIndex = height - visibleCount;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Render pieces from bottom to top
        // Bottom pieces are rendered first (lower in visual stack)
        for (int i = 0; i < visibleCount; i++)
          Transform.translate(
            // Each piece moves up as we go higher in the stack
            // i=0 is the lowest visible piece, i=visibleCount-1 is the top
            offset: Offset(0, -i * verticalOffset),
            child: _buildStackPiece(
              stack.pieces[startIndex + i],
              pieceSize,
              1.0,  // All confirmed pieces are solid (no depth fade)
            ),
          ),

        // Stack height badge (always show for stacks > 1)
        Positioned(
          bottom: 1,
          right: 1,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: badgePadding,
              vertical: badgePadding * 0.5,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6D4C41),
                  GameColors.stackBadge,
                ],
              ),
              borderRadius: BorderRadius.circular(badgePadding),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(0.5, 0.5),
                ),
              ],
            ),
            child: Text(
              '$height',
              style: TextStyle(
                color: GameColors.stackBadgeText,
                fontSize: badgeFontSize,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 1,
                    offset: const Offset(0.5, 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build a single piece in a stack with optional opacity
  Widget _buildStackPiece(Piece piece, double pieceSize, double opacity) {
    final isLightPlayer = piece.color == PlayerColor.white;
    final pieceColors = widget.pieceStyleData.colorsForPlayer(isLightPlayer);

    return Opacity(
      opacity: opacity,
      child: _buildPiece(piece.type, pieceSize, pieceColors, isLightPlayer),
    );
  }

  /// Build a piece widget based on type - uses current piece style
  Widget _buildPiece(PieceType type, double size, PieceColors colors, bool isLightPlayer) {
    final style = widget.pieceStyleData.style;

    switch (type) {
      case PieceType.flat:
        return _buildFlatStone(size, colors, isLightPlayer, style);
      case PieceType.standing:
        return _buildStandingStone(size, colors, style);
      case PieceType.capstone:
        return _buildCapstone(size, colors, style);
    }
  }

  /// Flat stone - uses procedural painter based on style
  Widget _buildFlatStone(double size, PieceColors colors, bool isLightPlayer, PieceStyle style) {
    return CustomPaint(
      size: Size(size, size * 0.55),
      painter: getFlatPainter(
        style: style,
        colors: colors,
        isLightPlayer: isLightPlayer,
      ),
    );
  }

  /// Standing stone (wall) - uses procedural painter based on style
  Widget _buildStandingStone(double size, PieceColors colors, PieceStyle style) {
    return CustomPaint(
      size: Size(size, size),
      painter: getWallPainter(
        style: style,
        colors: colors,
      ),
    );
  }

  /// Capstone - uses procedural painter based on style
  Widget _buildCapstone(double size, PieceColors colors, PieceStyle style) {
    final capSize = size * 0.85;
    return CustomPaint(
      size: Size(capSize, capSize),
      painter: getCapstonePainter(
        style: style,
        colors: colors,
      ),
    );
  }
}

/// Bottom controls panel - simplified for on-board interaction
class _BottomControls extends StatelessWidget {
  final GameState gameState;
  final UIState uiState;
  final Function(PieceType) onPieceTypeChanged;
  final VoidCallback onConfirmMove;
  final VoidCallback onCancel;
  final bool isWideScreen;

  const _BottomControls({
    required this.gameState,
    required this.uiState,
    required this.onPieceTypeChanged,
    required this.onConfirmMove,
    required this.onCancel,
    this.isWideScreen = false,
  });

  /// Tips shown randomly during idle state
  static const List<String> _takTips = [
    'Tip: Create a "road" connecting opposite edges to win!',
    'Tip: Capstones can flatten standing stones (walls).',
    'Tip: Walls block roads but don\'t count toward flat wins.',
    'Tip: Moving stacks lets you control the board faster.',
    'Tip: You can pick up to N pieces from a stack on an NxN board.',
    'Tip: The first two moves place your opponent\'s piece.',
    'Tip: Watch for threats – one move from completing a road!',
    'Tip: Press and hold on a stack to see all pieces.',
    'Tip: Capstones are powerful but limited – use them wisely!',
    'Tip: Flats count for tie-breakers, so place them strategically.',
  ];

  String _getRandomTip() {
    return _takTips[DateTime.now().millisecond % _takTips.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = math.max(MediaQuery.of(context).padding.bottom, 12.0);

    if (gameState.isGameOver) {
      return SizedBox(height: bottomPadding);
    }

    // Fixed height container to prevent board rescaling when controls change
    // Taller height for more breathing room with full hints
    return Container(
      height: 72 + bottomPadding,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 10 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9)
            : GameColors.controlPanelBg.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)
                : GameColors.controlPanelBorder.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: _buildControls(context),
    );
  }

  Widget _buildControls(BuildContext context) {
    switch (uiState.mode) {
      case InteractionMode.idle:
        return _buildIdleHint(context);
      case InteractionMode.placingPiece:
        return _buildPlacingPieceControls(context);
      case InteractionMode.movingStack:
        return _buildMovingStackHint(context);
      case InteractionMode.droppingPieces:
        return _buildDroppingPiecesControls(context);
    }
  }

  Widget _buildIdleHint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tipColor = isDark ? Colors.white54 : Colors.grey.shade600;
    final instructionColor = isDark ? Colors.white70 : Colors.grey.shade700;

    // Full instruction text
    final String instruction = gameState.isOpeningPhase
        ? 'Opening phase: Tap an empty cell to place your opponent\'s flat stone.'
        : 'Tap an empty cell to place a piece, or tap a stack you control to move it.';

    // Random tip
    final String tip = _getRandomTip();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Instruction
        Text(
          instruction,
          style: TextStyle(
            color: instructionColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        // Random tip
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 12, color: tipColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                tip,
                style: TextStyle(
                  color: tipColor,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlacingPieceControls(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : GameColors.subtitleColor;
    final pieces = gameState.currentPlayerPieces;
    final isOpening = gameState.isOpeningPhase;
    final currentType = uiState.ghostPieceType;

    // During opening, only flat stones allowed - simple hint
    if (isOpening) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Tap the highlighted cell again to place, or tap elsewhere to move.',
            style: TextStyle(color: textColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
        ],
      );
    }

    // On wide screens, piece selector is in side panel - just show hint
    if (isWideScreen) {
      final typeName = switch (currentType) {
        PieceType.flat => 'Flat',
        PieceType.standing => 'Wall',
        PieceType.capstone => 'Capstone',
      };
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Placing: $typeName · Tap cell to confirm, use sidebar to change type.',
            style: TextStyle(color: textColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
        ],
      );
    }

    // On narrow screens, show piece type selector in bottom area
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Select piece type, then tap to place:',
          style: TextStyle(color: textColor, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PieceTypeToggle(
              type: PieceType.flat,
              isSelected: currentType == PieceType.flat,
              isEnabled: pieces.flatStones > 0,
              onTap: pieces.flatStones > 0 ? () => onPieceTypeChanged(PieceType.flat) : null,
            ),
            const SizedBox(width: 6),
            _PieceTypeToggle(
              type: PieceType.standing,
              label: 'Wall',
              isSelected: currentType == PieceType.standing,
              isEnabled: pieces.flatStones > 0,
              onTap: pieces.flatStones > 0 ? () => onPieceTypeChanged(PieceType.standing) : null,
            ),
            const SizedBox(width: 6),
            _PieceTypeToggle(
              type: PieceType.capstone,
              isSelected: currentType == PieceType.capstone,
              isEnabled: pieces.capstones > 0,
              onTap: pieces.capstones > 0 ? () => onPieceTypeChanged(PieceType.capstone) : null,
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Cancel',
              color: textColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMovingStackHint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : GameColors.subtitleColor;
    final piecesPickedUp = uiState.piecesPickedUp;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Picking up $piecesPickedUp piece${piecesPickedUp > 1 ? 's' : ''}. Tap the stack again to change count.',
          style: TextStyle(color: textColor, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Move to an adjacent cell to start dropping.',
              style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 12),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDroppingPiecesControls(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : GameColors.subtitleColor;
    final remaining = uiState.piecesPickedUp;
    final drops = uiState.drops;

    // Calculate total pieces in this move to determine if it's a stack move
    final totalPiecesInMove = remaining + drops.fold<int>(0, (a, b) => a + b);
    final isStackMove = totalPiecesInMove > 1;

    // Can confirm when at least one drop has been made
    final canConfirm = drops.isNotEmpty;
    final allPiecesDropped = remaining == 0;

    if (allPiecesDropped && canConfirm) {
      // All pieces dropped - show confirm (for stack moves) or auto-confirmed (single piece)
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Move complete! Dropped: ${drops.join(' → ')}',
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: onConfirmMove,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Confirm Move'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: textColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Still dropping - show status
    final pendingDrop = uiState.pendingDropCount;

    // For single-piece moves, show simpler message
    if (!isStackMove) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Tap the highlighted cell to confirm move.',
            style: TextStyle(color: textColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
        ],
      );
    }

    // Build status text for stack moves based on drops made
    final statusText = drops.isEmpty
        ? 'Dropping $pendingDrop piece${pendingDrop > 1 ? 's' : ''} here. ${remaining - pendingDrop} remaining in hand.'
        : 'Dropped: ${drops.join(' → ')} · Now dropping $pendingDrop. ${remaining - pendingDrop} remaining.';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          statusText,
          style: TextStyle(color: textColor, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Show confirm button for stack moves with at least one drop
            if (canConfirm) ...[
              ElevatedButton.icon(
                onPressed: onConfirmMove,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Confirm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
              const SizedBox(width: 8),
            ],
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Toggle button for piece type selection
class _PieceTypeToggle extends StatelessWidget {
  final PieceType type;
  final String? label;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _PieceTypeToggle({
    required this.type,
    this.label,
    required this.isSelected,
    required this.isEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? type.name[0].toUpperCase() + type.name.substring(1);

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? GameColors.cellSelectedGlow.withValues(alpha: 0.3)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? GameColors.cellSelectedBorder
                  : GameColors.controlPanelBorder,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PieceIcon(type: type, size: 20),
              const SizedBox(height: 2),
              Text(
                displayLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? GameColors.cellSelectedBorder : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PieceIcon extends StatelessWidget {
  final PieceType type;
  final double size;

  const _PieceIcon({required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case PieceType.flat:
        return Container(
          width: size,
          height: size * 0.5,
          decoration: BoxDecoration(
            color: GameColors.pieceIconFill,
            border: Border.all(color: GameColors.pieceIconBorder),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: GameColors.flatStoneShadow,
                offset: const Offset(1, 1),
                blurRadius: 1,
              ),
            ],
          ),
        );
      case PieceType.standing:
        return Container(
          width: size * 0.4,
          height: size,
          decoration: BoxDecoration(
            color: GameColors.pieceIconFill,
            border: Border.all(color: GameColors.pieceIconBorder),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: GameColors.standingStoneShadow,
                offset: const Offset(2, 2),
                blurRadius: 2,
              ),
            ],
          ),
        );
      case PieceType.capstone:
        return CustomPaint(
          size: Size(size, size),
          painter: _HexagonIconPainter(),
        );
    }
  }
}

/// Simple hexagon painter for piece icons (neutral color)
class _HexagonIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final path = _createHexagonPath(center, radius * 0.85);

    // Fill
    final fillPaint = Paint()..color = GameColors.pieceIconFill;
    canvas.drawPath(path, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = GameColors.pieceIconBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, borderPaint);
  }

  Path _createHexagonPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Move history panel - collapsible sidebar showing moves in algebraic notation
class _MoveHistoryPanel extends StatelessWidget {
  final List<MoveRecord> moveHistory;
  final int boardSize;
  final VoidCallback onClose;

  const _MoveHistoryPanel({
    required this.moveHistory,
    required this.boardSize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: GameColors.controlPanelBg,
        border: const Border(
          left: BorderSide(color: GameColors.controlPanelBorder, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: GameColors.boardFrameInner,
              border: Border(
                bottom: BorderSide(color: GameColors.controlPanelBorder),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Move History',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),

          // Move list
          Expanded(
            child: moveHistory.isEmpty
                ? const Center(
                    child: Text(
                      'No moves yet',
                      style: TextStyle(
                        color: GameColors.subtitleColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: (moveHistory.length + 1) ~/ 2, // Number of turn pairs
                    itemBuilder: (context, turnIndex) {
                      return _buildTurnRow(turnIndex);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnRow(int turnIndex) {
    // Each turn has white's move and potentially black's move
    final whiteIndex = turnIndex * 2;
    final blackIndex = whiteIndex + 1;

    final hasWhiteMove = whiteIndex < moveHistory.length;
    final hasBlackMove = blackIndex < moveHistory.length;

    final turnNumber = turnIndex + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          // Turn number
          SizedBox(
            width: 28,
            child: Text(
              '$turnNumber.',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: GameColors.subtitleColor,
                fontSize: 12,
              ),
            ),
          ),
          // White's move
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: hasWhiteMove ? GameColors.lightPiece.withValues(alpha: 0.5) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: hasWhiteMove
                    ? Border.all(color: GameColors.lightPieceBorder.withValues(alpha: 0.3))
                    : null,
              ),
              child: Text(
                hasWhiteMove ? moveHistory[whiteIndex].notation : '',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasWhiteMove ? Colors.black87 : Colors.transparent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Black's move
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: hasBlackMove ? GameColors.darkPiece.withValues(alpha: 0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: hasBlackMove
                    ? Border.all(color: GameColors.darkPieceBorder.withValues(alpha: 0.3))
                    : null,
              ),
              child: Text(
                hasBlackMove ? moveHistory[blackIndex].notation : '',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasBlackMove ? Colors.white : Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small hexagon painter for piece count display
class _SmallHexagonPainter extends CustomPainter {
  final PieceColors colors;

  _SmallHexagonPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final path = _createHexagonPath(center, radius * 0.85);

    // Fill with gradient
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: colors.gradientColors,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, gradientPaint);

    // Border
    final borderPaint = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, borderPaint);
  }

  Path _createHexagonPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SmallHexagonPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

class _OnlineStatusBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;

  const _OnlineStatusBanner({
    required this.message,
    this.icon = Icons.wifi_tethering,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bannerColor = color ?? GameColors.boardFrameInner;
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.white.withValues(alpha: 0.95),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: bannerColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color != null ? bannerColor : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Version footer shown at the bottom of all pages
class VersionFooter extends StatelessWidget {
  const VersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final commitUrl = AppVersion.commitUrl;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: commitUrl != null
            ? MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _launchUrl(commitUrl),
                  child: Text(
                    AppVersion.displayVersion,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.grey.shade400,
                    ),
                  ),
                ),
              )
            : Text(
                AppVersion.displayVersion,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Dialog shown when an achievement is unlocked
class _AchievementUnlockDialog extends StatefulWidget {
  final GameAchievement achievement;

  const _AchievementUnlockDialog({required this.achievement});

  @override
  State<_AchievementUnlockDialog> createState() =>
      _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState extends State<_AchievementUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4A3728),
                  Color(0xFF2C1810),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFD4AF37),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                const Text(
                  'ACHIEVEMENT UNLOCKED',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),

                // Achievement name
                Text(
                  widget.achievement.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Achievement description
                Text(
                  widget.achievement.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),

                // Unlocked reward (if any)
                if (widget.achievement.unlocksReward != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFD4AF37),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Unlocked: ${widget.achievement.unlocksReward}',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Dismiss button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text('TAP TO DISMISS'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
