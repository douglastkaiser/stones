/// Isolated design review entry point. No Firebase, preferences or real rooms.
library;

import 'package:flutter/material.dart' hide Step;
import 'game/board_geometry.dart';
import 'game/board_view.dart';
import 'game/match_config.dart';
import 'game/match_rules.dart';
import 'game/match_state.dart';
import 'game/move_selection.dart';
import 'game/seat_appearance.dart';
import 'models/piece.dart';
import 'theme/tavern_theme.dart';

enum PreviewPage { home, setup, table, result }

void main() {
  final query = Uri.base.queryParameters;
  runApp(DesignPreviewApp(
    initialPage: PreviewPage.values.firstWhere(
        (page) => page.name == query['page'],
        orElse: () => PreviewPage.home),
    initialShape: query['shape'] == 'hex' ? BoardShape.hex : BoardShape.square,
    initialPlayers: query['players'] == '4' ? 4 : 2,
    initialBrightness:
        query['light'] == '1' ? Brightness.light : Brightness.dark,
  ));
}

class DesignPreviewApp extends StatefulWidget {
  const DesignPreviewApp(
      {super.key,
      this.initialPage = PreviewPage.home,
      this.initialShape = BoardShape.square,
      this.initialPlayers = 2,
      this.initialBrightness = Brightness.dark});
  final PreviewPage initialPage;
  final BoardShape initialShape;
  final int initialPlayers;
  final Brightness initialBrightness;
  @override
  State<DesignPreviewApp> createState() => _DesignPreviewAppState();
}

class _DesignPreviewAppState extends State<DesignPreviewApp> {
  late var _brightness = widget.initialBrightness;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Stones · The tavern preview',
        debugShowCheckedModeBanner: false,
        theme: TavernTheme.build(_brightness),
        home: _PreviewHome(
          initialPage: widget.initialPage,
          initialShape: widget.initialShape,
          initialPlayers: widget.initialPlayers,
          onTheme: () => setState(() => _brightness =
              _brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark),
        ),
      );
}

/// Composed visual study, deliberately not a saved/achievement-eligible game.
MatchState previewPosition(BoardShape shape, int players, {bool won = false}) {
  final config = MatchConfig.defaults(shape).copyWith(
      seats: SeatId.values.take(players).map(SeatConfig.new).toList());
  Cell cell(int x, int y) =>
      shape == BoardShape.square ? Cell(x + 2, y + 2) : Cell(x, y);
  final ids = config.ids;
  final board = <Cell, List<Stone>>{
    cell(0, 0): [
      for (var i = 0; i < 7; i++) Stone(ids[i % players], PieceType.flat),
      const Stone(SeatId.ivory, PieceType.flat),
    ],
    cell(-1, -1): [const Stone(SeatId.ivory, PieceType.capstone)],
    cell(1, 0): [const Stone(SeatId.charcoal, PieceType.flat)],
    cell(0, 1): [const Stone(SeatId.charcoal, PieceType.standing)],
    cell(-1, 1): [Stone(ids.last, PieceType.flat)],
    cell(1, -1): [const Stone(SeatId.ivory, PieceType.flat)],
  };
  if (won) {
    for (var x = -2; x <= 2; x++) {
      board[cell(x, 0)] = [const Stone(SeatId.ivory, PieceType.flat)];
    }
  }
  final reserves = {for (final id in ids) id: Reserve.initial(config)};
  for (final stone in board.values.expand((stack) => stack)) {
    reserves[stone.seat] = reserves[stone.seat]!.use(stone.type);
  }
  final position = MatchState(
      config: config, board: board, reserves: reserves, ply: players * 4);
  return won ? MatchRules.resolve(position, SeatId.ivory) : position;
}

class _PreviewHome extends StatefulWidget {
  const _PreviewHome(
      {required this.initialPage,
      required this.initialShape,
      required this.initialPlayers,
      required this.onTheme});
  final PreviewPage initialPage;
  final BoardShape initialShape;
  final int initialPlayers;
  final VoidCallback onTheme;
  @override
  State<_PreviewHome> createState() => _PreviewHomeState();
}

class _PreviewHomeState extends State<_PreviewHome> {
  late var _page = widget.initialPage;
  late var _shape = widget.initialShape;
  late var _players = widget.initialPlayers;
  late MatchState _game =
      previewPosition(_shape, _players, won: _page == PreviewPage.result);
  final _selection = MoveSelection();
  bool _advanced = false;
  bool _court = false;
  String _clock = 'No clock';
  final _controls = <SeatId, SeatControl>{};
  String get _shapeName => _shape == BoardShape.square ? 'Square' : 'Hex';

