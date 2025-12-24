import 'dart:math';

import '../../models/models.dart';
import 'lookahead_ai.dart';
import 'move_generator.dart';

/// AI difficulty levels
enum AIDifficulty { easy, medium, hard, expert }

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
      AIDifficulty.easy => LookaheadStonesAI(rng, searchDepth: 1),
      AIDifficulty.medium => LookaheadStonesAI(rng, searchDepth: 2),
      AIDifficulty.hard => LookaheadStonesAI(rng, searchDepth: 3),
      AIDifficulty.expert => LookaheadStonesAI(rng, searchDepth: 4),
    };
  }
}

/// Base class for AI move descriptions
sealed class AIMove {
  const AIMove();
}

/// Placement move
class AIPlacementMove extends AIMove {
  final Position position;
  final PieceType pieceType;

  const AIPlacementMove(this.position, this.pieceType) : super();
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
