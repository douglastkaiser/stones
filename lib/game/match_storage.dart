import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Board results live in the move log; only external endings have a result field.
/// Keep setup's replacement guard and local recovery in agreement.
MatchState replayLocalMatch(Map<String, dynamic> snapshot) {
  final config =
      MatchConfig.fromMap(Map<String, dynamic>.from(snapshot['config']));
  if (config.online) {
    throw const FormatException('Online games resume through their room');
  }
  var game = MatchState.initial(config);
  for (final value in snapshot['moves'] as List) {
    final record = Map<String, dynamic>.from(value);
    if (record['seat'] != game.current.name) {
      throw const FormatException('Saved turn mismatch');
    }
    final next = MatchRules.play(game, MatchMove.fromMap(record));
    if (next == null) throw const FormatException('Saved move is illegal');
    game = next;
  }
  if (snapshot['result'] != null) {
    final result = Map<String, dynamic>.from(snapshot['result']);
    final reason = ResultReason.values.byName(result['reason'] as String);
    if (game.finished ||
        ![ResultReason.time, ResultReason.resignation, ResultReason.abandoned]
            .contains(reason)) {
      throw const FormatException('Invalid saved termination');
    }
    game = game.copyWith(
        result: MatchResult(
            result['winner'] == null
                ? null
                : SeatId.values.byName(result['winner'] as String),
            reason));
  }
  return game;
}

abstract class LocalMatchStorage {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> snapshot);
}

class PreferencesMatchStorage implements LocalMatchStorage {
  static const key = 'unified_local_match_v1';
  Future<void> _writes = Future<void>.value();
  @override
  Future<Map<String, dynamic>?> read() async {
    final value = (await SharedPreferences.getInstance()).getString(key);
    if (value == null) return null;
    return Map<String, dynamic>.from(jsonDecode(value));
  }

  @override
  Future<void> write(Map<String, dynamic> snapshot) {
    final encoded = jsonEncode(snapshot);
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, encoded)) {
        throw StateError('Could not save this match');
      }
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}
