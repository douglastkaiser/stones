import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/piece.dart';
import 'hex_board.dart';
import 'hex_exercises.dart';
import 'hex_game.dart';

class HexLearningScreen extends StatefulWidget {
  const HexLearningScreen({super.key});
  @override
  State<HexLearningScreen> createState() => _HexLearningScreenState();
}

class _HexLearningScreenState extends State<HexLearningScreen> {
  static const progressKey = 'hex_learning_completed_v1';
  Set<String> _completed = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _completed = {...?prefs.getStringList(progressKey)});
    }
  }

  Future<void> _open(HexExercise exercise) async {
    final solved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => HexExerciseScreen(exercise: exercise)));
    if (solved != true || !mounted) return;
    setState(() => _completed.add(exercise.id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(progressKey, _completed.toList());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Hex tutorials & puzzles')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const Text('Learn the three-player variant',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text(
                      'Practice offline. Each lesson is its own sandbox; your matches and square achievements stay separate.'),
                  for (final puzzles in [false, true]) ...[
                    Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 8),
                        child: Text(
                            puzzles
                                ? 'One-move puzzles'
                                : 'Interactive tutorials',
                            style: Theme.of(context).textTheme.titleLarge)),
                    for (final exercise
                        in hexExercises.where((item) => item.puzzle == puzzles))
                      Card(
                          child: ListTile(
                              leading: Icon(
                                  _completed.contains(exercise.id)
                                      ? Icons.check_circle
                                      : puzzles
                                          ? Icons.extension_outlined
                                          : Icons.school_outlined,
                                  semanticLabel:
                                      _completed.contains(exercise.id)
                                          ? 'Completed'
                                          : 'Not completed'),
                              title: Text(exercise.title),
                              subtitle: Text(exercise.goal),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _open(exercise))),
                  ],
                ]))),
      );
}

class HexExerciseScreen extends StatefulWidget {
  const HexExerciseScreen({super.key, required this.exercise});
  final HexExercise exercise;
  @override
  State<HexExerciseScreen> createState() => _HexExerciseScreenState();
}

class _HexExerciseScreenState extends State<HexExerciseScreen> {
  late HexGame _game;
  HexCell? _source;
  int _carry = 1;
  PieceType _type = PieceType.flat;
  HexMove? _planned;
  List<HexMove> _choices = [];
  int _steps = 0;
  bool _done = false;
  bool _attempted = false;
  bool _hint = false;
  String? _feedback;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _clear() {
    _source = null;
    _planned = null;
    _choices = [];
  }

  void _reset() {
    _game = widget.exercise.initial;
    _steps = 0;
    _done = false;
    _attempted = false;
    _hint = false;
    _feedback = null;
    _clear();
  }

  HexCell _end(HexMove move) {
    var cell = move.from;
    for (final _ in move.drops) {
      cell = cell.step(move.direction!);
    }
    return cell;
  }

  List<HexMove> get _spreads => _source == null
      ? []
      : HexRules.spreads(_game, _source!, pickup: _carry).toList();
  void _tap(HexCell cell) {
    if (_done || _attempted) return;
    final options = _spreads.where((move) => _end(move) == cell).toList();
    setState(() {
      _feedback = null;
      if (options.isNotEmpty && cell != _source) {
        _choices = options;
        _planned = options.first;
      } else if (!_game.opening && _game.topAt(cell)?.seat == _game.current) {
        _clear();
        _source = cell;
        _carry = math.min(_game.carryLimit, _game.stackAt(cell).length);
      } else if (_game.stackAt(cell).isEmpty) {
        _clear();
        final move =
            HexMove.place(cell, _game.opening ? PieceType.flat : _type);
        if (HexRules.play(_game, move) != null) _planned = move;
      }
    });
  }

