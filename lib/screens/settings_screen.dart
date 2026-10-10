import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/theme_gallery.dart';
import '../widgets/account_card.dart';
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
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _SectionHeader(title: 'Account'),
                  const SizedBox(height: 12),
                  const AccountCard(),
                  const SizedBox(height: 32),
                  // Sound Section
                  const _SectionHeader(title: 'Audio'),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: settings.isSoundMuted
                        ? Icons.volume_off
                        : Icons.volume_up,
                    title: 'Sound Effects',
                    subtitle: settings.isSoundMuted ? 'Muted' : 'Enabled',
                    trailing: Switch(
                      value: !settings.isSoundMuted,
                      onChanged: (value) async {
                        await ref
                            .read(appSettingsProvider.notifier)
                            .setSoundMuted(!value);
                        if (!context.mounted) return;
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
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setThemeMode(mode);
                    },
                  ),
                  const SizedBox(height: 32),

                  // Chess Clock Defaults Section
                  const _SectionHeader(title: 'Chess Clock Defaults'),
                  const SizedBox(height: 12),
                  const _ChessClockDefaultsSection(),
                  const SizedBox(height: 32),

                  // Cosmetics Section
                  const _SectionHeader(title: 'Cosmetics'),
                  const Text(
                      'Five coordinated board and piece sets. Preview every set, then earn your favorites.'),
                  const SizedBox(height: 12),
                  const ThemeGallery(),
                  const SizedBox(height: 32),

                  // Play Games Section
                  const _SectionHeader(title: 'Google Play Games'),
                  const SizedBox(height: 12),
                  _PlayGamesSection(
                    playGames: playGames,
                    onRestore: () async {
                      final restored = await ref
                          .read(playGamesServiceProvider.notifier)
                          .restoreCloudGame();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(restored
                                ? 'Cloud match restored. Return to the menu to continue.'
                                : ref
                                        .read(playGamesServiceProvider)
                                        .errorMessage ??
                                    'No compatible cloud save found.')));
                      }
                    },
                    onManualSignIn: () async {
                      await ref
                          .read(playGamesServiceProvider.notifier)
                          .manualSignIn();
                      // Check if there was an error
                      final updatedState = ref.read(playGamesServiceProvider);
                      if (updatedState.errorMessage != null &&
                          context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(updatedState.errorMessage!),
                            backgroundColor: Colors.red.shade700,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      } else if (updatedState.isSignedIn && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Successfully signed in as ${updatedState.player?.displayName ?? 'User'}'),
                            backgroundColor: Colors.green.shade700,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ))),
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
          color:
              isDark ? colorScheme.onSurfaceVariant : GameColors.subtitleColor,
        ),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? colorScheme.onSurfaceVariant : Colors.grey.shade600,
          ),
        ),
        trailing: Semantics(label: title, child: trailing),
      ),
    );
  }
}

class _PlayGamesSection extends StatelessWidget {
  final PlayGamesState playGames;
  final Future<void> Function() onManualSignIn;
  final Future<void> Function() onRestore;

  const _PlayGamesSection({
    required this.playGames,
    required this.onManualSignIn,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    ImageProvider? avatar;
    if (playGames.iconImage != null) {
      try {
        avatar = MemoryImage(base64Decode(playGames.iconImage!));
      } catch (_) {}
    }

    final isSignedIn = playGames.isSignedIn;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                    backgroundImage: avatar,
                    child: avatar == null
                        ? const Icon(Icons.videogame_asset)
                        : null),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(kIsWeb
                        ? 'Play Games is available on Android'
                        : !playGamesAvailable
                            ? 'Play Games is not enabled in this build'
                            : isSignedIn
                                ? playGames.player?.displayName ?? 'Connected'
                                : 'Optional Play Games connection'))
              ]),
              const SizedBox(height: 12),
              Text(playGamesAvailable
                  ? 'Play Games is separate from your Stones account. Cloud saves support untimed square matches. Restore a save explicitly; it never replaces a match during sign-in.'
                  : 'Use the Account section above to sign in with Google. Achievements and themes work locally without Play Games.'),
              if (playGames.errorMessage != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(playGames.errorMessage!,
                        style: TextStyle(color: colorScheme.error))),
              if (playGamesAvailable)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: isSignedIn
                        ? OutlinedButton(
                            onPressed: onRestore,
                            child: const Text('Restore cloud save'))
                        : FilledButton.icon(
                            onPressed:
                                playGames.isSigningIn ? null : onManualSignIn,
                            icon: playGames.isSigningIn
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.videogame_asset),
                            label: Text(playGames.isSigningIn
                                ? 'Connecting…'
                                : 'Connect Play Games'))),
            ])));
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
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: '$size×$size minutes',
                          suffixText: 'min',
                          errorText:
                              (int.tryParse(_controllers[size]!.text) ?? 0) <= 0
                                  ? 'Enter 1–999'
                                  : null,
                        ),
                        onChanged: (value) {
                          setState(() {});
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
                Expanded(
                    child: Text(
                  'Theme',
                  style: Theme.of(context).textTheme.titleMedium,
                )),
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

/// Individual theme option button with accessibility support
class _ThemeOption extends StatefulWidget {
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
  State<_ThemeOption> createState() => _ThemeOptionState();
}

class _ThemeOptionState extends State<_ThemeOption> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Semantics(
        label: '${widget.label} theme',
        selected: widget.isSelected,
        button: true,
        child: Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: InkWell(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isFocused
                      ? colorScheme.primary
                      : widget.isSelected
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.3),
                  width: _isFocused ? 3 : (widget.isSelected ? 2 : 1),
                ),
                // Focus ring glow effect
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Icon(
                    widget.icon,
                    color: widget.isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: widget.isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: widget.isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
