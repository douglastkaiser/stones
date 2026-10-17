import 'dart:convert';
import 'dart:js_interop';
import 'package:stones/game/match_ai_engine.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/rating_pool.dart';

@JS('stonesEngine')
external set engine(JSFunction value);

/// Compiled for Node; gameplay and backend execute the very same rules and AI.
void main() {
  engine = ((JSString raw) => dispatch(raw.toDart).toJS).toJS;
}

Future<JSString> dispatch(String raw) async {
  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final config = MatchConfig.fromMap(Map<String, dynamic>.from(data['config']));
    if (config.court || config.profile == RulesProfile.legacyHex) {
      throw const FormatException('Practice or compatibility rules are unrated');
    }
    final records = data['moves'] as List;
    if (records.length > 4096) throw const FormatException('History too long');
    var game = MatchState.initial(config);
    for (final rawMove in records) {
      final record = Map<String, dynamic>.from(rawMove);
      if (record['seat'] != game.current.name) {
        throw const FormatException('Wrong turn');
      }
      final next = MatchRules.play(game, MatchMove.fromMap(record));
      if (next == null) throw const FormatException('Illegal move');
      game = next;
    }
    if (data['action'] == 'bot') {
      if (game.finished || config.seat(game.current).control != SeatControl.ai) {
        throw const FormatException('Not an AI turn');
      }
      final move = await MatchAI(config.seat(game.current).level).choose(game);
      return jsonEncode({'move': move?.toMap(game.current)}).toJS;
    }
    var result = game.result;
    final ended = data['resigned'] ?? data['timedOut'];
    if (ended != null) {
      if (result != null || !config.ids.any((id) => id.name == ended)) {
        throw const FormatException('Invalid termination');
      }
      if (config.seats.length == 2) {
        result = MatchResult(config.next(SeatId.values.byName(ended as String)),
            data['timedOut'] == null ? ResultReason.resignation : ResultReason.time);
      }
    }
    return jsonEncode({
      'pool': RatingPool.forConfig(config).id,
      'current': game.current.name,
      'ply': game.ply,
      'winner': result?.winner?.name,
      'reason': result?.reason.name,
      'finished': result != null,
    }).toJS;
  } catch (error) {
    return jsonEncode({'error': error.toString()}).toJS;
  }
}
