import 'package:flutter/material.dart';

/// Starts with an idea; revealing a concrete move is always a separate action.
class PuzzleHints extends StatelessWidget {
  const PuzzleHints({super.key, required this.hints});
  final List<String> hints;
  @override
  Widget build(BuildContext context) => TextButton.icon(
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('Hints'),
        onPressed: () {
          var revealed = 1;
          showDialog<void>(
              context: context,
              builder: (context) => StatefulBuilder(
                    builder: (context, update) => AlertDialog(
                      title: const Text('Puzzle hints'),
                      content: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            for (var i = 0; i < revealed; i++)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(hints[i]))
                          ])),
                      actions: [
                        if (revealed < hints.length)
                          TextButton(
                              onPressed: () => update(() => revealed++),
                              child: const Text('Reveal next hint')),
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close')),
                      ],
                    ),
                  ));
        },
      );
}
