import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'game_session_provider.dart';

const _prefsKey = 'achievements_state_v1';

class AchievementState {
  final Set<AchievementType> unlocked;
  final Set<String> completedTutorials;
  final Set<String> completedPuzzles;
  final int totalWins;
  final List<AchievementType> pendingToasts;

  const AchievementState({
    this.unlocked = const {},
    this.completedTutorials = const {},
    this.completedPuzzles = const {},
    this.totalWins = 0,
    this.pendingToasts = const [],
  });

  AchievementState copyWith({
    Set<AchievementType>? unlocked,
    Set<String>? completedTutorials,
    Set<String>? completedPuzzles,
    int? totalWins,
    List<AchievementType>? pendingToasts,
  }) {
    return AchievementState(
      unlocked: unlocked ?? this.unlocked,
      completedTutorials: completedTutorials ?? this.completedTutorials,
      completedPuzzles: completedPuzzles ?? this.completedPuzzles,
      totalWins: totalWins ?? this.totalWins,
      pendingToasts: pendingToasts ?? this.pendingToasts,
    );
  }

  Map<String, dynamic> toJson() => {
        'unlocked': unlocked.map((e) => e.name).toList(),
        'tutorials': completedTutorials.toList(),
        'puzzles': completedPuzzles.toList(),
        'totalWins': totalWins,
      };

  factory AchievementState.fromJson(Map<String, dynamic> json) {
    return AchievementState(
      unlocked: (json['unlocked'] as List<dynamic>? ?? [])
          .map((e) => AchievementType.values
              .firstWhere((a) => a.name == e, orElse: () => AchievementType.firstSteps))
          .toSet(),
      completedTutorials:
          Set<String>.from(json['tutorials'] as List<dynamic>? ?? const []),
      completedPuzzles:
          Set<String>.from(json['puzzles'] as List<dynamic>? ?? const []),
      totalWins: (json['totalWins'] as num?)?.toInt() ?? 0,
    );
  }
}

class AchievementsNotifier extends StateNotifier<AchievementState> {
  AchievementsNotifier() : super(const AchievementState());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        state = AchievementState.fromJson(map);
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  bool isUnlocked(AchievementType type) => state.unlocked.contains(type);

  AchievementType? consumeToast() {
    if (state.pendingToasts.isEmpty) return null;
    final next = state.pendingToasts.first;
    state = state.copyWith(pendingToasts: state.pendingToasts.sublist(1));
    return next;
  }

  void _queueToast(AchievementType type) {
    final pending = [...state.pendingToasts, type];
    state = state.copyWith(pendingToasts: pending);
  }

  Future<void> _unlock(AchievementType type) async {
    if (state.unlocked.contains(type)) return;
    final updated = {...state.unlocked, type};
    state = state.copyWith(unlocked: updated);
    _queueToast(type);
    await _persist();
  }

  Future<void> recordScenarioCompletion(GameScenario scenario) async {
    if (scenario.type == ScenarioType.tutorial) {
      if (!state.completedTutorials.contains(scenario.id)) {
        final tutorials = {...state.completedTutorials, scenario.id};
        state = state.copyWith(completedTutorials: tutorials);
      }
      final allTutorials = tutorialAndPuzzleLibrary
          .where((s) => s.type == ScenarioType.tutorial)
          .map((s) => s.id)
          .toSet();
      if (state.completedTutorials.containsAll(allTutorials)) {
        await _unlock(AchievementType.student);
      }
    } else if (scenario.type == ScenarioType.puzzle) {
      if (!state.completedPuzzles.contains(scenario.id)) {
        final puzzles = {...state.completedPuzzles, scenario.id};
        state = state.copyWith(completedPuzzles: puzzles);
      }
      final allPuzzles = tutorialAndPuzzleLibrary
          .where((s) => s.type == ScenarioType.puzzle)
          .map((s) => s.id)
          .toSet();
      if (state.completedPuzzles.containsAll(allPuzzles)) {
        await _unlock(AchievementType.puzzleSolver);
      }
    }
    await _persist();
  }

  Future<void> recordWin({
    required GameMode mode,
    required GameResult result,
    required WinReason? winReason,
    required AIDifficulty aiDifficulty,
    required bool isLocalPlayerWinner,
    bool isScenario = false,
  }) async {
    if (!isLocalPlayerWinner || result == GameResult.draw || isScenario) return;

    final wins = state.totalWins + 1;
    state = state.copyWith(totalWins: wins);

    if (wins >= 10) {
      await _unlock(AchievementType.dedicated);
    }
    if (wins >= 50) {
      await _unlock(AchievementType.veteran);
    }

    if (winReason == WinReason.time) {
      await _unlock(AchievementType.clockManager);
    }
    if (winReason == WinReason.flats) {
      await _unlock(AchievementType.domination);
    }

    if (mode == GameMode.vsComputer) {
      switch (aiDifficulty) {
        case AIDifficulty.easy:
          await _unlock(AchievementType.firstSteps);
        case AIDifficulty.medium:
          await _unlock(AchievementType.competitor);
        case AIDifficulty.hard:
          await _unlock(AchievementType.strategist);
        case AIDifficulty.expert:
          await _unlock(AchievementType.grandmaster);
      }
    }

    if (mode == GameMode.online) {
      await _unlock(AchievementType.connected);
    }

    await _persist();
  }
}

final achievementsProvider =
    StateNotifierProvider<AchievementsNotifier, AchievementState>((ref) {
  return AchievementsNotifier();
});
