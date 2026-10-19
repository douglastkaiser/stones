/// Account-progress merge contract. This is independent of Firebase and does not
/// replace the device-local achievement provider until storage is qualified.
library;

import 'dart:convert';

/// A frozen pre-sync baseline. Counters from overlapping historical saves use
/// maxima: legacy snapshots cannot prove which individual wins were distinct.
class ProgressBaseline {
  ProgressBaseline({
    Map<String, int> counters = const {},
    Set<String> matches = const {},
    Set<String> unlocks = const {},
    Set<String> legacyUnlocks = const {},
    Map<String, DateTime> earnedAt = const {},
    Set<String> tutorials = const {},
    Set<String> puzzles = const {},
    Set<String> unaided = const {},
    Map<String, Set<String>> tags = const {},
  })  : counters = Map.unmodifiable(counters),
        matches = Set.unmodifiable(matches),
        unlocks = Set.unmodifiable(unlocks),
        legacyUnlocks = Set.unmodifiable(legacyUnlocks),
        earnedAt = Map.unmodifiable(earnedAt),
        tutorials = Set.unmodifiable(tutorials),
        puzzles = Set.unmodifiable(puzzles),
        unaided = Set.unmodifiable(unaided),
        tags = Map.unmodifiable(tags.map(
            (key, value) => MapEntry(key, Set<String>.unmodifiable(value)))) {
    if (counters.values.any((value) => value < 0) ||
        !puzzles.containsAll(unaided)) {
      throw const FormatException('Invalid progress baseline');
    }
  }

  final Map<String, int> counters;
  final Set<String> matches,
      unlocks,
      legacyUnlocks,
      tutorials,
      puzzles,
      unaided;
  final Map<String, DateTime> earnedAt;
  final Map<String, Set<String>> tags;

  Map<String, Object?> toMap() => {
        'metrics': counters,
        'matches': matches.toList(),
        'unlocks': unlocks.toList(),
        'legacyUnlocks': legacyUnlocks.toList(),
        'earnedAt': earnedAt.map(
            (key, value) => MapEntry(key, value.toUtc().toIso8601String())),
        'tutorials': tutorials.toList(),
        'puzzles': puzzles.toList(),
        'unaided': unaided.toList(),
        'tags': tags.map((key, value) => MapEntry(key, value.toList())),
      };

  factory ProgressBaseline.fromMap(Map<String, dynamic> data) {
    final metrics = _object(data['metrics']);
    if (metrics.values.any((value) => value is! int || value < 0)) {
      throw const FormatException('Invalid progress counters');
    }
    final dates = _object(data['earnedAt'] ?? <String, dynamic>{});
    if (dates.values
        .any((value) => value is! String || DateTime.tryParse(value) == null)) {
      throw const FormatException('Invalid earned dates');
    }
    return ProgressBaseline(
      counters: metrics.cast<String, int>(),
      matches: _strings(data['matches']),
      unlocks: _strings(data['unlocks']),
      legacyUnlocks: _strings(data['legacyUnlocks'] ?? []),
      earnedAt: dates.map((key, value) => MapEntry(key, DateTime.parse(value))),
      tutorials: _strings(data['tutorials']),
      puzzles: _strings(data['puzzles']),
      unaided: _strings(data['unaided'] ?? []),
      tags: _object(data['tags'] ?? <String, dynamic>{})
          .map((key, value) => MapEntry(key, _strings(value))),
    );
  }

  /// The existing notifier first consolidates v1 flags/learning into v2. Freeze
  /// that v2 document once, before emitting account events; never import later
  /// materialized account counters back into the historical baseline.
  factory ProgressBaseline.fromLegacyV2(String encoded) {
    final data = _object(jsonDecode(encoded));
    if (data['version'] != 2) {
      throw const FormatException('Unsupported legacy progression version');
    }
    final normalized = Map<String, dynamic>.from(data);
    normalized['matches'] = _strings(data['matches'])
        .map((id) => id.replaceFirst(
            RegExp(r':\d+:(road|flats|time|resignation|abandoned)$'), ''))
        .toList();
    return ProgressBaseline.fromMap(normalized);
  }

  ProgressBaseline merge(ProgressBaseline other) => ProgressBaseline(
        counters: {
          for (final key in {...counters.keys, ...other.counters.keys})
            key: (counters[key] ?? 0) > (other.counters[key] ?? 0)
                ? counters[key]!
                : other.counters[key] ?? 0,
        },
        matches: {...matches, ...other.matches},
        unlocks: {...unlocks, ...other.unlocks},
        legacyUnlocks: {...legacyUnlocks, ...other.legacyUnlocks},
        earnedAt: {
          for (final key in {...earnedAt.keys, ...other.earnedAt.keys})
            key: earnedAt[key] == null
                ? other.earnedAt[key]!
                : other.earnedAt[key] == null ||
                        earnedAt[key]!.isBefore(other.earnedAt[key]!)
                    ? earnedAt[key]!
                    : other.earnedAt[key]!,
        },
        tutorials: {...tutorials, ...other.tutorials},
        puzzles: {...puzzles, ...other.puzzles},
        unaided: {...unaided, ...other.unaided},
        tags: {
          for (final key in {...tags.keys, ...other.tags.keys})
            key: {...?tags[key], ...?other.tags[key]},
        },
      );
}

