import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scenario.dart';
import '../services/ai/ai.dart';

/// Type of game being played
enum GameMode {
  local,
  vsComputer,
  online,
}

/// Session configuration for the current game
class GameSessionConfig {
  final GameMode mode;
  final AIDifficulty aiDifficulty;
  final GameScenario? scenario;
  final int? chessClockSecondsOverride;

  const GameSessionConfig({
    this.mode = GameMode.local,
    this.aiDifficulty = AIDifficulty.easy,
    this.scenario,
    this.chessClockSecondsOverride,
  });

  GameSessionConfig copyWith({
    GameMode? mode,
    AIDifficulty? aiDifficulty,
    GameScenario? scenario,
    int? chessClockSecondsOverride,
    bool clearScenario = false,
  }) {
    return GameSessionConfig(
      mode: mode ?? this.mode,
      aiDifficulty: aiDifficulty ?? this.aiDifficulty,
      scenario: clearScenario ? null : (scenario ?? this.scenario),
      chessClockSecondsOverride: chessClockSecondsOverride ?? this.chessClockSecondsOverride,
    );
  }
}

/// Provider for the current game session configuration
final gameSessionProvider =
    StateProvider<GameSessionConfig>((ref) => const GameSessionConfig());

/// Whether the AI is currently thinking (blocks input)
final aiThinkingProvider = StateProvider<bool>((ref) => false);

/// Whether the AI thinking indicator should be visible (shown after 500ms delay)
final aiThinkingVisibleProvider = StateProvider<bool>((ref) => false);
