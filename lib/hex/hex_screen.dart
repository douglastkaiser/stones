import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/piece.dart' show PieceType;
import '../models/cosmetics.dart';
import '../providers/cosmetics_provider.dart';
import '../widgets/match_theme_badge.dart';
import 'hex_game.dart';
import 'hex_move_selection.dart';
import 'hex_board.dart';
import 'hex_learning_screen.dart';
export 'hex_board.dart';
import 'hex_match_provider.dart';
import 'hex_room.dart';

const hexRulesText =
    '''Every color can connect any pair of opposite sides: A to A, B to B, or C to C. Use a continuous road of your exposed flats and capstones. Walls and buried pieces do not connect. Corner cells touch both incident sides; neighboring sides alone are not a win. Cells connect along six shared edges.

Turns cycle Ivory → Charcoal → Copper, starting with the chosen seat. On each of the first three turns, place a flat of the next color. Then place your own piece on an empty cell, or move a stack you control.

Carry up to the board's widest row (5, 7 or 9 pieces). Keep their order, travel straight in one of six directions, and drop at least one piece on every cell. Stacks can be taller than the carry limit. Walls and caps block covering; only a lone capstone at the last step can flatten a wall of any color.

Inspect: hover to fan a stack. Hold or right-click to open its full top-to-bottom list, including buried colors. Close it to return to play.

Check roads after the entire move. If multiple colors gain roads, the mover wins if included. One opponent road wins for that opponent; two opponent roads draw.

Without a road, a full board or any exhausted total reserve ends the match. Most exposed flats wins; a tie for most is a draw. Walls, caps and buried pieces do not score.

This is an experimental variant. Rotate the starting seat between matches. Three independent players can cooperate or compete; there are no teams or elimination. Clocks, ratings, achievements and square-game tutorials do not apply here.''';

void _showRules(BuildContext context, {bool legacy = false}) {
  showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('Three-player hex rules'),
            content: SingleChildScrollView(
                child: Text(legacy
                    ? 'This room uses legacy goals: Ivory lower left to upper right; Charcoal top to bottom; Copper lower right to upper left. Only your assigned pair wins.\n\n${hexRulesText.substring(hexRulesText.indexOf('Turns cycle'))}'
                    : hexRulesText)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ],
          ));
}

class HexSetupScreen extends ConsumerStatefulWidget {
  const HexSetupScreen({super.key, this.initialMode = HexSetupMode.local});
  final HexSetupMode initialMode;
  @override
  ConsumerState<HexSetupScreen> createState() => _HexSetupScreenState();
}

enum HexSetupMode { computer, local, online }

