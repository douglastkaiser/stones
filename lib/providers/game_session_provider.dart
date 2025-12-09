import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  const GameSessionConfig({
    this.mode = GameMode.local,
    this.aiDifficulty = AIDifficulty.easy,
  });

  GameSessionConfig copyWith({
    GameMode? mode,
    AIDifficulty? aiDifficulty,
  }) {
    return GameSessionConfig(
      mode: mode ?? this.mode,
      aiDifficulty: aiDifficulty ?? this.aiDifficulty,
    );
  }
}

/// Provider for the current game session configuration
final gameSessionProvider =
    StateProvider<GameSessionConfig>((ref) => const GameSessionConfig());

/// Whether the AI is currently thinking
final aiThinkingProvider = StateProvider<bool>((ref) => false);
