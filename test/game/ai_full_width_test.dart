import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/ai_duel_search.dart';
import 'package:stones/game/ai_search_cache.dart';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_ai.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/services/ai/search_budget.dart';
import '../../tools/ai_balance_proof.dart';

MatchConfig cfg(BoardShape shape,
        {int players = 2, String engine = 'shared-search-v3'}) =>
    MatchConfig(
        shape: shape,
        size: shape == BoardShape.square ? 3 : 2,
        aiEngine: engine,
        seats: SeatId.values.take(players).map(SeatConfig.new).toList());

double evaluation(MatchState game, SeatId root) {
  final scores = MatchAI.evaluate(game);
  return scores[root]! - scores[game.config.next(root)]!;
}

// Deliberately no production search, ordering, cache, tactics or pruning.
double oracle(MatchState game, SeatId root, int depth) {
  if (game.finished) {
    return game.result!.winner == null
        ? 0
        : game.result!.winner == root
            ? 200000 - game.ply.toDouble()
            : -200000 + game.ply.toDouble();
  }
  if (depth == 0) return evaluation(game, root);
  final values = [
    for (final move in MatchRules.legalMoves(game))
      oracle(MatchRules.play(game, move)!, root, depth - 1)
  ];
  return values.reduce(game.current == root ? math.max : math.min);
}

AiDuelSearch search(MatchState game,
        {AiSearchCache? cache,
        bool reverse = false,
        int? nodeLimit,
        bool tactics = false}) =>
    AiDuelSearch(
        budget: SearchBudget(enabled: false),
        evaluate: evaluation,
        root: game.current,
        cache: cache,
        reverseOrder: reverse,
        nodeLimit: nodeLimit,
        tactics: tactics,
        extensions: tactics,
        exactRootScores: true);

class ExpiredFullWidth extends MatchAI {
  ExpiredFullWidth({super.onSearchComplete})
      : super(BotLevel.hard, fullWidthDuels: true, yieldDuringSearch: false);
  @override
  Duration get thinkingLimit => Duration.zero;
}

class CompleteFullWidth extends MatchAI {
  CompleteFullWidth(super.level,
      {super.onSearchComplete,
      super.fullWidthDuels,
      super.roadResilienceWeight,
      super.duelThinkingLimit,
      super.tacticalSafety,
      super.useCaches})
      : super(yieldDuringSearch: false);
  @override
  int get depth => 1;
  @override
  Duration get thinkingLimit => const Duration(minutes: 1);
}