  void _open(PreviewPage page, {BoardShape? shape}) => setState(() {
        if (shape != null) {
          _shape = shape;
          _players = shape == BoardShape.square ? 2 : 3;
        }
        _selection.clear();
        _page = page;
        if (page == PreviewPage.table || page == PreviewPage.result) {
          _game = previewPosition(_shape, _players,
              won: page == PreviewPage.result);
        }
      });

  void _confirm() {
    final move = _selection.planned;
    if (move == null) return;
    final next = MatchRules.play(_game, move);
    if (next == null) return;
    setState(() {
      _game = next;
      _selection.clear();
      if (_game.finished) _page = PreviewPage.result;
    });
  }

  void _sampleList(String title, List<String> examples) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Example content for this design review.'),
                for (final example in examples)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(example)),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(body: TavernBackdrop(
        child: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 700;
          return SingleChildScrollView(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 40),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            children: [
                              Text('DESIGN PREVIEW · Your games are untouched',
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                              TextButton.icon(
                                  onPressed: widget.onTheme,
                                  icon: const Icon(Icons.contrast, size: 18),
                                  label: const Text('Light / dark')),
                            ])),
                    Row(children: [
                      TextButton(
                          onPressed: () => _open(PreviewPage.home),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.layers_outlined, size: 28),
                            const SizedBox(width: 10),
                            Text('STONES',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(letterSpacing: 4)),
                          ])),
                      const Spacer(),
                      if (!narrow)
                        TextButton(
                            onPressed: () => _sampleList('Learn the game', [
                                  'The opening exchange',
                                  'Build a road',
                                  'Control a stack',
                                  'Spread your stones',
                                  'Try a coached game'
                                ]),
                            child: const Text('Learn')),
                      IconButton(
                          tooltip: 'Preview collection',
                          onPressed: () =>
                              _sampleList('A collection of beautiful tables', [
                                'Classic Wood · Ready to play',
                                'Morocco · Your first learning reward',
                                'Slate, Marble & Kyoto · Mastery rewards'
                              ]),
                          icon: const Icon(Icons.auto_awesome_outlined)),
                      IconButton(
                          tooltip: 'Preview account',
                          onPressed: () =>
                              _sampleList('Your place at the table', [
                                'Play as a guest',
                                'Sign in with Google',
                                'Keep your games and earned collection together'
                              ]),
                          icon: const Icon(Icons.person_outline)),
                    ]),
                    const SizedBox(height: 28),
                    switch (_page) {
                      PreviewPage.home => _home(narrow),
                      PreviewPage.setup => _setup(),
                      PreviewPage.table => _table(narrow),
                      PreviewPage.result => _result(narrow),
                    },
                    const SizedBox(height: 32),
                    Center(
                        child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Text('A quiet table. A beautiful game.',
                                style: Theme.of(context).textTheme.bodySmall))),
                  ]),
            ),
          )));
        })),
      ));

  Widget _eyebrow(String text) => Text(text.toUpperCase(),
      style:
          Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 2));

  Widget _home(bool narrow) {
    final introduction =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _eyebrow('Make yourself at home'),
      const SizedBox(height: 12),
      Text('Pull up a chair.',
          style: narrow
              ? Theme.of(context).textTheme.displayMedium
              : Theme.of(context).textTheme.displayLarge),
      const SizedBox(height: 16),
      Text('A road to build. A friend to outwit.\nA little time well spent.',
          style:
              Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.6)),
      const SizedBox(height: 28),
      _boardChoice(BoardShape.square, 'Square',
          'The classic game of Tak. A lovely place to begin.',
          featured: true),
      const SizedBox(height: 12),
      _boardChoice(BoardShape.hex, 'Hex',
          'Take a different road. Explore the Stones variant.'),
      const SizedBox(height: 24),
      Wrap(spacing: 12, runSpacing: 12, children: [
        OutlinedButton.icon(
            onPressed: () => _sampleList('Join a friend', [
                  'Open an invitation link, or enter a room code.',
                  'The invitation brings you to your friend’s table.'
                ]),
            icon: const Icon(Icons.link),
            label: const Text('Join a friend')),
        TextButton.icon(
            onPressed: () => _sampleList('My games', [
                  'Your turn · Square with Rowan',
                  'Waiting · Hex with friends',
                  'Completed · A road well played'
                ]),
            icon: const Icon(Icons.bookmark_border),
            label: const Text('My games')),
      ]),
    ]);
    final scene = Column(children: [
      _boardScene(previewPosition(BoardShape.square, 2), hero: true),
      const SizedBox(height: 8),
      const Text('Classic Wood · Made for another game'),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (narrow)
        introduction
      else
        Row(children: [
          Expanded(child: introduction),
          const SizedBox(width: 44),
          Expanded(child: scene)
        ]),
      const SizedBox(height: 32),
      TavernPanel(
          padding: 20,
          child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 16,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('New to the table?',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  const Text('Learn a little, then try a friendly game.'),
                ]),
                OutlinedButton.icon(
                    onPressed: () => _sampleList('Your first road', [
                          'A short introduction',
                          'The same controls you will use in a game',
                          'Optional hints whenever you need them'
                        ]),
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Learn to play'))
              ])),
    ]);
  }

  Widget _boardChoice(BoardShape shape, String title, String description,
          {bool featured = false}) =>
      Material(
        color: featured
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
            onTap: () => _open(PreviewPage.setup, shape: shape),
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

  Widget _setup() => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _back('Back to the fireside'),
          const SizedBox(height: 12),
          _eyebrow('Set your table'),
          const SizedBox(height: 8),
          Text('A game of $_shapeName',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(_shape == BoardShape.square
              ? 'Classic Tak, or a table for more friends.'
              : 'Six directions. Shared goals. A Stones variant.'),
          const SizedBox(height: 24),
          TavernPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text('Who’s playing?',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                    'The same table for local friends, online friends or AI.'),
                const SizedBox(height: 20),
                for (final seat in SeatId.values.take(_players)) ...[
                  Row(children: [
                    _marker(seat),
                    const SizedBox(width: 12),
                    Expanded(
                        child: DropdownButtonFormField<SeatControl>(
                      key: ValueKey('preview-control-${seat.name}'),
                      initialValue: _controls[seat] ?? SeatControl.localHuman,
                      decoration: InputDecoration(labelText: seat.label),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: SeatControl.localHuman,
                            child: Text('On this device')),
                        DropdownMenuItem(
                            value: SeatControl.onlineHuman,
                            child: Text('Online friend')),
                        DropdownMenuItem(
                            value: SeatControl.ai, child: Text('Computer')),
                      ],
                      onChanged: (value) => setState(() {
                        if (value != null) _controls[seat] = value;
                      }),
                    )),
                    if (_players > 2 && seat.index == _players - 1)
                      IconButton(
                          tooltip: 'Remove ${seat.label}',
                          onPressed: () => setState(() => _players--),
                          icon: const Icon(Icons.remove_circle_outline)),
                  ]),
                  const SizedBox(height: 16),
                ],
                if (_players < 4)
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          onPressed: () => setState(() => _players++),
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Add a player'))),
                const SizedBox(height: 16),
                ExpansionTile(
                    key: const ValueKey('preview-advanced'),
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Table settings'),
                    subtitle:
                        const Text('Board size, clock and optional coaching'),
                    initiallyExpanded: _advanced,
                    onExpansionChanged: (value) =>
                        setState(() => _advanced = value),
                    children: [
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          initialValue: _clock,
                          decoration: const InputDecoration(
                              labelText: 'Time per player'),
                          items: [
                            'No clock',
                            '10 minutes',
                            '30 minutes',
                            '3 days'
                          ]
                              .map((value) => DropdownMenuItem(
                                  value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _clock = value ?? _clock)),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Court Mode'),
                          subtitle: const Text(
                              'Optional hints and takebacks for practice.'),
                          value: _court,
                          onChanged: (value) => setState(() => _court = value)),
                    ]),
                const SizedBox(height: 24),
                FilledButton.icon(
                    onPressed: () => _open(PreviewPage.table),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Try the table')),
                const SizedBox(height: 12),
                const Text('This preview opens a sample local position.',
                    textAlign: TextAlign.center),
              ])),
        ]),
      ));

  Widget _marker(SeatId seat) => Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SeatAppearance.marker(seat),
          border: Border.all(color: const Color(0xFF5C614F))),
      child: Text(seat.symbol,
          style: const TextStyle(
              color: Color(0xFF14271D),
              fontSize: 12,
              fontWeight: FontWeight.bold)));

  Widget _back(String label) => Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
          onPressed: () => _open(PreviewPage.home),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(label)));

  Widget _boardScene(MatchState game,
      {bool hero = false, bool interactive = false}) {
    final preview = interactive && _selection.planned != null
        ? MatchRules.apply(game, _selection.planned!)
        : null;
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
                  key: const ValueKey('preview-board'),
                  game: preview ?? game,
                  original: preview == null ? null : game,
                  selected: interactive
                      ? _selection.source ?? _selection.planned?.from
                      : null,
                  destinations:
                      interactive ? _selection.destinations(game) : const {},
                  road: game.result?.winner == null
                      ? const {}
                      : MatchRules.road(game, game.result!.winner!),
                  onCell: !interactive || game.finished
                      ? null
                      : (cell) {
                          var confirm = false;
                          setState(() => confirm = _selection.tap(_game, cell));
                          if (confirm) _confirm();
                        },
                  onSwipe: !interactive || game.finished
                      ? null
                      : (cell, direction) => setState(
                          () => _selection.swipe(_game, cell, direction)),
                ))));
  }

  Widget _table(bool narrow) {
    final controls = TavernPanel(
        padding: 20,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _eyebrow(_game.finished ? 'A road well played' : 'Make your move'),
          const SizedBox(height: 12),
          Text(_game.finished ? 'Ivory wins' : '${_game.current.label} to play',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Text(
                  _game.finished
                      ? 'The highlighted road joins opposite edges.'
                      : _selection.source != null
                          ? 'Carry ${_selection.carry}. Choose a destination, then confirm your move.'
                          : _selection.planned != null
                              ? 'Your stone is previewed. Tap again or confirm to place it.'
                              : 'Tap to preview a stone. Tap your stack to pick it up. Hold a stack to look inside.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.5))),
          if (!_game.finished)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final type in PieceType.values)
                ChoiceChip(
                    label: Text(switch (type) {
                      PieceType.flat => 'Flat',
                      PieceType.standing => 'Wall',
                      PieceType.capstone => 'Capstone'
                    }),
                    selected: _selection.type == type,
                    onSelected: (_) => setState(() {
                          _selection.clear();
                          _selection.type = type;
                        })),
            ]),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _selection.planned == null ? null : _confirm,
              child: const Text('Confirm move')),
          TextButton(
              onPressed: () => setState(_selection.clear),
              child: const Text('Cancel selection')),
          const Divider(height: 32),
          Text('Sample table · Take turns for all seats',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: () => _open(PreviewPage.result),
              child: const Text('Preview a finished game')),
        ]));
    final board =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 16, runSpacing: 12, children: [
        for (final id in _game.config.ids)
          Row(mainAxisSize: MainAxisSize.min, children: [
            _marker(id),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(id.label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                  '${_game.reserves[id]!.stones} stones · ${_game.reserves[id]!.caps} caps',
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
      ]),
      const SizedBox(height: 20),
      _boardScene(_game, interactive: true),
      const SizedBox(height: 16),
      Text(
          'Classic Wood · $_players players · ${_game.config.profile == RulesProfile.standardTak ? 'Standard Tak' : 'Stones variant'}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _back('Leave the sample table'),
      const SizedBox(height: 8),
      Text('An evening game', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      Text(
          '$_shapeName · ${_shape == BoardShape.square ? '5 × 5' : '19 cells'} · Sample position'),
      const SizedBox(height: 24),
      if (narrow) ...[board, const SizedBox(height: 24), controls] else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: board),
          const SizedBox(width: 32),
          Expanded(flex: 2, child: controls),
        ]),
    ]);
  }

  Widget _result(bool narrow) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(children: [
          _eyebrow('A road well played'),
          const SizedBox(height: 12),
          Text('Ivory connects the road.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          const Text('One continuous road. Two opposite edges.',
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
              width: narrow ? double.infinity : 460,
              child: _boardScene(previewPosition(_shape, _players, won: true))),
          const SizedBox(height: 28),
          TavernPanel(
              padding: 20,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('There’s always another road.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        onPressed: () => _open(PreviewPage.table),
                        icon: const Icon(Icons.replay),
                        label: const Text('Play again')),
                    const SizedBox(height: 8),
                    OutlinedButton(
                        onPressed: () => setState(() {
                              _game =
                                  previewPosition(_shape, _players, won: true);
                              _selection.clear();
                              _page = PreviewPage.table;
                            }),
                        child: const Text('See the winning road')),
                    TextButton(
                        onPressed: () => _open(PreviewPage.home),
                        child: const Text('Back to the fireside')),
                  ])),
        ]),
      ));
}
