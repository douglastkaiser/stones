// Explain static evaluation at a recorded decision. This does not replace search.
import 'dart:convert';
import 'dart:io';
import 'package:stones/game/ai_material.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_ai_engine.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';

void main(List<String> args) {
  String option(String key, String fallback) =>
      args
          .where((s) => s.startsWith('--$key='))
          .map((s) => s.substring(key.length + 3))
          .firstOrNull ??
      fallback;
  final records = File(option('replay', '')).readAsLinesSync();
  final row = jsonDecode(records[int.parse(option('game', '0'))])
      as Map<String, dynamic>;
  final moves = row['moves'] as List;
  final ply = int.parse(option('ply', '2'));
  if (ply < 0 || ply >= moves.length) throw ArgumentError('Invalid replay ply');
  var game = MatchState.initial(
      MatchConfig.fromMap(Map<String, dynamic>.from(row['config'] as Map)));
  if (game.config.aiEngine != MatchConfig.currentAiEngine) {
    throw ArgumentError('This diagnostic explains current v3 evaluation only');
  }
  for (final record in moves.take(ply)) {
    final map = Map<String, dynamic>.from(record as Map);
    if (map['seat'] != game.current.name) {
      throw StateError('Replay turn mismatch');
    }
    game = MatchRules.play(game, MatchMove.fromMap(map)) ??
        (throw StateError('Illegal replay'));
  }
  final seat = game.current;
  final endgame = game.config.seat(seat).level.index >= BotLevel.hard.index;
  final resilienceWeight = double.parse(option('road-resilience-weight', '0'));
  if (!resilienceWeight.isFinite || resilienceWeight < 0) {
    throw ArgumentError('Invalid resilience weight');
  }
  Map<String, Object?> explain(MatchState position) {
    final terms = {
      for (final id in position.config.ids)
        id: {
          ...MatchAI.evaluationTerms(position, id,
              endgame: endgame, roadResilienceWeight: resilienceWeight),
          if (!position.finished)
            'legalMaterial':
                aiMaterialScore(position, id, const AiMaterialWeights()),
        }
    };
    final scores = terms.map(
        (id, values) => MapEntry(id, values.values.fold(0.0, (a, b) => a + b)));
    final others = scores.entries
        .where((e) => e.key != seat)
        .fold(0.0, (sum, e) => sum + e.value);
    return {
      'terms': terms.map((id, values) => MapEntry(id.name, values)),
      'utility': scores[seat]! -
          (position.config.seats.length == 2 ? 1 : .35) * others,
    };
  }

  final recorded =
      MatchMove.fromMap(Map<String, dynamic>.from(moves[ply] as Map));
  final compare = option('compare', '');
  MatchMove? comparison;
  if (compare.isNotEmpty) {
    final parts = compare.split(':');
    final xy = parts[0].split(',').map(int.parse).toList();
    comparison =
        MatchMove.place(Cell(xy[0], xy[1]), PieceType.values.byName(parts[1]));
  }
  final alternatives = [
    recorded,
    if (recorded.type == PieceType.capstone)
      MatchMove.place(recorded.from, PieceType.flat),
    if (comparison != null) comparison,
  ];
  stdout.writeln(jsonEncode({
    'scope': 'Static position evaluation; search can prefer a different move',
    'ply': ply,
    'seat': seat.name,
    'before': explain(game),
    'alternatives': [
      for (final move in alternatives)
        if (MatchRules.play(game, move) case final MatchState next)
          {'move': move.toMap(seat), ...explain(next)}
    ]
  }));
}
