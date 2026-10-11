import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/piece.dart';
import '../providers/cosmetics_provider.dart';
import 'board_view.dart';
import 'board_geometry.dart';
import 'match_config.dart';
import 'match_controller.dart';
import 'match_provider.dart';
import 'match_rules.dart';
import 'match_state.dart';
import 'move_selection.dart';
import 'seat_appearance.dart';

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key});
  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  final _selection = MoveSelection();
  late MatchController _controller;
  @override
  void initState() {
    super.initState();
    _controller = ref.read(matchProvider.notifier);
  }

  @override
  void dispose() {
    _controller.suspend();
    super.dispose();
  }

  Future<void> _confirm() async {
    final move = _selection.planned;
    if (move == null || !ref.read(matchProvider).canPlay) return;
    if (await _controller.play(move) && mounted) setState(_selection.clear);
  }

  void _tap(MatchState game, Cell cell) {
    if (!ref.read(matchProvider).canPlay) return;
    var confirm = false;
    setState(() => confirm = _selection.tap(game, cell));
    if (confirm) unawaited(_confirm());
  }

  void _help() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text('Playing Stones'),
          scrollable: true,
          content: const Text(
              'Every player can build a road between any opposite sides. '
              'Only exposed flats and capstones connect. Walls block roads.\n\n'
              'During the opening exchange each player places the next player’s flat. '
              'Then place your own flat, wall or cap on an empty cell, or move a stack you control.\n\n'
              'Tap an empty cell to preview; tap it again to place. Tap a stack to choose Carry, '
              'then a neighbor to preview a move. Swiping or dragging does the same. '
              'Use Drop and Drop & next to spread bottom pieces in a straight line. '
              'Confirm leaves the remainder at the final cell. Back step revises; Cancel discards. '
              'Hold, right-click or hover to inspect a stack.\n\n'
              'Square has four directions; Hex has six. Carry is limited by the board’s longest row. '
              'A lone capstone can flatten a wall only at the final drop.\n\n'
              'Roads resolve after the complete move. The mover wins simultaneous roads if they have one; '
              'multiple opponent roads draw. Without a road, a full board or exhausted reserve ends play. '
              'Only exposed flats score; tied leaders draw.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))]));

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(matchProvider);
    final game = match.game;
    ref.listen(matchProvider.select((s) => s.game?.ply), (previous, next) {
      if (previous != next && mounted) setState(_selection.clear);
    });
    if (game == null) {
      return const Scaffold(body: Center(child: Text('No match loaded')));
    }
    final preview = _selection.planned == null
        ? null
        : MatchRules.apply(game, _selection.planned!);
    final styles = match.room?.styles ??
        {
          for (final id in game.config.ids)
            id: ref.watch(currentPieceStyleProvider).style
        };
    final boardTheme =
        match.room?.boardTheme ?? ref.watch(currentBoardThemeProvider).theme;
    final winner = game.result?.winner;
    final road = winner == null ? <Cell>{} : MatchRules.road(game, winner);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final status = game.finished
        ? '${winner?.label ?? (game.result!.draw ? 'Draw' : 'Match ended')} · ${game.result!.reason.name}'
        : !match.ready
            ? 'Waiting for online players'
            : !match.connected
                ? 'Disconnected · your board is retained'
                : match.paused &&
                        game.config.seat(game.current).control == SeatControl.ai
                    ? 'AI paused'
                    : match.busy
                        ? '${game.current.label} · ${game.config.seat(game.current).control == SeatControl.ai ? 'AI thinking' : 'Saving move'}'
                        : '${game.current.label} to play${game.opening ? ' · opening exchange' : ''}';
    return Scaffold(
        appBar: AppBar(
            title: Text(
                '${game.config.shape == BoardShape.square ? 'Square' : 'Hex'} · ${game.config.seats.length} players'),
            actions: [
              if (game.config.seats.any((s) => s.control == SeatControl.ai) &&
                  match.room == null)
                IconButton(
                    tooltip: match.paused ? 'Resume AI' : 'Pause AI',
                    onPressed: () => _controller.pause(!match.paused),
                    icon: Icon(match.paused ? Icons.play_arrow : Icons.pause)),
              IconButton(
                  tooltip: 'How to play',
                  onPressed: _help,
                  icon: const Icon(Icons.help_outline)),
            ]),
        body: LayoutBuilder(builder: (context, constraints) {
          final boardSide = math.min(
              680.0,
              math.min(constraints.maxWidth,
                  math.max(280.0, constraints.maxHeight - 330 * scale)));
          return SingleChildScrollView(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(children: [
              SizedBox(
                  height: 98 * scale,
                  child: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final seat in game.config.seats)
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                              color: seat.id == game.current
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Colors.transparent,
                                              width: 2),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                                radius: 12,
                                                backgroundColor:
                                                    SeatAppearance.marker(
                                                        seat.id),
                                                child: Text(seat.id.symbol,
                                                    textScaler:
                                                        TextScaler.noScaling,
                                                    style: const TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 10))),
                                            const SizedBox(width: 6),
                                            Flexible(
                                                child: Text(
                                                    '${seat.id.label}: ${game.reserves[seat.id]!.stones} + ${game.reserves[seat.id]!.caps} caps')),
                                          ])),
                              ])))),
              SizedBox(
                  height: 44 * scale,
                  child: Center(
                      child: Text(status,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium))),
              SizedBox(
                  key: const ValueKey('stable-board'),
                  width: boardSide,
                  height: boardSide,
                  child: BoardView(
                      game: preview ?? game,
                      original: preview == null ? null : game,
                      selected: _selection.source,
                      destinations:
                          match.canPlay ? _selection.destinations(game) : {},
                      road: road,
                      styles: styles,
                      theme: boardTheme,
                      onCell: match.canPlay ? (cell) => _tap(game, cell) : null,
                      onSwipe: !match.canPlay
                          ? null
                          : (cell, direction) => setState(
                              () => _selection.swipe(game, cell, direction)))),
              SizedBox(
                  height: 230 * scale,
                  child: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _controls(match, game)))),
              if (match.room != null)
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Text('Room ${match.room!.code}',
                          style: Theme.of(context).textTheme.titleMedium),
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
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy invitation code')),
                      for (final seat in game.config.seats)
                        Text(
                            '${seat.id.label} · ${seat.control == SeatControl.ai ? 'AI' : match.room!.owners[seat.id] == null ? 'Waiting for online human' : match.room!.owners[seat.id] == match.uid ? 'On this device' : 'Online human'}'),
                    ])),
              if (match.error != null)
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(match.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
            ]),
          )));
        }));
  }

  Widget _counter(String label, int value, int max, ValueChanged<int> update) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            tooltip: 'Decrease $label',
            onPressed:
                value <= 1 ? null : () => setState(() => update(value - 1)),
            icon: const Icon(Icons.remove)),
        Text('$label $value'),
        IconButton(
            tooltip: 'Increase $label',
            onPressed:
                value >= max ? null : () => setState(() => update(value + 1)),
            icon: const Icon(Icons.add)),
      ]);

  Widget _controls(MatchSession match, MatchState game) {
    if (game.finished) {
      return Column(children: [
        const Text('Match complete'),
        Text(
            'Exposed flats: ${MatchRules.flatCounts(game).entries.map((e) => '${e.key.label} ${e.value}').join(' · ')}'),
      ]);
    }
    if (!match.canPlay) {
      return Text(match.ready
          ? 'Waiting for the current player.'
          : 'Share the room code with your friends.');
    }
    final move = _selection.planned;
    final source = _selection.source;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (source == null)
        Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final type
                  in game.opening ? [PieceType.flat] : PieceType.values)
                ChoiceChip(
                    label: Text(switch (type) {
                      PieceType.flat => 'Flat',
                      PieceType.standing => 'Wall',
                      PieceType.capstone => 'Capstone'
                    }),
                    selected: _selection.type == type,
                    onSelected: !game.reserves[game.opening
                                ? game.config.next(game.current)
                                : game.current]!
                            .has(type)
                        ? null
                        : (_) => setState(() {
                              _selection.clear();
                              _selection.type = type;
                            })),
            ]),
      if (source != null)
        _counter(
            'Carry',
            _selection.carry,
            math.min(game.geometry.carryLimit, game.stackAt(source).length),
            _selection.setCarry),
      if (move?.direction != null) ...[
        Wrap(alignment: WrapAlignment.center, children: [
          _counter('Drop', _selection.pendingDrop, move!.drops.last,
              (v) => _selection.pendingDrop = v),
          TextButton(
              onPressed: _selection.continuation(game) == null
                  ? null
                  : () => setState(() => _selection.continueMove(game)),
              child: const Text('Drop & next')),
          TextButton(
              onPressed: () =>
                  setState(() => _selection.pendingDrop = move.drops.last),
              child: const Text('All here')),
          TextButton(
              onPressed: () => setState(() => _selection.backStep(game)),
              child: const Text('Back step')),
        ]),
        Text('Drop ${move.drops.join(' → ')}'),
      ],
      if (move != null || source != null)
        Wrap(spacing: 12, alignment: WrapAlignment.center, children: [
          TextButton(
              onPressed: () => setState(_selection.clear),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: previewLegal(game) ? _confirm : null,
              child: const Text('Confirm')),
        ])
      else
        const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Tap a cell to preview. Tap it again to place.')),
    ]);
  }

  bool previewLegal(MatchState game) =>
      _selection.planned != null &&
      MatchRules.apply(game, _selection.planned!) != null;
}
