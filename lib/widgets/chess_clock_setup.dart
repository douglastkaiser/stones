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
    return LayoutBuilder(builder: (context, constraints) {
      final toggle = ChessClockToggle(
        value: enabled,
        onChanged: onEnabledChanged,
      );
      final field = TextField(
        controller: minutesController,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Minutes per player',
          errorText: enabled && (int.tryParse(minutesController.text) ?? 0) <= 0
              ? 'Enter 1–999'
              : null,
          helperText: helperText,
        ),
        onChanged: onMinutesChanged,
      );
      if (constraints.maxWidth < 360) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          toggle,
          const SizedBox(height: 12),
          field,
        ]);
      }
      return Row(children: [
        Expanded(child: toggle),
        const SizedBox(width: 12),
        SizedBox(width: 160, child: field)
      ]);
    });
  }
}
