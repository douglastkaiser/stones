import '../game/match_completed.dart';
import '../game/study_catalog.dart';
import 'progress_merge.dart';
import 'progress_repository.dart';

/// Bind to the account repository when a game/study starts, not when its delayed
/// completion arrives. Auth switching must not reattribute an in-flight result.
/// This adapter is not enabled in the live provider until sync is qualified.
class ProgressRecorder {
  const ProgressRecorder(this.repository);
  final ProgressRepository repository;

  Future<AccountProgress?> recordMatch(MatchCompleted result) async {
    if (result.online && result.uid != repository.owner) return null;
    final event = matchProgressEvent(result);
    return event == null ? null : repository.record(event);
  }

  Future<AccountProgress?> completeStudy(String id,
      {bool unassisted = false}) async {
    final event = studyProgressEvent(id, unassisted: unassisted);
    return event == null ? null : repository.record(event);
  }
}

/// Uses the same full legal replay and eligibility checks as local achievements.
/// No wall-clock timestamps/derived awards enter a retryable event payload.
ProgressEvent? matchProgressEvent(MatchCompleted result) {
  final metrics = result.verifiedMetrics();
  if (metrics == null) return null;
  final match = result.id.replaceFirst(
      RegExp(r':\d+:(road|flats|time|resignation|abandoned)$'), '');
  if (match.isEmpty) return null;
  return ProgressEvent(
    id: 'match:$match',
    evidence: ProgressBaseline(
      matches: {match},
      counters: {
        for (final entry in metrics.entries)
          if (entry.key != 'streakResult') entry.key: entry.value,
      },
      tags: {
        if (metrics.containsKey('onlineWins')) 'opponents': result.opponentIds,
        if (metrics.containsKey('expertWins'))
          'expertSizes': {'${result.game.config.size}'},
      },
    ),
  );
}

/// Completion sets carry their own identity; assisted then unaided solves can
/// upgrade the same puzzle without incrementing a completion counter twice.
ProgressEvent? studyProgressEvent(String id, {bool unassisted = false}) {
  final study = matchStudies.where((study) => study.id == id).firstOrNull;
  if (study == null) return null;
  return ProgressEvent(
      id: study.puzzle
          ? 'puzzle:$id:${unassisted ? 'unaided' : 'assisted'}'
          : 'tutorial:$id',
      evidence: ProgressBaseline(
        tutorials: {if (!study.puzzle) id},
        puzzles: {if (study.puzzle) id},
        unaided: {if (study.puzzle && unassisted) id},
      ));
}
