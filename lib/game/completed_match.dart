import '../models/cosmetics.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'match_config.dart';
import 'match_controller.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Immutable, replay-validated local history. Reading never awards a result.
class CompletedMatch {
  CompletedMatch._(
      this.id,
      this.owner,
      this.config,
      this.moves,
      this.result,
      this.completedAt,
      this.finalPosition,
      this.durationMs,
      this.boardTheme,
      this.styles,
      this.cosmeticOwners,
      this.cosmeticHost);
  final int? durationMs;
  final BoardTheme? boardTheme;
  final Map<SeatId, PieceStyle> styles;
  final Map<SeatId, String?> cosmeticOwners;
  final String? cosmeticHost;
  final String id;
  final String? owner;
  final MatchConfig config;
  final List<Map<String, dynamic>> moves;
  final MatchResult result;
  final DateTime completedAt;
  final MatchState finalPosition;
  List<MatchState>? _positions;
  void Function()? _onPositionsRequested;

  /// Summaries need only the fully validated final position. Review retains
  /// intermediate states on demand, with the same immutable List API.
  List<MatchState> get positions {
    if (_positions case final positions?) return positions;
    _onPositionsRequested?.call();
    _onPositionsRequested = null;
    var game = MatchState.initial(config);
    final positions = [game];
    for (final move in moves) {
      game = MatchRules.play(game, MatchMove.fromMap(move))!;
      positions.add(game);
    }
    positions[positions.length - 1] = finalPosition;
    return _positions = List.unmodifiable(positions);
  }

  int get retainedPositionCount => _positions?.length ?? 1;

