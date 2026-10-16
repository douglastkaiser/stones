import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/match_completed.dart';
import '../game/match_config.dart';
import '../game/study_catalog.dart';
import '../models/achievement.dart';

class AchievementKeys {
  static const prefix = 'achievement_';
  static const totalWins = 'stats_total_wins';
  static const onlineWins = 'stats_online_wins';
  static const completedTutorials = 'stats_completed_tutorials';
  static const completedPuzzles = 'stats_completed_puzzles';
  static const winLedger = 'stats_win_ledger_v1';
  static const progression = 'achievement_progression_v2';
}

class AchievementState {
  const AchievementState(
      {this.unlockedAchievements = const {},
      this.metrics = const {},
      this.tags = const {},
      this.completedTutorials = const {},
      this.completedPuzzles = const {},
      this.unaidedPuzzles = const {},
      this.earnedAt = const {},
      this.legacyUnlocks = const {},
      this.pending = const [],
      this.loaded = false,
      this.storageError});
  final Set<AchievementType> unlockedAchievements, legacyUnlocks;
  final Map<String, int> metrics;
  final Map<String, Set<String>> tags;
  final Set<String> completedTutorials, completedPuzzles, unaidedPuzzles;
  final Map<AchievementType, DateTime> earnedAt;
  final List<AchievementType> pending;
  final bool loaded;
  final String? storageError;
  int get totalWins => metrics['wins'] ?? 0;
  int get onlineWins => metrics['onlineWins'] ?? 0;
  AchievementType? get justUnlocked => pending.firstOrNull;
  bool isUnlocked(AchievementType type) => unlockedAchievements.contains(type);
  static final Set<String> allTutorialIds = {
    for (final study in matchStudies)
      if (!study.puzzle) study.id
  };
  static final Set<String> allPuzzleIds = {
    for (final study in matchStudies)
      if (study.puzzle) study.id
  };
  static Set<String> puzzleIds(BoardShape shape) => {
        for (final study in matchStudies)
          if (study.puzzle && study.initial.config.shape == shape) study.id
      };
  bool get allTutorialsCompleted =>
      completedTutorials.containsAll(allTutorialIds);
  bool get allPuzzlesCompleted => completedPuzzles.containsAll(allPuzzleIds);
  int get points => achievements
      .where((a) => isUnlocked(a.type))
      .fold(0, (sum, a) => sum + a.points);
  String get rank => points >= 1400
      ? 'Legend'
      : points >= 850
          ? 'Master'
          : points >= 400
              ? 'Tactician'
              : points >= 150
                  ? 'Craftsman'
                  : 'Apprentice';
  int value(String metric) => switch (metric) {
        'tutorials' => completedTutorials.intersection(allTutorialIds).length,
        'puzzles' => completedPuzzles.intersection(allPuzzleIds).length,
        'squarePuzzles' =>
          completedPuzzles.intersection(puzzleIds(BoardShape.square)).length,
        'hexPuzzles' =>
          completedPuzzles.intersection(puzzleIds(BoardShape.hex)).length,
        'cleanSquare' =>
          unaidedPuzzles.intersection(puzzleIds(BoardShape.square)).length,
        'cleanHex' =>
          unaidedPuzzles.intersection(puzzleIds(BoardShape.hex)).length,
        'opponents' || 'expertSizes' => tags[metric]?.length ?? 0,
        _ => metrics[metric] ?? 0,
      };
  int target(AchievementRequirement requirement) => requirement.target > 0
      ? requirement.target
      : switch (requirement.metric) {
          'tutorials' => allTutorialIds.length,
          'puzzles' => allPuzzleIds.length,
          'squarePuzzles' => puzzleIds(BoardShape.square).length,
          'hexPuzzles' => puzzleIds(BoardShape.hex).length,
          _ => 1,
        };
  double progress(GameAchievement achievement) =>
      achievement.requirements
          .map((r) => (value(r.metric) / target(r)).clamp(0.0, 1.0))
          .fold(0.0, (sum, v) => sum + v) /
      achievement.requirements.length;