/// Only additive evidence belongs here. Streaks need an ordered stream and must
/// never be obtained by adding independent devices' counters.
class ProgressEvent {
  ProgressEvent({required this.id, required this.evidence}) {
    if (id.isEmpty ||
        evidence.counters.keys.any((key) =>
            key == 'hardStreak' ||
            key == 'bestHardStreak' ||
            key == 'streakResult') ||
        evidence.matches.any((match) => id != 'match:$match')) {
      throw const FormatException('Invalid progress event');
    }
  }

  final String id;
  final ProgressBaseline evidence;

  bool sameAs(ProgressEvent other) =>
      _mapEquals(evidence.counters, other.evidence.counters) &&
      _setEquals(evidence.matches, other.evidence.matches) &&
      _setEquals(evidence.unlocks, other.evidence.unlocks) &&
      _setEquals(evidence.legacyUnlocks, other.evidence.legacyUnlocks) &&
      evidence.earnedAt.length == other.evidence.earnedAt.length &&
      evidence.earnedAt.entries.every(
          (entry) => entry.value == other.evidence.earnedAt[entry.key]) &&
      _setEquals(evidence.tutorials, other.evidence.tutorials) &&
      _setEquals(evidence.puzzles, other.evidence.puzzles) &&
      _setEquals(evidence.unaided, other.evidence.unaided) &&
      evidence.tags.length == other.evidence.tags.length &&
      evidence.tags.entries.every((entry) =>
          _setEquals(entry.value, other.evidence.tags[entry.key] ?? {}));
}

/// Immutable owner-scoped state. Merge is commutative, associative and idempotent
/// for compatible events. Reusing an ID with different evidence fails closed.
class AccountProgress {
  AccountProgress({
    required this.owner,
    ProgressBaseline? baseline,
    Map<String, ProgressEvent> events = const {},
  })  : baseline = baseline ?? ProgressBaseline(),
        events = Map.unmodifiable(events) {
    if (owner.isEmpty || events.entries.any((e) => e.key != e.value.id)) {
      throw const FormatException('Invalid account progress');
    }
  }

  final String owner;
  final ProgressBaseline baseline;
  final Map<String, ProgressEvent> events;

  String encode() => jsonEncode({
        'version': 1,
        'owner': owner,
        'baseline': baseline.toMap(),
        'events':
            events.map((id, event) => MapEntry(id, event.evidence.toMap())),
      });

  /// A cache key alone is insufficient: validate the payload's owner as well.
  factory AccountProgress.decode(String encoded, {required String owner}) {
    final data = _object(jsonDecode(encoded));
    if (data['version'] != 1 || data['owner'] != owner) {
      throw const FormatException('Unsupported or foreign account progress');
    }
    return AccountProgress(
      owner: owner,
      baseline: ProgressBaseline.fromMap(_object(data['baseline'])),
      events: _object(data['events']).map((id, value) => MapEntry(
          id,
          ProgressEvent(
              id: id, evidence: ProgressBaseline.fromMap(_object(value))))),
    );
  }

  AccountProgress merge(AccountProgress other) {
    if (owner != other.owner) {
      throw StateError('Cannot merge different progress owners');
    }
    for (final entry in other.events.entries) {
      final existing = events[entry.key];
      if (existing != null && !existing.sameAs(entry.value)) {
        throw StateError('Conflicting progress event: ${entry.key}');
      }
    }
    return AccountProgress(
      owner: owner,
      baseline: baseline.merge(other.baseline),
      events: {...events, ...other.events},
    );
  }

  AccountProgress record(ProgressEvent event) => merge(AccountProgress(
        owner: owner,
        events: {event.id: event},
      ));

  /// Called only after an explicit guest-import choice. Sign-in itself must not
  /// call this method. The original guest save remains intact for recovery.
  AccountProgress importBaseline(ProgressBaseline imported) => AccountProgress(
        owner: owner,
        baseline: baseline.merge(imported),
        events: events,
      );

  ProgressBaseline get materialize {
    var result = baseline;
    final counters = {...baseline.counters};
    for (final event in events.values) {
      // A late legacy import may already include this match. Conservatively
      // suppress its whole delta rather than creating specialist evidence twice.
      result = result.merge(event.evidence);
      if (event.evidence.matches.any(baseline.matches.contains)) continue;
      for (final entry in event.evidence.counters.entries) {
        counters[entry.key] = (counters[entry.key] ?? 0) + entry.value;
      }
    }
    return ProgressBaseline(
      counters: counters,
      matches: result.matches,
      unlocks: result.unlocks,
      legacyUnlocks: result.legacyUnlocks,
      earnedAt: result.earnedAt,
      tutorials: result.tutorials,
      puzzles: result.puzzles,
      unaided: result.unaided,
      tags: result.tags,
    );
  }
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

bool _mapEquals(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length &&
    a.entries.every((entry) => b[entry.key] == entry.value);

Map<String, dynamic> _object(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected progress object');
  }
  return Map<String, dynamic>.from(value);
}

Set<String> _strings(Object? value) {
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('Expected progress identifiers');
  }
  return value.cast<String>().toSet();
}
