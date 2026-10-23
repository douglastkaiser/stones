import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_ai.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';

void main() {
  for (final shape in BoardShape.values) {
    for (final level in [BotLevel.hard, BotLevel.expert]) {
      test('$shape $level develops connected material on the largest board',
          () async {
        final config = MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 8 : 4,
            seats: const [
              SeatConfig(SeatId.ivory),
              SeatConfig(SeatId.charcoal)
            ]);
        final home =
            shape == BoardShape.square ? const Cell(4, 4) : const Cell(0, 0);
        final rival =
            shape == BoardShape.square ? const Cell(0, 0) : const Cell(-4, 0);
        final game = MatchState.initial(config).copyWith(ply: 2, board: {
          home: const [Stone(SeatId.ivory, PieceType.flat)],
          rival: const [Stone(SeatId.charcoal, PieceType.flat)],
        });
        final move =
            await MatchAI(level, yieldDuringSearch: false).choose(game);
        expect(move, isNotNull);
        expect(MatchRules.play(game, move!), isNotNull);
        expect(move.type, isNotNull,
            reason: 'Develop rather than relocate the only road stone');
        expect(game.geometry.directions.any((d) => home.step(d) == move.from),
            isTrue,
            reason:
                'Extend the central road instead of scattering on a distant edge: ${move.from}');
      });
    }
  }
  for (final shape in BoardShape.values) {
    for (final count in [2, 4]) {
      for (final level in BotLevel.values) {
        for (final defend in [false, true]) {
          test(
              '$shape $count seats $level ${defend ? "blocks" : "takes"} a late-board road',
              () async {
            final config = MatchConfig(
                shape: shape,
                size: shape == BoardShape.square ? 8 : 4,
                seats: SeatId.values.take(count).map(SeatConfig.new).toList());
            final owner = defend ? SeatId.charcoal : SeatId.ivory;
            final gap = shape == BoardShape.square
                ? const Cell(7, 7)
                : const Cell(3, 0);
            final game =
                MatchState.initial(config).copyWith(ply: count, board: {
              if (shape == BoardShape.square)
                for (var x = 0; x < 7; x++)
                  Cell(x, 7): [Stone(owner, PieceType.flat)]
              else
                for (var x = -4; x <= 4; x++)
                  if (Cell(x, 0) != gap)
                    Cell(x, 0): [Stone(owner, PieceType.flat)],
            });
            final move =
                await MatchAI(level, yieldDuringSearch: false).choose(game);
            final next = MatchRules.play(game, move!)!;
            if (defend) {
              expect(next.topAt(gap)?.seat, SeatId.ivory);
              expect(
                  MatchRules.legalMoves(next).any((reply) =>
                      MatchRules.play(next, reply)!.result?.winner == owner),
                  isFalse);
            } else {
              expect(next.result?.winner, owner);
            }
          });
        }
      }
    }
  }

  for (final level in [BotLevel.medium, BotLevel.hard, BotLevel.expert]) {
    test('$level accounts for road defense across a full radius-4 Hex round',
        () async {
      final config = MatchConfig(shape: BoardShape.hex, size: 4, seats: const [
        SeatConfig(SeatId.ivory,
            control: SeatControl.ai, level: BotLevel.medium),
        SeatConfig(SeatId.charcoal,
            control: SeatControl.ai, level: BotLevel.hard),
        SeatConfig(SeatId.copper,
            control: SeatControl.ai, level: BotLevel.expert),
      ]);
      final game = MatchState.initial(config).copyWith(ply: 3, board: {
        for (var x = -4; x <= -2; x++)
          Cell(x, 0): const [Stone(SeatId.ivory, PieceType.flat)],
        for (var y = -4; y <= 2; y++)
          Cell(0, y): const [Stone(SeatId.charcoal, PieceType.flat)],
        for (var x = 2; x <= 4; x++)
          Cell(x, -x): const [Stone(SeatId.copper, PieceType.flat)],
        // The third seat has closed the side routes, leaving a two-move
        // approach that can be contested now rather than on the last gap.
        for (final cell in const [
          Cell(-1, 3),
          Cell(-1, 4),
          Cell(1, 2),
          Cell(1, 3)
        ])
          cell: const [Stone(SeatId.copper, PieceType.standing)],
      });
      final before = MatchAI.pathCost(game, SeatId.charcoal);
      expect(before, 2);
      var position = game;
      for (var turn = 0;
          turn < config.seats.length && !position.finished;
          turn++) {
        final actor = position.current;
        final move = await MatchAI(turn == 0 ? level : config.seat(actor).level,
                yieldDuringSearch: false)
            .choose(position);
        final next = MatchRules.play(position, move!)!;
        position = next;
      }
      // Full-round search may anticipate a later block, and the leader can
      // develop an alternative instead. It must not advance uncontested.
      if (!position.finished) {
        expect(MatchAI.pathCost(position, SeatId.charcoal),
            greaterThanOrEqualTo(before),
            reason:
                'The leading road must not progress uncontested across the round');
      }
      expect(position.result?.winner, isNot(SeatId.charcoal));
    });
  }

  test(
      'indexed path search agrees with independent shortest paths at every size',
      () {
    final random = math.Random(491);
    for (final shape in BoardShape.values) {
      for (var size = shape == BoardShape.square ? 3 : 2;
          size <= (shape == BoardShape.square ? 8 : 4);
          size++) {
        final initial = MatchState.initial(MatchConfig(
            shape: shape,
            size: size,
            seats: SeatId.values.map(SeatConfig.new).toList()));
        for (var sample = 0; sample < 4; sample++) {
          final game = initial.copyWith(ply: 4, board: {
            for (final cell in initial.geometry.cells)
              if (random.nextBool())
                cell: [
                  Stone(SeatId.values[random.nextInt(4)],
                      PieceType.values[random.nextInt(3)])
                ]
          });
          for (final seat in game.config.ids) {
            expect(MatchAI.pathCost(game, seat), _referencePathCost(game, seat),
                reason: '$shape size $size sample $sample seat $seat');
          }
        }
      }
    }
  });
}

// A simple minimum-scan Dijkstra provides a separate reference implementation.
double _referencePathCost(MatchState game, SeatId seat) {
  var best = double.infinity;
  for (var axis = 0; axis < game.geometry.axisCount; axis++) {
    int cost(Cell cell) {
      final top = game.topAt(cell);
      if (top == null) return 1;
      if (top.seat == seat && top.type != PieceType.standing) return 0;
      return top.type == PieceType.flat ? 3 : 6;
    }

    final pending = game.geometry.cells.toSet();
    final distances = {
      for (final cell in pending)
        cell: game.geometry.boundary(cell, axis, false) ? cost(cell) : 1000
    };
    while (pending.isNotEmpty) {
      final cell =
          pending.reduce((a, b) => distances[a]! < distances[b]! ? a : b);
      pending.remove(cell);
      final distance = distances[cell]!;
      if (game.geometry.boundary(cell, axis, true)) {
        best = math.min(best, distance.toDouble());
        break;
      }
      for (final direction in game.geometry.directions) {
        final next = cell.step(direction);
        if (pending.contains(next)) {
          distances[next] = math.min(distances[next]!, distance + cost(next));
        }
      }
    }
  }
  return best;
}