  factory CompletedMatch.capture(
      MatchSession session, List<Map<String, dynamic>> moves,
      {BoardTheme? localBoard,
      PieceStyle? localPieces,
      String? localCosmeticOwner}) {
    if (session.id == null || session.game?.finished != true) {
      throw StateError('Only completed matches can enter history');
    }
    return CompletedMatch.fromMap({
      if (session.room != null || localBoard != null || localPieces != null)
        'appearance': {
          'board':
              (session.room?.boardTheme ?? localBoard ?? BoardTheme.classicWood)
                  .name,
          'pieces': {
            for (final id in session.game!.config.ids)
              id.name: (session.room?.styles[id] ??
                      localPieces ??
                      PieceStyle.standard)
                  .name
          },
          'owners': {
            for (final id in session.game!.config.ids)
              id.name: session.room == null
                  ? localCosmeticOwner ?? session.uid
                  : session.room!.owners[id]
          },
          'host': session.room?.host ?? localCosmeticOwner ?? session.uid,
        },
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
    for (final record in moves) {
      if (record['seat'] != game.current.name) {
        throw const FormatException('History turn mismatch');
      }
      final next = MatchRules.play(game, MatchMove.fromMap(record));
      if (next == null) throw const FormatException('Illegal history move');
      game = next;
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
    }
    final appearance = map['appearance'] is Map
        ? Map<String, dynamic>.from(map['appearance'])
        : null;
    final pieces = appearance?['pieces'] is Map
        ? Map<String, dynamic>.from(appearance!['pieces'])
        : const <String, dynamic>{};
    final owners = appearance?['owners'] is Map
        ? Map<String, dynamic>.from(appearance!['owners'])
        : const <String, dynamic>{};
    return CompletedMatch._(
        map['id'],
        map['owner'],
        config,
        List.unmodifiable(moves),
        result,
        DateTime.parse(map['completedAt']),
        game,
        map['durationMs'] as int?,
        appearance == null ? null : boardThemeFromWire(appearance['board']),
        Map.unmodifiable({
          for (final id in config.ids)
            if (appearance != null) id: pieceStyleFromWire(pieces[id.name])
        }),
        Map.unmodifiable({
          for (final id in config.ids)
            if (owners[id.name] is String) id: owners[id.name] as String
        }),
        appearance?['host'] is String ? appearance!['host'] as String : null);
  }

  Map<String, dynamic> toMap() => {
        if (boardTheme != null)
          'appearance': {
            'board': boardTheme!.name,
            'pieces': {
              for (final entry in styles.entries)
                entry.key.name: entry.value.name
            },
            'owners': {
              for (final entry in cosmeticOwners.entries)
                entry.key.name: entry.value
            },
            'host': cosmeticHost,
          },
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
  static const _metadataLimit = 1024;
  static const _matchLimit = 32;
  static const _characterLimit = 2 * 1024 * 1024;
  final _metadata = <String, (String, DateTime?)>{};
  final _validated = <String, (String, CompletedMatch?)>{};
  int _metadataCharacters = 0, _matchCharacters = 0;
  (String?, bool)? _scope;

  int get cachedMetadataCount => _metadata.length;
  int get cachedMatchCount => _validated.length;

  void _removeMatch(String key) {
    final old = _validated.remove(key);
    if (old == null) return;
    _matchCharacters -= old.$1.length;
    old.$2?._onPositionsRequested = null;
  }

  void _cacheMatch(String key, String encoded, CompletedMatch? match) {
    _removeMatch(key);
    if (encoded.length > _characterLimit || match?._positions != null) return;
    while (_validated.isNotEmpty &&
        (_validated.length >= _matchLimit ||
            _matchCharacters + encoded.length > _characterLimit)) {
      _removeMatch(_validated.keys.first);
    }
    _validated[key] = (encoded, match);
    _matchCharacters += encoded.length;
    if (match != null) {
      match._onPositionsRequested = () {
        if (identical(_validated[key]?.$2, match)) _removeMatch(key);
      };
    }
  }

  void _cacheMetadata(String key, String encoded, DateTime? completedAt) {
    final old = _metadata.remove(key);
    if (old != null) _metadataCharacters -= old.$1.length;
    if (encoded.length > _characterLimit) return;
    while (_metadata.isNotEmpty &&
        (_metadata.length >= _metadataLimit ||
            _metadataCharacters + encoded.length > _characterLimit)) {
      _metadataCharacters -= _metadata.remove(_metadata.keys.first)!.$1.length;
    }
    _metadata[key] = (encoded, completedAt);
    _metadataCharacters += encoded.length;
  }

  void _setScope(String? owner, bool includeGuest) {
    final scope = (owner, includeGuest);
    if (_scope == scope) return;
    for (final key in _validated.keys.toList()) {
      _removeMatch(key);
    }
    _metadata.clear();
    _metadataCharacters = 0;
    _scope = scope;
  }

  Future<void> save(CompletedMatch match) {
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final key =
          '$prefix${Uri.encodeComponent(jsonEncode([match.owner, match.id]))}';
      final encoded = prefs.getString(key);
      if (encoded != null) {
        final old = CompletedMatch.fromMap(
            Map<String, dynamic>.from(jsonDecode(encoded)));
        final before = old.toMap()
          ..remove('completedAt')
          ..remove('appearance');
        final after = match.toMap()
          ..remove('completedAt')
          ..remove('appearance');
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
    _setScope(owner, includeGuest);
    final keys = prefs.getKeys();
    for (final key in _metadata.keys.where((k) => !keys.contains(k)).toList()) {
      _metadataCharacters -= _metadata.remove(key)!.$1.length;
    }
    for (final key
        in _validated.keys.where((k) => !keys.contains(k)).toList()) {
      _removeMatch(key);
    }
    final entries = <(DateTime, String, String, Map<String, dynamic>?)>[];
    var unreadable = 0;
    for (final key in keys.where((key) => key.startsWith(prefix))) {
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
        final encoded = prefs.getString(key)!;
        final cached = _metadata[key];
        if (cached != null && cached.$1 == encoded) {
          _cacheMetadata(key, encoded, cached.$2);
          if (cached.$2 == null) {
            unreadable++;
          } else {
            entries.add((cached.$2!, key, encoded, null));
          }
          continue;
        }
        _removeMatch(key);
        final map = Map<String, dynamic>.from(jsonDecode(encoded));
        if (map['owner'] != identity[0] || map['id'] != identity[1]) {
          throw const FormatException('History identity mismatch');
        }
        final time = DateTime.parse(map['completedAt']);
        _cacheMetadata(key, encoded, time);
        entries.add((time, key, encoded, map));
      } catch (_) {
        final raw = prefs.get(key);
        if (raw is String) _cacheMetadata(key, raw, null);
        unreadable++;
      }
    }
    entries.sort((a, b) => b.$1.compareTo(a.$1));
    final result = <CompletedMatch>[];
    for (final entry in entries.take(limit ?? entries.length)) {
      final cached = _validated[entry.$2];
      CompletedMatch? match;
      if (cached != null && cached.$1 == entry.$3) {
        match = cached.$2;
      } else {
        try {
          match = CompletedMatch.fromMap(
              entry.$4 ?? Map<String, dynamic>.from(jsonDecode(entry.$3)));
        } catch (_) {
          // A negative cache is tied to the exact raw record; repairs revalidate.
        }
      }
      _cacheMatch(entry.$2, entry.$3, match);
      if (match == null) {
        unreadable++;
      } else {
        result.add(match);
      }
    }
    return CompletedMatchPage(result,
        hasMore: limit != null && entries.length > limit,
        unreadableCount: unreadable);
  }
}
