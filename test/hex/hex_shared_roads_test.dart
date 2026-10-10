import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_ai.dart';
import 'package:stones/models/piece.dart';

List<HexCell> arc(int radius, int rotations) {
  var cells = [
    for (var n = 0; n <= radius; n++) HexCell(-n, -radius + n),
    for (var n = 1; n <= radius; n++) HexCell(-radius, n),
  ];
  for (var n = 0; n < rotations; n++) {
    cells = [for (final cell in cells) HexCell(cell.s, cell.q)];
  }
  return cells;
}

void main() {
  test('bucketed AI costs agree with independent relaxation for both versions',
      () {
    final random = Random(21532);
    for (final radius in [2, 3, 4]) {
      for (final version in [1, 2]) {
        final empty = HexGame.initial(radius: radius, rulesVersion: version);
        for (var n = 0; n < 24; n++) {
          final game = empty.copyWith(ply: 3, board: {
            for (final cell in empty.cells)
              if (random.nextBool())
                cell: [
                  HexStone(HexSeat.values[random.nextInt(3)],
                      PieceType.values[random.nextInt(3)])
                ],
          });
          for (final seat in HexSeat.values) {
            expect(HexAI.roadCost(game, seat), referenceCost(game, seat));
          }
        }
      }
    }
  });

  test('neighboring sides and disconnected opposite endpoints are not roads',
      () {
    for (final cells in [
      [const HexCell(0, -2), const HexCell(1, -2), const HexCell(2, -2)],
      [
        const HexCell(0, -2),
        const HexCell(0, 2),
        const HexCell(-2, 0),
        const HexCell(2, 0)
      ],
    ]) {
      final game = HexGame.initial().copyWith(ply: 3, board: {
        for (final cell in cells)
          cell: [const HexStone(HexSeat.ivory, PieceType.flat)],
      });
      expect(HexRules.road(game, HexSeat.ivory), isEmpty);
      expect(HexRules.resolve(game, HexSeat.ivory).finished, isFalse);
    }
  });

  for (final radius in [2, 3, 4]) {
    for (final seat in HexSeat.values) {
      for (var rotation = 0; rotation < 3; rotation++) {
        test('${seat.name} can use shared pair $rotation on radius $radius',
            () {
          final path = arc(radius, rotation);
          final game = HexGame.initial(radius: radius, starter: seat)
              .copyWith(ply: 3, board: {
            for (final cell in path) cell: [HexStone(seat, PieceType.flat)],
          });
          final axes = HexAxis.values.where(
              (axis) => HexRules.roadOnAxis(game, seat, axis).isNotEmpty);
          expect(axes.length, 1, reason: 'An arc isolates one opposite pair');
          expect(HexRules.resolve(game, seat).winner, seat);
          final missing = path.first;
          final before = game.copyWith(board: {...game.board}..remove(missing));
          expect(HexRules.resolve(before, seat).finished, isFalse);
          final after = HexRules.play(
              before, HexMove.place(missing, PieceType.capstone))!;
          expect(after.winner, seat);
          expect(after.rulesVersion, 2);
        });
      }
    }
  }

  for (final seat in HexSeat.values) {
    test('both AI paths take ${seat.name} wins on any shared pair', () async {
      for (var rotation = 0; rotation < 3; rotation++) {
        final path = arc(2, rotation);
        final game = HexGame.initial(starter: seat).copyWith(ply: 3, board: {
          for (final cell in path.skip(1))
            cell: [HexStone(seat, PieceType.flat)],
        });
        expect(HexRules.play(game, HexAI.choose(game)!)!.winner, seat);
        expect(
            HexRules.play(game, (await HexAI.chooseResponsive(game))!)!.winner,
            seat);
      }
    });
  }

  test('two parallel shared roads use mover priority; other mover draws', () {
    final left = arc(2, 0);
    final game = HexGame.initial().copyWith(ply: 3, board: {
      for (final cell in left)
        cell: [const HexStone(HexSeat.ivory, PieceType.flat)],
      for (final cell in left)
        HexCell(-cell.q, -cell.r): [
          const HexStone(HexSeat.charcoal, PieceType.flat)
        ],
    });
    expect(HexRules.resolve(game, HexSeat.ivory).winner, HexSeat.ivory);
    expect(HexRules.resolve(game, HexSeat.charcoal).winner, HexSeat.charcoal);
    final draw = HexRules.resolve(game, HexSeat.copper);
    expect(draw.finished, isTrue);
    expect(draw.winner, isNull);
    expect(draw.reason, 'Simultaneous opponent roads — draw');
  });

  test('legacy games retain assigned pairs and preserve version through moves',
      () {
    final cells = arc(2, 0);
    final game = HexGame.initial(rulesVersion: 1).copyWith(ply: 3, board: {
      for (final cell in cells)
        cell: [const HexStone(HexSeat.ivory, PieceType.flat)],
    });
    expect(HexRules.road(game, HexSeat.ivory), isEmpty);
    expect(HexRules.resolve(game, HexSeat.ivory).finished, isFalse);
    final next = HexRules.play(
        game, HexMove.place(const HexCell(0, 0), PieceType.standing))!;
    expect(next.rulesVersion, 1);
  });
}

// Relaxation over cube-distance neighbors, independent of the bucket queue
// and HexDirection iteration used by production evaluation.
double referenceCost(HexGame game, HexSeat seat) {
  final cells = game.cells.toList();
  final costs = <HexCell, int>{};
  for (final cell in cells) {
    final top = game.topAt(cell);
    costs[cell] = top == null
        ? 1
        : top.seat == seat && top.type != PieceType.standing
            ? 0
            : top.type == PieceType.flat
                ? 3
                : 6;
  }
  var best = 1000;
  for (var axis = 0; axis < 3; axis++) {
    if (game.rulesVersion == 1 && axis != seat.index) {
      continue;
    }
    int coordinate(HexCell cell) => [cell.q, cell.r, -cell.q - cell.r][axis];
    final distances = {
      for (final cell in cells)
        cell: coordinate(cell) == -game.radius ? costs[cell]! : 1000
    };
    for (var n = 0; n < cells.length; n++) {
      var changed = false;
      for (final a in cells) {
        for (final b in cells) {
          if (max((a.q - b.q).abs(),
                  max((a.r - b.r).abs(), (a.s - b.s).abs())) !=
              1) {
            continue;
          }
          final candidate = distances[a]! + costs[b]!;
          if (candidate < distances[b]!) {
            distances[b] = candidate;
            changed = true;
          }
        }
      }
      if (!changed) break;
    }
    best = min(
        best,
        cells
            .where((cell) => coordinate(cell) == game.radius)
            .map((cell) => distances[cell]!)
            .reduce(min));
  }
  return best.toDouble();
}
