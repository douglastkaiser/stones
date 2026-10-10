import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/models/piece.dart';

const ivory = HexStone(HexSeat.ivory, PieceType.flat);
const charcoal = HexStone(HexSeat.charcoal, PieceType.flat);
const copper = HexStone(HexSeat.copper, PieceType.flat);

/// Exact visible tops/heights from 21532.jpg. Buried colors cannot be read
/// from the screenshot; this assignment matches the visible reserve totals.
HexGame reportedPosition({int rulesVersion = 2}) =>
    HexGame(rulesVersion: rulesVersion, radius: 2, ply: 40, reserves: const [
      HexReserve(5, 1),
      HexReserve(7, 1),
      HexReserve(9, 0)
    ], board: {
      const HexCell(0, -2): [ivory],
      const HexCell(1, -2): [charcoal],
      const HexCell(2, -2): [charcoal],
      const HexCell(-1, -1): [ivory],
      const HexCell(0, -1): [ivory],
      const HexCell(2, -1): [copper, charcoal],
      const HexCell(-2, 0): [ivory],
      const HexCell(-1, 0): [copper],
      const HexCell(0, 0): [ivory, ivory, ivory, copper, ivory],
      const HexCell(1, 0): [copper],
      const HexCell(2, 0): [copper],
      const HexCell(-2, 1): [ivory],
      const HexCell(-1, 1): [copper],
      const HexCell(0, 1): [
        charcoal,
        charcoal,
        const HexStone(HexSeat.copper, PieceType.capstone)
      ],
      const HexCell(1, 1): [charcoal],
      const HexCell(-2, 2): [ivory],
      const HexCell(-1, 2): [charcoal],
      const HexCell(0, 2): [charcoal],
    });

/// Independent connected-components oracle. Uses cube distance rather than
/// HexDirection/road traversal, and explicit boundary pairs rather than axis().
bool oracleRoad(HexGame game, HexSeat seat) {
  final cells = game.cells.where((cell) {
    final top = game.topAt(cell);
    return top?.seat == seat && top?.type != PieceType.standing;
  }).toSet();
  while (cells.isNotEmpty) {
    final component = {cells.first};
    cells.remove(component.first);
    var changed = true;
    while (changed) {
      changed = false;
      for (final candidate in cells.toList()) {
        if (component.any((cell) =>
            max(
                (cell.q - candidate.q).abs(),
                max((cell.r - candidate.r).abs(),
                    (cell.s - candidate.s).abs())) ==
            1)) {
          component.add(candidate);
          cells.remove(candidate);
          changed = true;
        }
      }
    }
    for (var axis = 0; axis < 3; axis++) {
      if (game.rulesVersion == 1 && axis != seat.index) {
        continue;
      }
      final coordinates = component
          .map((cell) => switch (axis) {
                0 => cell.q,
                1 => cell.r,
                _ => -cell.q - cell.r,
              })
          .toSet();
      if (coordinates.contains(-game.radius) &&
          coordinates.contains(game.radius)) {
        return true;
      }
    }
  }
  return false;
}

void main() {
  test('reported screenshot is an Ivory top-to-bottom road under shared goals',
      () {
    final game = reportedPosition();
    expect(oracleRoad(game, HexSeat.ivory), isTrue);
    final path = HexRules.road(game, HexSeat.ivory);
    expect(path, containsAll([const HexCell(0, -2), const HexCell(-2, 2)]));
    final result = HexRules.resolve(game, HexSeat.ivory);
    expect(result.finished, isTrue);
    expect(result.winner, HexSeat.ivory);
    expect(result.reason, 'Road');
    expect(HexRules.legalMoves(result), isEmpty);
  });

  test('legacy screenshot obeys its original assigned goals', () {
    final game = reportedPosition(rulesVersion: 1);
    final ivoryTops =
        game.cells.where((cell) => game.topAt(cell)?.seat == HexSeat.ivory);
    expect(ivoryTops.map((cell) => cell.r), containsAll([-2, 2]));
    expect(ivoryTops.any((cell) => cell.q == 2), isFalse);
    for (final seat in HexSeat.values) {
      expect(HexRules.road(game, seat), isEmpty);
      expect(oracleRoad(game, seat), isFalse);
    }
    expect(HexRules.resolve(game, HexSeat.ivory).finished, isFalse);
    expect(HexRules.flatCounts(game), [7, 6, 4]);
    // The lone empty hex does not end the game; exposed stacks remain occupied.
    expect(game.cells.where((cell) => game.stackAt(cell).isEmpty).single,
        const HexCell(1, -1));
  });

  test('a completed whole spread reaches the missing Ivory goal and ends play',
      () {
    final before = reportedPosition(rulesVersion: 1).copyWith(ply: 39);
    final result = HexRules.play(before,
        HexMove.spread(const HexCell(0, 0), HexDirection.northEast, [3, 2]))!;
    expect(result.finished, isTrue);
    expect(result.winner, HexSeat.ivory);
    expect(result.reason, 'Road');
    expect(result.current, HexSeat.charcoal);
    expect(
        HexRules.road(result, HexSeat.ivory), contains(const HexCell(2, -2)));
    expect(HexRules.legalMoves(result), isEmpty);
  });

  test('reported position waits for the final hole before scoring flats', () {
    final game = reportedPosition(rulesVersion: 1);
    final drawn = HexRules.play(
        game, HexMove.place(const HexCell(1, -1), PieceType.flat))!;
    expect(drawn.finished, isTrue);
    expect(drawn.winner, isNull);
    expect(drawn.reason, 'Tied flats — draw');
    expect(HexRules.flatCounts(drawn), [7, 7, 4]);
    final won = HexRules.play(
        game, HexMove.place(const HexCell(1, -1), PieceType.standing))!;
    expect(won.winner, HexSeat.ivory);
    expect(won.reason, 'Flats');
  });

  for (var radius = 2; radius <= 4; radius++) {
    test(
        'roads and adjudication agree with independent oracle at radius $radius',
        () {
      final random = Random(21532 + radius);
      final empty = HexGame.initial(radius: radius).copyWith(ply: 3);
      for (var sample = 0; sample < 600; sample++) {
        final board = <HexCell, List<HexStone>>{};
        // Include dense single-seat boards to exercise long connected paths,
        // plus mixed boards, buried colors, standing blockers and caps.
        for (final cell in empty.cells) {
          if (random.nextDouble() < .25) continue;
          final seat = sample % 4 == 3
              ? HexSeat.values[random.nextInt(3)]
              : HexSeat.values[sample % 3];
          final type = PieceType.values[random.nextInt(5) % 3];
          board[cell] = [copper, charcoal, HexStone(seat, type)];
        }
        final game = empty.copyWith(board: board);
        final winners =
            HexSeat.values.where((seat) => oracleRoad(game, seat)).toSet();
        for (final seat in HexSeat.values) {
          final path = HexRules.road(game, seat);
          expect(path.isNotEmpty, winners.contains(seat),
              reason: 'radius $radius sample $sample seat $seat');
          if (path.isNotEmpty) {
            expect(
                path.every((cell) =>
                    game.topAt(cell)?.seat == seat &&
                    game.topAt(cell)?.type != PieceType.standing),
                isTrue);
          }
          final result = HexRules.resolve(game, seat);
          if (winners.isNotEmpty) {
            expect(result.finished, isTrue);
            expect(
                result.winner,
                winners.contains(seat)
                    ? seat
                    : winners.length == 1
                        ? winners.single
                        : null);
            expect(result.reason!.toLowerCase(), contains('road'));
          }
        }
      }
    });
  }
}
