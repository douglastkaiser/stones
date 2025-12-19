import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/services.dart';
import '../theme/theme.dart';

/// Settings screen with sound toggle, chess clock toggle, and theme toggle
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
          _ThemeSelector(
            currentMode: settings.themeMode,
            onModeChanged: (mode) async {
              await ref.read(appSettingsProvider.notifier).setThemeMode(mode);
            },
          ),
          const SizedBox(height: 32),

          // Chess Clock Defaults Section
          const _SectionHeader(title: 'Chess Clock Defaults'),
          const SizedBox(height: 12),
          const _ChessClockDefaultsSection(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white : GameColors.titleColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDark ? colorScheme.onSurfaceVariant : GameColors.subtitleColor,
        ),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? colorScheme.onSurfaceVariant : Colors.grey.shade600,
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    ImageProvider? avatar;
    if (playGames.iconImage != null) {
      try {
        avatar = MemoryImage(base64Decode(playGames.iconImage!));
      } catch (_) {}
    }

    final isSignedIn = playGames.isSignedIn;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
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
          style: TextStyle(
            color: isDark ? colorScheme.onSurfaceVariant : Colors.grey.shade600,
          ),
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

class _ChessClockDefaultsSection extends ConsumerStatefulWidget {
  const _ChessClockDefaultsSection();

  @override
  ConsumerState<_ChessClockDefaultsSection> createState() =>
      _ChessClockDefaultsSectionState();
}

class _ChessClockDefaultsSectionState
    extends ConsumerState<_ChessClockDefaultsSection> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    for (int size = 3; size <= 8; size++) {
      final minutes = settings.chessClockSecondsForSize(size) ~/ 60;
      _controllers[size] = TextEditingController(text: minutes.toString());
      _focusNodes[size] = FocusNode();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    for (int size = 3; size <= 8; size++) {
      final controller = _controllers[size]!;
      final focusNode = _focusNodes[size]!;
      if (!focusNode.hasFocus) {
        final minutes = settings.chessClockSecondsForSize(size) ~/ 60;
        final text = minutes.toString();
        if (controller.text != text) {
          controller.text = text;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (int size = 3; size <= 8; size++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('$size×$size board'),
                    ),
                    SizedBox(
                      width: 88,
                      child: TextField(
                        controller: _controllers[size],
                        focusNode: _focusNodes[size],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          suffixText: 'min',
                        ),
                        onChanged: (value) {
                          final minutes = int.tryParse(value);
                          if (minutes == null || minutes <= 0) return;
                          ref
                              .read(appSettingsProvider.notifier)
                              .setChessClockDefault(size, minutes * 60);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Defaults apply when starting new games; you can still override per game.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? colorScheme.onSurfaceVariant
                        : Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Theme mode selector widget
class _ThemeSelector extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onModeChanged;

  const _ThemeSelector({
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForMode(currentMode),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ThemeOption(
                  icon: Icons.brightness_auto,
                  label: 'System',
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () => onModeChanged(ThemeMode.system),
                ),
                const SizedBox(width: 12),
                _ThemeOption(
                  icon: Icons.light_mode,
                  label: 'Light',
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () => onModeChanged(ThemeMode.light),
                ),
                const SizedBox(width: 12),
                _ThemeOption(
                  icon: Icons.dark_mode,
                  label: 'Dark',
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () => onModeChanged(ThemeMode.dark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }
}

/// Individual theme option button
class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
