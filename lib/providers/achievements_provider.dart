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
      justUnlocked: clearJustUnlocked ? null : (justUnlocked ?? this.justUnlocked),
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
    final totalWins = prefs.getInt(AchievementKeys.totalWins) ?? 0;
    final onlineWins = prefs.getInt(AchievementKeys.onlineWins) ?? 0;

    // Load completed scenarios
    final tutorialsList = prefs.getStringList(AchievementKeys.completedTutorials) ?? [];
    final puzzlesList = prefs.getStringList(AchievementKeys.completedPuzzles) ?? [];

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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final newUnlocks = <AchievementType>[];

    // Update total wins first
    final newTotalWins = state.totalWins + 1;
    await prefs.setInt(AchievementKeys.totalWins, newTotalWins);

    var newOnlineWins = state.onlineWins;
    if (isOnline) {
      newOnlineWins = state.onlineWins + 1;
      await prefs.setInt(AchievementKeys.onlineWins, newOnlineWins);
    }

    // Update state with new win counts FIRST before checking achievements
    state = state.copyWith(
      totalWins: newTotalWins,
      onlineWins: newOnlineWins,
    );

    // Now check for achievements (each unlock will trigger notification)

    // Online win achievement
    if (isOnline && !state.isUnlocked(AchievementType.connected)) {
      if (await unlock(AchievementType.connected)) {
        newUnlocks.add(AchievementType.connected);
      }
    }

    // AI difficulty achievements
    if (aiDifficulty != null) {
      final aiAchievement = switch (aiDifficulty) {
        AIDifficulty.easy => AchievementType.firstSteps,
        AIDifficulty.medium => AchievementType.competitor,
        AIDifficulty.hard => AchievementType.strategist,
        AIDifficulty.expert => AchievementType.grandmaster,
      };
      if (!state.isUnlocked(aiAchievement)) {
        if (await unlock(aiAchievement)) {
          newUnlocks.add(aiAchievement);
        }
      }
    }

    // Win count achievements
    if (newTotalWins >= 10 && !state.isUnlocked(AchievementType.dedicated)) {
      if (await unlock(AchievementType.dedicated)) {
        newUnlocks.add(AchievementType.dedicated);
      }
    }
    if (newTotalWins >= 50 && !state.isUnlocked(AchievementType.veteran)) {
      if (await unlock(AchievementType.veteran)) {
        newUnlocks.add(AchievementType.veteran);
      }
    }

    // Win condition achievements
    if (byTime && !state.isUnlocked(AchievementType.clockManager)) {
      if (await unlock(AchievementType.clockManager)) {
        newUnlocks.add(AchievementType.clockManager);
      }
    }
    if (byFlats && !state.isUnlocked(AchievementType.domination)) {
      if (await unlock(AchievementType.domination)) {
        newUnlocks.add(AchievementType.domination);
      }
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
    if (state.allTutorialsCompleted && !state.isUnlocked(AchievementType.student)) {
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
    if (state.allPuzzlesCompleted && !state.isUnlocked(AchievementType.puzzleSolver)) {
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
