import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/services.dart';
import '../theme/theme.dart';
import '../version.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'game_screen.dart';

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
    AIDifficulty difficulty = AIDifficulty.easy,
  }) {
    final gameState = ref.read(gameStateProvider);
    final settings = ref.read(appSettingsProvider);
    final isGameInProgress = !gameState.isGameOver &&
        (gameState.turnNumber > 1 || gameState.board.occupiedPositions.isNotEmpty);

    void start() => _doStartNewGame(context, settings.boardSize, mode, difficulty);

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
                start();
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
      start();
    }
  }

  void _doStartNewGame(
    BuildContext context,
    int size,
    GameMode mode,
    AIDifficulty difficulty,
  ) {
    ref.read(gameSessionProvider.notifier).state =
        GameSessionConfig(mode: mode, aiDifficulty: difficulty);
    ref.read(gameStateProvider.notifier).newGame(size);
    ref.read(uiStateProvider.notifier).reset();
    ref.read(animationStateProvider.notifier).reset();
    ref.read(moveHistoryProvider.notifier).clear();
    ref.read(lastMoveProvider.notifier).state = null;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  void _startVsComputer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (dialogContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('Easy'),
              subtitle: const Text('Random moves with placement bias early on'),
              onTap: () {
                Navigator.pop(dialogContext);
                _startNewGame(context, GameMode.vsComputer, difficulty: AIDifficulty.easy);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Medium'),
              subtitle: const Text('Plays simple road-building and blocking heuristics'),
              onTap: () {
                Navigator.pop(dialogContext);
                _startNewGame(context, GameMode.vsComputer, difficulty: AIDifficulty.medium);
              },
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
                      Text(
                        'A game of roads and flats',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: GameColors.subtitleColor,
                            ),
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
                      const Text(
                        'You play as White when facing the computer',
                        style: TextStyle(color: GameColors.subtitleColor),
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
                color: GameColors.titleColor,
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

class _PlayerChip extends StatelessWidget {
  final String displayName;
  final String? iconImage;

  const _PlayerChip({
    required this.displayName,
    this.iconImage,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatar;
    if (iconImage != null) {
      try {
        avatar = MemoryImage(base64Decode(iconImage!));
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          AppVersion.displayVersion,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
