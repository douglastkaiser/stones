import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../services/services.dart';
import '../theme/theme.dart';
import '../version.dart';
import '../game/match_config.dart';
import '../game/match_provider.dart';
import '../game/match_screen.dart';
import '../game/match_setup_screen.dart';
import '../game/learning_hub.dart';
import '../widgets/play_mode_card.dart';
import '../widgets/saved_online_games.dart';
import 'achievements_screen.dart';
import 'leaderboard_screen.dart';
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
  bool _resuming = false;

  void _openSetup(BoardShape shape) => Navigator.push<void>(context,
      MaterialPageRoute(builder: (context) => MatchSetupScreen(shape: shape)));

  Future<void> _resumeMatch() async {
    if (_resuming) return;
    setState(() => _resuming = true);
    try {
      final controller = ref.read(matchProvider.notifier);
      final session = ref.read(matchProvider);
      if (session.game == null || session.room != null) {
        if (!await controller.resumeLocal()) return;
      }
      controller.pause(false);
      if (!mounted) return;
      await Navigator.push<void>(context,
          MaterialPageRoute(builder: (context) => const MatchScreen()));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not resume: $error')));
      }
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

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

    // Prepare optional Play Games; interactive sign-in belongs in Settings.
    await ref.read(playGamesServiceProvider.notifier).initialize();

    // Initialize ELO rating system
    await ref.read(eloProvider.notifier).initialize(syncOnline: false);
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
                          title: 'Continue previous game',
                          description: 'Resume your match from this session.',
                          icon: Icons.play_arrow,
                          featured: true,
                          onTap: () => _continueGame(context)),
                      const SizedBox(height: 12),
                    ],
                    if (ref.watch(savedLocalMatchProvider).valueOrNull !=
                            null ||
                        ref.watch(matchProvider.select(
                            (s) => s.game != null && s.room == null))) ...[
                      PlayModeCard(
                          title: 'Continue saved game',
                          description:
                              'Pick up your local match with its board and seats intact.',
                          icon: Icons.play_arrow,
                          featured: true,
                          onTap: _resuming ? () {} : _resumeMatch),
                      const SizedBox(height: 12),
                    ],
                    PlayModeCard(
                        title: 'Square',
                        description:
                            'Classic Tak or a two-to-four-player variant. Choose local humans, online humans or AI for each seat.',
                        icon: Icons.grid_view,
                        featured: true,
                        onTap: () => _openSetup(BoardShape.square)),
                    const SizedBox(height: 12),
                    PlayModeCard(
                        title: 'Hex',
                        description:
                            'Six directions, shared road goals and two to four players. The same controls and seat choices.',
                        icon: Icons.hexagon_outlined,
                        onTap: () => _openSetup(BoardShape.hex)),
                    const SizedBox(height: 20),
                    PlayModeCard(
                        title: 'Tutorials & Puzzles',
                        description:
                            'Learn either board, then solve progressive tactical studies.',
                        icon: Icons.school_outlined,
                        onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LearningHub()))),
                    const SizedBox(height: 16),
                    const Text(
                        'Local matches, achievements and settings are saved on this device. Online rooms remain available through their invitations.',
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
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'STONES',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : GameColors.titleColor,
                    letterSpacing: 8,
                  ),
            )),
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
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
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
