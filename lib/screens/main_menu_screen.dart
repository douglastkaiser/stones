import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../theme/theme.dart';
import '../version.dart';
import '../hex/hex_screen.dart';
import '../hex/hex_learning_screen.dart';
import '../widgets/chess_clock_setup.dart';
import '../widgets/play_mode_card.dart';
import '../widgets/saved_online_games.dart';
import 'achievements_screen.dart';
import 'leaderboard_screen.dart';
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

    // Load achievements
    await ref.read(achievementProvider.notifier).load();

    // Load cosmetics
    await ref.read(cosmeticsProvider.notifier).load();

    // Initialize sound manager
    final soundManager = ref.read(soundManagerProvider);
    await soundManager.initialize();

    // Sync mute state with settings
    final settings = ref.read(appSettingsProvider);
    await soundManager.setMuted(settings.isSoundMuted);
    ref.read(isMutedProvider.notifier).state = soundManager.isMuted;

    // Attempt silent sign-in for Google Play Games
    await ref.read(playGamesServiceProvider.notifier).initialize();

    // Initialize ELO rating system
    await ref.read(eloProvider.notifier).initialize(syncOnline: false);
  }

  void _startNewGame(
    BuildContext context,
    GameMode mode, {
    AIDifficulty difficulty = AIDifficulty.easy,
  }) {
    final gameState = ref.read(gameStateProvider);
    final isGameInProgress = !gameState.isGameOver &&
        (gameState.turnNumber > 1 ||
            gameState.board.occupiedPositions.isNotEmpty);

    void showBoardSizePicker() =>
        _showBoardSizePickerDialog(context, mode, difficulty);

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
    int chessClockSeconds = settings.chessClockSecondsForSize(selectedSize);
    bool chessClockOverridden = false;
    final clockMinutesController = TextEditingController(
      text: (chessClockSeconds ~/ 60).toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Board Size'),
          scrollable: true,
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
                        if (!chessClockOverridden) {
                          chessClockSeconds =
                              settings.chessClockSecondsForSize(size);
                          clockMinutesController.text =
                              (chessClockSeconds ~/ 60).toString();
                        }
                      }),
                      selectedColor:
                          GameColors.boardFrameInner.withValues(alpha: 0.2),
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
              // Chess clock toggle
              ChessClockSetup(
                enabled: chessClockEnabled,
                onEnabledChanged: (value) =>
                    setState(() => chessClockEnabled = value),
                minutesController: clockMinutesController,
                onMinutesChanged: (value) {
                  setState(() {});
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
              onPressed: chessClockEnabled &&
                      (int.tryParse(clockMinutesController.text) ?? 0) <= 0
                  ? null
                  : () {
                      // Save chess clock preference
                      ref
                          .read(appSettingsProvider.notifier)
                          .setChessClockEnabled(chessClockEnabled);
                      Navigator.pop(dialogContext);
                      _doStartNewGame(
                        context,
                        selectedSize,
                        mode,
                        difficulty,
                        chessClockEnabled && chessClockOverridden
                            ? chessClockSeconds
                            : null,
                        ref.read(gameSessionProvider).vsComputerPlayerColor,
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

  String _getBoardSizeDescription(int size) {
    final counts = PieceCounts.forBoardSize(size);
    return '${counts.flatStones} stones (flat or wall), ${counts.capstones} capstone${counts.capstones == 1 ? '' : 's'} per player';
  }

  void _doStartNewGame(
    BuildContext context,
    int size,
    GameMode mode,
    AIDifficulty difficulty,
    int? chessClockSecondsOverride,
    PlayerColor vsComputerPlayerColor, {
    bool courtMode = false,
  }) {
    ref.read(appSettingsProvider.notifier).setBoardSize(size);
    ref.read(scenarioStateProvider.notifier).clearScenario();
    ref.read(gameSessionProvider.notifier).state = GameSessionConfig(
      mode: mode,
      courtMode: courtMode,
      aiDifficulty: difficulty,
      chessClockSecondsOverride: chessClockSecondsOverride,
      vsComputerPlayerColor: vsComputerPlayerColor,
    );
    ref.read(gameStateProvider.notifier).newGame(size);
    ref.read(uiStateProvider.notifier).reset();
    ref.read(animationStateProvider.notifier).reset();
    ref.read(moveHistoryProvider.notifier).clear();
    ref.read(lastMoveProvider.notifier).state = null;

    // Always reset chess clock when starting a new game
    final settings = ref.read(appSettingsProvider);
    if (settings.chessClockEnabled && !courtMode) {
      // Initialize with new board size (resets times and stops any running timer)
      ref.read(chessClockProvider.notifier).initialize(
            size,
            secondsOverride: chessClockSecondsOverride,
          );
      // Clock will start when first move is made in _switchChessClock
    } else {
      // Stop any running clock when clock is disabled
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
        (gameState.turnNumber > 1 ||
            gameState.board.occupiedPositions.isNotEmpty);

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
    final scenarioState = ref.read(scenarioStateProvider);

    // Don't prompt for replace if: game is over, tutorial/puzzle is complete, or no game in progress
    final isScenarioComplete = scenarioState.isSuccessful(gameState);
    final isGameInProgress = !gameState.isGameOver &&
        !isScenarioComplete &&
        (gameState.turnNumber > 1 ||
            gameState.board.occupiedPositions.isNotEmpty);

    void startScenario() {
      ref.read(scenarioStateProvider.notifier).startScenario(scenario);
      ref.read(gameSessionProvider.notifier).state = GameSessionConfig(
        mode: GameMode.vsComputer,
        aiDifficulty: scenario.aiDifficulty,
        vsComputerPlayerColor: scenario.buildInitialState().currentPlayer,
        scenario: scenario,
      );
      ref
          .read(gameStateProvider.notifier)
          .loadState(scenario.buildInitialState());
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
    final achievements = ref.read(achievementProvider);
    final completedScenarioIds = <String>{
      ...achievements.completedTutorials,
      ...achievements.completedPuzzles,
    };
    final chapterGroups = buildScenarioChapterGroups();

    bool isScenarioUnlocked(GameScenario scenario) {
      // Progression model: each scenario can declare prerequisite IDs that must
      // be completed before the next lesson/puzzle is available. This lets us
      // gate advanced content while preserving legacy scenario IDs/progress.
      return scenario.prerequisiteScenarioIds
          .every((id) => completedScenarioIds.contains(id));
    }

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
                ListTile(
                  leading: const Icon(Icons.hexagon_outlined),
                  title: const Text('Hex tutorials & puzzles'),
                  subtitle: const Text(
                      'Learn three-player roads, spreads and capstone puzzles.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HexLearningScreen()));
                  },
                ),
                for (final group in chapterGroups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        group.chapter.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                  for (final scenario in group.scenarios)
                    _ScenarioListTile(
                      scenario: scenario,
                      completed: scenario.type == ScenarioType.tutorial
                          ? achievements.completedTutorials
                              .contains(scenario.id)
                          : achievements.completedPuzzles.contains(scenario.id),
                      locked: !isScenarioUnlocked(scenario),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        _startScenarioFlow(context, scenario);
                      },
                    ),
                ],
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
    AIDifficulty selectedDifficulty =
        ref.read(gameSessionProvider).aiDifficulty;
    bool chessClockEnabled = settings.chessClockEnabled;
    bool courtMode = false;
    PlayerColor selectedPlayerColor =
        ref.read(gameSessionProvider).vsComputerPlayerColor;
    int chessClockSeconds = settings.chessClockSecondsForSize(selectedSize);
    bool chessClockOverridden = false;
    final clockMinutesController = TextEditingController(
      text: (chessClockSeconds ~/ 60).toString(),
    );

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
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
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
                            chessClockSeconds =
                                settings.chessClockSecondsForSize(size);
                            clockMinutesController.text =
                                (chessClockSeconds ~/ 60).toString();
                          }
                        }),
                        selectedColor:
                            GameColors.boardFrameInner.withValues(alpha: 0.2),
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
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Court Mode'),
                  subtitle: const Text(
                      'Learn with hints, AI explanations and free takebacks. Untimed practice; no ratings or achievements.'),
                  value: courtMode,
                  onChanged: (value) => setState(() => courtMode = value),
                ),
                if (!courtMode)
                  ChessClockSetup(
                    enabled: chessClockEnabled,
                    onEnabledChanged: (value) =>
                        setState(() => chessClockEnabled = value),
                    minutesController: clockMinutesController,
                    onMinutesChanged: (value) {
                      setState(() {});
                      chessClockOverridden = true;
                      final minutes = int.tryParse(value);
                      if (minutes != null && minutes > 0) {
                        chessClockSeconds = minutes * 60;
                      }
                    },
                  ),
                const SizedBox(height: 20),

                // Color Section
                Builder(
                  builder: (context) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
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
                    Expanded(
                      child: _ColorOption(
                        title: 'White',
                        color: PlayerColor.white,
                        isSelected: selectedPlayerColor == PlayerColor.white,
                        onTap: () => setState(
                            () => selectedPlayerColor = PlayerColor.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ColorOption(
                        title: 'Black',
                        color: PlayerColor.black,
                        isSelected: selectedPlayerColor == PlayerColor.black,
                        onTap: () => setState(
                            () => selectedPlayerColor = PlayerColor.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Difficulty Section
                Builder(
                  builder: (context) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
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
                Consumer(
                  builder: (context, ref, _) {
                    final eloState = ref.watch(eloProvider);
                    return Column(
                      children: [
                        for (final diff in AIDifficulty.values)
                          _DifficultyOption(
                            title: diff.name[0].toUpperCase() +
                                diff.name.substring(1),
                            subtitle:
                                '${diff.description} · Rating ${eloState.aiRatingFor(diff)}',
                            isSelected: selectedDifficulty == diff,
                            dense: true,
                            onTap: () =>
                                setState(() => selectedDifficulty = diff),
                          ),
                      ],
                    );
                  },
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
              onPressed: !courtMode &&
                      chessClockEnabled &&
                      (int.tryParse(clockMinutesController.text) ?? 0) <= 0
                  ? null
                  : () {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setChessClockEnabled(chessClockEnabled);
                      Navigator.pop(dialogContext);
                      _doStartNewGame(
                        context,
                        selectedSize,
                        GameMode.vsComputer,
                        selectedDifficulty,
                        chessClockEnabled && chessClockOverridden
                            ? chessClockSeconds
                            : null,
                        selectedPlayerColor,
                        courtMode: courtMode,
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
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use granular selector to avoid rebuilding on every game state change
    // Only rebuild when "has game in progress" status actually changes
    final hasGameInProgress = ref.watch(gameSessionProvider
            .select((session) => session.mode != GameMode.online)) &&
        ref.watch(gameStateProvider.select(
          (s) =>
              !s.isGameOver &&
              (s.turnNumber > 1 || s.board.occupiedPositions.isNotEmpty),
        ));
    final playGames = ref.watch(playGamesServiceProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with settings and about
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
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
                    child: Text(
                      'About',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (playGames.player != null)
                    Consumer(
                      builder: (context, ref, _) {
                        final eloState = ref.watch(eloProvider);
                        return _PlayerChip(
                          displayName: playGames.player!.displayName,
                          iconImage: playGames.iconImage,
                          rating: eloState.localPlayerRating?.rating,
                        );
                      },
                    ),
                  // Right side icons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Leaderboard button
                      IconButton(
                        icon: Icon(
                          Icons.leaderboard,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Leaderboard',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LeaderboardScreen()),
                          );
                        },
                      ),
                      // Achievements button
                      IconButton(
                        icon: Icon(
                          Icons.emoji_events,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Achievements',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AchievementsScreen()),
                          );
                        },
                      ),
                      // Settings gear
                      IconButton(
                        icon: Icon(
                          Icons.settings,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Settings',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Center(
                    child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(children: [
                    _buildLogo(context),
                    const SizedBox(height: 8),
                    const Text('Connect opposite edges. Build your road.'),
                    const SizedBox(height: 24),
                    const SavedOnlineGames(),
                    if (hasGameInProgress) ...[
                      PlayModeCard(
                          title: 'Continue Game',
                          description: 'Resume your match from this session.',
                          icon: Icons.play_arrow,
                          featured: true,
                          onTap: () => _continueGame(context)),
                      const SizedBox(height: 12),
                    ],
                    PlayModeCard(
                        title: 'Tutorials & Puzzles',
                        description:
                            'New to Tak? Learn by playing, then solve challenges.',
                        icon: Icons.school_outlined,
                        featured: !hasGameInProgress,
                        onTap: () => _openScenarioSelector(context)),
                    const SizedBox(height: 12),
                    PlayModeCard(
                        title: 'Vs Computer',
                        description:
                            'One player · four AI difficulties · no connection needed.',
                        icon: Icons.smart_toy_outlined,
                        onTap: () => _startVsComputer(context)),
                    const SizedBox(height: 12),
                    PlayModeCard(
                        title: 'Local Game',
                        description: 'Two players sharing this device.',
                        icon: Icons.group_outlined,
                        onTap: () => _startNewGame(context, GameMode.local)),
                    const SizedBox(height: 12),
                    PlayModeCard(
                        title: 'Online Game',
                        description:
                            'Two players on separate devices · share a room code.',
                        icon: Icons.wifi,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const OnlineLobbyScreen()))),
                    ...[
                      const SizedBox(height: 12),
                      PlayModeCard(
                          title: 'Three-player Hex',
                          description:
                              'Experimental · any mix of three humans and AI.',
                          icon: Icons.hexagon_outlined,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HexSetupScreen()))),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                        'Offline matches resume in this session. Achievements and settings are saved on this device.',
                        textAlign: TextAlign.center),
                  ]),
                )),
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
        Semantics(
          label: 'Stones game logo showing stacked game pieces',
          image: true,
          child: SizedBox(
            height: 80,
            width: 120,
            child: CustomPaint(
              painter: _LogoPainter(),
            ),
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
    _drawFlatStone(canvas, centerX, baseY, 50, GameColors.darkPiece,
        GameColors.darkPieceBorder);
    _drawFlatStone(canvas, centerX, baseY - 12, 50, GameColors.lightPiece,
        GameColors.lightPieceBorder);
    _drawFlatStone(canvas, centerX, baseY - 24, 50, GameColors.darkPiece,
        GameColors.darkPieceBorder);

    // Draw a capstone on top
    _drawCapstone(canvas, centerX, baseY - 50, 16, GameColors.lightPiece,
        GameColors.lightPieceBorder);
  }

  void _drawFlatStone(Canvas canvas, double x, double y, double width,
      Color fill, Color border) {
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

  void _drawCapstone(Canvas canvas, double x, double y, double radius,
      Color fill, Color border) {
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
  final bool completed;
  final bool locked;
  final VoidCallback onTap;

  const _ScenarioListTile({
    required this.scenario,
    required this.completed,
    required this.locked,
    required this.onTap,
  });

  String _getScenarioLabel() {
    if (scenario.type == ScenarioType.tutorial) {
      return 'Tutorial';
    }
    final difficulty = scenario.puzzleDifficulty;
    if (difficulty == null) return 'Puzzle';
    return switch (difficulty) {
      PuzzleDifficulty.easy => 'Easy',
      PuzzleDifficulty.medium => 'Medium',
      PuzzleDifficulty.hard => 'Hard',
      PuzzleDifficulty.expert => 'Expert',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isPuzzle = scenario.type == ScenarioType.puzzle;
    final accent = locked
        ? Theme.of(context).colorScheme.outline
        : (isPuzzle ? Colors.deepPurple : GameColors.boardFrameInner);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: accent.withValues(alpha: isDark ? 0.55 : 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        onTap: locked ? null : onTap,
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.12),
          foregroundColor: accent,
          child: Icon(locked
              ? Icons.lock_outline
              : (isPuzzle ? Icons.extension : Icons.menu_book)),
        ),
        title: Text(
          scenario.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: locked
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : (isDark ? Colors.white : null),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            locked
                ? 'Complete: ${scenario.prerequisiteScenarioIds.map((id) => tutorialAndPuzzleLibrary.firstWhere((s) => s.id == id).title).join(', ')}'
                : scenario.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Chip(
              label: Text(locked ? 'Locked' : _getScenarioLabel()),
              backgroundColor: accent.withValues(alpha: 0.15),
              labelStyle: TextStyle(color: accent, fontWeight: FontWeight.w600),
            ),
            if (completed) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade600,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final String displayName;
  final String? iconImage;
  final int? rating;

  const _PlayerChip({
    required this.displayName,
    this.iconImage,
    this.rating,
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
        mainAxisSize: MainAxisSize.min,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (rating != null)
                Text(
                  'ELO: $rating',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color:
                        isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
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
    // Improved contrast: use shade600 instead of shade500 for WCAG AA compliance
    final textColor = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Colors.grey.shade600;
    final separatorColor =
        isDark ? Theme.of(context).colorScheme.outline : Colors.grey.shade500;

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
            // Use InkWell for better accessibility (focus support, larger touch target)
            InkWell(
              onTap: _openPrivacyPolicy,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Semantics(
                  label: 'Privacy policy',
                  link: true,
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
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool dense;

  const _DifficultyOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isSelected
        ? GameColors.boardFrameInner
        : isDark
            ? Colors.grey.shade600
            : Colors.grey.shade300;

    return Semantics(
        selected: isSelected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 8 : 12),
            margin: EdgeInsets.only(bottom: dense ? 2 : 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? GameColors.boardFrameInner
                      .withValues(alpha: isDark ? 0.2 : 0.1)
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: dense ? 13 : 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? GameColors.boardFrameInner
                              : isDark
                                  ? Colors.white
                                  : null,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? GameColors.boardFrameInner
                                    .withValues(alpha: 0.7)
                                : isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                          ),
                        ),
                    ],
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
        ));
  }
}

class _ColorOption extends StatelessWidget {
  final String title;
  final PlayerColor color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.title,
    required this.color,
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
    final chipColor = color == PlayerColor.white
        ? GameColors.lightPiece
        : GameColors.darkPiece;

    return Semantics(
        selected: isSelected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? GameColors.boardFrameInner
                      .withValues(alpha: isDark ? 0.2 : 0.1)
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
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
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
        ));
  }
}
