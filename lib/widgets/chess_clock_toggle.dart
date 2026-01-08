import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Chess clock toggle with accessibility support
class ChessClockToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ChessClockToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<ChessClockToggle> createState() => _ChessClockToggleState();
}

class _ChessClockToggleState extends State<ChessClockToggle> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final inactiveColor =
        isDark ? colorScheme.onSurfaceVariant : Colors.grey.shade700;

    return Semantics(
      label: 'Chess clock ${widget.value ? 'enabled' : 'disabled'}',
      toggled: widget.value,
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: InkWell(
          onTap: () => widget.onChanged(!widget.value),
          borderRadius: BorderRadius.circular(8),
          focusColor: colorScheme.primary.withValues(alpha: 0.12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: _isFocused
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer,
                  size: 20,
                  color: widget.value ? GameColors.boardFrameInner : inactiveColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Chess Clock',
                  style: TextStyle(
                    fontWeight: widget.value ? FontWeight.bold : FontWeight.normal,
                    color: widget.value ? GameColors.boardFrameInner : inactiveColor,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: widget.value,
                  onChanged: widget.onChanged,
                  activeTrackColor: GameColors.boardFrameInner.withValues(alpha: 0.5),
                  activeThumbColor: GameColors.boardFrameInner,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
