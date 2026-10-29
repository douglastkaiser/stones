import 'package:flutter/material.dart';
import 'match_config.dart';

/// Shared by quick-start dialogs and the full table editor.
class MatchBoardSizeField extends StatelessWidget {
  const MatchBoardSizeField(
      {super.key,
      required this.shape,
      required this.size,
      required this.onChanged});
  final BoardShape shape;
  final int size;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
      isExpanded: true,
      key: ValueKey('size-${shape.name}-$size'),
      initialValue: size,
      decoration: const InputDecoration(labelText: 'Board size'),
      items: MatchConfig.sizesFor(shape)
          .map((size) => DropdownMenuItem(
              value: size,
              child: Text(shape == BoardShape.square
                  ? '$size × $size'
                  : 'Radius $size · ${1 + 3 * size * (size + 1)} cells')))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      });
}

class MatchBotLevelField extends StatelessWidget {
  const MatchBotLevelField(
      {super.key,
      required this.level,
      required this.onChanged,
      this.label = 'Computer difficulty'});
  final BotLevel level;
  final ValueChanged<BotLevel> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<BotLevel>(
      isExpanded: true,
      key: ValueKey(level),
      initialValue: level,
      decoration: InputDecoration(labelText: label),
      items: BotLevel.values
          .map((level) => DropdownMenuItem(
              value: level,
              child: Text(switch (level) {
                BotLevel.easy => 'Easy',
                BotLevel.medium => 'Medium',
                BotLevel.hard => 'Hard',
                BotLevel.expert => 'Expert',
              })))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      });
}
