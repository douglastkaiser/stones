import 'package:flutter/material.dart';

import '../theme/theme.dart';

class ChessClockToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ChessClockToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? Theme.of(context).colorScheme.onSurfaceVariant : Colors.grey.shade700;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer,
              size: 20,
              color: value ? GameColors.boardFrameInner : inactiveColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Chess Clock',
              style: TextStyle(
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
                color: value ? GameColors.boardFrameInner : inactiveColor,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: GameColors.boardFrameInner.withValues(alpha: 0.5),
              activeThumbColor: GameColors.boardFrameInner,
            ),
          ],
        ),
      ),
    );
  }
}
