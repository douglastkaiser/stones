import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/ai_tactics.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_ai.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/services/ai/search_budget.dart';
import '../../tools/ai_balance_proof.dart';

class CompleteChoiceAI extends MatchAI {
  CompleteChoiceAI(super.level, {super.variation, super.onSearchComplete})
      : super(yieldDuringSearch: false);
  @override
  Duration get thinkingLimit => const Duration(seconds: 30);
  @override
  int get depth => 1;
}

class ExpiredChoiceAI extends MatchAI {
  ExpiredChoiceAI(super.level, {super.variation, super.onSearchComplete})
      : super(yieldDuringSearch: false);
  @override
  Duration get thinkingLimit => Duration.zero;
}

class GenerousAI extends MatchAI {
  GenerousAI(super.level, {super.onSearchComplete})
      : super(yieldDuringSearch: false);
  @override
  Duration get thinkingLimit => const Duration(seconds: 30);
}

class WideForkAI extends CompleteChoiceAI {
  WideForkAI({super.onSearchComplete})
      : super(BotLevel.hard, variation: AiMoveVariation.ties);
  @override
  int get branching => 64;
}

class CappedExpertAI extends GenerousAI {
  CappedExpertAI({super.onSearchComplete}) : super(BotLevel.expert);
  @override
  int get depth => 2;
}

class CompleteMateAI extends MatchAI {
  CompleteMateAI({super.onSearchComplete})
      : super(BotLevel.hard, yieldDuringSearch: false, tacticalSafety: false);
  @override
  Duration get thinkingLimit => const Duration(seconds: 30);
}

