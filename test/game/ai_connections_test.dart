import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/ai_duel_tactics.dart';
import 'package:stones/game/ai_road_connections.dart';
import 'package:stones/game/ai_tactics.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/services/ai/search_budget.dart';

void main() {
  for (final shape in BoardShape.values) {
    for (final size in shape == BoardShape.square ? [3, 5, 8] : [2, 3, 4]) {
      test('$shape/$size component wins equal full legal adjudication',
          () async {
        for (final seats in [2, 3, 4]) {
          final config = MatchConfig(
              shape: shape,
              size: size,
              seats: SeatId.values.take(seats).map(SeatConfig.new).toList());
          for (var seed = 0; seed < 3; seed++) {
            var game = MatchState.initial(config);
            final random = Random(seed * 31 + size);
            for (var ply = 0; ply < 36 && !game.finished; ply++) {
              final legal = MatchRules.legalMoves(game).toList();
              final expected = [
                for (final move in legal)
                  if (MatchRules.play(game, move)!.result?.winner ==
                      game.current)
                    jsonEncode(move.toMap(game.current))
              ];
              final found = await aiDuelWinningMoves(
                  game, game.current, SearchBudget(enabled: false));
              expect(
                  found.map((m) => jsonEncode(m.toMap(game.current))).toList(),
                  expected);
              game =
                  MatchRules.play(game, legal[random.nextInt(legal.length)])!;
            }
          }
        }
      });
    }
  }
  test('two-placement completions and common gaps agree with exhaustive pairs',
      () {
    for (final shape in BoardShape.values) {
      final cfg = MatchConfig(
          shape: shape,
          size: shape == BoardShape.square ? 4 : 2,
          seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
      for (var seed = 0; seed < 16; seed++) {
        var game = MatchState.initial(cfg);
        final random = Random(seed);
        for (var ply = 0; ply < 8 && !game.finished; ply++) {
          final legal = MatchRules.legalMoves(game).toList();
          game = MatchRules.play(game, legal[random.nextInt(legal.length)])!;
        }
        if (game.finished) continue;
        for (final seat in cfg.ids) {
          final road = AiRoadConnections(game, seat);
          final empty =
              game.geometry.cells.where((c) => game.topAt(c) == null).toList();
          bool completes(Set<Cell> cells) => MatchRules.road(
                  game.copyWith(board: {
                    ...game.board,
                    for (final c in cells) c: [Stone(seat, PieceType.flat)]
                  }),
                  seat)
              .isNotEmpty;
          final singles = {
            for (final c in empty)
              if (completes({c})) c
          };
          expect(road.winningCells, singles);
          final sets = <Set<Cell>>[];
          if (singles.isNotEmpty) {
            sets.addAll(singles.map((c) => {c}));
          } else {
            for (var i = 0; i < empty.length; i++) {
              for (var j = i + 1; j < empty.length; j++) {
                final pair = {empty[i], empty[j]};
                if (completes(pair)) sets.add(pair);
              }
            }
          }
          final pairs = <Cell, int>{};
          if (singles.isEmpty) {
            for (final pair in sets) {
              for (final c in pair) {
                pairs.update(c, (n) => n + 1, ifAbsent: () => 1);
              }
            }
          }
          expect(road.pairContinuations, pairs);
          final expected = sets.isEmpty ? 3 : sets.first.length;
          expect(road.continuations.gaps, expected);
          expect(
              road.continuations.criticalCells,
              sets.isEmpty
                  ? <Cell>{}
                  : sets.reduce((a, b) => a.intersection(b)));
        }
      }
    }
  });
  test('flat endings and unresolved roads retain exact canonical handling',
      () async {
    final config = MatchConfig(
        shape: BoardShape.square,
        size: 3,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    final game = MatchState.initial(config).copyWith(ply: 4, board: {
      for (var x = 0; x < 3; x++)
        Cell(x, 0): const [Stone(SeatId.ivory, PieceType.flat)]
    });
    for (final position in [
      game,
      game.copyWith(
          reserves: {...game.reserves, SeatId.ivory: const Reserve(1, 0)})
    ]) {
      final actual = await aiDuelWinningMoves(
          position, SeatId.ivory, SearchBudget(enabled: false));
      final expected = await aiWinningMoves(
          position, SeatId.ivory, SearchBudget(enabled: false));
      expect(actual.map((m) => jsonEncode(m.toMap(SeatId.ivory))).toList(),
          expected.map((m) => jsonEncode(m.toMap(SeatId.ivory))).toList());
    }
  });
  test('flat-winning placements and spreads agree with canonical road priority',
      () async {
    final cfg = MatchConfig(
        shape: BoardShape.square,
        size: 3,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    const own = Stone(SeatId.ivory, PieceType.flat);
    const wall = Stone(SeatId.charcoal, PieceType.standing);
    final placement = MatchState.initial(cfg).copyWith(ply: 4, board: {
      for (final c in MatchState.initial(cfg).geometry.cells)
        if (c != const Cell(2, 2))
          c: [
            c == const Cell(0, 0) ||
                    c == const Cell(0, 1) ||
                    c == const Cell(1, 0)
                ? own
                : wall
          ]
    });
    final spread = MatchState.initial(cfg).copyWith(ply: 4, board: {
      for (final c in MatchState.initial(cfg).geometry.cells)
        if (c != const Cell(1, 0))
          c: c == const Cell(0, 0)
              ? [wall, own]
              : [c == const Cell(1, 1) || c == const Cell(2, 2) ? own : wall]
    });
    for (final g in [placement, spread]) {
      final expected = [
        for (final m in MatchRules.legalMoves(g))
          if (MatchRules.play(g, m)!.result?.winner == SeatId.ivory)
            jsonEncode(m.toMap(g.current))
      ];
      final actual = await aiDuelWinningMoves(
          g, SeatId.ivory, SearchBudget(enabled: false));
      expect(
          actual.map((m) => jsonEncode(m.toMap(g.current))).toList(), expected);
      expect(actual, isNotEmpty);
    }
    expect(
        MatchRules.play(spread,
                MatchMove.spread(const Cell(0, 0), Step.east, const [1]))!
            .result
            ?.reason,
        ResultReason.flats);
  });
}
