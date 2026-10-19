import 'package:flutter/material.dart';
import '../game/board_view.dart';
import '../game/example_position.dart';
import '../game/match_config.dart';
import '../game/match_rules.dart';
import '../game/match_state.dart';

/// The same play/learn menu in production and visual review.
class GameMenu extends StatefulWidget {
  const GameMenu(
      {super.key,
      required this.onSquare,
      required this.onHex,
      required this.onJoin,
      required this.onMyGames,
      required this.onLearn,
      this.onOpenTables});
  final VoidCallback? onOpenTables;
  final VoidCallback onSquare;
  final VoidCallback onHex;
  final VoidCallback onJoin;
  final VoidCallback onMyGames;
  final VoidCallback onLearn;
  @override
  State<GameMenu> createState() => _GameMenuState();
}

class _GameMenuState extends State<GameMenu> {
  bool _showHomeRoad = true;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 700;
        final menu =
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Play Stones', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          const Text('Pick a board. Bring friends or take on the computer.'),
          const SizedBox(height: 20),
          _boardChoice(
              BoardShape.square, 'Square', 'Start here for classic Tak.',
              featured: true),
          const SizedBox(height: 10),
          _boardChoice(BoardShape.hex, 'Hex',
              'More directions. Same goal. A Stones variant.'),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 4, children: [
            OutlinedButton.icon(
                onPressed: widget.onJoin,
                icon: const Icon(Icons.link),
                label: const Text('Join a friend')),
            if (widget.onOpenTables != null)
              OutlinedButton.icon(
                  onPressed: widget.onOpenTables,
                  icon: const Icon(Icons.public),
                  label: const Text('Open tables')),
            TextButton.icon(
                onPressed: widget.onMyGames,
                icon: const Icon(Icons.bookmark_border),
                label: const Text('My games')),
          ]),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text('First game?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
              'Place stones, build stacks, connect a road. Learn by playing.'),
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                  onPressed: widget.onLearn,
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Learn to play'))),
        ]);
        final example = Column(children: [
          ConstrainedBox(
              constraints: BoxConstraints(maxWidth: narrow ? 260 : 480),
              child: _boardScene(
                  examplePosition(BoardShape.square, 2, won: _showHomeRoad),
                  hero: !narrow)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 4, children: [
            ChoiceChip(
                label: const Text('The road'),
                selected: _showHomeRoad,
                onSelected: (_) => setState(() => _showHomeRoad = true)),
            ChoiceChip(
                label: const Text('The stack'),
                selected: !_showHomeRoad,
                onSelected: (_) => setState(() => _showHomeRoad = false)),
          ]),
          const SizedBox(height: 8),
          Text(
              _showHomeRoad
                  ? 'Ivory connects opposite edges. That’s a win.'
                  : 'The top stone controls the stack. Move it to change the board.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('Example position',
              style: Theme.of(context).textTheme.bodySmall),
        ]);
        return narrow
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                menu,
                const SizedBox(height: 24),
                example,
              ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: menu),
                const SizedBox(width: 64),
                Expanded(flex: 6, child: example),
              ]);
      });

  Widget _boardChoice(BoardShape shape, String title, String description,
          {bool featured = false}) =>
      Material(
        color: featured
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
            onTap: shape == BoardShape.square ? widget.onSquare : widget.onHex,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Icon(
                      shape == BoardShape.square
                          ? Icons.grid_view
                          : Icons.hexagon_outlined,
                      color: featured
                          ? Theme.of(context).colorScheme.onPrimary
                          : null),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    color: featured
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : null)),
                        const SizedBox(height: 6),
                        Text(description,
                            style: TextStyle(
                                color: featured
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : null,
                                height: 1.4))
                      ])),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward,
                      color: featured
                          ? Theme.of(context).colorScheme.onPrimary
                          : null),
                ]))),
      );

  Widget _boardScene(MatchState game, {bool hero = false}) {
    return DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF735139),
                  Color(0xFF3A2B22),
                  Color(0xFF563C29)
                ]),
            border: Border.all(color: const Color(0xFFAD8750), width: 1.5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 32,
                  offset: Offset(0, 16))
            ]),
        child: Padding(
            padding: EdgeInsets.all(hero ? 24 : 12),
            child: AspectRatio(
                aspectRatio: 1,
                child: BoardView(
                    game: game,
                    road: game.result?.winner == null
                        ? const {}
                        : MatchRules.road(game, game.result!.winner!)))));
  }
}
