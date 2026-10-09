import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import 'ai.dart';
import 'board_analysis.dart';

/// Factual commentary about a legal move, rather than invented search thoughts.
class CourtCoach {
  static GameState? apply(GameState state, AIMove move) => switch (move) {
        AIPlacementMove() =>
          GameRules.tryPlacePiece(state, move.position, move.pieceType),
        AIStackMove() =>
          GameRules.tryMoveStack(state, move.from, move.direction, move.drops),
      };

  static String square(Position position, int size) =>
      '${String.fromCharCode(97 + position.col)}${size - position.row}';

  static String explain(GameState before, AIMove move) {
    final after = apply(before, move);
    if (after == null) {
      return 'This move is no longer legal. Ask again from the current position.';
    }
    final parts = <String>[];
    switch (move) {
      case AIPlacementMove():
        final type = switch (move.pieceType) {
          PieceType.flat => 'flat stone',
          PieceType.standing => 'standing stone',
          PieceType.capstone => 'capstone',
        };
        parts.add(
            'Place a $type on ${square(move.position, before.boardSize)}.');
        if (before.isOpeningPhase) {
          parts.add(
              'In the opening you place your opponent’s flat, using their reserve. Its location shapes their starting position; it is not part of your own road.');
        } else {
          parts.add(switch (move.pieceType) {
            PieceType.flat =>
              'This adds a road piece and an exposed flat for scoring.',
            PieceType.standing =>
              'This square cannot be covered by ordinary stones. The wall blocks roads, but contributes neither to a road nor to flat scoring.',
            PieceType.capstone =>
              'This road piece cannot be covered and can flatten a wall when it arrives alone. It does not count in flat scoring.',
          });
          final neighbors = move.position
              .adjacentPositions(before.boardSize)
              .where((p) => BoardAnalysis.controlsForRoad(
                  before, p, before.currentPlayer))
              .length;
          if (move.pieceType != PieceType.standing && neighbors > 0) {
            parts.add(
                'It joins $neighbors adjacent friendly road ${neighbors == 1 ? 'square' : 'squares'}.');
          }
        }
      case AIStackMove():
        final picked = move.drops.fold(0, (a, b) => a + b);
        var position = move.from;
        final steps = <String>[];
        var captures = 0;
        var walls = 0;
        for (final drop in move.drops) {
          position = move.direction.apply(position);
          steps.add('drop $drop on ${square(position, before.boardSize)}');
          if (before.board.stackAt(position).controller == before.opponent &&
              after.board.stackAt(position).controller ==
                  before.currentPlayer) {
            captures++;
          }
          if (before.board.stackAt(position).topPiece?.type ==
              PieceType.standing) {
            walls++;
          }
        }
        parts.add(
            'Carry $picked from ${square(move.from, before.boardSize)}: ${steps.join(', then ')}. Drop from the bottom of your hand.');
        if (captures > 0) {
          parts.add(
              'This takes control of $captures opposing ${captures == 1 ? 'square' : 'squares'}.');
        }
        if (walls > 0) {
          parts.add(
              'The capstone arrives alone at the final square, flattening its wall.');
        }
        final source = after.board.stackAt(move.from);
        if (source.isEmpty) {
          parts.add(
              'The source square becomes empty; check whether that breaks your road.');
        }
        if (source.controller == before.opponent) {
          parts.add('The source is left under your opponent’s control.');
        }
    }
    final winner =
        BoardAnalysis.getRoadWinner(after, lastMover: before.currentPlayer);
    if (winner != null) {
      parts.add(winner == before.currentPlayer
          ? 'This completes a winning road. If both roads form, the mover wins.'
          : 'This completes your opponent’s road, so they win.');
    } else if (GameRules.flatResult(after) != null) {
      parts.add(
          'This ends the game by flat scoring. Only exposed flats count; equal counts draw.');
    }
    parts.add(
        'The AI chose this using its limited search and position evaluation. These are concrete effects of the move, not a guarantee that it is best.');
    return parts.join('\n\n');
  }

  /// Both sides can call Tak. Test all legal placements AND spreads, including
  /// capstone flattening, with actual reserves and mover-priority road results.
  static Future<String> warnings(GameState state) async {
    if (state.isGameOver || state.isOpeningPhase) return '';
    final warnings = <String>[];
    var slice = Stopwatch()..start();
    for (final color in PlayerColor.values) {
      final position = state.copyWith(currentPlayer: color);
      for (final move in const AIMoveGenerator().generateMoves(position)) {
        if (slice.elapsedMilliseconds >= 4) {
          await Future<void>.delayed(Duration.zero);
          slice = Stopwatch()..start();
        }
        final after = apply(position, move);
        if (after != null &&
            BoardAnalysis.getRoadWinner(after, lastMover: color) == color) {
          final name = color == PlayerColor.white ? 'White' : 'Black';
          warnings.add(
              'Tak! $name has a legal road win in one move if the position is unchanged.');
          break;
        }
      }
    }
    return warnings.join('\n');
  }
}

Future<String> courtWarnings(GameState state) =>
    kIsWeb ? CourtCoach.warnings(state) : compute(CourtCoach.warnings, state);
