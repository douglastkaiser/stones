import 'dart:math';

import '../../models/models.dart';
import 'intro_ai.dart';
import 'easy_ai.dart';
import 'medium_ai.dart';
import 'hard_ai.dart';
import 'move_generator.dart';

/// AI difficulty levels
enum AIDifficulty { intro, easy, medium, hard }

/// Base class for Stones AI opponents
abstract class StonesAI {
  StonesAI(this.random);

  final Random random;

  /// Choose the next move for the given game state
  Future<AIMove?> selectMove(GameState state);

  /// Factory to create an AI for the chosen difficulty
  factory StonesAI.forDifficulty(AIDifficulty difficulty, {Random? random}) {
    final rng = random ?? Random();
    return switch (difficulty) {
      AIDifficulty.intro => IntroStonesAI(rng),
      AIDifficulty.easy => EasyStonesAI(rng),
      AIDifficulty.medium => MediumStonesAI(rng),
      AIDifficulty.hard => HardStonesAI(rng),
    };
  }
}

/// Base class for AI move descriptions
sealed class AIMove {}

/// Placement move
class AIPlacementMove extends AIMove {
  final Position position;
  final PieceType pieceType;

  const AIPlacementMove(this.position, this.pieceType);
}

/// Stack movement move
class AIStackMove extends AIMove {
  final Position from;
  final Direction direction;
  final List<int> drops;

  AIStackMove(this.from, this.direction, this.drops);
}

/// Utility to build move generators
class AIMoveGenerator {
  const AIMoveGenerator();

  /// Generate all legal moves for the current player
  List<AIMove> generateMoves(GameState state) {
    final generator = MoveGenerator(state);
    return [
      ...generator.generatePlacements(),
      ...generator.generateStackMoves(),
    ];
  }
}
