import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/ai_duel_safety.dart';
import 'package:stones/game/match_ai_engine.dart';
import 'package:stones/game/ai_search_cache.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/services/ai/search_budget.dart';
import '../../tools/ai_balance_proof.dart';

class SafetyProbeAI extends MatchAI {
  SafetyProbeAI(
      {required bool enabled, this.expired = false, super.onSearchComplete})
      : super(BotLevel.hard,
            tacticalSafety: enabled,
            yieldDuringSearch: false,
            duelThinkingLimit: expired ? Duration.zero : null);
  final bool expired;
  @override
  int get depth => 0;
  @override
  Duration get thinkingLimit => const Duration(seconds: 5);
}

MatchState counterexample() {
  final row = jsonDecode(File('docs/qa/ai-balance-hex-counterexample.jsonl')
      .readAsStringSync()) as Map;
  var game = MatchState.initial(
      MatchConfig.fromMap(Map<String, dynamic>.from(row['config'])));
  for (final raw in (row['moves'] as List).take(5)) {
    game = MatchRules.play(
        game, MatchMove.fromMap(Map<String, dynamic>.from(raw)))!;
  }
  return game;
}

void main() {
  for (final shape in BoardShape.values) {
    test('$shape safety objective equals independent bounded minimax',
        () async {
      final cfg = MatchConfig(
          shape: shape,
          size: shape == BoardShape.square ? 3 : 2,
          seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
      for (var seed = 0; seed < 6; seed++) {
        var game = MatchState.initial(cfg);
        final rng = Random(6100 + seed);
        for (var p = 0; p < 8 && !game.finished; p++) {
          final legal = MatchRules.legalMoves(game).toList();
          game = MatchRules.play(game, legal[rng.nextInt(legal.length)])!;
        }
        final cache = AiSearchCache(capacity: 100);
        for (final attacker in cfg.ids) {
          for (final horizon in [1, 2, 3]) {
            final expected = BoundedDuelProof().solve(game, attacker, horizon);
            expect(expected, isNot(DuelProof.unknown));
            final actual =
                await AiDuelSafety(SearchBudget(enabled: false), cache: cache)
                    .forced(game, attacker, horizon);
            expect(actual, expected == DuelProof.proven);
          }
        }
      }
    });
  }
  test('known greedy loss is proved and quiet defense is refuted', () async {
    final row = jsonDecode(File('docs/qa/ai-balance-hex-counterexample.jsonl')
        .readAsStringSync()) as Map;
    var game = MatchState.initial(
        MatchConfig.fromMap(Map<String, dynamic>.from(row['config'])));
    for (final raw in (row['moves'] as List).take(5)) {
      game = MatchRules.play(
          game, MatchMove.fromMap(Map<String, dynamic>.from(raw)))!;
    }
    final proof =
        AiDuelSafety(SearchBudget(enabled: false), cache: AiSearchCache());
    expect(
        await proof.forced(
            MatchRules.play(
                game, MatchMove.place(const Cell(0, 0), PieceType.flat))!,
            SeatId.ivory,
            3),
        isTrue);
    expect(
        await proof.forced(
            MatchRules.play(
                game, MatchMove.place(const Cell(1, 0), PieceType.flat))!,
            SeatId.ivory,
            3),
        isFalse);
  });
  test('five-ply safety agrees with the earlier preventive-defense oracle',
      () async {
    final row = jsonDecode(File('docs/qa/ai-balance-hex-counterexample.jsonl')
        .readAsStringSync()) as Map;
    var game = MatchState.initial(
        MatchConfig.fromMap(Map<String, dynamic>.from(row['config'])));
    for (final raw in (row['moves'] as List).take(3)) {
      game = MatchRules.play(
          game, MatchMove.fromMap(Map<String, dynamic>.from(raw)))!;
    }
    for (final move in [
      MatchMove.place(const Cell(1, 0), PieceType.capstone),
      MatchMove.fromMap(Map<String, dynamic>.from(row['moves'][3]))
    ]) {
      final next = MatchRules.play(game, move)!;
      final expected =
          BoundedDuelProof(maxNodes: 1000000).solve(next, SeatId.ivory, 5);
      expect(expected, isNot(DuelProof.unknown));
      expect(
          await AiDuelSafety(SearchBudget(enabled: false),
                  cache: AiSearchCache())
              .forced(next, SeatId.ivory, 5),
          expected == DuelProof.proven);
    }
  });
  test('an interrupted proof cannot publish a forced-loss result', () async {
    final cfg = MatchConfig(
        shape: BoardShape.square,
        size: 3,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    var game = MatchState.initial(cfg);
    for (final c in [
      const Cell(0, 0),
      const Cell(0, 1),
      const Cell(1, 0),
      const Cell(1, 1)
    ]) {
      game = MatchRules.play(game, MatchMove.place(c, PieceType.flat))!;
    }
    final cache = AiSearchCache();
    await expectLater(
        AiDuelSafety(SearchBudget(enabled: false), cache: cache, nodeLimit: 1)
            .forced(game, SeatId.ivory, 3),
        throwsA(isA<SearchTimedOut>()));
    final expected = BoundedDuelProof().solve(game, SeatId.ivory, 3);
    expect(
        await AiDuelSafety(SearchBudget(enabled: false), cache: cache)
            .forced(game, SeatId.ivory, 3),
        expected == DuelProof.proven);
  });
  test('a completed strategic choice changes only with an independent proof',
      () async {
    final game = counterexample();
    final before = await SafetyProbeAI(enabled: false).choose(game);
    late MatchSearchStats stats;
    final after =
        await SafetyProbeAI(enabled: true, onSearchComplete: (s) => stats = s)
            .choose(game);
    if (stats.safetyVetoes == 0) {
      expect(after!.toMap(game.current), before!.toMap(game.current));
    } else {
      expect(stats.safetyReplacedMove, before!.toMap(game.current));
      expect(
          BoundedDuelProof(maxNodes: 1000000).solve(
              MatchRules.play(game, before)!, SeatId.ivory, stats.safetyPlies),
          DuelProof.proven);
      expect(
          BoundedDuelProof(maxNodes: 1000000).solve(
              MatchRules.play(game, after!)!, SeatId.ivory, stats.safetyPlies),
          DuelProof.refuted);
    }
  });
  test('an exhausted safety allowance cannot invent a veto', () async {
    final game = counterexample();
    final before =
        await SafetyProbeAI(enabled: false, expired: true).choose(game);
    late MatchSearchStats stats;
    final after = await SafetyProbeAI(
        enabled: true,
        expired: true,
        onSearchComplete: (s) => stats = s).choose(game);
    expect(after!.toMap(game.current), before!.toMap(game.current));
    expect(stats.safetyVetoes, 0);
    expect(stats.safetyUnknown, isTrue);
  });
}