class _HexSetupScreenState extends ConsumerState<HexSetupScreen> {
  int _radius = 2;
  HexSeat _starter = HexSeat.ivory;
  final _kinds = [
    HexSeatKind.localHuman,
    HexSeatKind.localHuman,
    HexSeatKind.localHuman
  ];
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialMode == HexSetupMode.computer) {
      _kinds[1] = HexSeatKind.ai;
      _kinds[2] = HexSeatKind.ai;
    } else if (widget.initialMode == HexSetupMode.online) {
      _kinds[1] = HexSeatKind.remoteHuman;
      _kinds[2] = HexSeatKind.remoteHuman;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start({bool join = false}) async {
    final controller = ref.read(hexMatchProvider.notifier);
    if (join) {
      await controller.join(_code.text);
    } else if (_kinds.contains(HexSeatKind.remoteHuman)) {
      await controller.create(_radius, _kinds, _starter);
    } else {
      controller.startLocal(_radius, _kinds, _starter);
    }
    if (!mounted || ref.read(hexMatchProvider).game == null) return;
    await Navigator.push<void>(
        context, MaterialPageRoute(builder: (_) => const HexGameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(hexMatchProvider);
    return Scaffold(
      appBar: AppBar(
          title: Text('Hex · ${switch (widget.initialMode) {
            HexSetupMode.computer => 'Vs Computer',
            HexSetupMode.local => 'Local Game',
            HexSetupMode.online => 'Online Game',
          }}'),
          actions: [
            IconButton(
                onPressed: () => _showRules(context),
                icon: const Icon(Icons.help_outline),
                tooltip: 'Hex rules'),
          ]),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text('Three colors. Three roads.',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Experimental hex variant. Every color can connect any pair of opposite sides. Choose any mix of human and AI seats. Matches do not award square-game achievements or ratings.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: () => Navigator.push<void>(context,
                  MaterialPageRoute(builder: (_) => const HexLearningScreen())),
              icon: const Icon(Icons.school_outlined),
              label: const Text('Hex tutorials & puzzles')),
          const SizedBox(height: 24),
          const Text('Board size'),
          Wrap(spacing: 8, children: [
            for (var radius = 2; radius <= 4; radius++)
              ChoiceChip(
                  label: Text('${3 * radius * (radius + 1) + 1} cells'),
                  selected: _radius == radius,
                  onSelected: match.busy
                      ? null
                      : (_) => setState(() => _radius = radius)),
          ]),
          const SizedBox(height: 16),
          for (final seat in HexSeat.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DropdownButtonFormField<HexSeatKind>(
                isExpanded: true,
                initialValue: _kinds[seat.index],
                decoration: InputDecoration(
                    labelText: seat.label, border: const OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: HexSeatKind.localHuman,
                      child: Text('Human on this device')),
                  DropdownMenuItem(
                      value: HexSeatKind.remoteHuman,
                      child: Text('Human joining online')),
                  DropdownMenuItem(value: HexSeatKind.ai, child: Text('AI')),
                ],
                onChanged: match.busy
                    ? null
                    : (kind) => setState(() => _kinds[seat.index] = kind!),
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<HexSeat>(
            isExpanded: true,
            initialValue: _starter,
            decoration: const InputDecoration(
                labelText: 'Starting seat', border: OutlineInputBorder()),
            items: HexSeat.values
                .map((seat) =>
                    DropdownMenuItem(value: seat, child: Text(seat.label)))
                .toList(),
            onChanged:
                match.busy ? null : (seat) => setState(() => _starter = seat!),
          ),
          const SizedBox(height: 16),
          if (_kinds.contains(HexSeatKind.remoteHuman))
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                  'Share the room code with remote players. The match starts when every human seat is filled. Keep the host connected for AI turns.'),
            ),
          FilledButton.icon(
              onPressed: match.busy ? null : () => unawaited(_start()),
              icon: const Icon(Icons.hexagon_outlined),
              label: Text(_kinds.contains(HexSeatKind.remoteHuman)
                  ? 'Create hex room'
                  : 'Start hex match')),
          if (widget.initialMode == HexSetupMode.online) ...[
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              maxLength: 7,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Join a hex room',
                  hintText: 'HABCDEF',
                  border: OutlineInputBorder()),
              onSubmitted:
                  match.busy ? null : (_) => unawaited(_start(join: true)),
            ),
            OutlinedButton(
                onPressed:
                    match.busy ? null : () => unawaited(_start(join: true)),
                child: const Text('Join room')),
          ],
          if (match.busy)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator())),
          if (match.error != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(match.error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
      )),
    );
  }
}

class HexGameScreen extends ConsumerStatefulWidget {
  const HexGameScreen({super.key});
  @override
  ConsumerState<HexGameScreen> createState() => _HexGameScreenState();
}

class _HexGameScreenState extends ConsumerState<HexGameScreen> {
  late final HexMatchController _controller;
  final _selection = HexMoveSelection();
  HexCell? get _source => _selection.source;
  PieceType get _type => _selection.type;
  set _type(PieceType value) => _selection.type = value;
  HexMove? get _planned => _selection.planned;
  set _planned(HexMove? value) => _selection.planned = value;
  @override
  void initState() {
    super.initState();
    _controller = ref.read(hexMatchProvider.notifier);
  }

  @override
  void dispose() {
    _controller.leave(notify: false);
    super.dispose();
  }

  void _clear() => _selection.clear();

