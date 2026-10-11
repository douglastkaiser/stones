import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/scenario.dart';
import '../services/ai/ai.dart';

/// Keys for SharedPreferences
class AchievementKeys {
  static const String prefix = 'achievement_';
  static const String totalWins = 'stats_total_wins';
  static const String onlineWins = 'stats_online_wins';
  static const String completedTutorials = 'stats_completed_tutorials';
  static const String completedPuzzles = 'stats_completed_puzzles';
  static const String winLedger = 'stats_win_ledger_v1';
}

/// Achievement state containing unlocked achievements and stats
class AchievementState {
  final Set<AchievementType> unlockedAchievements;
  final int totalWins;
  final int onlineWins;
  final Set<String> completedTutorials;
  final Set<String> completedPuzzles;
  final AchievementType? justUnlocked;

  const AchievementState({
    this.unlockedAchievements = const {},
    this.totalWins = 0,
    this.onlineWins = 0,
    this.completedTutorials = const {},
    this.completedPuzzles = const {},
    this.justUnlocked,
  });

  AchievementState copyWith({
    Set<AchievementType>? unlockedAchievements,
    int? totalWins,
    int? onlineWins,
    Set<String>? completedTutorials,
    Set<String>? completedPuzzles,
    AchievementType? justUnlocked,
    bool clearJustUnlocked = false,
  }) {
    return AchievementState(
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      totalWins: totalWins ?? this.totalWins,
      onlineWins: onlineWins ?? this.onlineWins,
      completedTutorials: completedTutorials ?? this.completedTutorials,
      completedPuzzles: completedPuzzles ?? this.completedPuzzles,
      justUnlocked:
          clearJustUnlocked ? null : (justUnlocked ?? this.justUnlocked),
    );
  }

  bool isUnlocked(AchievementType type) => unlockedAchievements.contains(type);

  /// Get all tutorials from library
  static Set<String> get allTutorialIds {
    return tutorialAndPuzzleLibrary
        .where((s) => s.type == ScenarioType.tutorial)
        .map((s) => s.id)
        .toSet();
  }

  /// Get all puzzles from library
  static Set<String> get allPuzzleIds {
    return tutorialAndPuzzleLibrary
        .where((s) => s.type == ScenarioType.puzzle)
        .map((s) => s.id)
        .toSet();
  }

  bool get allTutorialsCompleted =>
      allTutorialIds.every((id) => completedTutorials.contains(id));

  bool get allPuzzlesCompleted =>
      allPuzzleIds.every((id) => completedPuzzles.contains(id));
}

/// Notifier for achievement state with persistence
class AchievementNotifier extends StateNotifier<AchievementState> {
  AchievementNotifier() : super(const AchievementState());
  Future<void> _winWrites = Future.value();
  Set<String> _recordedMatches = {};

  /// Load achievements from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Load unlocked achievements
    final unlockedSet = <AchievementType>{};
    for (final type in AchievementType.values) {
      final key = '${AchievementKeys.prefix}${type.name}';
      if (prefs.getBool(key) ?? false) {
        unlockedSet.add(type);
      }
    }

    // Load stats
    var totalWins = prefs.getInt(AchievementKeys.totalWins) ?? 0;
    var onlineWins = prefs.getInt(AchievementKeys.onlineWins) ?? 0;
    final ledgerJson = prefs.getString(AchievementKeys.winLedger);
    if (ledgerJson != null) {
      final ledger = Map<String, dynamic>.from(jsonDecode(ledgerJson));
      totalWins = ledger['totalWins'] as int;
      onlineWins = ledger['onlineWins'] as int;
      _recordedMatches = (ledger['matches'] as List).cast<String>().toSet();
      unlockedSet.addAll((ledger['unlocks'] as List)
          .cast<String>()
          .map(AchievementType.values.byName));
    }

    // Load completed scenarios
    final tutorialsList =
        prefs.getStringList(AchievementKeys.completedTutorials) ?? [];
    final puzzlesList =
        prefs.getStringList(AchievementKeys.completedPuzzles) ?? [];

