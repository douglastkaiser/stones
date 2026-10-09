import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cosmetics.dart';
import '../providers/cosmetics_provider.dart';
import 'theme_gallery.dart';

void showPieceThemePreview(BuildContext context, PieceStyle style) {
  showDialog<void>(context: context, builder: (_) => _MatchThemePreview(style));
}

class MatchThemeBadge extends StatelessWidget {
  const MatchThemeBadge({super.key, required this.label, required this.style});
  final String label;
  final PieceStyle style;
  @override
  Widget build(BuildContext context) => ActionChip(
      avatar: const Icon(Icons.auto_awesome, size: 16),
      label: Text(
          '$label · ${BoardThemeData.forTheme(BoardTheme.values[style.index]).name}'),
      tooltip: 'Inspect pieces and how to unlock this theme',
      onPressed: () => showPieceThemePreview(context, style));
}

class _MatchThemePreview extends ConsumerWidget {
  const _MatchThemePreview(this.style);
  final PieceStyle style;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = BoardTheme.values[style.index];
    final unlocked = ref.watch(isBoardThemeUnlockedProvider(theme)) ||
        ref.watch(isPieceStyleUnlockedProvider(style));
    final requirements = [
      ref.watch(boardThemeUnlockRequirementProvider(theme)),
      ref.watch(pieceStyleUnlockRequirementProvider(style)),
    ].whereType<String>().join(' or ');
    return AlertDialog(
        title: Text(BoardThemeData.forTheme(theme).name),
        content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              SizedBox(
                  width: 320,
                  child: AspectRatio(
                      aspectRatio: 1.5, child: ThemeSample(theme: theme))),
              const SizedBox(height: 12),
              Text(unlocked
                  ? 'You own this set. Select it in Settings for your next match.'
                  : '$requirements. Earn either reward, then select this set in Settings.'),
              const SizedBox(height: 8),
              const Text(
                  'Players bring their own pieces. Online matches use the host’s board theme.'),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ]);
  }
}