  AchievementState copyWith(
          {Set<AchievementType>? unlockedAchievements,
          Map<String, int>? metrics,
          Map<String, Set<String>>? tags,
          Set<String>? completedTutorials,
          Set<String>? completedPuzzles,
          Set<String>? unaidedPuzzles,
          Map<AchievementType, DateTime>? earnedAt,
          Set<AchievementType>? legacyUnlocks,
          List<AchievementType>? pending,
          bool? loaded,
          String? storageError}) =>
      AchievementState(
          unlockedAchievements:
              unlockedAchievements ?? this.unlockedAchievements,
          metrics: metrics ?? this.metrics,
          tags: tags ?? this.tags,
          completedTutorials: completedTutorials ?? this.completedTutorials,
          completedPuzzles: completedPuzzles ?? this.completedPuzzles,
          unaidedPuzzles: unaidedPuzzles ?? this.unaidedPuzzles,
          earnedAt: earnedAt ?? this.earnedAt,
          legacyUnlocks: legacyUnlocks ?? this.legacyUnlocks,
          pending: pending ?? this.pending,
          loaded: loaded ?? this.loaded,
          storageError: storageError);
}

/// All operations (including load, learning, reset and unlocks) share one queue.
/// One durable document commits evidence, deduplication and awards together.
class AchievementNotifier extends StateNotifier<AchievementState> {
  AchievementNotifier({Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance,
        super(const AchievementState());
  final Future<SharedPreferences> Function() _preferences;
  Future<void> _writes = Future.value();
  Set<String> _matches = {};
  Set<String> _unknownUnlocks = {};
  Future<T> _queue<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _writes = _writes.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        if (mounted) {
          state = state.copyWith(
              storageError:
                  'Progress could not be saved or loaded. Retry; your saved data has not been replaced.');
        }
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  static Set<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toSet() : {};
  static Set<AchievementType> _types(Object? value) => {
        for (final name in _strings(value))
          ...AchievementType.values.where((type) => type.name == name)
      };
  static int _count(Object? value) => value is int && value >= 0 ? value : 0;
  static String _matchKey(String value) => value.replaceFirst(
      RegExp(r':\d+:(road|flats|time|resignation|abandoned)$'), '');

  Future<void> load() => _queue(() async {
        try {
          await _read();
        } catch (_) {
          if (mounted) {
            state = state.copyWith(
                storageError:
                    'Progress could not be loaded. Retry; your saved data has not been replaced.');
          }
        }
      });

  Future<void> _read() async {
    if (state.loaded) return;
    final prefs = await _preferences();
    final encoded = prefs.getString(AchievementKeys.progression);
    if (encoded != null) {
      final data = Map<String, dynamic>.from(jsonDecode(encoded));
      if (data['version'] != 2 ||
          data['metrics'] is! Map ||
          data['matches'] is! List ||
          data['unlocks'] is! List ||
          data['tutorials'] is! List ||
          data['puzzles'] is! List) {
        throw const FormatException(
            'Unsupported or incomplete progression save');
      }
      final dates = Map<String, dynamic>.from(data['earnedAt'] as Map? ?? {});
      _matches = _strings(data['matches']);
      _unknownUnlocks = _strings(data['unlocks'])
          .difference(AchievementType.values.map((a) => a.name).toSet());
      if (mounted) {
        state = AchievementState(
            loaded: true,
            metrics: Map<String, dynamic>.from(data['metrics'])
                .map((k, v) => MapEntry(k, _count(v))),
            tags: Map<String, dynamic>.from(data['tags'] as Map? ?? {})
                .map((k, v) => MapEntry(k, _strings(v))),
            unlockedAchievements: _types(data['unlocks']),
            legacyUnlocks: _types(data['legacyUnlocks']),
            pending: _types(data['pending']).toList(),
            completedTutorials: _strings(data['tutorials']),
            completedPuzzles: _strings(data['puzzles']),
            unaidedPuzzles: _strings(data['unaided']),
            earnedAt: {
              for (final type in AchievementType.values)
                if (dates[type.name] is String &&
                    DateTime.tryParse(dates[type.name]) != null)
                  type: DateTime.parse(dates[type.name])
            });
      }
      return;
    }
    // Legacy unlocks stay earned, even where new requirements are harder.
    final legacy = {
      for (final type in AchievementType.values)
        if (prefs.getBool('${AchievementKeys.prefix}${type.name}') ?? false)
          type
    };
    var wins = prefs.getInt(AchievementKeys.totalWins) ?? 0;
    var online = prefs.getInt(AchievementKeys.onlineWins) ?? 0;
    final ledger = prefs.getString(AchievementKeys.winLedger);
    if (ledger != null) {
      final data = Map<String, dynamic>.from(jsonDecode(ledger));
      if (data['matches'] is! List || data['unlocks'] is! List) {
        throw const FormatException('Incomplete legacy ledger');
      }
      wins = _count(data['totalWins']);
      online = _count(data['onlineWins']);
      legacy.addAll(_types(data['unlocks']));
      _unknownUnlocks = _strings(data['unlocks'])
          .difference(AchievementType.values.map((a) => a.name).toSet());
      _matches = _strings(data['matches']).map(_matchKey).toSet();
    }
    final lessons = {
      ...?prefs.getStringList(AchievementKeys.completedTutorials)
    };
    final puzzles = {...?prefs.getStringList(AchievementKeys.completedPuzzles)};
    final other = {
      ...?prefs.getStringList(hexLearningProgressKey),
      ...?prefs.getStringList(unifiedLearningProgressKey)
    };
    lessons.addAll(other.intersection(AchievementState.allTutorialIds));
    puzzles.addAll(other.intersection(AchievementState.allPuzzleIds));
    if (mounted) {
      state = AchievementState(
          loaded: true,
          legacyUnlocks: legacy,
          unlockedAchievements: legacy,
          metrics: {'wins': _count(wins), 'onlineWins': _count(online)},
          completedTutorials: lessons,
          completedPuzzles: puzzles);
    }
  }

  Future<List<AchievementType>> _commit(
      AchievementState next, Set<String> matches,
      {bool evaluate = true}) async {
    final awards = evaluate
        ? achievements
            .where((a) =>
                !next.isUnlocked(a.type) &&
                a.requirements.every((r) =>
                    next.target(r) > 0 &&
                    next.value(r.metric) >= next.target(r)))
            .map((a) => a.type)
            .toList()
        : <AchievementType>[];
    final now = DateTime.now().toUtc();
    next = next.copyWith(
        unlockedAchievements: {...next.unlockedAchievements, ...awards},
        earnedAt: {...next.earnedAt, for (final type in awards) type: now},
        pending: [...next.pending, ...awards],
        loaded: true);
    final prefs = await _preferences();
    final saved = await prefs.setString(
        AchievementKeys.progression,
        jsonEncode({
          'version': 2,
          'metrics': next.metrics,
          'tags': next.tags.map((k, v) => MapEntry(k, v.toList())),
          'matches': matches.toList(),
          'unlocks': {
            ...next.unlockedAchievements.map((a) => a.name),
            ..._unknownUnlocks
          }.toList(),
          'legacyUnlocks': next.legacyUnlocks.map((a) => a.name).toList(),
          'earnedAt': next.earnedAt
              .map((k, v) => MapEntry(k.name, v.toIso8601String())),
          'pending': next.pending.map((a) => a.name).toList(),
          'tutorials': next.completedTutorials.toList(),
          'puzzles': next.completedPuzzles.toList(),
          'unaided': next.unaidedPuzzles.toList(),
        }));
    if (!saved) throw StateError('Progress storage unavailable');
    _matches = matches;
    if (mounted) state = next;
    return awards;
  }

  Future<List<AchievementType>> recordMatch(MatchCompleted event) =>
      _queue(() async {
        await _read();
        final key = _matchKey(event.id);
        if (_matches.contains(key)) return [];
        final delta = event.verifiedMetrics();
        if (delta == null) return [];
        final metrics = {...state.metrics};
        for (final entry
            in delta.entries.where((e) => e.key != 'streakResult')) {
          metrics[entry.key] = (metrics[entry.key] ?? 0) + entry.value;
        }
        if (delta.containsKey('streakResult')) {
          final current =
              delta['streakResult'] == 1 ? (metrics['hardStreak'] ?? 0) + 1 : 0;
          metrics['hardStreak'] = current;
          if (current > (metrics['bestHardStreak'] ?? 0)) {
            metrics['bestHardStreak'] = current;
          }
        }
        final tags = {
          for (final e in state.tags.entries) e.key: {...e.value}
        };
        if (delta.containsKey('onlineWins')) {
          tags['opponents'] = {...?tags['opponents'], ...event.opponentIds};
        }
        if (delta.containsKey('expertWins')) {
          tags['expertSizes'] = {
            ...?tags['expertSizes'],
            '${event.game.config.size}'
          };
        }
        return _commit(
            state.copyWith(metrics: metrics, tags: tags), {..._matches, key});
      });

  Future<List<AchievementType>> completeTutorial(String id) =>
      _lesson(id, false, false);
  Future<List<AchievementType>> completePuzzle(String id,
          {bool unassisted = false}) =>
      _lesson(id, true, unassisted);
  Future<List<AchievementType>> _lesson(String id, bool puzzle, bool clean) =>
      _queue(() async {
        await _read();
        final known = puzzle
            ? AchievementState.allPuzzleIds
            : AchievementState.allTutorialIds;
        if (!known.contains(id)) return [];
        if (puzzle
            ? state.completedPuzzles.contains(id) &&
                (!clean || state.unaidedPuzzles.contains(id))
            : state.completedTutorials.contains(id)) {
          return [];
        }
        return _commit(
            state.copyWith(completedTutorials: {
              ...state.completedTutorials,
              if (!puzzle) id
            }, completedPuzzles: {
              ...state.completedPuzzles,
              if (puzzle) id
            }, unaidedPuzzles: {
              ...state.unaidedPuzzles,
              if (puzzle && clean) id
            }),
            _matches);
      });

  Future<bool> unlock(AchievementType type) => _queue(() async {
        await _read();
        if (state.isUnlocked(type)) return false;
        await _commit(
            state.copyWith(
                unlockedAchievements: {...state.unlockedAchievements, type},
                earnedAt: {...state.earnedAt, type: DateTime.now().toUtc()},
                pending: [...state.pending, type]),
            _matches,
            evaluate: false);
        return true;
      });
  Future<void> acknowledgeUnlocks(Iterable<AchievementType> types) =>
      _queue(() async {
        await _read();
        await _commit(
            state.copyWith(
                pending:
                    state.pending.where((a) => !types.contains(a)).toList()),
            _matches,
            evaluate: false);
      });
  void clearJustUnlocked() {
    unawaited(acknowledgeUnlocks(state.pending).catchError((Object _) {}));
  }

  Future<void> resetAll() => _queue(() async {
        // The new authoritative save shadows legacy keys, even if cleanup fails.
        _unknownUnlocks = {};
        await _commit(const AchievementState(loaded: true), {},
            evaluate: false);
      });
}

final achievementProvider =
    StateNotifierProvider<AchievementNotifier, AchievementState>(
        (ref) => AchievementNotifier());
final justUnlockedAchievementProvider = Provider<AchievementType?>(
    (ref) => ref.watch(achievementProvider).justUnlocked);
final isAchievementUnlockedProvider = Provider.family<bool, AchievementType>(
    (ref, type) => ref.watch(achievementProvider).isUnlocked(type));
