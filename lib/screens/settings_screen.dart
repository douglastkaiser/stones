import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../theme/theme.dart';

/// Settings screen with board size picker, sound toggle, and theme toggle
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final playGames = ref.watch(playGamesServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: GameColors.boardFrameInner,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Board Size Section
          const _SectionHeader(title: 'Board Size'),
          const SizedBox(height: 12),
          _BoardSizePicker(
            selectedSize: settings.boardSize,
            onSizeChanged: (size) async {
              await ref.read(appSettingsProvider.notifier).setBoardSize(size);
            },
          ),
          const SizedBox(height: 32),

          // Sound Section
          const _SectionHeader(title: 'Audio'),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: settings.isSoundMuted ? Icons.volume_off : Icons.volume_up,
            title: 'Sound Effects',
            subtitle: settings.isSoundMuted ? 'Muted' : 'Enabled',
            trailing: Switch(
              value: !settings.isSoundMuted,
              onChanged: (value) async {
                await ref.read(appSettingsProvider.notifier).setSoundMuted(!value);
                final soundManager = ref.read(soundManagerProvider);
                await soundManager.setMuted(!value);
                ref.read(isMutedProvider.notifier).state = !value;
              },
              activeTrackColor: GameColors.boardFrameInner,
            ),
          ),
          const SizedBox(height: 32),

          // Theme Section
          const _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: settings.isDarkTheme ? Icons.dark_mode : Icons.light_mode,
            title: 'Dark Theme',
            subtitle: settings.isDarkTheme ? 'Enabled' : 'Disabled',
            trailing: Switch(
              value: settings.isDarkTheme,
              onChanged: (value) async {
                await ref.read(appSettingsProvider.notifier).setDarkTheme(value);
              },
              activeTrackColor: GameColors.boardFrameInner,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Dark theme support coming soon',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Play Games Section
          const _SectionHeader(title: 'Google Play Games'),
          const SizedBox(height: 12),
          _PlayGamesSection(
            playGames: playGames,
            onManualSignIn: () =>
                ref.read(playGamesServiceProvider.notifier).manualSignIn(),
          ),
        ],
      ),
    );
  }
}

/// Section header widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: GameColors.titleColor,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

/// Generic settings tile widget
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: GameColors.subtitleColor),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: trailing,
      ),
    );
  }
}

class _PlayGamesSection extends StatelessWidget {
  final PlayGamesState playGames;
  final VoidCallback onManualSignIn;

  const _PlayGamesSection({
    required this.playGames,
    required this.onManualSignIn,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatar;
    if (playGames.iconImage != null) {
      try {
        avatar = MemoryImage(base64Decode(playGames.iconImage!));
      } catch (_) {}
    }

    final isSignedIn = playGames.isSignedIn;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: avatar,
          child: avatar == null
              ? const Icon(Icons.videogame_asset, color: Colors.white)
              : null,
        ),
        title: Text(
          isSignedIn ? playGames.player?.displayName ?? 'Signed in' : 'Not signed in',
        ),
        subtitle: Text(
          isSignedIn
              ? 'Achievements, leaderboards, and cloud saves are enabled.'
              : 'Sign in to enable achievements, leaderboards, and cloud saves.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: isSignedIn
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton.icon(
                onPressed: playGames.isSigningIn ? null : onManualSignIn,
                icon: playGames.isSigningIn
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(playGames.isSigningIn ? 'Signing in' : 'Sign in'),
              ),
      ),
    );
  }
}

/// Board size picker widget
class _BoardSizePicker extends StatelessWidget {
  final int selectedSize;
  final ValueChanged<int> onSizeChanged;

  const _BoardSizePicker({
    required this.selectedSize,
    required this.onSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (int size = 3; size <= 8; size++)
          _BoardSizeOption(
            size: size,
            isSelected: size == selectedSize,
            onTap: () => onSizeChanged(size),
          ),
      ],
    );
  }
}

/// Individual board size option
class _BoardSizeOption extends StatelessWidget {
  final int size;
  final bool isSelected;
  final VoidCallback onTap;

  const _BoardSizeOption({
    required this.size,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final counts = PieceCounts.forBoardSize(size);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? GameColors.boardFrameInner : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? GameColors.boardFrameOuter : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: GameColors.boardFrameInner.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Text(
              '${size}x$size',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : GameColors.titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${counts.flatStones}F ${counts.capstones}C',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white70 : GameColors.subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