  Future<void> _confirm() async {
    final move = _planned;
    if (move == null || !ref.read(hexMatchProvider).canPlay) return;
    if (await _controller.play(move) && mounted) setState(_clear);
  }

  void _tap(HexCell cell, HexGame game) {
    if (!ref.read(hexMatchProvider).canPlay) return;
    var confirm = false;
    setState(() => confirm = _selection.tap(game, cell));
    if (confirm) unawaited(_confirm());
  }

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(hexMatchProvider);
    ref.listen<HexMatchState>(hexMatchProvider, (previous, next) {
      if (previous?.game?.ply != next.game?.ply && mounted) setState(_clear);
    });
    final game = match.game;
    if (game == null) {
      return const Scaffold(body: Center(child: Text('No hex match loaded')));
    }
    // A sole human's goal stays visible while either bot takes its turn.
    final goalSeat =
        match.controls.length == 1 ? match.controls.single : game.current;
    final preview = _planned == null ? null : HexRules.play(game, _planned!);
    final road = game.finished && game.winner != null
        ? HexRules.road(game, game.winner!)
        : <HexCell>{};
    final status = !match.connected
        ? 'Connection lost — rejoin your room'
        : !match.ready
            ? 'Waiting for all human seats'
            : game.finished
                ? '${game.winner?.label ?? 'Draw'} · ${game.reason}'
                : match.busy
                    ? '${game.current.label} · ${match.kinds[game.current.index] == HexSeatKind.ai ? 'AI thinking' : 'Saving move'}'
                    : match.kinds[game.current.index] == HexSeatKind.ai
                        ? '${game.current.label} · AI turn${match.room == null ? '' : ' (host)'}'
                        : '${game.current.label} to play${game.opening ? ' · place ${game.current.next.label} flat' : ''}';

