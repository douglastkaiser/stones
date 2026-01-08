import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cosmetics.dart';
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

          // Cosmetics Section
          const _SectionHeader(title: 'Cosmetics'),
          const SizedBox(height: 12),
          const _BoardThemeSelector(),
          const SizedBox(height: 16),
          const _PieceStyleSelector(),
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
          child: GestureDetector(
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
                      fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
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

/// Board theme selector widget
class _BoardThemeSelector extends ConsumerWidget {
  const _BoardThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cosmetics = ref.watch(cosmeticsProvider);
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.grid_view,
                  color: isDark ? colorScheme.onSurfaceVariant : GameColors.subtitleColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Board Theme',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final theme in BoardTheme.values)
                  _CosmeticOption(
                    name: BoardThemeData.forTheme(theme).name,
                    description: BoardThemeData.forTheme(theme).description,
                    isSelected: cosmetics.selectedBoardTheme == theme,
                    isUnlocked: ref.watch(isBoardThemeUnlockedProvider(theme)),
                    unlockRequirement: ref.watch(boardThemeUnlockRequirementProvider(theme)),
                    previewColor: BoardThemeData.forTheme(theme).cellBackground,
                    onTap: () {
                      if (ref.read(isBoardThemeUnlockedProvider(theme))) {
                        ref.read(cosmeticsProvider.notifier).setBoardTheme(theme);
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Piece style selector widget
class _PieceStyleSelector extends ConsumerWidget {
  const _PieceStyleSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cosmetics = ref.watch(cosmeticsProvider);
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  color: isDark ? colorScheme.onSurfaceVariant : GameColors.subtitleColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Piece Style',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final style in PieceStyle.values)
                  _CosmeticOption(
                    name: PieceStyleData.forStyle(style).name,
                    description: PieceStyleData.forStyle(style).description,
                    isSelected: cosmetics.selectedPieceStyle == style,
                    isUnlocked: ref.watch(isPieceStyleUnlockedProvider(style)),
                    unlockRequirement: ref.watch(pieceStyleUnlockRequirementProvider(style)),
                    previewColor: PieceStyleData.forStyle(style).lightPrimary,
                    onTap: () {
                      if (ref.read(isPieceStyleUnlockedProvider(style))) {
                        ref.read(cosmeticsProvider.notifier).setPieceStyle(style);
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic cosmetic option widget (for board themes and piece styles) with accessibility
class _CosmeticOption extends StatefulWidget {
  final String name;
  final String description;
  final bool isSelected;
  final bool isUnlocked;
  final String? unlockRequirement;
  final Color previewColor;
  final VoidCallback onTap;

  const _CosmeticOption({
    required this.name,
    required this.description,
    required this.isSelected,
    required this.isUnlocked,
    required this.unlockRequirement,
    required this.previewColor,
    required this.onTap,
  });

  @override
  State<_CosmeticOption> createState() => _CosmeticOptionState();
}

class _CosmeticOptionState extends State<_CosmeticOption> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: widget.isUnlocked ? widget.description : (widget.unlockRequirement ?? ''),
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        label: '${widget.name} style${widget.isUnlocked ? '' : ', locked'}${widget.isSelected ? ', selected' : ''}',
        selected: widget.isSelected,
        enabled: widget.isUnlocked,
        button: true,
        child: Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: GestureDetector(
            onTap: widget.isUnlocked ? widget.onTap : null,
            onLongPress: widget.isUnlocked
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(widget.unlockRequirement ?? 'Locked'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? colorScheme.primaryContainer
                    : widget.isUnlocked
                        ? (isDark ? colorScheme.surface : Colors.grey.shade100)
                        : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isFocused
                      ? colorScheme.primary
                      : widget.isSelected
                          ? colorScheme.primary
                          : widget.isUnlocked
                              ? colorScheme.outline.withValues(alpha: 0.3)
                              : Colors.grey.shade400,
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
                  // Color preview
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.isUnlocked ? widget.previewColor : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.isUnlocked ? widget.previewColor.withValues(alpha: 0.5) : Colors.grey,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: widget.isUnlocked
                        ? null
                        : const Icon(Icons.lock, size: 20, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                      color: widget.isUnlocked
                          ? (widget.isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface)
                          : Colors.grey.shade600,
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
