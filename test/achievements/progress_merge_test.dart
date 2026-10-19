import 'package:flutter_test/flutter_test.dart';
import 'package:stones/progression/progress_merge.dart';

ProgressEvent win(String match, {int wins = 1}) => ProgressEvent(
      id: 'match:$match',
      evidence: ProgressBaseline(
          matches: {match}, counters: {'wins': wins, 'roadWins': wins}),
    );

void main() {
  test('overlapping legacy counters use maxima and preserve unknown unlocks',
      () {
    final a = AccountProgress(
        owner: 'alice',
        baseline: ProgressBaseline(
            counters: {'wins': 12, 'onlineWins': 3},
            matches: {'old-a'},
            unlocks: {'future-set'},
            legacyUnlocks: {'future-set'},
            tutorials: {'old-lesson'},
            puzzles: {'old-study'}));
    final b = AccountProgress(
        owner: 'alice',
        baseline: ProgressBaseline(
            counters: {'wins': 10, 'onlineWins': 4},
            matches: {'old-a', 'old-b'},
            puzzles: {'old-study'},
            unaided: {'old-study'}));
    final merged = a.merge(b).materialize;
    expect(merged.counters, {'wins': 12, 'onlineWins': 4});
    expect(merged.matches, {'old-a', 'old-b'});
    expect(merged.unlocks, {'future-set'});
    expect(merged.legacyUnlocks, {'future-set'});
    expect(merged.tutorials, {'old-lesson'});
    expect(merged.unaided, {'old-study'});
    expect(merged.counters['roadWins'], isNull);
    expect(merged.earnedAt, isEmpty);
  });

  test('independent offline results converge once in either sync order', () {
    final initial = AccountProgress(
        owner: 'alice', baseline: ProgressBaseline(counters: {'wins': 12}));
    final a = initial.record(win('a')).record(win('shared'));
    final b = initial.record(win('b')).record(win('shared'));
    for (final merged in [
      a.merge(b),
      b.merge(a),
      a.merge(b).merge(a).merge(b)
    ]) {
      expect(merged.materialize.counters, {'wins': 15, 'roadWins': 3});
      expect(merged.materialize.matches, {'a', 'b', 'shared'});
      expect(merged.events.length, 3);
    }
    final c = initial.record(win('c'));
    expect(a.merge(b).merge(c).materialize.counters,
        a.merge(b.merge(c)).materialize.counters);
  });

  test('retried import and late replay never count historical matches again',
      () {
    final legacy = ProgressBaseline(counters: {'wins': 12}, matches: {'old'});
    final imported = AccountProgress(owner: 'alice')
        .record(win('old'))
        .importBaseline(legacy)
        .importBaseline(legacy)
        .record(win('new'));
    expect(imported.materialize.counters, {'wins': 13, 'roadWins': 1});
    expect(imported.record(win('old')).materialize.counters,
        imported.materialize.counters);
  });

  test('different account owners cannot merge or share progress', () {
    final a = AccountProgress(owner: 'alice').record(win('a'));
    final b = AccountProgress(owner: 'bob');
    expect(() => b.merge(a), throwsStateError);
    expect(b.materialize.counters, isEmpty);
    expect(a.materialize.counters['wins'], 1);
  });

  test('conflicting stable IDs fail instead of selecting a device winner', () {
    final a = AccountProgress(owner: 'alice').record(win('same'));
    expect(() => a.record(win('same', wins: 2)), throwsStateError);
    expect(a.materialize.counters['wins'], 1);
    expect(() => ProgressEvent(id: 'different', evidence: win('same').evidence),
        throwsFormatException);
  });

  test('learning upgrades union; achievement dates retain earliest known date',
      () {
    final early = DateTime.utc(2024);
    final late = DateTime.utc(2025);
    final a = AccountProgress(
        owner: 'alice',
        baseline: ProgressBaseline(
            unlocks: {'earned', 'no-date'}, earnedAt: {'earned': late}));
    final b = AccountProgress(owner: 'alice').record(ProgressEvent(
        id: 'study:one:unaided',
        evidence: ProgressBaseline(unlocks: {
          'earned'
        }, puzzles: {
          'one'
        }, unaided: {
          'one'
        }, earnedAt: {
          'earned': early
        }, tags: {
          'opponents': {'bob'}
        })));
    final result = a.merge(b).materialize;
    expect(result.unaided, {'one'});
    expect(result.earnedAt, {'earned': early});
    expect(result.unlocks, {'earned', 'no-date'});
    expect(result.tags, {
      'opponents': {'bob'}
    });
  });

  test('streaks cannot be summed across unordered device histories', () {
    for (final key in ['hardStreak', 'bestHardStreak', 'streakResult']) {
      expect(
          () => ProgressEvent(
              id: 'event', evidence: ProgressBaseline(counters: {key: 1})),
          throwsFormatException);
    }
  });

  test('snapshots own their collections and reject invalid counters/evidence',
      () {
    final counters = {'wins': 1};
    final opponents = {'bob'};
    final baseline =
        ProgressBaseline(counters: counters, tags: {'opponents': opponents});
    counters['wins'] = 500;
    opponents.add('carol');
    expect(baseline.counters['wins'], 1);
    expect(baseline.tags['opponents'], {'bob'});
    expect(
        () => baseline.tags['opponents']!.add('carol'), throwsUnsupportedError);
    expect(
        () => ProgressBaseline(counters: {'wins': -1}), throwsFormatException);
    expect(
        () => ProgressBaseline(unaided: {'unsolved'}), throwsFormatException);
    expect(() => AccountProgress(owner: ''), throwsFormatException);
  });
}