    return Scaffold(
      appBar: AppBar(title: const Text('Three-player Hex'), actions: [
        if (match.room == null && match.kinds.contains(HexSeatKind.ai))
          IconButton(
              onPressed: _controller.togglePause,
              icon: Icon(match.paused ? Icons.play_arrow : Icons.pause),
              tooltip: match.paused ? 'Resume AI' : 'Pause AI'),
        IconButton(
            onPressed: () =>
                _showRules(context, legacy: game.rulesVersion == 1),
            icon: const Icon(Icons.help_outline),
            tooltip: 'Hex rules'),
      ]),
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final textScale =
            MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
        // Reserve chrome independently of the current move. Otherwise a new
        // instruction, Carry slider or Confirm button resizes the board.
        final headerHeight =
            (constraints.maxWidth < 600 ? 220 : 160) * textScale;
        final controlsHeight = 240 * textScale;
        final boardHeight = math.min(320.0, constraints.maxWidth);
        return SingleChildScrollView(
            child: SizedBox(
                // Short screens scroll the whole play surface without shrinking
                // cells. Each dock can also scroll independently for long text.
                height: math.max(constraints.maxHeight,
                    headerHeight + boardHeight + controlsHeight),
                child: Column(children: [
                  SizedBox(
                    height: headerHeight,
                    child: SingleChildScrollView(
                      child: Column(children: [
                        if (match.room != null)
                          TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: match.room!.code));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Room code copied')));
                                }
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: Text('Room ${match.room!.code}')),
                        Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: HexSeat.values
                                  .map((seat) => ActionChip(
                                        tooltip:
                                            '${seat.label} · ${BoardThemeData.forTheme(BoardTheme.values[(match.room?.pieceStyles[seat.index] ?? ref.watch(cosmeticsProvider).selectedPieceStyle).index]).name} pieces. Tap to preview and see unlock requirements.',
                                        onPressed: () => showPieceThemePreview(
                                            context,
                                            match.room
                                                    ?.pieceStyles[seat.index] ??
                                                ref
                                                    .read(cosmeticsProvider)
                                                    .selectedPieceStyle),
                                        avatar: CircleAvatar(
                                            backgroundColor:
                                                hexSeatColors[seat.index],
                                            child: Text(
                                                hexSeatSymbols[seat.index],
                                                style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 11))),
                                        label: Text(
                                            '${seat.label}: ${game.reserves[seat.index].stones} + ${game.reserves[seat.index].caps} caps\n${_seatStatus(match, seat)}'),
                                        side: BorderSide(
                                            color: seat ==
                                                    (game.finished
                                                        ? game.winner
                                                        : game.current)
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Colors.transparent,
                                            width: 2),
                                      ))
                                  .toList(),
                            )),
                        Text(status,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium),
                        Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: Text(
                                game.rulesVersion == 1
                                    ? 'Legacy room · ${goalSeat.label}: ${goalSeat.goalLabel}\nConnect ${hexSeatSymbols[goalSeat.index]} A to ${hexSeatSymbols[goalSeat.index]} B.'
                                    : 'Any color · A to A, B to B, or C to C\nConnect opposite sides with your exposed flats or caps.',
                                textAlign: TextAlign.center)),
                      ]),
                    ),
                  ),
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: HexBoard(
                              goalSeat: goalSeat,
                              turnSeat: game.current,
                              pieceStyles: match.room?.pieceStyles,
                              boardTheme: match.room?.boardTheme,
                              preview: _planned != null,
                              game: preview ?? game,
                              inspectionGame: preview == null ? null : game,
                              selected: _source,
                              destinations: _selection.destinations(game),
                              road: road,
                              onSwipe: match.canPlay
                                  ? (cell, direction) => setState(() =>
                                      _selection.swipe(game, cell, direction))
                                  : null,
                              onCell: match.canPlay
                                  ? (cell) => _tap(cell, game)
                                  : null))),
                  SizedBox(
                      height: controlsHeight,
                      child: SingleChildScrollView(
                          child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          if (game.finished) ...[
                            Text(
                                'Exposed flats: ${HexSeat.values.map((seat) => '${seat.label} ${HexRules.flatCounts(game)[seat.index]}').join(' · ')}',
                                textAlign: TextAlign.center),
                            TextButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Set up another match')),
                          ],
                          if (match.paused) const Text('AI paused'),
                          if (match.error != null)
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(match.error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          if (!match.ready)
                            const Text(
                                'Share the room code. Each joining device fills one open human seat.'),
                          if (match.canPlay && !game.opening && _source == null)
                            Wrap(
                                spacing: 8,
                                children: PieceType.values
                                    .map((type) => ChoiceChip(
                                          label: Text(switch (type) {
                                            PieceType.flat => 'Flat',
                                            PieceType.standing => 'Wall',
                                            PieceType.capstone => 'Capstone'
                                          }),
                                          selected: _type == type,
                                          onSelected: game
                                                  .reserves[game.current.index]
                                                  .has(type)
                                              ? (_) => setState(() {
                                                    _type = type;
                                                    _planned = null;
                                                  })
                                              : null,
                                        ))
                                    .toList()),
                          if (match.canPlay && _source != null)
                            HexMoveControls(
                                selection: _selection,
                                game: game,
                                onChanged: () => setState(() {})),
                          if (match.canPlay)
                            Text(_planned != null
                                ? 'Preview — confirm to finish your move'
                                : _source != null
                                    ? 'Tap a highlighted destination or drag toward it. Carry chooses the top pieces.'
                                    : 'Tap to preview; tap again to place. Tap or drag your stack to spread.'),
                          if (_planned != null || _source != null)
                            Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: [
                                  TextButton(
                                      onPressed: () => setState(_clear),
                                      child: const Text('Cancel')),
                                  if (_planned != null)
                                    FilledButton(
                                        onPressed:
                                            match.canPlay ? _confirm : null,
                                        child: const Text('Confirm')),
                                ]),
                        ]),
                      ))),
                ])));
      })),
    );
  }

  String _seatStatus(HexMatchState match, HexSeat seat) {
    if (match.kinds[seat.index] == HexSeatKind.ai) return 'AI';
    if (match.controls.contains(seat)) return 'This device';
    if (match.room?.owners[seat.index] == null) return 'Open seat';
    return 'Remote human';
  }
}