void main() {
  for (final shape in BoardShape.values) {
    test('$shape full-width values match exhaustive minimax and optimal moves',
        () async {
      final random = math.Random(17);
      var game = MatchState.initial(cfg(shape));
      for (var ply = 0; ply < 5; ply++) {
        final legal = MatchRules.legalMoves(game).toList();
        game = MatchRules.play(game, legal[random.nextInt(legal.length)])!;
      }
      for (var depth = 1; depth <= 2; depth++) {
        final expected = oracle(game, game.current, depth);
        for (final useCache in [false, true]) {
          for (final reverse in [false, true]) {
            final s = search(game,
                cache: useCache ? AiSearchCache(capacity: 97) : null,
                reverse: reverse);
            expect(await s.valueAt(game, depth), expected);
            final iteration = await s.iteration(game, depth);
            expect(iteration.score, expected);
            expect(
                oracle(MatchRules.play(game, iteration.move)!, game.current,
                    depth - 1),
                expected);
            expect(iteration.exactScores, isTrue);
            expect(s.stats.completedDepth, depth);
          }
        }
      }
    });

    test('$shape cached window bounds and horizons cannot corrupt exact values',
        () async {
      final game = MatchState.initial(cfg(shape)).copyWith(ply: 2);
      final s = search(game, cache: AiSearchCache());
      final expected = oracle(game, game.current, 2);
      expect(await s.valueAt(game, 2, alpha: expected - 2, beta: expected - 1),
          greaterThanOrEqualTo(expected - 1));
      expect(await s.valueAt(game, 2, alpha: expected + 1, beta: expected + 2),
          lessThanOrEqualTo(expected + 1));
      expect(await s.valueAt(game, 2), expected);
      expect(await s.valueAt(game, 1), oracle(game, game.current, 1));
    });
  }

  test('depth-three oracle equivalence includes legal stack spreads', () async {
    final game =
        MatchState.initial(cfg(BoardShape.square)).copyWith(ply: 8, board: {
      const Cell(0, 0): const [
        Stone(SeatId.charcoal, PieceType.flat),
        Stone(SeatId.ivory, PieceType.flat)
      ],
      const Cell(1, 1): const [Stone(SeatId.charcoal, PieceType.flat)],
      const Cell(2, 0): const [Stone(SeatId.charcoal, PieceType.standing)],
      const Cell(2, 2): const [Stone(SeatId.ivory, PieceType.flat)],
    });
    expect(MatchRules.legalMoves(game).any((m) => m.drops.isNotEmpty), isTrue);
    expect(await search(game, cache: AiSearchCache()).valueAt(game, 3),
        oracle(game, game.current, 3));
  });

  test('interruption cannot publish an iteration or a partial transposition',
      () async {
    final game = MatchState.initial(cfg(BoardShape.square)).copyWith(ply: 2);
    final cache = AiSearchCache();
    final s = search(game, cache: cache, nodeLimit: 100);
    final completed = await s.iteration(game, 1);
    expect(s.stats.completedDepth, 1);
    await expectLater(s.iteration(game, 3), throwsA(isA<SearchTimedOut>()));
    expect(s.stats.completedDepth, 1);
    expect(completed.scores, isNotEmpty);
    expect(await search(game, cache: cache).valueAt(game, 2),
        oracle(game, game.current, 2));
  });

  test('expired duel reports legal emergency fallback without claiming a round',
      () async {
    final game = MatchState.initial(cfg(BoardShape.hex));
    late MatchSearchStats stats;
    final move =
        await ExpiredFullWidth(onSearchComplete: (s) => stats = s).choose(game);
    expect(MatchRules.play(game, move!), isNotNull);
    expect(stats.searchModel, 'full-width');
    expect(stats.completedDepth, 0);
    expect(stats.completedRounds, 0);
    expect(stats.emergencyFallback, isTrue);
    expect(stats.alternatives, isEmpty);
    expect(stats.timedOut, isTrue);
  });

  test('cancelling full-width search returns no move', () async {
    expect(
        await ExpiredFullWidth().choose(MatchState.initial(cfg(BoardShape.hex)),
            cancelled: () => true),
        isNull);
  });

  test(
      'cancellation after selecting emergency legality is not a returned fallback',
      () async {
    final game = MatchState.initial(cfg(BoardShape.square));
    var checks = 0;
    late MatchSearchStats stats;
    final move = await CompleteFullWidth(BotLevel.hard,
            fullWidthDuels: true, onSearchComplete: (s) => stats = s)
        .choose(game, cancelled: () => ++checks > 3);
    expect(move, isNull);
    expect(stats.completedDepth, 0);
    expect(stats.emergencyFallback, isFalse);
    expect(stats.timedOut, isFalse);
  });

  test('tactical win/loss claims have independent finite-horizon certificates',
      () async {
    var claims = 0;
    for (var seed = 0; seed < 12; seed++) {
      final random = math.Random(seed);
      var game = MatchState.initial(cfg(BoardShape.square));
      for (var ply = 0; ply < 7 && !game.finished; ply++) {
        final legal = MatchRules.legalMoves(game).toList();
        game = MatchRules.play(game, legal[random.nextInt(legal.length)])!;
        if (game.finished || ply < 3) continue;
        final value = await search(game, tactics: true).valueAt(game, 0);
        if (value.abs() < 100000) continue;
        final winner =
            value > 0 ? game.current : game.config.next(game.current);
        expect(BoundedDuelProof().solve(game, winner, 3), DuelProof.proven);
        claims++;
      }
    }
    expect(claims, greaterThan(0));
  });

  test('terminal draws and either winner receive correct mate scores',
      () async {
    final game = MatchState.initial(cfg(BoardShape.square));
    final s = search(game);
    expect(
        await s.valueAt(
            game.copyWith(result: const MatchResult(null, ResultReason.flats)),
            2),
        0);
    expect(
        await s.valueAt(
            game.copyWith(
                ply: 7,
                result: const MatchResult(SeatId.ivory, ResultReason.road)),
            2),
        199993);
    expect(
        await s.valueAt(
            game.copyWith(
                ply: 7,
                result: const MatchResult(SeatId.charcoal, ResultReason.road)),
            2),
        -199993);
  });

  test('horizon fork proof and draw defense survive the full-width extension',
      () async {
    var game = MatchState.initial(cfg(BoardShape.square));
    for (final c in [const Cell(0, 0), const Cell(0, 1), const Cell(1, 0)]) {
      game = MatchRules.play(game, MatchMove.place(c, PieceType.flat))!;
    }
    final quiet = MatchMove.place(const Cell(2, 2), PieceType.flat);
    final fork = MatchRules.play(MatchRules.play(game, quiet)!,
        MatchMove.place(const Cell(1, 1), PieceType.flat))!;
    expect(
        await search(fork, tactics: true).valueAt(fork, 0), lessThan(-100000));
    final drawGame = game.copyWith(
        reserves: {...game.reserves, SeatId.charcoal: const Reserve(1, 0)});
    final draw = MatchRules.play(drawGame, quiet)!;
    expect(draw.result!.draw, isTrue);
    expect(await search(drawGame, tactics: true).valueAt(draw, 0), 0);
  });

  test('saved engines and multiplayer ignore both experiments', () async {
    for (final (players, engine) in [
      (2, 'shared-search-v1'),
      (2, 'shared-search-v2'),
      (3, 'shared-search-v3'),
      (4, 'shared-search-v3')
    ]) {
      final game = MatchState.initial(
          cfg(BoardShape.square, players: players, engine: engine));
      late MatchSearchStats stats;
      final normal = await CompleteFullWidth(BotLevel.hard).choose(game);
      final experimental = await CompleteFullWidth(BotLevel.hard,
          fullWidthDuels: true,
          roadResilienceWeight: 16,
          duelThinkingLimit: Duration.zero,
          onSearchComplete: (s) => stats = s).choose(game);
      expect(
          AiDuelSearch.moveKey(experimental!), AiDuelSearch.moveKey(normal!));
      expect(stats.searchModel, 'selective');
      expect(stats.exhaustiveDepth, 0);
    }
  });

  test('native dispatch carries experimental options without a format change',
      () async {
    final game =
        MatchState.initial(cfg(BoardShape.square)).copyWith(ply: 2, board: {
      for (final y in [0, 1])
        Cell(0, y): const [Stone(SeatId.ivory, PieceType.flat)]
    });
    final move = await selectMatchMove(game, BotLevel.easy,
        fullWidthDuels: true, roadResilienceWeight: 16);
    expect(MatchRules.play(game, move!)!.result!.winner, game.current);
  });

  test(
      'repetition choices use exact scores from a completed full-width iteration',
      () async {
    final game = MatchState.initial(cfg(BoardShape.square)).copyWith(ply: 2);
    final normal = await CompleteFullWidth(BotLevel.hard, fullWidthDuels: true)
        .choose(game);
    late MatchSearchStats stats;
    final alternative = await CompleteFullWidth(BotLevel.hard,
        fullWidthDuels: true,
        onSearchComplete: (s) => stats = s).choose(game, recentPositionKeys: [
      aiPositionKey(MatchRules.play(game, normal!)!)
    ]);
    expect(stats.exhaustiveDepth, 2);
    expect(stats.alternatives.every((s) => s['exact'] == true), isTrue);
    expect(AiDuelSearch.moveKey(alternative!),
        isNot(AiDuelSearch.moveKey(normal)));
  });

  test(
      'recorded defense remains in full-width roots and has no scripted coordinates',
      () async {
    final row = jsonDecode(File('docs/qa/ai-balance-hex-counterexample.jsonl')
        .readAsStringSync()) as Map;
    var game = MatchState.initial(
        MatchConfig.fromMap(Map<String, dynamic>.from(row['config'])));
    for (final raw in (row['moves'] as List).take(5)) {
      game = MatchRules.play(
          game, MatchMove.fromMap(Map<String, dynamic>.from(raw)))!;
    }
    final s = search(game);
    final iteration = await s.iteration(game, 1);
    expect(iteration.scores.length, MatchRules.legalMoves(game).length);
    expect(
        iteration.scores.any((s) =>
            s.$1.from == const Cell(1, 0) && s.$1.type == PieceType.flat),
        isTrue);
  });
}
