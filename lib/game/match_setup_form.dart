import 'package:flutter/material.dart';
import 'match_config.dart';
import 'match_state.dart';

/// The same seat editor for either shape; local/AI/online is derived from rows.
class MatchSetupForm extends StatefulWidget {
  const MatchSetupForm(
      {super.key, required this.initialConfig, required this.onStart});
  final MatchConfig initialConfig;
  final Future<void> Function(MatchConfig) onStart;
  @override
  State<MatchSetupForm> createState() => _MatchSetupFormState();
}

class _MatchSetupFormState extends State<MatchSetupForm> {
  late MatchConfig _config = widget.initialConfig;
  bool _busy = false;
  String? _error;

  void _update(MatchConfig value) => setState(() {
        _config = value;
        _error = null;
      });

  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onStart(_config);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not start: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supply = Reserve.initial(_config);
    final local =
        _config.seats.where((s) => s.control == SeatControl.localHuman).length;
    final online =
        _config.seats.where((s) => s.control == SeatControl.onlineHuman).length;
    final bots = _config.seats.length - local - online;
    return AbsorbPointer(
        absorbing: _busy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 12, runSpacing: 8, children: [
              for (final shape in BoardShape.values)
                ChoiceChip(
                    label: Text(shape == BoardShape.square ? 'Square' : 'Hex'),
                    selected: _config.shape == shape,
                    onSelected: (_) => _update(_config.copyWith(shape: shape))),
            ]),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
                isExpanded: true,
                key: ValueKey('size-${_config.shape.name}-${_config.size}'),
                initialValue: _config.size,
                decoration: const InputDecoration(labelText: 'Board size'),
                items: MatchConfig.sizesFor(_config.shape)
                    .map((size) => DropdownMenuItem(
                        value: size,
                        child: Text(_config.shape == BoardShape.square
                            ? '$size × $size'
                            : 'Radius $size · ${1 + 3 * size * (size + 1)} cells')))
                    .toList(),
                onChanged: (size) {
                  if (size != null) _update(_config.copyWith(size: size));
                }),
            const SizedBox(height: 12),
            Text('${supply.stones} stones + ${supply.caps} caps per player. '
                '${_config.profile == RulesProfile.standardTak ? 'Standard Tak.' : 'Stones variant: every player shares all opposite-side goals.'}'),
            const SizedBox(height: 20),
            Text('${_config.seats.length} players',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final seat in _config.seats)
              Card(
                  key: ValueKey('seat-${seat.id.name}'),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                              child: Text(
                                  '${seat.id.symbol} · ${seat.id.label}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium)),
                          if (_config.seats.length > 2)
                            IconButton(
                                tooltip: 'Remove ${seat.id.label}',
                                onPressed: () =>
                                    _update(_config.removePlayer(seat.id)),
                                icon: const Icon(Icons.person_remove_outlined)),
                        ]),
                        DropdownButtonFormField<SeatControl>(
                            isExpanded: true,
                            key: ValueKey(
                                'control-${seat.id.name}-${seat.control.name}'),
                            initialValue: seat.control,
                            decoration: InputDecoration(
                                labelText: '${seat.id.label} control'),
                            items: const [
                              DropdownMenuItem(
                                  value: SeatControl.localHuman,
                                  child: Text('Local human')),
                              DropdownMenuItem(
                                  value: SeatControl.onlineHuman,
                                  child: Text('Online human')),
                              DropdownMenuItem(
                                  value: SeatControl.ai, child: Text('AI')),
                            ],
                            onChanged: (control) {
                              if (control == null) return;
                              _update(_config.copyWith(
                                  seats: _config.seats
                                      .map((s) => s.id == seat.id
                                          ? s.copyWith(control: control)
                                          : s)
                                      .toList()));
                            }),
                        if (seat.control == SeatControl.ai) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<BotLevel>(
                              isExpanded: true,
                              key: ValueKey(
                                  'level-${seat.id.name}-${seat.level.name}'),
                              initialValue: seat.level,
                              decoration: InputDecoration(
                                  labelText: '${seat.id.label} difficulty'),
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
                              onChanged: (level) {
                                if (level == null) return;
                                _update(_config.copyWith(
                                    seats: _config.seats
                                        .map((s) => s.id == seat.id
                                            ? s.copyWith(level: level)
                                            : s)
                                        .toList()));
                              }),
                        ],
                      ]))),
            if (_config.seats.length < 4)
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      onPressed: () => _update(_config.addPlayer()),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Add player'))),
            const SizedBox(height: 16),
            DropdownButtonFormField<SeatId>(
                isExpanded: true,
                key: ValueKey('starter-${_config.starter.name}'),
                initialValue: _config.starter,
                decoration: const InputDecoration(labelText: 'Starting player'),
                items: _config.ids
                    .map((id) =>
                        DropdownMenuItem(value: id, child: Text(id.label)))
                    .toList(),
                onChanged: (id) {
                  if (id != null) _update(_config.copyWith(starter: id));
                }),
            const SizedBox(height: 16),
            Text('$local local · $online online · $bots AI'),
            if (local == 0)
              Text(online == 0
                  ? 'Watch the AIs play. You can pause the match.'
                  : 'You host as an observer. Online humans join with the room invitation.'),
            if (local > 1)
              const Text('Local humans take turns on this device.'),
            if (online > 0)
              const Text('The match starts once every online seat is filled.'),
            if (online == 0 && bots > 0 && local > 0)
              SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Court Mode'),
                  subtitle: const Text(
                      'Hints, AI explanations and takebacks. Untimed practice; no awards.'),
                  value: _config.court,
                  onChanged: (value) =>
                      _update(_config.copyWith(court: value))),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      semanticsLabel: _error,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _busy ? null : _start,
                child: Text(_busy
                    ? 'Starting…'
                    : _config.online
                        ? 'Create room'
                        : 'Start game')),
          ],
        ));
  }
}
