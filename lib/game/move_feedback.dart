import '../models/piece.dart';
import 'board_geometry.dart';
import 'match_state.dart';

/// Ephemeral presentation data, never part of a save or room protocol.
class MoveFeedbackBatch {
  MoveFeedbackBatch(List<ConfirmedMoveFeedback> moves)
      : token = ++_nextToken,
        moves = List.unmodifiable(moves);
  static int _nextToken = 0;
  final int token;
  final List<ConfirmedMoveFeedback> moves;
}

class ConfirmedMoveFeedback {
  ConfirmedMoveFeedback(this.before, this.move, this.after);
  final MatchState before, after;
  final MatchMove move;

  static const landingMilliseconds = 280;
  static const contactMilliseconds = 100;

  int get staggerMilliseconds => move.drops.length <= 1
      ? 0
      : (140 ~/ (move.drops.length - 1)).clamp(0, 35);
  int get durationMilliseconds =>
      landingMilliseconds +
      (move.drops.isEmpty ? 0 : move.drops.length - 1) * staggerMilliseconds;

  List<StoneLanding> get landings {
    if (move.type != null) {
      return [StoneLanding(move.from, 0, 1, 0, false)];
    }
    var cell = move.from;
    final result = <StoneLanding>[];
    for (var i = 0; i < move.drops.length; i++) {
      cell = cell.step(move.direction!);
      result.add(StoneLanding(
        cell,
        after.stackAt(cell).length - move.drops[i],
        move.drops[i],
        i * staggerMilliseconds,
        before.topAt(cell)?.type == PieceType.standing &&
            after.topAt(cell)?.type == PieceType.capstone,
      ));
    }
    return result;
  }
}

class StoneLanding {
  const StoneLanding(this.cell, this.startIndex, this.count,
      this.delayMilliseconds, this.crush);
  final Cell cell;
  final int startIndex, count, delayMilliseconds;
  final bool crush;

  double progress(double elapsedMilliseconds) =>
      ((elapsedMilliseconds - delayMilliseconds) /
              ConfirmedMoveFeedback.landingMilliseconds)
          .clamp(0, 1);
}
