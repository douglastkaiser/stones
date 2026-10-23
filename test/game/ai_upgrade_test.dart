import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/ai_material.dart';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/ai_search_cache.dart';
import 'package:stones/game/ai_tactics.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_ai.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/services/ai/search_budget.dart';

class BaselineOnlyAI extends MatchAI {
  BaselineOnlyAI(super.level, {super.useCaches, super.onSearchComplete});
  @override
  Duration get thinkingLimit => Duration.zero;
}

class CompleteAI extends MatchAI {
  CompleteAI(super.level,
      {super.useCaches, super.cacheCapacity, super.onSearchComplete});
  @override
  Duration get thinkingLimit => const Duration(minutes: 1);
  @override
  int get depth => 2;
}

const ivory = Stone(SeatId.ivory, PieceType.flat);
const charcoal = Stone(SeatId.charcoal, PieceType.flat);
MatchConfig config([int seats = 2]) => MatchConfig(
    shape: BoardShape.square,
    size: 3,
    seats: SeatId.values.take(seats).map(SeatConfig.new).toList());
SearchBudget budget() => SearchBudget(enabled: false);

void main() {
  test(
      'weighted FIFO bounds retained children and preserves oldest order on hit',
      () {
    final cache = AiSearchCache(capacity: 4);
    cache.put('a', 'first', cost: 2);
    cache.put('b', 'second');
    expect(cache.get<String>('a'), 'first');
    cache.put('c', 'third', cost: 2);
    expect(cache.get<String>('a'), isNull);
    expect(cache.weight, 3);
    expect(cache.evictions, 1);
    cache.put('huge', 'ignored', cost: 5);
    expect(cache.length, 2);
    cache.put('b', 'replaced', cost: 3);
    expect(cache.weight, 3);
    expect(cache.get<String>('b'), 'replaced');
  });
  test(
      'position identity includes buried order, reserves, turn, phase and config',
      () {
    final start = MatchState.initial(config());
    final game = start.copyWith(ply: 2, board: {
      const Cell(1, 1): [ivory, charcoal, ivory]
    });
    final key = aiPositionKey(game);
    final compact = aiDecisionPositionKey(game);
    expect(aiDecisionPositionKey(game.copyWith(ply: 4)), isNot(compact));
    expect(
        aiDecisionPositionKey(game.copyWith(board: {
          const Cell(1, 1): [charcoal, ivory, ivory]
        })),
        isNot(compact));
    expect(
        aiDecisionPositionKey(game.copyWith(
            reserves: {...game.reserves, SeatId.ivory: const Reserve(1, 0)})),
        isNot(compact));
    expect(
        aiDecisionPositionKey(game.copyWith(
            result: const MatchResult(SeatId.ivory, ResultReason.road))),
        isNot(compact));
    final a = game.copyWith(board: {
      const Cell(0, 0): [ivory],
      const Cell(2, 2): [charcoal]
    });
    final b = game.copyWith(board: {
      const Cell(2, 2): [charcoal],
      const Cell(0, 0): [ivory]
    });
    expect(aiDecisionPositionKey(a), aiDecisionPositionKey(b));

    expect(aiPositionKey(game.copyWith(ply: 4)), key);
    expect(aiPositionKey(game.copyWith(ply: 3)), isNot(key));
    expect(aiPositionKey(game.copyWith(ply: 0)), isNot(key));
    expect(
        aiPositionKey(game.copyWith(board: {
          const Cell(1, 1): [charcoal, ivory, ivory]
        })),
        isNot(key));
    expect(
        aiPositionKey(game.copyWith(
            reserves: {...game.reserves, SeatId.ivory: const Reserve(1, 0)})),
        isNot(key));
    final other =
        MatchState.initial(config(3)).copyWith(ply: 3, board: game.board);
    expect(aiPositionKey(other), isNot(key));
  });
  test(
      'confirmed history rebuilds after takeback, prefix changes and new matches',
      () {
    final cfg = MatchConfig.defaults(BoardShape.square);
    var game = MatchState.initial(cfg);
    final history = AiPositionHistory();
    final records = <Map<String, dynamic>>[];
    final states = <MatchState>[game];
    for (var i = 0; i < 74; i++) {
      final move = i < 2
          ? MatchMove.place(
              i == 0 ? const Cell(0, 0) : const Cell(4, 4), PieceType.flat)
          : MatchMove.spread(
              i.isEven
                  ? Cell(i % 4 == 2 ? 4 : 3, 4)
                  : Cell(i % 4 == 3 ? 0 : 1, 0),
              i.isEven
                  ? (i % 4 == 2 ? Step.west : Step.east)
                  : (i % 4 == 3 ? Step.east : Step.west),
              [1]);
      records.add(move.toMap(game.current));
      game = MatchRules.play(game, move)!;
      states.add(game);
      final keys = history.keysFor('one', cfg, records, game);
      expect(keys.last, aiPositionKey(game));
      expect(keys.length, (i + 2).clamp(0, 64));
    }
    expect(
        history.keysFor('one', cfg, records.take(3).toList(), states[3]).length,
        4);
    expect(history.keysFor('one', cfg, records, game).length, 64);
    final fresh = AiPositionHistory().keysFor('one', cfg, records, game);
    expect(history.keysFor('one', cfg, records, game), fresh);
    expect(history.keysFor('two', cfg, [], states.first),
        [aiPositionKey(states.first)]);
    expect(history.keysFor('two', cfg, records, states.first), isEmpty);
    expect(
        history.keysFor(
            'two',
            cfg,
            [
              {'seat': 'wrong'}
            ],
            game),
        isEmpty);
    history.clear();
    expect(history.keysFor('one', cfg, records, game), fresh);
  });
  test('legal multi-drop spread win can have path cost greater than one',
      () async {
    final game = MatchState.initial(MatchConfig.defaults(BoardShape.square))
        .copyWith(ply: 2, board: {
      const Cell(0, 2): [ivory],
      const Cell(1, 2): [ivory, ivory, ivory],
      const Cell(4, 2): [ivory],
    });
    expect(MatchAI.pathCost(game, SeatId.ivory), greaterThan(1));
    final wins = await aiWinningMoves(game, SeatId.ivory, budget());
    expect(wins.any((m) => m.drops.length == 2), isTrue);
    for (final level in BotLevel.values) {
      final move = await MatchAI(level, yieldDuringSearch: false).choose(game);
      expect(MatchRules.play(game, move!)!.result?.winner, SeatId.ivory);
    }
  });
  test(
      'material win bound never skips an exact legal win on replayed positions',
      () {
    for (final shape in BoardShape.values) {
      for (final seats in [2, 3, 4]) {
        final cfg = MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 3 : 2,
            seats: SeatId.values.take(seats).map(SeatConfig.new).toList());
        for (var seed = 0; seed < 4; seed++) {
          var game = MatchState.initial(cfg);
          final random = Random(seed);
          for (var ply = 0; ply < 28 && !game.finished; ply++) {
            final legal = MatchRules.legalMoves(game).toList();
            if (!aiMayWinInOne(game, game.current)) {
              expect(
                  legal.any((move) =>
                      MatchRules.play(game, move)!.result?.winner ==
                      game.current),
                  isFalse);
            }
            game = MatchRules.play(game, legal[random.nextInt(legal.length)])!;
          }
        }
      }
    }
  });
  test('fork proof respects joint defenses in actual multiplayer order',
      () async {
    final board = {
      for (final y in [1, 3])
        for (var x = 0; x < 4; x++) Cell(x, y): [ivory]
    };
    MatchConfig forkConfig(int seats) => MatchConfig(
        shape: BoardShape.square,
        size: 5,
        seats: SeatId.values.take(seats).map(SeatConfig.new).toList());
    final duel =
        MatchState.initial(forkConfig(2)).copyWith(ply: 3, board: board);
    expect(await aiVerifyFork(duel, SeatId.ivory, budget(), maxNodes: 10000),
        AiForkStatus.proven);
    final multi =
        MatchState.initial(forkConfig(3)).copyWith(ply: 4, board: board);
    expect(await aiVerifyFork(multi, SeatId.ivory, budget(), maxNodes: 10000),
        AiForkStatus.refuted);
    expect(await aiVerifyFork(duel, SeatId.ivory, budget(), maxNodes: 1),
        AiForkStatus.unknown);
    var timedOut = false;
    expect(
        await aiVerifyFork(duel, SeatId.ivory,
            SearchBudget(enabled: false, thinkingLimit: Duration.zero),
            onTimeout: () => timedOut = true),
        AiForkStatus.unknown);
    expect(timedOut, isTrue);
  });
  test('material probes count only legal cap crushes and remain bounded', () {
    final start = MatchState.initial(config()).copyWith(ply: 2);
    final cap = start.copyWith(board: {
      const Cell(1, 1): [const Stone(SeatId.ivory, PieceType.capstone)],
      const Cell(2, 1): [const Stone(SeatId.charcoal, PieceType.standing)],
    });
    final flat = start.copyWith(board: {
      const Cell(1, 1): [ivory],
      const Cell(2, 1): [const Stone(SeatId.charcoal, PieceType.standing)],
    });
    const crushOnly = AiMaterialWeights(crush: 12, exposure: 0, access: 0);
    expect(aiMaterialScore(cap, SeatId.ivory, crushOnly), 12);
    expect(aiMaterialScore(flat, SeatId.ivory, crushOnly), 0);
    final capBlock = cap.copyWith(board: {
      ...cap.board,
      const Cell(2, 1): [const Stone(SeatId.charcoal, PieceType.capstone)]
    });
    expect(aiMaterialScore(capBlock, SeatId.ivory, crushOnly), 0);
    const extreme = AiMaterialWeights(
        mobility: 1000, crush: 1000, exposure: 1000, access: 1000);
    expect(
        aiMaterialScore(cap, SeatId.ivory, extreme), inInclusiveRange(-40, 40));
    expect(aiMaterialScore(cap, SeatId.ivory, AiMaterialWeights.zero), 0);
  });
  for (final seats in [2, 3, 4]) {
    test('cached and uncached complete round agree for $seats seats', () async {
      final game = MatchState.initial(config(seats)).copyWith(ply: seats);
      MatchSearchStats? stats;
      final cached = await BaselineOnlyAI(BotLevel.easy,
          onSearchComplete: (s) => stats = s).choose(game);
      final uncached =
          await BaselineOnlyAI(BotLevel.easy, useCaches: false).choose(game);
      expect(cached!.toMap(game.current), uncached!.toMap(game.current));
      expect(stats!.completedRounds, 1);
      expect(stats!.cacheEntries, lessThanOrEqualTo(10000));
      expect(stats!.timedOut, isTrue);
    });
  }
  test(
      'repetition only changes near equal roots and cannot avoid a winning move',
      () async {
    final game = MatchState.initial(config()).copyWith(ply: 2);
    final ai = BaselineOnlyAI(BotLevel.easy);
    final first = (await ai.choose(game))!;
    final key = aiPositionKey(MatchRules.play(game, first)!);
    final different =
        (await ai.choose(game, recentPositionKeys: List.filled(64, key)))!;
    expect(different.toMap(game.current), isNot(first.toMap(game.current)));
    // Context must be cleared between decisions, including reuse of the object.
    expect((await ai.choose(game))!.toMap(game.current),
        first.toMap(game.current));
    final winning = game.copyWith(board: {
      const Cell(0, 0): [ivory],
      const Cell(1, 0): [ivory]
    });
    final win = (await MatchAI(BotLevel.easy, yieldDuringSearch: false)
        .choose(winning))!;
    final repeatedWin = aiPositionKey(MatchRules.play(winning, win)!);
    final again = (await MatchAI(BotLevel.easy, yieldDuringSearch: false)
        .choose(winning, recentPositionKeys: List.filled(64, repeatedWin)))!;
    expect(MatchRules.play(winning, again)!.result?.winner, SeatId.ivory);
  });
  for (final seats in [2, 3]) {
    test('completed duel/MaxN cache equivalence with eviction at $seats seats',
        () async {
      final cfg = MatchConfig(
          shape: BoardShape.square,
          size: 4,
          seats: SeatId.values.take(seats).map(SeatConfig.new).toList());
      final game = MatchState.initial(cfg).copyWith(ply: seats);
      MatchSearchStats? cachedStats;
      MatchSearchStats? plainStats;
      final cached = await CompleteAI(BotLevel.hard,
          cacheCapacity: 128,
          onSearchComplete: (s) => cachedStats = s).choose(game);
      final plain = await CompleteAI(BotLevel.hard,
          useCaches: false,
          onSearchComplete: (s) => plainStats = s).choose(game);
      expect(cached!.toMap(game.current), plain!.toMap(game.current));
      expect(cachedStats!.completedDepth, 2 * seats);
      expect(plainStats!.completedDepth, cachedStats!.completedDepth);
      expect(cachedStats!.timedOut, isFalse);
      expect(cachedStats!.cacheEntries, lessThanOrEqualTo(128));
      expect(cachedStats!.cacheEvictions, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
  test('Hard repetition choices use exact root scores with pruning enabled',
      () async {
    final cfg = MatchConfig(
        shape: BoardShape.square,
        size: 4,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    final game = MatchState.initial(cfg).copyWith(ply: 2);
    final ai = CompleteAI(BotLevel.hard);
    final best = (await ai.choose(game))!;
    final repeated = aiPositionKey(MatchRules.play(game, best)!);
    final alternative =
        (await ai.choose(game, recentPositionKeys: List.filled(64, repeated)))!;
    expect(alternative.toMap(game.current), isNot(best.toMap(game.current)));
  });
  test('legal exposure distinguishes friendly and enemy buried roads', () {
    final base = MatchState.initial(config()).copyWith(ply: 2);
    final friendly = base.copyWith(board: {
      const Cell(1, 1): [ivory, ivory]
    });
    final enemy = base.copyWith(board: {
      const Cell(1, 1): [charcoal, ivory]
    });
    const exposure = AiMaterialWeights(crush: 0, exposure: 12, access: 0);
    expect(aiMaterialScore(friendly, SeatId.ivory, exposure), 12);
    expect(aiMaterialScore(enemy, SeatId.ivory, exposure), -12);
    final trapped = friendly.copyWith(board: {
      ...friendly.board,
      for (final direction in friendly.geometry.directions)
        const Cell(1, 1).step(direction): [
          const Stone(SeatId.charcoal, PieceType.capstone)
        ]
    });
    const access = AiMaterialWeights(crush: 0, exposure: 0, access: 12);
    expect(aiMaterialScore(friendly, SeatId.ivory, access), greaterThan(0));
    expect(aiMaterialScore(trapped, SeatId.ivory, access), lessThan(0));
    expect(aiMaterialScore(trapped, SeatId.ivory, exposure), 0);
  });
  test('cancellation never returns a partially searched move', () async {
    final game = MatchState.initial(config(4)).copyWith(ply: 4);
    expect(
        await MatchAI(BotLevel.expert, yieldDuringSearch: false)
            .choose(game, cancelled: () => true),
        isNull);
  });
}
