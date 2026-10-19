import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_standings.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/rating_pool.dart';
import 'package:stones/game/rating_submission.dart';
import 'package:stones/game/result_share_data.dart';
import 'package:stones/game/skill_rating.dart';
import 'package:stones/models/elo_rating.dart';
import '../game/result_sharing_test.dart' show position;

void main() {
  test('Glickman published reference example matches independently', () {
    final result = SkillCalculator.update(
        const SkillEstimate(mean: 1500, deviation: 200), const [
      SkillObservation(SkillEstimate(mean: 1400, deviation: 30), 1),
      SkillObservation(SkillEstimate(mean: 1550, deviation: 100), 0),
      SkillObservation(SkillEstimate(mean: 1700, deviation: 300), 0),
    ]);
    expect(result.mean, closeTo(1464.106, .001));
    expect(result.deviation, closeTo(151.399, .001));
  });

  Map<String, SkillEstimate> play(List<String> ids, int winner,
          [Map<String, SkillEstimate>? estimates]) =>
      SkillCalculator.forMatch(
          participants: ids,
          winner: winner,
          estimates: estimates ??
              {for (final id in ids) id: const SkillEstimate(deviation: 100)});

  test('equally rated multiplayer losers all lose without inferred draws', () {
    final result = play(['a', 'b', 'c', 'd'], 0);
    expect(result['a']!.mean, greaterThan(1200));
    for (final id in ['b', 'c', 'd']) {
      expect(result[id]!.mean, lessThan(1200));
      expect(result[id]!.mean, result['b']!.mean);
    }
    expect(result['b']!.mean, closeTo(1191.079, .001));
    expect(result['b']!.deviation, greaterThan(result['a']!.deviation));
  });

  test('winner evidence is capped at one duel; larger losses are smaller', () {
    final duel = play(['a', 'b'], 0);
    final three = play(['a', 'b', 'c'], 0);
    final four = play(['a', 'b', 'c', 'd'], 0);
    expect(four['a']!.mean, duel['a']!.mean);
    expect(three['a']!.mean, duel['a']!.mean);
    expect(four['b']!.mean, greaterThan(three['b']!.mean));
    expect(three['b']!.mean, greaterThan(duel['b']!.mean));
  });

  test('unrelated losing seats cannot change another loser adjustment', () {
    final prior = {
      for (final id in ['a', 'b', 'c', 'd'])
        id: const SkillEstimate(deviation: 100)
    };
    final before = play(['a', 'b', 'c', 'd'], 0, prior);
    final after = play(
        ['a', 'b', 'c', 'd'],
        0,
        {
          ...prior,
          'c': const SkillEstimate(mean: 2200, deviation: 50),
          'd': const SkillEstimate(mean: 300)
        });
    expect(after['b']!.mean, before['b']!.mean);
    expect(after['b']!.deviation, before['b']!.deviation);
  });

  test('seat permutation preserves skill posteriors', () {
    final prior = {
      'a': const SkillEstimate(mean: 1700, deviation: 80),
      'b': const SkillEstimate(mean: 1300, deviation: 250),
      'c': const SkillEstimate(mean: 1550, deviation: 60)
    };
    final a = play(['a', 'b', 'c'], 1, prior);
    final b = play(['c', 'a', 'b'], 2, prior);
    for (final id in prior.keys) {
      expect(a[id]!.mean, closeTo(b[id]!.mean, 1e-10));
      expect(a[id]!.deviation, closeTo(b[id]!.deviation, 1e-10));
    }
  });

  test('draws update every participant and unknown players remain uncertain',
      () {
    final draw = play(['a', 'b', 'c', 'd'], -1);
    for (final rating in draw.values) {
      expect(rating.mean, 1200);
      expect(rating.deviation, lessThan(100));
    }
    final unequal = play(
        ['a', 'b'],
        -1,
        {
          'a': const SkillEstimate(mean: 1800, deviation: 100),
          'b': const SkillEstimate(deviation: 100)
        });
    expect(unequal['a']!.mean, lessThan(1800));
    expect(unequal['b']!.mean, greaterThan(1200));
  });

  test('repeated AI has one posterior, no self-opponent evidence', () {
    final repeated = play(['a', 'bot', 'bot', 'bot'], 0);
    final single = play(['a', 'bot', 'b', 'c'], 0);
    expect(repeated.keys, unorderedEquals(['a', 'bot']));
    expect(repeated['bot']!.mean, single['bot']!.mean);
    expect(repeated['bot']!.deviation, single['bot']!.deviation);
    final allSame = play(['bot', 'bot', 'bot'], 0);
    expect(allSame['bot']!.mean, 1200);
    expect(allSame['bot']!.deviation, 100);
  });

  test('uncertainty has a floor and never becomes negative or non-finite', () {
    var prior = {
      for (final id in ['a', 'b']) id: const SkillEstimate()
    };
    for (var i = 0; i < 500; i++) {
      prior = play(['a', 'b'], i.isEven ? 0 : 1, prior);
      for (final skill in prior.values) {
        expect(skill.mean.isFinite, isTrue);
        expect(skill.deviation, inInclusiveRange(50, 350));
      }
    }
    expect(prior['a']!.deviation, 50);
  });

  test('invalid inputs and fabricated scores are rejected', () {
    expect(() => play(['a'], 0), throwsArgumentError);
    expect(() => play(['a', 'b'], 2), throwsArgumentError);
    expect(
        () => SkillCalculator.update(const SkillEstimate(),
            const [SkillObservation(SkillEstimate(), .75)]),
        throwsArgumentError);
    expect(
        () =>
            SkillCalculator.update(const SkillEstimate(deviation: 0), const []),
        throwsArgumentError);
  });

  test('v3 defaults and overall scope preserve legacy decoding', () {
    final config = MatchConfig.defaults(BoardShape.square);
    expect(config.ratingVersion, 3);
    final wire = config.toMap()..remove('ratingVersion');
    expect(MatchConfig.fromMap(wire).ratingVersion, 1);
    expect(const RatingPool.overall().id, 'overall');
    expect(RatingPool.forConfig(config).id, 'square-5-2-standardTak-open');
  });

  test('v3 standings label losses equally regardless of flats', () {
    final legacy = position(players: 4);
    final config =
        MatchConfig.fromMap({...legacy.config.toMap(), 'ratingVersion': 3});
    final game = MatchState(
        config: config,
        board: legacy.board,
        reserves: legacy.reserves,
        result: legacy.result,
        ply: legacy.ply);
    final standings = MatchStandings.forGame(game)!;
    expect(standings.ranks.values, [1, 2, 2, 2]);
    final draw =
        game.copyWith(result: const MatchResult(null, ResultReason.flats));
    expect(MatchStandings.forGame(draw)!.ranks.values, [1, 1, 1, 1]);
  });

  test('skill uncertainty survives serialization and controls calibration', () {
    const rating = EloRating(
        id: 'a',
        displayName: 'Alice',
        gamesPlayed: 20,
        skill: SkillEstimate(deviation: 180));
    final restored = EloRating.fromMap('a', rating.toMap());
    expect(restored.provisional, isTrue);
    expect(restored.skill!.deviation, 180);
    expect(restored.uncertaintyLabel, contains('847–1553'));
    const established = EloRating(
        id: 'b',
        displayName: 'Bob',
        gamesPlayed: 20,
        skill: SkillEstimate(deviation: 80));
    expect(established.provisional, isFalse);
  });

  test('v3 loser shares only the loss; spectators describe a whole-game draw',
      () {
    final old = position(players: 4);
    final game = MatchState(
        config:
            MatchConfig.fromMap({...old.config.toMap(), 'ratingVersion': 3}),
        board: old.board,
        reserves: old.reserves,
        result: old.result,
        ply: old.ply);
    final data = ResultShareData(MatchSession(game: game),
        names: {SeatId.ivory: 'Alex'},
        viewer: SeatId.charcoal,
        rating: const RatingSubmission(RatingSubmissionState.failed, 'pending',
            skillBased: true,
            deltas: {SeatId.charcoal: RatingDelta(1200, 1190)}));
    expect(data.outcome, 'Lost to Alex');
    expect(data.placement, 'Lost · 4 players');
    expect(data.text, contains('Overall -10 · Format pending'));
    expect(data.text, isNot(contains('Tied with')));
    expect(data.text, isNot(contains('2nd')));
    final draw = ResultShareData(
        MatchSession(
            game: game.copyWith(
                result: const MatchResult(null, ResultReason.flats))),
        names: {},
        viewer: null,
        rating: const RatingSubmission.unrated());
    expect(draw.outcome, endsWith(' drew'));
    expect(draw.outcome, isNot(contains('first')));
  });
}