    state = AchievementState(
      unlockedAchievements: unlockedSet,
      totalWins: totalWins,
      onlineWins: onlineWins,
      completedTutorials: tutorialsList.toSet(),
      completedPuzzles: puzzlesList.toSet(),
    );
  }

  /// Unlock an achievement and persist
  Future<bool> unlock(AchievementType type) async {
    if (state.isUnlocked(type)) return false;

    final prefs = await SharedPreferences.getInstance();
    final key = '${AchievementKeys.prefix}${type.name}';
    await prefs.setBool(key, true);

    state = state.copyWith(
      unlockedAchievements: {...state.unlockedAchievements, type},
      justUnlocked: type,
    );

    return true;
  }

  /// Clear the just unlocked flag (after showing notification)
  void clearJustUnlocked() {
    state = state.copyWith(clearJustUnlocked: true);
  }

  /// Record a win and check for win-based achievements
  Future<List<AchievementType>> recordWin({
    required bool isOnline,
    required AIDifficulty? aiDifficulty,
    required bool byTime,
    required bool byFlats,
    String? matchId,
  }) {
    final result = Completer<List<AchievementType>>();
    _winWrites = _winWrites.then((value) async {
      try {
        result.complete(await _recordWin(
            isOnline: isOnline,
            aiDifficulty: aiDifficulty,
            byTime: byTime,
            byFlats: byFlats,
            matchId: matchId));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<List<AchievementType>> _recordWin(
      {required bool isOnline,
      required AIDifficulty? aiDifficulty,
      required bool byTime,
      required bool byFlats,
      String? matchId}) async {
    if (matchId != null && _recordedMatches.contains(matchId)) return [];
    final prefs = await SharedPreferences.getInstance();
    final newTotalWins = state.totalWins + 1;
    final newOnlineWins = state.onlineWins + (isOnline ? 1 : 0);
    final candidates = <AchievementType>{
      if (isOnline) AchievementType.connected,
      if (aiDifficulty != null)
        switch (aiDifficulty) {
          AIDifficulty.easy => AchievementType.firstSteps,
          AIDifficulty.medium => AchievementType.competitor,
          AIDifficulty.hard => AchievementType.strategist,
          AIDifficulty.expert => AchievementType.grandmaster,
        },
      if (newTotalWins >= 10) AchievementType.dedicated,
      if (newTotalWins >= 50) AchievementType.veteran,
      if (byTime) AchievementType.clockManager,
      if (byFlats) AchievementType.domination,
    };
    final newUnlocks =
        candidates.difference(state.unlockedAchievements).toList();
    final unlocks = {...state.unlockedAchievements, ...candidates};
    final recorded = {..._recordedMatches, if (matchId != null) matchId};
    // One durable write commits both counters and deduplication. A crash cannot
    // grant a second win or lose an unlock between separate preference writes.
    final saved = await prefs.setString(
        AchievementKeys.winLedger,
        jsonEncode({
          'totalWins': newTotalWins,
          'onlineWins': newOnlineWins,
          'matches': recorded.toList(),
          'unlocks': unlocks.map((a) => a.name).toList(),
        }));
    if (!saved) throw StateError('Win could not be saved');
    _recordedMatches = recorded;
    state = state.copyWith(
        totalWins: newTotalWins,
        onlineWins: newOnlineWins,
        unlockedAchievements: unlocks,
        justUnlocked: newUnlocks.firstOrNull);
    // Maintain the legacy keys for upgrades and existing integrations.
    await prefs.setInt(AchievementKeys.totalWins, newTotalWins);
    await prefs.setInt(AchievementKeys.onlineWins, newOnlineWins);
    for (final type in newUnlocks) {
      await prefs.setBool('${AchievementKeys.prefix}${type.name}', true);
    }
    return newUnlocks;
  }

  /// Record a completed tutorial
  Future<List<AchievementType>> completeTutorial(String tutorialId) async {
    if (state.completedTutorials.contains(tutorialId)) {
      return [];
    }

    final prefs = await SharedPreferences.getInstance();
    final newUnlocks = <AchievementType>[];

    final newCompletedTutorials = {...state.completedTutorials, tutorialId};
    await prefs.setStringList(
      AchievementKeys.completedTutorials,
      newCompletedTutorials.toList(),
    );

    state = state.copyWith(completedTutorials: newCompletedTutorials);

    // Check if all tutorials completed
    if (state.allTutorialsCompleted &&
        !state.isUnlocked(AchievementType.student)) {
      await unlock(AchievementType.student);
      newUnlocks.add(AchievementType.student);
    }

    return newUnlocks;
  }

  /// Record a completed puzzle
  Future<List<AchievementType>> completePuzzle(String puzzleId) async {
    if (state.completedPuzzles.contains(puzzleId)) {
      return [];
    }

    final prefs = await SharedPreferences.getInstance();
    final newUnlocks = <AchievementType>[];

    final newCompletedPuzzles = {...state.completedPuzzles, puzzleId};
    await prefs.setStringList(
      AchievementKeys.completedPuzzles,
      newCompletedPuzzles.toList(),
    );

    state = state.copyWith(completedPuzzles: newCompletedPuzzles);

    // Check if all puzzles completed
    if (state.allPuzzlesCompleted &&
        !state.isUnlocked(AchievementType.puzzleSolver)) {
      await unlock(AchievementType.puzzleSolver);
      newUnlocks.add(AchievementType.puzzleSolver);
    }

    return newUnlocks;
  }

  /// Reset all achievements and stats
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();

    for (final type in AchievementType.values) {
      final key = '${AchievementKeys.prefix}${type.name}';
      await prefs.remove(key);
    }

    await prefs.remove(AchievementKeys.totalWins);
    await prefs.remove(AchievementKeys.onlineWins);
    await prefs.remove(AchievementKeys.completedTutorials);
    await prefs.remove(AchievementKeys.completedPuzzles);
    await prefs.remove(AchievementKeys.winLedger);
    _recordedMatches = {};

    state = const AchievementState();
  }
}

/// Provider for achievement state
final achievementProvider =
    StateNotifierProvider<AchievementNotifier, AchievementState>((ref) {
  return AchievementNotifier();
});

/// Provider for just unlocked achievement (for notifications)
final justUnlockedAchievementProvider = Provider<AchievementType?>((ref) {
  return ref.watch(achievementProvider).justUnlocked;
});

/// Provider for checking if a specific achievement is unlocked
final isAchievementUnlockedProvider =
    Provider.family<bool, AchievementType>((ref, type) {
  return ref.watch(achievementProvider).isUnlocked(type);
});
