import 'dart:convert';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Exact position identity: ordered buried stones matter; elapsed ply does not.
String aiPositionKey(MatchState game) {
  final cells = game.board.keys.toList()
    ..sort((a, b) => a.x == b.x ? a.y.compareTo(b.y) : a.x.compareTo(b.x));
  return jsonEncode([
    game.config.toMap(),
    game.current.index,
    game.opening,
    for (final seat in game.config.ids)
      [seat.index, game.reserves[seat]!.stones, game.reserves[seat]!.caps],
    for (final cell in cells)
      [
        cell.x,
        cell.y,
        for (final stone in game.board[cell]!)
          [stone.seat.index, stone.type.index]
      ],
    if (game.result != null)
      [game.result!.winner?.index, game.result!.reason.index],
  ]);
}

/// Compact exact key within one decision, whose configuration is fixed.
/// Absolute ply is required here because mate scores prefer earlier wins.
/// Public repetition identity above intentionally omits elapsed ply.
String aiDecisionPositionKey(MatchState game) {
  final key = StringBuffer()
    ..write(game.ply)
    ..write('/');
  for (final id in game.config.ids) {
    final reserve = game.reserves[id]!;
    key
      ..write(reserve.stones)
      ..write(',')
      ..write(reserve.caps)
      ..write(';');
  }
  var index = 0;
  for (final cell in game.geometry.cells) {
    final stack = game.board[cell];
    if (stack != null) {
      key
        ..write(index)
        ..write(':');
      for (final stone in stack) {
        key.writeCharCode(65 + stone.seat.index * 3 + stone.type.index);
      }
      key.write(';');
    }
    index++;
  }
  final result = game.result;
  if (result != null) {
    key
      ..write('R')
      ..write(result.winner?.index ?? 4)
      ..write('/')
      ..write(result.reason.index);
  }
  return key.toString();
}

/// Derives history solely from durable moves. No new save/wire format is needed.
class AiPositionHistory {
  String? _source;
  MatchState? _position;
  final _moves = <String>[];
  final _keys = <String>[];
  void clear() {
    _source = null;
    _position = null;
    _moves.clear();
    _keys.clear();
  }

  List<String> keysFor(String? matchId, MatchConfig config,
      List<Map<String, dynamic>> records, MatchState current) {
    final source = jsonEncode([matchId, config.toMap()]);
    final encoded = records.map(jsonEncode).toList();
    if (_source != source ||
        encoded.length < _moves.length ||
        List.generate(_moves.length, (i) => encoded[i] != _moves[i])
            .any((v) => v)) {
      clear();
      _source = source;
      _position = MatchState.initial(config);
      _keys.add(aiPositionKey(_position!));
    }
    try {
      for (var i = _moves.length; i < records.length; i++) {
        if (records[i]['seat'] != _position!.current.name) {
          throw StateError('Wrong history seat');
        }
        final next = MatchRules.play(_position!, MatchMove.fromMap(records[i]));
        if (next == null) throw StateError('Invalid confirmed history');
        _position = next;
        _moves.add(encoded[i]);
        _keys.add(aiPositionKey(next));
        if (_keys.length > 64) _keys.removeAt(0);
      }
      if (aiPositionKey(current) != aiPositionKey(_position!)) return const [];
      return List.unmodifiable(_keys);
    } on Object {
      clear();
      return const [];
    }
  }
}
