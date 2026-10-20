import 'package:flutter/material.dart';
import 'board_view.dart';
import 'completed_match.dart';
import 'match_rules.dart';
import 'result_explanation.dart';

/// No match controller or reward callbacks: review cannot change a live game.
class MatchReviewScreen extends StatefulWidget {
  const MatchReviewScreen({super.key, required this.match});
  final CompletedMatch match;
  @override
  State<MatchReviewScreen> createState() => _MatchReviewScreenState();
}

class _MatchReviewScreenState extends State<MatchReviewScreen> {
  late int _ply = widget.match.moves.length;
  @override
  Widget build(BuildContext context) {
    final position = widget.match.positions[_ply];
    final winner = position.result?.winner;
    return Scaffold(
        appBar: AppBar(title: const Text('Review game')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Read-only review · your current game is unchanged'),
          const SizedBox(height: 12),
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: AspectRatio(
                      aspectRatio: 1,
                      child: BoardView(
                          game: position,
                          road: winner == null
                              ? const {}
                              : MatchRules.road(position, winner))))),
          const SizedBox(height: 12),
          Text('Move $_ply of ${widget.match.moves.length}',
              textAlign: TextAlign.center),
          if (widget.match.moves.isNotEmpty)
            Slider(
                value: _ply.toDouble(),
                max: widget.match.moves.length.toDouble(),
                divisions: widget.match.moves.length,
                label: 'Move $_ply',
                onChanged: (value) => setState(() => _ply = value.round())),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                tooltip: 'First position',
                onPressed: _ply == 0 ? null : () => setState(() => _ply = 0),
                icon: const Icon(Icons.first_page)),
            IconButton(
                tooltip: 'Previous move',
                onPressed: _ply == 0 ? null : () => setState(() => _ply--),
                icon: const Icon(Icons.chevron_left)),
            IconButton(
                tooltip: 'Next move',
                onPressed: _ply == widget.match.moves.length
                    ? null
                    : () => setState(() => _ply++),
                icon: const Icon(Icons.chevron_right)),
            IconButton(
                tooltip: 'Final position',
                onPressed: _ply == widget.match.moves.length
                    ? null
                    : () => setState(() => _ply = widget.match.moves.length),
                icon: const Icon(Icons.last_page)),
          ]),
          if (position.finished)
            Text(explainResult(position), textAlign: TextAlign.center),
        ])));
  }
}
