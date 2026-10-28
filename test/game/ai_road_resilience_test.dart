import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/ai_road_resilience.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_ai_engine.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';

const ivory = Stone(SeatId.ivory, PieceType.flat);
const charcoal = Stone(SeatId.charcoal, PieceType.flat);

MatchState position(Map<Cell, List<Stone>> board) => MatchState.initial(
        MatchConfig(shape: BoardShape.square, size: 5, seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal)
    ])).copyWith(ply: 6, board: board);

void main() {
  test('independent routes survive a blocker that damages a single route', () {
    final one = position({
      for (final x in [0, 1, 3, 4]) Cell(x, 1): [ivory]
    });
    final two = position({
      for (final y in [1, 3])
        for (final x in [0, 1, 3, 4]) Cell(x, y): [ivory]
    });
    final single = AiRoadResilience.measure(one, SeatId.ivory);
    final independent = AiRoadResilience.measure(two, SeatId.ivory);
    expect(single.cost, 1);
    expect(independent.cost, single.cost);
    expect(single.maximumIncrease, greaterThan(0));
    expect(independent.maximumIncrease, 0);
  });

  test('routes sharing the same gap retain a bottleneck', () {
    final game = position({
      for (final c in [
        const Cell(0, 1),
        const Cell(1, 1),
        const Cell(1, 2),
        const Cell(3, 2),
        const Cell(3, 3),
        const Cell(4, 3)
      ])
        c: [ivory],
    });
    final result = AiRoadResilience.measure(game, SeatId.ivory);
    expect(result.cost, 1);
    expect(result.maximumIncrease, greaterThan(0));
  });

  test('independent axes may share an un-coverable capstone', () {
    final game = position({
      for (final x in [0, 1, 4]) Cell(x, 2): [ivory],
      for (final y in [0, 1, 4]) Cell(2, y): [ivory],
      const Cell(2, 2): const [Stone(SeatId.ivory, PieceType.capstone)],
    });
    final result = AiRoadResilience.measure(game, SeatId.ivory);
    expect(result.cost, 1);
    expect(result.maximumIncrease, 0);
  });

  test('legal captures expose flat vulnerability while a cap cannot be covered',
      () {
    final flat = position({
      const Cell(0, 2): [ivory],
      const Cell(1, 2): [ivory],
      for (final y in [1, 3])
        for (final x in [1, 2, 4]) Cell(x, y): [ivory],
      const Cell(2, 2): [charcoal]
    });
    final cap = position({
      ...flat.board,
      const Cell(1, 2): const [Stone(SeatId.ivory, PieceType.capstone)]
    });
    final a = AiRoadResilience.measure(flat, SeatId.ivory);
    final b = AiRoadResilience.measure(cap, SeatId.ivory);
    expect(a.cost, b.cost);
    expect(a.maximumIncrease, 1);
    expect(b.maximumIncrease, 0);
    expect(a.score(1000), greaterThanOrEqualTo(-40));
    expect(a.score(0), 0);
  });

  test(
      'recorded quiet flat creates an opposing bottleneck beyond equal distance',
      () {
    final row = jsonDecode(File('docs/qa/ai-balance-hex-counterexample.jsonl')
        .readAsStringSync()) as Map;
    var game = MatchState.initial(
        MatchConfig.fromMap(Map<String, dynamic>.from(row['config'])));
    for (final raw in (row['moves'] as List).take(5)) {
      game = MatchRules.play(
          game, MatchMove.fromMap(Map<String, dynamic>.from(raw)))!;
    }
    final greedy = MatchRules.play(
        game, MatchMove.place(const Cell(0, 0), PieceType.flat))!;
    final defense = MatchRules.play(
        game, MatchMove.place(const Cell(1, 0), PieceType.flat))!;
    double utility(MatchState g, {required bool resilience}) {
      final scores = MatchAI.evaluate(g);
      if (resilience) {
        for (final id in g.config.ids) {
          scores[id] = scores[id]! + AiRoadResilience.measure(g, id).score(16);
        }
      }
      return scores[SeatId.charcoal]! - scores[SeatId.ivory]!;
    }

    expect(MatchAI.pathCost(greedy, SeatId.ivory),
        MatchAI.pathCost(defense, SeatId.ivory));
    expect(AiRoadResilience.measure(greedy, SeatId.ivory).maximumIncrease, 0);
    expect(AiRoadResilience.measure(defense, SeatId.ivory).maximumIncrease, 1);
    expect(utility(greedy, resilience: false),
        greaterThan(utility(defense, resilience: false)));
    expect(utility(defense, resilience: true),
        greaterThan(utility(greedy, resilience: true)));
  });

  test('resilience and cheapest cost preserve topology and color symmetries',
      () {
    for (final shape in BoardShape.values) {
      final config = MatchConfig(
          shape: shape,
          size: shape == BoardShape.square ? 5 : 2,
          seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
      var game = MatchState.initial(config);
      for (var ply = 0; ply < 6 && !game.finished; ply++) {
        final legal = MatchRules.legalMoves(game).toList();
        game = MatchRules.play(game, legal[(ply * 13) % legal.length])!;
      }
      SeatId swap(SeatId id) =>
          id == SeatId.ivory ? SeatId.charcoal : SeatId.ivory;
      Cell rotate(Cell c) => shape == BoardShape.square
          ? Cell(4 - c.y, c.x)
          : Cell(-c.y, c.x + c.y);
      final mirror = MatchState(
          config: config.copyWith(starter: SeatId.charcoal),
          ply: game.ply,
          board: game.board.map((c, stack) => MapEntry(rotate(c),
              stack.map((s) => Stone(swap(s.seat), s.type)).toList())),
          reserves: game.reserves.map((id, r) => MapEntry(swap(id), r)));
      for (final id in config.ids) {
        final a = AiRoadResilience.measure(game, id);
        final b = AiRoadResilience.measure(mirror, swap(id));
        expect(a.cost, MatchAI.pathCost(game, id).clamp(0, 3));
        expect(b.cost, a.cost);
        expect(b.maximumIncrease, a.maximumIncrease);
      }
    }
  });

  test('opening and terminal positions have no resilience adjustment', () {
    final game = position({});
    expect(
        AiRoadResilience.measure(game.copyWith(ply: 0), SeatId.ivory).score(16),
        0);
    expect(
        AiRoadResilience.measure(
                game.copyWith(
                    result: const MatchResult(SeatId.ivory, ResultReason.road)),
                SeatId.ivory)
            .score(16),
        0);
  });
}
