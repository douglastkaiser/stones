import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chess_clock_toggle.dart';

class ChessClockSetup extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final TextEditingController minutesController;
  final ValueChanged<String> onMinutesChanged;
  final String? helperText;

  const ChessClockSetup({
    super.key,
    required this.enabled,
    required this.onEnabledChanged,
    required this.minutesController,
    required this.onMinutesChanged,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChessClockToggle(
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Minutes per player',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Colors.grey.shade700,
                    ),
              ),
            ),
            SizedBox(
              width: 88,
              child: TextField(
                controller: minutesController,
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Min',
                  helperText: helperText,
                ),
                onChanged: onMinutesChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
