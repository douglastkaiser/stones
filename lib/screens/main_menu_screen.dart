import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../theme/theme.dart';
import '../version.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'game_screen.dart';
import 'online_lobby_screen.dart';

/// Main menu screen with title, play button, settings, and about links
class MainMenuScreen extends ConsumerStatefulWidget {
  const MainMenuScreen({super.key});

  @override
  ConsumerState<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends ConsumerState<MainMenuScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Load settings
    await ref.read(appSettingsProvider.notifier).load();

    // Initialize sound manager
    final soundManager = ref.read(soundManagerProvider);
    await soundManager.initialize();

    // Sync mute state with settings
    final settings = ref.read(appSettingsProvider);
    await soundManager.setMuted(settings.isSoundMuted);
    ref.read(isMutedProvider.notifier).state = soundManager.isMuted;

    // Attempt silent sign-in for Google Play Games
    await ref.read(playGamesServiceProvider.notifier).initialize();
  }

  void _startNewGame(
    BuildContext context,
    GameMode mode, {
    AIDifficulty difficulty = AIDifficulty.intro,
  }) {
    final gameState = ref.read(gameStateProvider);
    final isGameInProgress = !gameState.isGameOver &&
        (gameState.turnNumber > 1 || gameState.board.occupiedPositions.isNotEmpty);

    void showBoardSizePicker() => _showBoardSizePickerDialog(context, mode, difficulty);

    if (isGameInProgress) {
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
                showBoardSizePicker();
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
      showBoardSizePicker();
    }
  }

  void _showBoardSizePickerDialog(
    BuildContext context,
    GameMode mode,
    AIDifficulty difficulty,
  ) {
    final settings = ref.read(appSettingsProvider);
    int selectedSize = settings.boardSize;
    bool chessClockEnabled = settings.chessClockEnabled;
    int chessClockSeconds = settings.timeForBoardSize(selectedSize);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Board Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (context) {
                  return Text(
                    'Choose the board size for your game:',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (int size = 3; size <= 8; size++)
                    ChoiceChip(
                      label: Text(
                        '$size×$size',
                        style: TextStyle(
                          fontWeight: selectedSize == size
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: selectedSize == size,
                      onSelected: (_) => setState(() {
                        selectedSize = size;
                        chessClockSeconds = settings.timeForBoardSize(size);
                      }),
                      selectedColor: GameColors.boardFrameInner.withValues(alpha: 0.2),
                      checkmarkColor: GameColors.boardFrameInner,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  return Text(
                    _getBoardSizeDescription(selectedSize),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildChessClockSection(
                enabled: chessClockEnabled,
                seconds: chessClockSeconds,
                onEnabledChanged: (enabled) => setState(() => chessClockEnabled = enabled),
                onSecondsChanged: (seconds) => setState(() => chessClockSeconds = seconds),
              // Chess clock toggle
              Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final inactiveColor = isDark
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Colors.grey.shade700;
                  return InkWell(
                    onTap: () => setState(() => chessClockEnabled = !chessClockEnabled),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 20,
                            color: chessClockEnabled
                                ? GameColors.boardFrameInner
                                : inactiveColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Chess Clock',
                            style: TextStyle(
                              fontWeight: chessClockEnabled ? FontWeight.bold : FontWeight.normal,
                              color: chessClockEnabled
                                  ? GameColors.boardFrameInner
                                  : inactiveColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: chessClockEnabled,
                            onChanged: (v) => setState(() => chessClockEnabled = v),
                            activeTrackColor: GameColors.boardFrameInner.withValues(alpha: 0.5),
                            activeThumbColor: GameColors.boardFrameInner,
                          ),
                        ],
                      ),
                    ),
                  );
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
                Navigator.pop(dialogContext);
                _doStartNewGame(
                  context,
                  selectedSize,
                  mode,
                  difficulty,
                  chessClockEnabled: chessClockEnabled,
                  chessClockSeconds: chessClockSeconds,
                );
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

  Widget _buildChessClockSection({
    required bool enabled,
    required int seconds,
    required ValueChanged<bool> onEnabledChanged,
    required ValueChanged<int> onSecondsChanged,
  }) {
    final minutes = (seconds / 60).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Chess clock toggle
        InkWell(
          onTap: () => onEnabledChanged(!enabled),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer,
                  size: 20,
                  color: enabled ? GameColors.boardFrameInner : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Chess Clock',
                  style: TextStyle(
                    fontWeight: enabled ? FontWeight.bold : FontWeight.normal,
                    color:
                        enabled ? GameColors.boardFrameInner : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: enabled,
                  onChanged: onEnabledChanged,
                  activeTrackColor: GameColors.boardFrameInner.withValues(alpha: 0.5),
                  activeThumbColor: GameColors.boardFrameInner,
                ),
              ],
            ),
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('clock_$seconds'),
            initialValue: minutes.toString(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Time per player (minutes)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              final minutes = int.tryParse(value);
              if (minutes != null && minutes > 0) {
                onSecondsChanged(minutes * 60);
              }
            },
          ),
        ],
      ],
    );
  }

  String _getBoardSizeDescription(int size) {
    final counts = PieceCounts.forBoardSize(size);
    return '${counts.flatStones} flat stones, ${counts.capstones} capstone${counts.capstones == 1 ? '' : 's'} per player';
  }

  void _doStartNewGame(
    BuildContext context,
    int size,
    GameMode mode,
    AIDifficulty difficulty, {
    bool chessClockEnabled = false,
    int? chessClockSeconds,
    PlayerColor playerColor = PlayerColor.white,
  }) {
    final clockSeconds =
        chessClockSeconds ?? ref.read(appSettingsProvider).timeForBoardSize(size);
    ref.read(scenarioStateProvider.notifier).clearScenario();
    ref.read(gameSessionProvider.notifier).state = GameSessionConfig(
      mode: mode,
      aiDifficulty: difficulty,
      chessClockEnabled: chessClockEnabled,
      chessClockSeconds: clockSeconds,
      playerColor: playerColor,
    );
    ref.read(gameStateProvider.notifier).newGame(size);
    ref.read(uiStateProvider.notifier).reset();
    ref.read(animationStateProvider.notifier).reset();
    ref.read(moveHistoryProvider.notifier).clear();
    ref.read(lastMoveProvider.notifier).state = null;

    // Always reset chess clock when starting a new game
    if (chessClockEnabled) {
      // Initialize with new board size (resets times and stops any running timer)
      ref.read(chessClockProvider.notifier).initialize(clockSeconds);
      // Clock will start when first move is made in _switchChessClock
    } else {
      // Stop any running clock when disabled
      ref.read(chessClockProvider.notifier).stop();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  void _startVsComputer(BuildContext context) {
    final gameState = ref.read(gameStateProvider);
    final isGameInProgress = !gameState.isGameOver &&
        (gameState.turnNumber > 1 || gameState.board.occupiedPositions.isNotEmpty);

    void showPickers() => _showVsComputerPickerDialog(context);

    if (isGameInProgress) {
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
                showPickers();
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
      showPickers();
    }
  }

  void _startScenarioFlow(BuildContext context, GameScenario scenario) {
    final gameState = ref.read(gameStateProvider);
    final isGameInProgress = !gameState.isGameOver &&
        (gameState.turnNumber > 1 || gameState.board.occupiedPositions.isNotEmpty);

    void startScenario() {
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

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    }

    if (isGameInProgress) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace current game?'),
          content: Text(
            'Starting "${scenario.title}" will replace the game you are currently playing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                startScenario();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Scenario'),
            ),
          ],
        ),
      );
    } else {
      startScenario();
    }
  }

  void _openScenarioSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tutorials & Puzzles'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final scenario in tutorialAndPuzzleLibrary)
                  _ScenarioListTile(
                    scenario: scenario,
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _startScenarioFlow(context, scenario);
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showVsComputerPickerDialog(BuildContext context) {
    final settings = ref.read(appSettingsProvider);
    int selectedSize = settings.boardSize;
    AIDifficulty selectedDifficulty = AIDifficulty.easy;
    bool chessClockEnabled = settings.chessClockEnabled;
    int chessClockSeconds = settings.timeForBoardSize(selectedSize);
    PlayerColor playerColor = PlayerColor.white;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Play vs Computer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Board Size Section
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
                          chessClockSeconds = settings.timeForBoardSize(size);
                        }),
                        selectedColor: GameColors.boardFrameInner.withValues(alpha: 0.2),
                        checkmarkColor: GameColors.boardFrameInner,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    return Text(
                      _getBoardSizeDescription(selectedSize),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Color selection
                const Text(
                  'Your Color',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: GameColors.titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('White'),
                      avatar: const Icon(
                        Icons.circle,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                      ),
                      selected: playerColor == PlayerColor.white,
                      onSelected: (_) => setState(() => playerColor = PlayerColor.white),
                      selectedColor: GameColors.boardFrameInner.withValues(alpha: 0.2),
                      checkmarkColor: GameColors.boardFrameInner,
                    ),
                    ChoiceChip(
                      label: const Text('Black'),
                      avatar: const Icon(Icons.circle, color: Colors.black),
                      selected: playerColor == PlayerColor.black,
                      onSelected: (_) => setState(() => playerColor = PlayerColor.black),
                      selectedColor: GameColors.boardFrameInner.withValues(alpha: 0.2),
                      checkmarkColor: GameColors.boardFrameInner,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Difficulty Section
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
                _DifficultyOption(
                  title: 'Intro',
                  isSelected: selectedDifficulty == AIDifficulty.intro,
                  onTap: () => setState(() => selectedDifficulty = AIDifficulty.intro),
                ),
                _DifficultyOption(
                  title: 'Easy',
                  isSelected: selectedDifficulty == AIDifficulty.easy,
                  onTap: () => setState(() => selectedDifficulty = AIDifficulty.easy),
                ),
                _DifficultyOption(
                  title: 'Medium',
                  isSelected: selectedDifficulty == AIDifficulty.medium,
                  onTap: () => setState(() => selectedDifficulty = AIDifficulty.medium),
                ),
                _DifficultyOption(
                  title: 'Hard',
                  isSelected: selectedDifficulty == AIDifficulty.hard,
                  onTap: () => setState(() => selectedDifficulty = AIDifficulty.hard),
                ),
                const SizedBox(height: 20),

                // Chess clock controls
                _buildChessClockSection(
                  enabled: chessClockEnabled,
                  seconds: chessClockSeconds,
                  onEnabledChanged: (enabled) => setState(() => chessClockEnabled = enabled),
                  onSecondsChanged: (seconds) => setState(() => chessClockSeconds = seconds),
                ),
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
                Navigator.pop(dialogContext);
                ref.read(appSettingsProvider.notifier).setChessClockEnabled(chessClockEnabled);
                _doStartNewGame(
                  context,
                  selectedSize,
                  GameMode.vsComputer,
                  selectedDifficulty,
                  chessClockEnabled: chessClockEnabled,
                  chessClockSeconds: chessClockSeconds,
                  playerColor: playerColor,
                );
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

  void _continueGame(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final hasGameInProgress = !gameState.isGameOver &&
        (gameState.turnNumber > 1 || gameState.board.occupiedPositions.isNotEmpty);
    final playGames = ref.watch(playGamesServiceProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with settings and about
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // About link on the left
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                    child: const Text(
                      'About',
                      style: TextStyle(
                        color: GameColors.subtitleColor,
                      ),
                    ),
                  ),
                  if (playGames.player != null)
                    _PlayerChip(
                      displayName: playGames.player!.displayName,
                      iconImage: playGames.iconImage,
                    ),
                  // Settings gear on the right
                  IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: GameColors.subtitleColor,
                    ),
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo/Title
                      _buildLogo(context),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Text(
                            'A game of roads and flats',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: isDark
                                      ? Theme.of(context).colorScheme.onSurfaceVariant
                                      : GameColors.subtitleColor,
                                ),
                          );
                        },
                      ),
                      const SizedBox(height: 64),

                      // Game mode buttons
                      SizedBox(
                        width: 220,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => _startNewGame(context, GameMode.local),
                          icon: const Icon(Icons.group, size: 24),
                          label: const Text(
                            'Local Game',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GameColors.boardFrameInner,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: 220,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OnlineLobbyScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.wifi, size: 22),
                          label: const Text(
                            'Online Game',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GameColors.boardFrameOuter,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: 220,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () => _startVsComputer(context),
                          icon: const Icon(Icons.smart_toy_outlined, size: 22),
                          label: const Text(
                            'Vs Computer',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GameColors.boardFrameInner,
                            side: const BorderSide(color: GameColors.boardFrameInner, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Text(
                            'You play as White when facing the computer',
                            style: TextStyle(
                              color: isDark
                                  ? Theme.of(context).colorScheme.onSurfaceVariant
                                  : GameColors.subtitleColor,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Tutorial and puzzle hub
                      Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          final colorScheme = Theme.of(context).colorScheme;
                          // In dark mode, use primary color for better contrast
                          final buttonColor = isDark
                              ? colorScheme.primary
                              : GameColors.boardFrameInner;
                          return SizedBox(
                            width: 220,
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: () => _openScenarioSelector(context),
                              icon: Icon(Icons.school, size: 22, color: buttonColor),
                              label: Text(
                                'Tutorials & Puzzles',
                                style: TextStyle(fontSize: 17, color: buttonColor),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: buttonColor,
                                side: BorderSide(color: buttonColor, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Text(
                            'Guided boards with scripted examples',
                            style: TextStyle(
                              color: isDark
                                  ? Theme.of(context).colorScheme.onSurfaceVariant
                                  : GameColors.subtitleColor,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Continue game button (if game in progress)
                      if (hasGameInProgress) ...[
                        SizedBox(
                          width: 200,
                          child: OutlinedButton.icon(
                            onPressed: () => _continueGame(context),
                            icon: const Icon(Icons.replay),
                            label: const Text('Continue Game'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: GameColors.subtitleColor,
                              side: const BorderSide(color: GameColors.subtitleColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Version footer
            const _VersionFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Stack of styled stones as logo
        SizedBox(
          height: 80,
          width: 120,
          child: CustomPaint(
            painter: _LogoPainter(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'STONES',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : GameColors.titleColor,
                letterSpacing: 8,
              ),
        ),
      ],
    );
  }
}

/// Custom painter for the logo - stacked stones
class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final baseY = size.height * 0.85;

    // Draw three stacked flat stones
    _drawFlatStone(canvas, centerX, baseY, 50, GameColors.darkPiece, GameColors.darkPieceBorder);
    _drawFlatStone(canvas, centerX, baseY - 12, 50, GameColors.lightPiece, GameColors.lightPieceBorder);
    _drawFlatStone(canvas, centerX, baseY - 24, 50, GameColors.darkPiece, GameColors.darkPieceBorder);

    // Draw a capstone on top
    _drawCapstone(canvas, centerX, baseY - 50, 16, GameColors.lightPiece, GameColors.lightPieceBorder);
  }

  void _drawFlatStone(Canvas canvas, double x, double y, double width, Color fill, Color border) {
    const height = 10.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: width, height: height),
      const Radius.circular(2),
    );

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(rect.shift(const Offset(2, 2)), shadowPaint);

    // Fill
    final fillPaint = Paint()..color = fill;
    canvas.drawRRect(rect, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rect, borderPaint);
  }

  void _drawCapstone(Canvas canvas, double x, double y, double radius, Color fill, Color border) {
    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(x + 2, y + 2), radius, shadowPaint);

    // Fill
    final fillPaint = Paint()..color = fill;
    canvas.drawCircle(Offset(x, y), radius, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(x, y), radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScenarioListTile extends StatelessWidget {
  final GameScenario scenario;
  final VoidCallback onTap;

  const _ScenarioListTile({required this.scenario, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPuzzle = scenario.type == ScenarioType.puzzle;
    final accent = isPuzzle ? Colors.deepPurple : GameColors.boardFrameInner;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: isDark ? 0.55 : 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.12),
          foregroundColor: accent,
          child: Icon(isPuzzle ? Icons.extension : Icons.menu_book),
        ),
        title: Text(
          scenario.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            scenario.summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Chip(
          label: Text(scenario.type == ScenarioType.puzzle ? 'Puzzle' : 'Tutorial'),
          backgroundColor: accent.withValues(alpha: 0.15),
          labelStyle: TextStyle(color: accent, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final String displayName;
  final String? iconImage;

  const _PlayerChip({
    required this.displayName,
    this.iconImage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    ImageProvider? avatar;
    if (iconImage != null) {
      try {
        avatar = MemoryImage(base64Decode(iconImage!));
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: avatar,
            child: avatar == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Version footer widget
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  Future<void> _openPrivacyPolicy() async {
    // On web, use relative URL so it works for both production and PR previews
    // On mobile, use absolute URL to production site
    final Uri url = kIsWeb
        ? Uri.base.resolve('privacy')
        : Uri.parse('https://douglastkaiser.github.io/stones/privacy');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Colors.grey.shade500;
    final separatorColor = isDark
        ? Theme.of(context).colorScheme.outline
        : Colors.grey.shade400;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppVersion.displayVersion,
              style: TextStyle(
                fontSize: 11,
                color: textColor,
              ),
            ),
            Text(
              '  \u2022  ',
              style: TextStyle(
                fontSize: 11,
                color: separatorColor,
              ),
            ),
            GestureDetector(
              onTap: _openPrivacyPolicy,
              child: Text(
                'Privacy',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                  decoration: TextDecoration.underline,
                  decorationColor: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Difficulty option for AI picker
class _DifficultyOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _DifficultyOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isSelected
        ? GameColors.boardFrameInner
        : isDark
            ? Colors.grey.shade600
            : Colors.grey.shade300;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
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
}