void main() {
  final cfg = MatchConfig(
      shape: BoardShape.square,
      size: 4,
      seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
  final symmetric = MatchState.initial(cfg).copyWith(ply: 2);
  String key(MatchMove move) => jsonEncode(move.toMap(SeatId.ivory));

  test(
      'winning-move bounds retain a board-filling spread with too few road stones',
      () async {
    final cfg = MatchConfig(
        shape: BoardShape.square,
        size: 5,
        seats: SeatId.values.take(3).map(SeatConfig.new).toList());
    final initial = MatchState.initial(cfg);
    final board = <Cell, List<Stone>>{
      const Cell(0, 0): const [
        Stone(SeatId.ivory, PieceType.flat),
        Stone(SeatId.charcoal, PieceType.flat),
        Stone(SeatId.charcoal, PieceType.flat),
        Stone(SeatId.charcoal, PieceType.flat)
      ]
    };
    var wall = 0;
    for (final cell in initial.geometry.cells) {
      if (cell == const Cell(0, 0) ||
          cell.y == 0 && cell.x >= 1 && cell.x <= 3) {
        continue;
      }
      board[cell] = [
        Stone(
            wall++ % 2 == 0 ? SeatId.ivory : SeatId.copper, PieceType.standing)
      ];
    }
    final game = initial.copyWith(ply: 40, board: board, reserves: {
      for (final id in cfg.ids)
        id: Reserve(
            21 -
                board.values.expand((s) => s).where((s) => s.seat == id).length,
            1)
    });
    final spread =
        MatchMove.spread(const Cell(0, 0), Step.east, const [1, 1, 1]);
    expect(MatchRules.play(game, spread)!.result!.reason, ResultReason.flats);
    expect(MatchRules.play(game, spread)!.result!.winner, SeatId.charcoal);
    expect(aiMayWinInOne(game, SeatId.charcoal), isTrue);
    final wins = await aiWinningMoves(
        game, SeatId.charcoal, SearchBudget(enabled: false));
    expect(wins.map((m) => jsonEncode(m.toMap(game.current))),
        contains(jsonEncode(spread.toMap(game.current))));
  });

  test('pruned winning-move search agrees with full legal enumeration',
      () async {
    for (final shape in BoardShape.values) {
      for (var seats = 2; seats <= 4; seats++) {
        final cfg = MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 5 : 2,
            seats: SeatId.values.take(seats).map(SeatConfig.new).toList());
        for (var seed = 0; seed < 3; seed++) {
          var game = MatchState.initial(cfg);
          final random = Random(seed);
          for (var ply = 0; ply < 24 && !game.finished; ply++) {
            final legal = MatchRules.legalMoves(game).toList();
            final expected = {
              for (final move in legal)
                if (MatchRules.play(game, move)!.result?.winner == game.current)
                  jsonEncode(move.toMap(game.current))
            };
            final found = await aiWinningMoves(
                game, game.current, SearchBudget(enabled: false));
            expect(found.map((m) => jsonEncode(m.toMap(game.current))).toSet(),
                expected);
            game = MatchRules.play(game, legal[random.nextInt(legal.length)])!;
          }
        }
      }
    }
  });

  test('Expert widens a completed round without reporting an extra round',
      () async {
    late MatchSearchStats stats;
    final move = await CappedExpertAI(onSearchComplete: (s) => stats = s)
        .choose(symmetric);
    expect(move, isNotNull);
    expect(stats.timedOut, isFalse);
    expect(stats.completedDepth, 4);
    expect(stats.completedRounds, 2);
    expect(stats.completedRootWidth, 16);
    expect(stats.alternatives.length, 16);
  });

  test('a selective reply beam cannot certify a refuted forced win', () async {
    var position = MatchState.initial(MatchConfig(
        shape: BoardShape.square,
        size: 3,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]));
    for (final (cell, type) in [
      (const Cell(1, 1), PieceType.flat),
      (const Cell(1, 0), PieceType.flat),
      (const Cell(1, 2), PieceType.standing),
      (const Cell(0, 0), PieceType.flat),
      (const Cell(0, 2), PieceType.flat),
      (const Cell(2, 2), PieceType.standing),
    ]) {
      position = MatchRules.play(position, MatchMove.place(cell, type))!;
    }
    final proposed = MatchMove.place(const Cell(2, 1), PieceType.flat);
    expect(
        BoundedDuelProof(maxNodes: 150000)
            .solve(MatchRules.play(position, proposed)!, position.current, 8),
        DuelProof.refuted);
    late MatchSearchStats stats;
    final move = await CompleteMateAI(onSearchComplete: (s) => stats = s)
        .choose(position, decisionSeed: 0);
    expect(MatchRules.play(position, move!), isNotNull);
    expect(stats.timedOut, isFalse);
    expect(stats.completedDepth, 4);
    final result = stats.alternatives.singleWhere((entry) =>
        jsonEncode(entry['move']) == jsonEncode(move.toMap(position.current)));
    expect(result['score'] as double, lessThan(100000));
  });

  test(
      'an unanswerable rival fork at the horizon is a forced loss, not a quiet position',
      () async {
    final cfg = MatchConfig(
        shape: BoardShape.square,
        size: 3,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    var game = MatchState.initial(cfg);
    for (final cell in [const Cell(0, 0), const Cell(0, 1), const Cell(1, 0)]) {
      game = MatchRules.play(game, MatchMove.place(cell, PieceType.flat))!;
    }
    final quiet = MatchMove.place(const Cell(2, 2), PieceType.flat);
    final fork = MatchRules.play(MatchRules.play(game, quiet)!,
        MatchMove.place(const Cell(1, 1), PieceType.flat))!;
    expect(
        await aiVerifyFork(fork, SeatId.ivory, SearchBudget(enabled: false),
            maxNodes: 10000),
        AiForkStatus.proven);
    late MatchSearchStats stats;
    final chosen = await WideForkAI(onSearchComplete: (s) => stats = s)
        .choose(game, decisionSeed: 1);
    final losing = stats.alternatives.singleWhere(
        (s) => jsonEncode(s['move']) == jsonEncode(quiet.toMap(game.current)));
    final selected = stats.alternatives.singleWhere((s) =>
        jsonEncode(s['move']) == jsonEncode(chosen!.toMap(game.current)));
    expect(stats.timedOut, isFalse);
    expect(losing['score']! as double, lessThan(-100000));
    expect(selected['score']! as double, greaterThan(-100000));
  });

  test('a terminal draw remains a valid defense against a horizon fork',
      () async {
    final cfg = MatchConfig(
        shape: BoardShape.square,
        size: 3,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    var game = MatchState.initial(cfg);
    for (final cell in [const Cell(0, 0), const Cell(0, 1), const Cell(1, 0)]) {
      game = MatchRules.play(game, MatchMove.place(cell, PieceType.flat))!;
    }
    game = game.copyWith(
        reserves: {...game.reserves, SeatId.charcoal: const Reserve(2, 0)});
    final quiet = MatchMove.place(const Cell(2, 2), PieceType.flat);
    late MatchSearchStats stats;
    await WideForkAI(onSearchComplete: (s) => stats = s)
        .choose(game, decisionSeed: 1);
    final drawing = stats.alternatives.singleWhere(
        (s) => jsonEncode(s['move']) == jsonEncode(quiet.toMap(game.current)));
    expect(stats.timedOut, isFalse);
    expect(drawing['score'], 0);
  });

  test('Medium deepens duels while retaining multiplayer and saved v2 targets',
      () async {
    for (final (players, engine, expectedDepth, expectedRounds) in [
      (2, 'shared-search-v3', 4, 2),
      (3, 'shared-search-v3', 3, 1),
      (2, 'shared-search-v2', 1, 0),
    ]) {
      final cfg = MatchConfig(
          shape: BoardShape.square,
          size: 3,
          aiEngine: engine,
          seats: SeatId.values.take(players).map(SeatConfig.new).toList());
      late MatchSearchStats stats;
      final move =
          await GenerousAI(BotLevel.medium, onSearchComplete: (s) => stats = s)
              .choose(MatchState.initial(cfg).copyWith(ply: players));
      expect(move, isNotNull);
      expect(stats.completedDepth, expectedDepth);
      expect(stats.completedRounds, expectedRounds);
      expect(stats.timedOut, isFalse);
    }
  });

  test('Expert establishes the same lower-depth fallback as Hard', () async {
    final game = MatchState.initial(MatchConfig(
        shape: BoardShape.square,
        size: 5,
        seats: const [
          SeatConfig(SeatId.ivory),
          SeatConfig(SeatId.charcoal)
        ])).copyWith(ply: 2, board: {
      const Cell(0, 0): const [Stone(SeatId.charcoal, PieceType.flat)],
      const Cell(1, 1): const [Stone(SeatId.ivory, PieceType.flat)],
    });
    late MatchSearchStats hardStats;
    late MatchSearchStats expertStats;
    final hard = await ExpiredChoiceAI(BotLevel.hard,
        onSearchComplete: (s) => hardStats = s).choose(game);
    final expert = await ExpiredChoiceAI(BotLevel.expert,
        onSearchComplete: (s) => expertStats = s).choose(game);
    expect(key(expert!), key(hard!));
    expect(expertStats.alternatives.length, hardStats.alternatives.length);
    expect(expertStats.alternatives.length, 12);
    expect(expertStats.completedRounds, 1);
  });

  test('native dispatch carries the same seed and final-choice policy',
      () async {
    final direct = await MatchAI(BotLevel.easy,
            variation: AiMoveVariation.ties, yieldDuringSearch: false)
        .choose(symmetric, decisionSeed: 123);
    final native = await selectMatchMove(symmetric, BotLevel.easy,
        variation: AiMoveVariation.ties, decisionSeed: 123);
    expect(key(native!), key(direct!));
  });

  test('unseeded experiments report a seed that reproduces their choice',
      () async {
    late MatchSearchStats stats;
    final move = await CompleteChoiceAI(BotLevel.medium,
        variation: AiMoveVariation.ties,
        onSearchComplete: (s) => stats = s).choose(symmetric);
    expect(stats.decisionSeed, isNotNull);
    final replay =
        await CompleteChoiceAI(BotLevel.medium, variation: AiMoveVariation.ties)
            .choose(symmetric, decisionSeed: stats.decisionSeed);
    expect(key(replay!), key(move!));
  });

  test('normal play ignores decision seeds and consumes no choice RNG',
      () async {
    late MatchSearchStats stats;
    final ai =
        CompleteChoiceAI(BotLevel.medium, onSearchComplete: (s) => stats = s);
    final first = await ai.choose(symmetric, decisionSeed: 1);
    final second = await ai.choose(symmetric, decisionSeed: 2);
    expect(key(first!), key(second!));
    expect(stats.decisionSeed, isNull);
  });

  test(
      'Medium uses its best completed score instead of a periodic second choice',
      () async {
    var game = MatchState.initial(MatchConfig(
        shape: BoardShape.square,
        size: 5,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]));
    for (final cell in [const Cell(0, 1), const Cell(3, 3)]) {
      game = MatchRules.play(game, MatchMove.place(cell, PieceType.flat))!;
    }
    late MatchSearchStats stats;
    final move = await CompleteChoiceAI(BotLevel.medium,
        onSearchComplete: (s) => stats = s).choose(game);
    final best = stats.alternatives
        .map((s) => s['score']! as double)
        .reduce((a, b) => a > b ? a : b);
    final chosen = stats.alternatives.singleWhere(
        (s) => jsonEncode(s['move']) == jsonEncode(move!.toMap(game.current)));
    expect(chosen['score'], best);
  });

  for (final policy in [AiMoveVariation.ties, AiMoveVariation.weighted]) {
    test('$policy repeats seeds and chooses only verified close alternatives',
        () async {
      final choices = <String>{};
      for (var seed = 0; seed < 12; seed++) {
        late MatchSearchStats stats;
        final ai = CompleteChoiceAI(BotLevel.medium,
            variation: policy, onSearchComplete: (s) => stats = s);
        final first = await ai.choose(symmetric, decisionSeed: seed);
        final second = await ai.choose(symmetric, decisionSeed: seed);
        expect(key(first!), key(second!));
        expect(stats.timedOut, isFalse);
        expect(stats.alternatives.every((s) => s['exact'] == true), isTrue);
        final scores = stats.alternatives.map((s) => s['score']! as double);
        final best = scores.reduce((a, b) => a > b ? a : b);
        final chosen = stats.alternatives
            .singleWhere((s) => jsonEncode(s['move']) == key(first));
        expect(
            chosen['score']! as double,
            greaterThanOrEqualTo(
                best - (policy == AiMoveVariation.ties ? 0 : 4)));
        choices.add(key(first));
      }
      expect(choices.length, greaterThan(1));
    });

    test('$policy preserves the least repeated eligible alternatives',
        () async {
      final initial = await CompleteChoiceAI(BotLevel.medium, variation: policy)
          .choose(symmetric, decisionSeed: 0);
      final repeated = aiPositionKey(MatchRules.play(symmetric, initial!)!);
      for (var seed = 0; seed < 5; seed++) {
        final move = await CompleteChoiceAI(BotLevel.medium, variation: policy)
            .choose(symmetric,
                decisionSeed: seed, recentPositionKeys: [repeated]);
        expect(
            aiPositionKey(MatchRules.play(symmetric, move!)!), isNot(repeated));
      }
    });

    test('$policy timeout uses deterministic completed baseline', () async {
      late MatchSearchStats stats;
      final first = await ExpiredChoiceAI(BotLevel.expert,
              variation: policy, onSearchComplete: (s) => stats = s)
          .choose(symmetric, decisionSeed: 0);
      final second = await ExpiredChoiceAI(BotLevel.expert, variation: policy)
          .choose(symmetric, decisionSeed: 1);
      expect(key(first!), key(second!));
      expect(stats.timedOut, isTrue);
      expect(stats.timeoutStage, 'roots');
      expect(stats.completedRounds, 1);
    });

    for (final level in BotLevel.values) {
      test('$policy $level preserves immediate wins and required defenses',
          () async {
        final base = MatchState.initial(MatchConfig(
            shape: BoardShape.square,
            size: 5,
            seats: const [
              SeatConfig(SeatId.ivory),
              SeatConfig(SeatId.charcoal)
            ]));
        for (final attacker in [SeatId.ivory, SeatId.charcoal]) {
          final game = base.copyWith(ply: 2, board: {
            for (final x in [0, 1, 3, 4])
              Cell(x, 2): [Stone(attacker, PieceType.flat)]
          });
          final move =
              await MatchAI(level, variation: policy, yieldDuringSearch: false)
                  .choose(game, decisionSeed: 42);
          final next = MatchRules.play(game, move!)!;
          if (attacker == SeatId.ivory) {
            expect(next.result?.winner, SeatId.ivory);
          } else {
            expect(
                MatchRules.legalMoves(next).any((reply) =>
                    MatchRules.play(next, reply)!.result?.winner == attacker),
                isFalse);
          }
        }
      });
    }
  }

  test('cap and flat diagnostics distinguish their actual board roles', () {
    final game = MatchState.initial(MatchConfig(
        shape: BoardShape.square,
        size: 5,
        seats: const [
          SeatConfig(SeatId.ivory),
          SeatConfig(SeatId.charcoal)
        ])).copyWith(ply: 2);
    final flat = MatchRules.play(
        game, MatchMove.place(const Cell(2, 2), PieceType.flat))!;
    final cap = MatchRules.play(
        game, MatchMove.place(const Cell(2, 2), PieceType.capstone))!;
    final flatTerms = MatchAI.evaluationTerms(flat, SeatId.ivory);
    final capTerms = MatchAI.evaluationTerms(cap, SeatId.ivory);
    expect(flatTerms['capMaterial'], 0);
    expect(capTerms['capMaterial'], 5);
    expect(capTerms['flats'], 0);
    expect(flatTerms['flats'], greaterThan(0));
    expect(flatTerms['road'], capTerms['road']);
    expect(flatTerms['development'], capTerms['development']);
    for (final position in [game, flat, cap]) {
      for (final seat in position.config.ids) {
        expect(
            MatchAI.evaluationTerms(position, seat)
                .values
                .reduce((a, b) => a + b),
            closeTo(MatchAI.evaluate(position)[seat]!, .000001));
      }
    }
  });

  test('early capstone can still make the only immediate road win', () async {
    final cfg = MatchConfig(
        shape: BoardShape.square,
        size: 5,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    final game = MatchState.initial(cfg).copyWith(ply: 2, board: {
      for (final x in [0, 1, 3, 4])
        Cell(x, 2): const [Stone(SeatId.ivory, PieceType.flat)]
    }, reserves: {
      SeatId.ivory: const Reserve(0, 1),
      SeatId.charcoal: Reserve.initial(cfg)
    });
    for (final level in BotLevel.values) {
      final move = await MatchAI(level, yieldDuringSearch: false).choose(game);
      expect(move!.type, PieceType.capstone);
      expect(MatchRules.play(game, move)!.result?.winner, SeatId.ivory);
    }
  });
}
