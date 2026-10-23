// Persistent NDJSON worker. Requests contain a complete replay from opening.
import 'dart:convert';
import 'dart:io';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

typedef Decision = Future<Map<String, Object?>> Function(
    MatchState, BotLevel, List<String>, Map<String, dynamic>);
Future<void> serve(Decision decide) async {
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    try {
      final request = jsonDecode(line) as Map<String, dynamic>;
      var game = MatchState.initial(
          MatchConfig.fromMap(request['config'] as Map<String, dynamic>));
      final history = <String>[aiPositionKey(game)];
      for (final record in request['moves'] as List) {
        final map = Map<String, dynamic>.from(record as Map);
        if (map['seat'] != game.current.name) {
          throw StateError('Replay turn mismatch');
        }
        game = MatchRules.play(game, MatchMove.fromMap(map)) ??
            (throw StateError('Illegal replay'));
        history.add(aiPositionKey(game));
        if (history.length > 64) history.removeAt(0);
      }
      final result = await decide(game,
          BotLevel.values.byName(request['level'] as String), history, request);
      stdout.writeln(jsonEncode(
          {'id': request['id'], 'position': aiPositionKey(game), ...result}));
    } catch (error) {
      stdout.writeln(jsonEncode({'error': error.toString()}));
    }
  }
}
