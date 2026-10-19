import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/match_completed.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/study_catalog.dart';
import 'package:stones/progression/progress_merge.dart';
import 'package:stones/progression/progress_recorder.dart';
import 'package:stones/progression/progress_repository.dart';

import '../fixtures/achievement_matches.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'legal replay produces deterministic additive metrics across shapes/seats',
      () {
    for (final shape in BoardShape.values) {
      for (var count = 2; count <= 4; count++) {
        final result = roadMatch(shape: shape, count: count);
        final first = matchProgressEvent(result)!;
        final replay = matchProgressEvent(result)!;
        expect(first.sameAs(replay), isTrue);
        expect(first.evidence.counters['wins'], 1);
        expect(first.evidence.counters['roadWins'], 1);
        expect(first.evidence.counters.containsKey('streakResult'), isFalse);
        expect(first.evidence.earnedAt, isEmpty);
        expect(first.evidence.unlocks, isEmpty);
        final merged =
            AccountProgress(owner: 'alice').record(first).record(replay);
        expect(merged.materialize.counters['wins'], 1);
      }
    }
  });

  test('practice and terminal flags without full history produce no event', () {
    expect(matchProgressEvent(roadMatch(court: true)), isNull);
    final valid = roadMatch();
    final missingHistory =
        MatchCompleted(MatchSession(id: valid.id, game: valid.game));
    expect(matchProgressEvent(missingHistory), isNull);
  });

  test('expert and online evidence retains distinct tags without award dates',
      () {
    final expert = matchProgressEvent(roadMatch(level: BotLevel.expert))!;
    expect(expert.evidence.tags['expertSizes'], {'5'});
    final online = matchProgressEvent(roadMatch(online: true))!;
    expect(online.evidence.counters['onlineWins'], 1);
    expect(online.evidence.tags['opponents'], {'opponent-1'});
    expect(online.evidence.earnedAt, isEmpty);
  });

  test('normalized legacy result ID cannot award the same match twice', () {
    final first = matchProgressEvent(roadMatch(id: 'room:11:road'))!;
    final replay = matchProgressEvent(roadMatch(id: 'room'))!;
    expect(first.id, 'match:room');
    expect(first.sameAs(replay), isTrue);
    expect(
        AccountProgress(owner: 'alice')
            .record(first)
            .record(replay)
            .materialize
            .counters['wins'],
        1);
  });

  test('learning accepts catalog IDs and upgrades unaided without new totals',
      () {
    final lesson = matchStudies.firstWhere((study) => !study.puzzle).id;
    final puzzle = matchStudies.firstWhere((study) => study.puzzle).id;
    final progress = AccountProgress(owner: 'alice')
        .record(studyProgressEvent(lesson)!)
        .record(studyProgressEvent(puzzle)!)
        .record(studyProgressEvent(puzzle, unassisted: true)!)
        .record(studyProgressEvent(puzzle, unassisted: true)!);
    expect(progress.materialize.tutorials, {lesson});
    expect(progress.materialize.puzzles, {puzzle});
    expect(progress.materialize.unaided, {puzzle});
    expect(progress.materialize.counters, isEmpty);
    expect(studyProgressEvent('unverified-study'), isNull);
  });

  test('bound recorder persists before sync and rejects other online owners',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cache =
        PreferencesProgressCache(await SharedPreferences.getInstance());
    final repository = ProgressRepository(owner: 'wrong-owner', cache: cache);
    final recorder = ProgressRecorder(repository);
    expect(await recorder.recordMatch(roadMatch(online: true)), isNull);
    expect(repository.current, isNull);
    final local = roadMatch();
    await recorder.recordMatch(local);
    await recorder.recordMatch(local);
    final restarted = ProgressRepository(owner: 'wrong-owner', cache: cache);
    expect((await restarted.load()).materialize.counters['wins'], 1);
  });
}
