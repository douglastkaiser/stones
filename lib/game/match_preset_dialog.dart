import 'package:flutter/material.dart';
import 'match_config.dart';
import 'match_preset.dart';
import 'match_setup_fields.dart';

class MatchPresetDialog extends StatefulWidget {
  const MatchPresetDialog(
      {super.key, required this.preset, required this.shape});
  final MatchPreset preset;
  final BoardShape shape;

  @override
  State<MatchPresetDialog> createState() => _MatchPresetDialogState();
}

class _MatchPresetDialogState extends State<MatchPresetDialog> {
  late final _defaults = widget.preset.configuration(widget.shape);
  late int _size = _defaults.size;
  late int _players = _defaults.seats.length;
  BotLevel _level = BotLevel.easy;

  @override
  Widget build(BuildContext context) {
    final againstComputer = widget.preset == MatchPreset.learn ||
        widget.preset == MatchPreset.computer;
    return AlertDialog(
        title: Text(widget.preset.label),
        scrollable: true,
        content: SizedBox(
            width: 360,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.preset.description),
                  const SizedBox(height: 20),
                  MatchBoardSizeField(
                      shape: widget.shape,
                      size: _size,
                      onChanged: (size) => setState(() => _size = size)),
                  const SizedBox(height: 16),
                  if (againstComputer)
                    MatchBotLevelField(
                        level: _level,
                        onChanged: (level) => setState(() => _level = level))
                  else
                    DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _players,
                        decoration: const InputDecoration(labelText: 'Players'),
                        items: [
                          for (final count in [2, 3, 4])
                            DropdownMenuItem(
                                value: count, child: Text('$count players')),
                        ],
                        onChanged: (count) {
                          if (count != null) {
                            setState(() => _players = count);
                          }
                        }),
                ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  context,
                  widget.preset.configuration(widget.shape,
                      size: _size, playerCount: _players, level: _level)),
              child: Text(_defaults.online ? 'Create room' : 'Start game')),
        ]);
  }
}
