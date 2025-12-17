import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
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
  final bool chessClockEnabled;
  final int chessClockSeconds;
  final PlayerColor playerColor;

  const GameSessionConfig({
    this.mode = GameMode.local,
    this.aiDifficulty = AIDifficulty.intro,
    this.scenario,
    this.chessClockEnabled = false,
    this.chessClockSeconds = 300,
    this.playerColor = PlayerColor.white,
  });

  GameSessionConfig copyWith({
    GameMode? mode,
    AIDifficulty? aiDifficulty,
    GameScenario? scenario,
    bool clearScenario = false,
    bool? chessClockEnabled,
    int? chessClockSeconds,
    PlayerColor? playerColor,
  }) {
    return GameSessionConfig(
      mode: mode ?? this.mode,
      aiDifficulty: aiDifficulty ?? this.aiDifficulty,
      scenario: clearScenario ? null : (scenario ?? this.scenario),
      chessClockEnabled: chessClockEnabled ?? this.chessClockEnabled,
      chessClockSeconds: chessClockSeconds ?? this.chessClockSeconds,
      playerColor: playerColor ?? this.playerColor,
    );
  }
}

/// Provider for the current game session configuration
final gameSessionProvider =
    StateProvider<GameSessionConfig>((ref) => const GameSessionConfig());

/// Whether the AI is currently thinking
final aiThinkingProvider = StateProvider<bool>((ref) => false);
