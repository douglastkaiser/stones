import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../providers/account_provider.dart';
import '../services/services.dart';
import '../theme/tavern_theme.dart';
import '../version.dart';
import '../game/match_config.dart';
import '../game/match_setup_screen.dart';
import '../game/learning_hub.dart';
import '../widgets/game_menu.dart';
import '../game/join_room_screen.dart';
import 'saved_games_screen.dart';
import 'achievements_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';

/// Main menu screen with title, play button, settings, and about links
class MainMenuScreen extends ConsumerStatefulWidget {
  const MainMenuScreen({super.key});

  @override
  ConsumerState<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends ConsumerState<MainMenuScreen> {
  void _openSetup(BoardShape shape) => Navigator.push<void>(context,
      MaterialPageRoute(builder: (context) => MatchSetupScreen(shape: shape)));

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    ref.read(eloProvider);
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
    await ref.read(eloProvider.notifier).initialize();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider).identity;
    final rating = ref.watch(eloProvider);
    void open(Widget screen) => Navigator.push<void>(context,
        MaterialPageRoute(builder: (_) => screen));
    return Scaffold(body: TavernBackdrop(child: SafeArea(
      child: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('STONES', maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 3))),
              IconButton(tooltip: 'Leaderboard', icon: const Icon(Icons.leaderboard_outlined),
                  onPressed: () => open(const LeaderboardScreen())),
              IconButton(tooltip: 'Achievements & piece sets', icon: const Icon(Icons.emoji_events_outlined),
                  onPressed: () => open(const AchievementsScreen())),
              IconButton(tooltip: 'Settings & account', icon: const Icon(Icons.settings_outlined),
                  onPressed: () => open(const SettingsScreen())),
            ]),
            if (account != null && !account.guest) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: _PlayerChip(
                displayName: account.name ?? 'Player',
                ratingLabel: '${rating.selectedPool.shape.name} ${rating.selectedPool.size} · ${rating.personalLabel}${rating.rank == null ? "" : " · #${rating.rank}"}')),
            ],
            const SizedBox(height: 28),
            GameMenu(
              onSquare: () => _openSetup(BoardShape.square),
              onHex: () => _openSetup(BoardShape.hex),
              onLearn: () => open(const LearningHub()),
              onJoin: () => open(const JoinRoomScreen()),
              onMyGames: () => open(const SavedGamesScreen())),
            const SizedBox(height: 24),
            Center(child: TextButton(onPressed: () => open(const AboutScreen()),
                child: const Text('About Stones'))),
            const _VersionFooter(),
          ])))))));
  }
}

class _PlayerChip extends StatelessWidget {
  final String displayName;
  final String? ratingLabel;

  const _PlayerChip({
    required this.displayName,
    this.ratingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

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
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (ratingLabel != null)
                Text(
                  ratingLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color:
                        isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                  ),
                ),
            ],
          )),
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
        : Uri.parse('https://www.douglastkaiser.com/stones/privacy');
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
