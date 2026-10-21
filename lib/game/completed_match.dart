import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'match_config.dart';
import 'match_controller.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Immutable, replay-validated local history. Reading never awards a result.
class CompletedMatch {
  CompletedMatch._(this.id, this.owner, this.config, this.moves, this.result,
      this.completedAt, this.positions, this.durationMs);
  final int? durationMs;
  final String id;
  final String? owner;
  final MatchConfig config;
  final List<Map<String, dynamic>> moves;
  final MatchResult result;
  final DateTime completedAt;
  final List<MatchState> positions;
  MatchState get finalPosition => positions.last;

  factory CompletedMatch.capture(
      MatchSession session, List<Map<String, dynamic>> moves) {
    if (session.id == null || session.game?.finished != true) {
      throw StateError('Only completed matches can enter history');
    }
    return CompletedMatch.fromMap({
      'durationMs': session.elapsed?.at(DateTime.now()).inMilliseconds,
      'version': 1,
      'id': session.id,
      'owner': session.uid,
      'config': session.game!.config.toMap(),
      'moves': moves,
      'winner': session.game!.result!.winner?.name,
      'reason': session.game!.result!.reason.name,
      'completedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  factory CompletedMatch.fromMap(Map<String, dynamic> map) {
    if (map['version'] != 1 ||
        map['id'] is! String ||
        (map['id'] as String).isEmpty ||
        (map['owner'] != null && map['owner'] is! String)) {
      throw const FormatException('Invalid completed match');
    }
    final config =
        MatchConfig.fromMap(Map<String, dynamic>.from(map['config']));
    final moves = (map['moves'] as List).map((m) {
      final move = MatchMove.fromMap(Map<String, dynamic>.from(m));
      final record = move.toMap(SeatId.values.byName(m['seat'] as String));
      record['drops'] = List<int>.unmodifiable(move.drops);
      return Map<String, dynamic>.unmodifiable(record);
    }).toList();
    var game = MatchState.initial(config);
    final positions = [game];
    for (final record in moves) {
      if (record['seat'] != game.current.name) {
        throw const FormatException('History turn mismatch');
      }
      final next = MatchRules.play(game, MatchMove.fromMap(record));
      if (next == null) throw const FormatException('Illegal history move');
      game = next;
      positions.add(game);
    }
    final result = MatchResult(
        map['winner'] == null ? null : SeatId.values.byName(map['winner']),
        ResultReason.values.byName(map['reason']));
    if (game.finished) {
      if (game.result!.winner != result.winner ||
          game.result!.reason != result.reason) {
        throw const FormatException('History result disagrees with replay');
      }
    } else {
      if (![ResultReason.resignation, ResultReason.time, ResultReason.abandoned]
          .contains(result.reason)) {
        throw const FormatException('History has no adjudicated board result');
      }
      game = game.copyWith(result: result);
      positions[positions.length - 1] = game;
    }
    return CompletedMatch._(
        map['id'],
        map['owner'],
        config,
        List.unmodifiable(moves),
        result,
        DateTime.parse(map['completedAt']),
        List.unmodifiable(positions),
        map['durationMs'] as int?);
  }

  Map<String, dynamic> toMap() => {
        'durationMs': durationMs,
        'version': 1,
        'id': id,
        'owner': owner,
        'config': config.toMap(),
        'moves': moves,
        'winner': result.winner?.name,
        'reason': result.reason.name,
        'completedAt': completedAt.toUtc().toIso8601String(),
      };
}

class CompletedMatchPage {
  CompletedMatchPage(Iterable<CompletedMatch> matches,
      {this.hasMore = false, this.unreadableCount = 0})
      : matches = List.unmodifiable(matches);
  final List<CompletedMatch> matches;
  final bool hasMore;
  final int unreadableCount;
}

class CompletedMatchStorage {
  static const prefix = 'completed_match_v1:';
  Future<void> _writes = Future.value();

  Future<void> save(CompletedMatch match) {
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final key =
          '$prefix${Uri.encodeComponent(jsonEncode([match.owner, match.id]))}';
      final encoded = prefs.getString(key);
      if (encoded != null) {
        final old = CompletedMatch.fromMap(
            Map<String, dynamic>.from(jsonDecode(encoded)));
        final before = old.toMap()..remove('completedAt');
        final after = match.toMap()..remove('completedAt');
        if (jsonEncode(before) != jsonEncode(after)) {
          throw StateError('A completed game cannot be replaced');
        }
        return;
      }
      if (!await prefs.setString(key, jsonEncode(match.toMap()))) {
        throw StateError('Completed game could not be saved');
      }
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  Future<List<CompletedMatch>> list(String? owner,
          {bool includeGuest = false}) async =>
      (await readPage(owner, includeGuest: includeGuest)).matches;

  /// Decode metadata first; replay only the visible page. A damaged record is
  /// retained and reported without hiding readable games or other accounts.
  Future<CompletedMatchPage> readPage(String? owner,
      {bool includeGuest = false, int? limit}) async {
    if (limit != null && limit < 1) throw ArgumentError.value(limit, 'limit');
    final prefs = await SharedPreferences.getInstance();
    final entries = <(DateTime, Map<String, dynamic>)>[];
    var unreadable = 0;
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      List<dynamic> identity;
      try {
        identity = jsonDecode(Uri.decodeComponent(key.substring(prefix.length)))
            as List<dynamic>;
        if (identity.length != 2) continue;
      } catch (_) {
        continue; // An invalid key cannot be attributed to the current account.
      }
      if (identity[0] != owner && !(includeGuest && identity[0] == null)) {
        continue;
      }
      try {
        final map =
            Map<String, dynamic>.from(jsonDecode(prefs.getString(key)!));
        if (map['owner'] != identity[0] || map['id'] != identity[1]) {
          throw const FormatException('History identity mismatch');
        }
        entries.add((DateTime.parse(map['completedAt']), map));
      } catch (_) {
        unreadable++;
      }
    }
    entries.sort((a, b) => b.$1.compareTo(a.$1));
    final result = <CompletedMatch>[];
    for (final entry in entries.take(limit ?? entries.length)) {
      try {
        result.add(CompletedMatch.fromMap(entry.$2));
      } catch (_) {
        unreadable++;
      }
    }
    return CompletedMatchPage(result,
        hasMore: limit != null && entries.length > limit,
        unreadableCount: unreadable);
  }
}