  void _confirm() {
    final move = _planned;
    if (move == null) return;
    final result = HexRules.play(_game, move);
    if (result == null) return;
    if (!widget.exercise.accepts(_game, move, _steps)) {
      setState(() => _feedback =
          'Try the lesson’s objective. Your board has not changed.');
      return;
    }
    setState(() {
      _game = result;
      _steps++;
      _clear();
      _done = widget.exercise.completed(result, _steps);
      _attempted = widget.exercise.puzzle && !_done;
      _feedback = _done
          ? 'Complete! You solved the objective.'
          : _attempted
              ? 'That move did not win. Try again or reveal the hint.'
              : 'Good. Next: ${_game.current.label} places ${_game.current.next.label}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final preview = _planned == null ? null : HexRules.play(_game, _planned!);
    final carryMax = _source == null
        ? 1
        : math.min(_game.carryLimit, _game.stackAt(_source!).length);
    return Scaffold(
      appBar: AppBar(title: Text(exercise.title)),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(exercise.goal,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(_done
                            ? 'Objective complete'
                            : _attempted
                                ? 'Retry to explore another move'
                                : '${_game.current.label} · ${_game.opening ? 'place ${_game.current.next.label} flat' : 'connect your matching edges'}'),
                        const Text('I: Ivory · Ch: Charcoal · Cu: Copper'),
                        SizedBox(
                            height: MediaQuery.sizeOf(context)
                                .width
                                .clamp(260.0, 420.0),
                            child: HexBoard(
                                turnSeat: _game.current,
                                preview: _planned != null,
                                game: preview ?? _game,
                                selected: _source,
                                destinations: _spreads.map(_end).toSet(),
                                road: _done && _game.winner != null
                                    ? HexRules.road(_game, _game.winner!)
                                    : {},
                                onCell: _done || _attempted ? null : _tap)),
                        if (!_done &&
                            !_attempted &&
                            !_game.opening &&
                            _source == null)
                          Wrap(spacing: 8, children: [
                            for (final type in PieceType.values)
                              ChoiceChip(
                                  label: Text(type == PieceType.standing
                                      ? 'Wall'
                                      : type.name),
                                  selected: _type == type,
                                  onSelected: (_) => setState(() {
                                        _type = type;
                                        _planned = null;
                                      }))
                          ]),
                        if (_source != null)
                          Row(children: [
                            Text('Carry: $_carry'),
                            Expanded(
                                child: Slider(
                                    label: 'Carry $_carry',
                                    value: _carry.toDouble(),
                                    min: 1,
                                    max: math.max(2, carryMax).toDouble(),
                                    divisions: math.max(1, carryMax - 1),
                                    onChanged: carryMax == 1
                                        ? null
                                        : (value) => setState(() {
                                              _carry = value.round();
                                              _planned = null;
                                              _choices = [];
                                            }))),
                          ]),
                        if (_choices.isNotEmpty)
                          Wrap(spacing: 8, children: [
                            for (final move in _choices)
                              ChoiceChip(
                                  label: Text('Drop ${move.drops.join(' → ')}'),
                                  selected: identical(move, _planned),
                                  onSelected: (_) =>
                                      setState(() => _planned = move))
                          ]),
                        if (!_done && !_attempted)
                          const Text(
                              'Tap an empty cell to place, or your stack then a highlighted destination. Confirm applies the preview.'),
                        if (_feedback != null)
                          Semantics(
                              liveRegion: true,
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(_feedback!))),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          if (_planned != null)
                            FilledButton(
                                onPressed: _confirm,
                                child: const Text('Confirm')),
                          if (_source != null || _planned != null)
                            TextButton(
                                onPressed: () => setState(_clear),
                                child: const Text('Cancel')),
                          OutlinedButton(
                              onPressed: () => setState(() => _hint = !_hint),
                              child: Text(_hint ? 'Hide hint' : 'Hint')),
                          OutlinedButton(
                              onPressed: () => setState(_reset),
                              child: const Text('Retry')),
                          if (_done)
                            FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Finish lesson')),
                        ]),
                        if (_hint)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(exercise.hint)),
                      ])))),
    );
  }
}
