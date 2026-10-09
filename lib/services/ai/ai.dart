import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import 'lookahead_ai.dart';
import 'move_generator.dart';

/// AI difficulty levels
enum AIDifficulty { easy, medium, hard, expert }

extension AIDifficultyPresentation on AIDifficulty {
  String get label => name[0].toUpperCase() + name.substring(1);
  String get description => switch (this) {
        AIDifficulty.easy => 'A gentle first opponent',
        AIDifficulty.medium => 'More options, fewer mistakes',
        AIDifficulty.hard => 'Looks three turns ahead',
        AIDifficulty.expert => 'Deepest search; may take longer',
      };
}

/// Keep native search off the UI thread. Web search yields between candidates.
Future<AIMove?> selectStonesMove(GameState state, AIDifficulty difficulty) =>
    kIsWeb
        ? StonesAI.forDifficulty(difficulty).selectMove(state)
        : compute(_selectStonesMove, (state, difficulty));

Future<AIMove?> _selectStonesMove((GameState, AIDifficulty) request) =>
    StonesAI.forDifficulty(request.$2).selectMove(request.$1);

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
      AIDifficulty.easy => LookaheadStonesAI(
          rng,
          searchDepth: 2,
          maxBranchingLimit: 10,
          midBranchingLimit: 8,
          evaluationJitter: 0.08,
        ),
      AIDifficulty.medium => LookaheadStonesAI(
          rng,
          searchDepth: 2,
          maxBranchingLimit: 16,
          midBranchingLimit: 12,
          evaluationJitter: 0.05,
        ),
      AIDifficulty.hard => LookaheadStonesAI(
          rng,
          searchDepth: 3,
          maxBranchingLimit: 14,
          midBranchingLimit: 10,
          deepBranchingLimit: 8,
          evaluationJitter: 0.03,
        ),
      AIDifficulty.expert => LookaheadStonesAI(
          rng,
          searchDepth: 4,
          maxBranchingLimit: 12,
          midBranchingLimit: 9,
          deepBranchingLimit: 6,
          evaluationJitter: 0.015,
        ),
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
