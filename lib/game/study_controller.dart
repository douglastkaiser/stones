import 'match_controller.dart';
import 'match_rules.dart';
import 'match_state.dart';
import 'match_storage.dart';
import 'match_study.dart';

/// Learning uses the match shell and engine, with catalog-specific objectives.
/// Its sandbox never overwrites the player's saved match or competitive result.
class StudyController extends MatchController {
  StudyController(this.study, {this.onSolved})
      : super(
            storage: _StudyStorage(),
            authenticate: () async => '',
            store: () => throw StateError('Learning is offline')) {
    reset();
  }
  final MatchStudy study;
  final Future<void> Function(MatchStudy)? onSolved;
  int steps = 0;
  bool solved = false, failed = false;
  bool _rewarded = false;
  void reset() {
    steps = 0;
    solved = false;
    failed = false;
    state = MatchSession(id: 'study-${study.id}', game: study.initial);
  }

  @override
  Future<bool> play(MatchMove move, {bool bot = false}) async {
    if (!state.canPlay || solved || failed || bot) return false;
    final before = state.game!;
    var next = MatchRules.play(before, move);
    if (next == null) return false;
    if (!study.accepts(move, steps)) {
      state = state.copyWith(
          error: 'Try the lesson’s objective. Your board has not changed.');
      return false;
    }
    steps++;
    if (study.puzzle && steps == 1 && !next.finished && study.moveLimit > 1) {
      final replies = study.replies(move);
      if (replies == null) {
        failed = true;
      } else {
        for (final reply in replies) {
          if (next!.finished) break;
          next = MatchRules.play(next, reply);
          if (next == null) {
            failed = true;
            break;
          }
        }
      }
    }
    final game = next ?? before;
    solved = !failed && study.success(game, steps);
    failed = failed ||
        (study.puzzle &&
            !solved &&
            (game.finished || steps >= study.moveLimit));
    state = state.copyWith(
        game: game,
        inputLocked: solved || failed,
        explanation: solved
            ? 'Complete! ${study.explanation}'
            : failed
                ? 'No win within the move limit. Retry and try another idea.'
                : study.puzzle
                    ? 'Your turn: ${study.moveLimit - steps} move remaining.'
                    : 'Opening exchange: ${game.current.label} places ${game.config.next(game.current).label}’s flat.');
    if (solved && !_rewarded) {
      try {
        await onSolved?.call(study);
        _rewarded = true;
      } catch (error) {
        if (mounted) {
          state = state.copyWith(
              error: 'Solved; progress could not be saved: $error');
        }
      }
    }
    return true;
  }
}

class _StudyStorage implements LocalMatchStorage {
  @override
  Future<Map<String, dynamic>?> read() async => null;
  @override
  Future<void> write(Map<String, dynamic> snapshot) async {}
}
