/// Isolated design review entry point. No Firebase, preferences or real rooms.
library;

import 'package:flutter/material.dart';
import 'game/board_view.dart';
import 'game/match_config.dart';
import 'game/match_rules.dart';
import 'game/match_state.dart';
import 'game/move_selection.dart';
import 'game/stack_move_tray.dart';
import 'game/seat_appearance.dart';
import 'models/piece.dart';
import 'theme/tavern_theme.dart';
import 'game/example_position.dart';
import 'widgets/game_menu.dart';
import 'version.dart';

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
        title: 'Stones · Game design preview',
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

/// Compatibility entry point for the isolated visual review fixtures.
MatchState previewPosition(BoardShape shape, int players, {bool won = false}) =>
    examplePosition(shape, players, won: won);

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
  String get _finishLabel => _game.result?.winner == null
      ? 'A drawn game'
      : '${_game.result!.winner!.label} wins';

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
                              Text('DESIGN PREVIEW · Sample tables only',
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                              if (narrow)
                                IconButton(
                                    tooltip: 'Switch light and dark',
                                    onPressed: widget.onTheme,
                                    icon: const Icon(Icons.contrast, size: 18))
                              else
                                TextButton.icon(
                                    onPressed: widget.onTheme,
                                    icon: const Icon(Icons.contrast, size: 18),
                                    label: const Text('Light / dark')),
                            ])),
                    Row(children: [
                      Expanded(
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                  onPressed: () => _open(PreviewPage.home),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.layers_outlined,
                                            size: 28),
                                        const SizedBox(width: 10),
                                        Flexible(
                                            child: FittedBox(
                                                child: Text('STONES',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleLarge
                                                        ?.copyWith(
                                                            letterSpacing:
                                                                4)))),
                                      ])))),
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
                          onPressed: () => _sampleList('Piece sets', [
                                'Classic Wood · Ready to play',
                                'Morocco · Your first learning reward',
                                'Slate, Marble & Kyoto · Mastery rewards'
                              ]),
                          icon: const Icon(Icons.auto_awesome_outlined)),
                      IconButton(
                          tooltip: 'Preview account',
                          onPressed: () => _sampleList('Your account', [
                                'Play as a guest',
                                'Sign in with Google',
                                'Keep your games and earned collection together'
                              ]),
                          icon: const Icon(Icons.person_outline)),
                    ]),
                    SizedBox(height: _page == PreviewPage.table ? 12 : 28),
                    switch (_page) {
                      PreviewPage.home => _home(),
                      PreviewPage.setup => _setup(),
                      PreviewPage.table => _table(narrow),
                      PreviewPage.result => _result(narrow),
                    },
                    const SizedBox(height: 32),
                    Center(
                        child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Text(
                                'Stones · Design preview · ${AppVersion.commitHash}',
                                style: Theme.of(context).textTheme.bodySmall))),
                  ]),
            ),
          )));
        })),
      ));

  Widget _eyebrow(String text) => Text(text.toUpperCase(),
      style:
          Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 2));

  Widget _home() => GameMenu(
      onSquare: () => _open(PreviewPage.setup, shape: BoardShape.square),
      onHex: () => _open(PreviewPage.setup, shape: BoardShape.hex),
      onLearn: () => _sampleList('Learn to play', [
            'Connect opposite edges with your flat stones and capstones.',
            'Move stacks to take control. Standing stones block roads.',
            'Try the guided lessons, then play with Court Mode hints.'
          ]),
      onJoin: () => _sampleList('Join a friend', [
            'Open an invitation link, or enter a room code.',
            'Choose your seat and play.'
          ]),
      onMyGames: () => _sampleList('My games', [
            'Your turn · Square with Rowan',
            'Waiting · Hex with friends',
            'Completed · Ivory won by road'
          ]));

  Widget _setup() => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _back('Back to games'),
          const SizedBox(height: 12),
          _eyebrow('New game'),
          const SizedBox(height: 8),
          Text('A game of $_shapeName',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(_shape == BoardShape.square
              ? 'Classic Tak. Add extra players for a Stones variant.'
              : 'Connect opposite edges on a hex board. A Stones variant.'),
          const SizedBox(height: 24),
          TavernPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text('Who’s playing?',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                    'Mix players on this device, online friends and AI.'),
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
                    subtitle: const Text('Clock and optional coaching'),
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
          style: TextStyle(
              color: seat == SeatId.charcoal
                  ? const Color(0xFFFFF8E8)
                  : const Color(0xFF14271D),
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
    final preview = interactive ? _selection.preview(game) : null;
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
                  routeSource: interactive ? _selection.source : null,
                  routeDirection: interactive ? _selection.direction : null,
                  drops: interactive ? _selection.drops : const [],
                  carried: interactive ? _selection.hand(game) : const [],
                  handCell: interactive ? _selection.current : null,
                  onInspect: !interactive
                      ? null
                      : (cell) =>
                          setState(() => _selection.inspect(game, cell)),
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

  Widget _sampleStack() {
    final cell = _selection.inspected;
    if (cell == null) return const SizedBox.shrink();
    final source = _selection.source;
    final stones = (cell == source ? _game : _selection.preview(_game) ?? _game)
        .stackAt(cell);
    final isCarry = source == cell;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      StackMoveTray(
          label: 'Stack $cell',
          stones: stones,
          styles: const {},
          carry: isCarry ? _selection.carry : 0,
          dropped: isCarry ? _selection.dropped : 0,
          started: _selection.started,
          carryLimit: _game.geometry.carryLimit,
          onCarry: !isCarry || _selection.started
              ? null
              : (count) => setState(() => _selection.setCarry(count))),
      if (_selection.started)
        Wrap(spacing: 4, children: [
          if (_selection.remaining > 0)
            TextButton(
                onPressed: () =>
                    setState(() => _selection.dropRemaining(_game)),
                child: const Text('Drop remaining here')),
          TextButton(
              onPressed: () => setState(_selection.undoDrop),
              child: const Text('Undo last drop')),
        ]),
    ]);
  }

  Widget _table(bool narrow) {
    final controls = TavernPanel(
        padding: 20,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _eyebrow(_game.finished ? 'Game over' : 'Make your move'),
          const SizedBox(height: 12),
          Text(_game.finished ? _finishLabel : '${_game.current.label} to play',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Text(
                  _game.finished
                      ? 'The highlighted road joins opposite edges.'
                      : _selection.source != null
                          ? 'Carry ${_selection.remaining} · ${_selection.dropped} staged. Tap a neighbor to drop one bottom stone.'
                          : _selection.planned != null
                              ? 'Your stone is previewed. Tap again or confirm to place it.'
                              : 'Tap to preview a stone. Tap your stack to pick it up. Tap a stack to look inside.',
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
          _sampleStack(),
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
      if (narrow)
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              IconButton(
                  tooltip: 'Leave the sample table',
                  onPressed: () => _open(PreviewPage.home),
                  icon: const Icon(Icons.arrow_back)),
              Expanded(
                  child: Text('$_shapeName · Sample table',
                      style: Theme.of(context).textTheme.titleLarge)),
            ]))
      else ...[
        _back('Leave the sample table'),
        const SizedBox(height: 8),
        Text('$_shapeName game',
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
            '$_shapeName · ${_shape == BoardShape.square ? '5 × 5' : '19 cells'} · Sample position'),
        const SizedBox(height: 24),
      ],
      if (narrow) ...[
        board,
        const SizedBox(height: 16),
        _compactControls()
      ] else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: board),
          const SizedBox(width: 32),
          Expanded(flex: 2, child: controls),
        ]),
    ]);
  }

  Widget _compactControls() => TavernPanel(
      padding: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(
                  _game.finished
                      ? _finishLabel
                      : '${_game.current.label} to play',
                  style: Theme.of(context).textTheme.titleLarge)),
          IconButton(
              tooltip: 'How to move',
              onPressed: () => _sampleList('Game controls', [
                    'Tap an empty cell to preview a stone; tap again to place it.',
                    'Choose top stones, then tap neighbors to stage bottom stones. Confirm when the hand is empty.',
                    'Tap a stack to inspect the stones inside.'
                  ]),
              icon: const Icon(Icons.help_outline)),
        ]),
        if (!_game.finished)
          Wrap(spacing: 8, runSpacing: 4, children: [
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
        const SizedBox(height: 8),
        _sampleStack(),
        Row(children: [
          Expanded(
              child: FilledButton(
                  onPressed: _selection.planned == null ? null : _confirm,
                  child: const Text('Confirm move'))),
          const SizedBox(width: 8),
          TextButton(
              onPressed: () => setState(_selection.clear),
              child: const Text('Cancel')),
        ]),
        const SizedBox(height: 8),
        Text(
            _selection.source != null
                ? 'Carry ${_selection.remaining} · ${_selection.dropped} staged. Drop all stones, then confirm.'
                : 'Tap to preview. Tap a stack to look inside.',
            style: Theme.of(context).textTheme.bodySmall),
        TextButton(
            onPressed: () => _open(PreviewPage.result),
            child: const Text('Preview a finished game')),
      ]));

  Widget _result(bool narrow) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(children: [
          _eyebrow('Game over'),
          const SizedBox(height: 12),
          Text(
              _game.result?.reason == ResultReason.road &&
                      _game.result?.winner != null
                  ? '${_game.result!.winner!.label} connects the road.'
                  : _finishLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(
              _game.result?.reason == ResultReason.road
                  ? 'One continuous road. Two opposite edges.'
                  : 'The final position determines the result.',
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
              width: narrow ? double.infinity : 460, child: _boardScene(_game)),
          const SizedBox(height: 28),
          TavernPanel(
              padding: 20,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Play again?',
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
                              _selection.clear();
                              _page = PreviewPage.table;
                            }),
                        child: const Text('See the winning road')),
                    TextButton(
                        onPressed: () => _open(PreviewPage.home),
                        child: const Text('Back to games')),
                  ])),
        ]),
      ));
}
