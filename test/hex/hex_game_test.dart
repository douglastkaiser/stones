import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stones/hex/hex_ai.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/models/piece.dart' show PieceType;

const i = HexStone(HexSeat.ivory, PieceType.flat);
const ch = HexStone(HexSeat.charcoal, PieceType.flat);
const cu = HexStone(HexSeat.copper, PieceType.flat);
const cap = HexStone(HexSeat.ivory, PieceType.capstone);
const wall = HexStone(HexSeat.charcoal, PieceType.standing);

HexGame playing(Map<HexCell, List<HexStone>> board, {int ply = 3}) =>
    HexGame.initial().copyWith(board: board, ply: ply);

void main() {
  group('hex geometry and setup', () {
    for (var radius = 2; radius <= 4; radius++) {
      test('radius $radius is a symmetric hex with correct supply', () {
        final game = HexGame.initial(radius: radius);
        expect(game.cells.length, 1 + 3 * radius * (radius + 1));
        expect(game.carryLimit, 2 * radius + 1);
        for (final seat in HexSeat.values) {
          expect(game.cells.where((cell) => seat.axis(cell) == radius).length,
              radius + 1);
          expect(game.cells.where((cell) => seat.axis(cell) == -radius).length,
              radius + 1);
        }
        expect(
            game.reserves.map((reserve) => reserve.stones).toSet().length, 1);
        expect(game.reserves.first.stones, {2: 15, 3: 25, 4: 40}[radius]);
        expect(game.reserves.first.caps, radius == 4 ? 2 : 1);
      });
    }
    test('six neighbors are distinct; cube constraint excludes clipped corners',
        () {
      const origin = HexCell(0, 0);
      expect(HexDirection.values.map(origin.step).toSet().length, 6);
      expect(const HexCell(2, 2).inside(2), isFalse);
      expect(const HexCell(-2, 2).inside(2), isTrue);
    });
    for (final starter in HexSeat.values) {
      test('opening rotates opposing placements with ${starter.label} starting',
          () {
        var game = HexGame.initial(starter: starter);
        for (var turn = 0; turn < 3; turn++) {
          final mover = game.current;
          final cell = HexCell(turn - 1, 0);
          expect(HexRules.play(game, HexMove.place(cell, PieceType.standing)),
              isNull);
          expect(HexRules.play(game, HexMove.place(cell, PieceType.capstone)),
              isNull);
          game = HexRules.play(game, HexMove.place(cell, PieceType.flat))!;
          expect(game.topAt(cell)!.seat, mover.next);
        }
        expect(game.current, starter);
        expect(game.opening, isFalse);
        expect(game.reserves.map((reserve) => reserve.stones), [14, 14, 14]);
        expect(game.reserves.map((reserve) => reserve.caps), [1, 1, 1]);
      });
    }
    test('board and stack lists are immutable', () {
      final pieces = [i];
      final board = {const HexCell(0, 0): pieces};
      final game = playing(board);
      pieces.add(cu);
      board.clear();
      expect(game.stackAt(const HexCell(0, 0)).length, 1);
      expect(() => game.board.clear(), throwsUnsupportedError);
      expect(() => game.stackAt(const HexCell(0, 0)).add(ch),
          throwsUnsupportedError);
    });
  });

  group('atomic movement', () {
    for (final direction in HexDirection.values) {
      test('straight spread in ${direction.name}', () {
        final source = playing({
          const HexCell(0, 0): [cu, ch, i]
        });
        final next = HexRules.play(
            source, HexMove.spread(const HexCell(0, 0), direction, [1, 2]))!;
        expect(next.stackAt(const HexCell(0, 0)), isEmpty);
        final first = const HexCell(0, 0).step(direction);
        expect(next.stackAt(first), [cu]);
        expect(next.stackAt(first.step(direction)), [ch, i]);
        expect(source.stackAt(const HexCell(0, 0)), [cu, ch, i]);
        expect(next.reserves, source.reserves);
        expect(next.current, HexSeat.charcoal);
      });
    }
    test('carry limit restricts pickup, not stack height', () {
      final game = playing({const HexCell(0, 0): List.filled(7, i)});
      expect(
          HexRules.play(game,
              HexMove.spread(const HexCell(0, 0), HexDirection.east, [6])),
          isNull);
      final next = HexRules.play(
          game, HexMove.spread(const HexCell(0, 0), HexDirection.east, [5]))!;
      expect(next.stackAt(const HexCell(0, 0)).length, 2);
      expect(next.stackAt(const HexCell(1, 0)).length, 5);
    });
    for (final owner in HexSeat.values) {
      test('lone cap flattens ${owner.label} wall only at final step', () {
        final game = playing({
          const HexCell(0, 0): [cu, ch, cap],
          const HexCell(2, 0): [HexStone(owner, PieceType.standing)]
        });
        final next = HexRules.play(game,
            HexMove.spread(const HexCell(0, 0), HexDirection.east, [2, 1]))!;
        expect(next.topAt(const HexCell(1, 0))!.seat, HexSeat.charcoal);
        expect(next.stackAt(const HexCell(2, 0)).first.type, PieceType.flat);
        expect(next.stackAt(const HexCell(2, 0)).first.seat, owner);
        expect(next.topAt(const HexCell(2, 0))!.type, PieceType.capstone);
      });
    }
    test(
        'invalid drops, blockers, wrong ownership, bounds and opening rejected',
        () {
      final game = playing({
        const HexCell(0, 0): [cu, cap],
        const HexCell(1, 0): [wall],
        const HexCell(-1, 0): [
          const HexStone(HexSeat.copper, PieceType.capstone)
        ]
      });
      for (final drops in [
        <int>[],
        [0],
        [-1],
        [3],
        [2],
        [1, 1]
      ]) {
        expect(
            HexRules.play(game,
                HexMove.spread(const HexCell(0, 0), HexDirection.east, drops)),
            isNull);
      }
      expect(
          HexRules.play(game,
              HexMove.spread(const HexCell(0, 0), HexDirection.west, [1])),
          isNull);
      expect(
          HexRules.play(game,
              HexMove.spread(const HexCell(1, 0), HexDirection.east, [1])),
          isNull);
      expect(
          HexRules.play(
              game,
              HexMove.spread(
                  const HexCell(0, 0), HexDirection.east, [1, 1, 1])),
          isNull);
      expect(
          HexRules.play(game.copyWith(ply: 0),
              HexMove.spread(const HexCell(0, 0), HexDirection.east, [1])),
          isNull);
      expect(
          HexRules.play(
              game, HexMove.place(const HexCell(2, 2), PieceType.flat)),
          isNull);
      expect(
          HexRules.play(
              game, HexMove.place(const HexCell(0, 0), PieceType.flat)),
          isNull);
      expect(game.ply, 3);
      expect(game.stackAt(const HexCell(0, 0)), [cu, cap]);
    });
  });

  group('shared roads and flat results', () {
    for (final seat in HexSeat.values) {
      test('${seat.label} can complete an opposite pair', () {
        final board = <HexCell, List<HexStone>>{};
        for (var coordinate = -2; coordinate <= 2; coordinate++) {
          final cell = seat == HexSeat.charcoal
              ? HexCell(0, coordinate)
              : HexCell(coordinate, 0);
          board[cell] = [
            HexStone(
                seat, coordinate == 0 ? PieceType.capstone : PieceType.flat)
          ];
        }
        final game = playing(board);
        expect(HexRules.road(game, seat).length, 5);
        final result = HexRules.resolve(game, HexSeat.ivory);
        expect(result.finished, isTrue);
        expect(result.winner, seat);
        expect(result.reason, 'Road');
      });
    }
    test('every pair wins, but covered flats and walls do not form a road', () {
      var game = playing({
        for (var r = -2; r <= 2; r++) HexCell(0, r): [i]
      });
      expect(HexRules.road(game, HexSeat.ivory), isNotEmpty);
      game = playing({
        for (var q = -2; q <= 2; q++) HexCell(q, 0): q == 0 ? [i, ch] : [i]
      });
      expect(HexRules.road(game, HexSeat.ivory), isEmpty);
      game = playing({
        for (var q = -2; q <= 2; q++)
          HexCell(q, 0):
              q == 0 ? [const HexStone(HexSeat.ivory, PieceType.standing)] : [i]
      });
      expect(HexRules.road(game, HexSeat.ivory), isEmpty);
    });
    test('exposing an opponent road loses to that opponent', () {
      final game = playing({
        for (var r = -2; r <= 2; r++) HexCell(0, r): r == 0 ? [ch, i] : [ch]
      });
      final next = HexRules.play(
          game, HexMove.spread(const HexCell(0, 0), HexDirection.east, [1]))!;
      expect(next.winner, HexSeat.charcoal);
      expect(next.reason, 'Road');
      expect(
          HexRules.play(
              next, HexMove.place(const HexCell(2, 0), PieceType.flat)),
          isNull);
      expect(HexAI.choose(next), isNull);
    });
    test('road takes priority over last-reserve scoring', () {
      final game = playing({
        for (var q = -2; q <= 1; q++) HexCell(q, 0): [i]
      }).copyWith(reserves: [
        const HexReserve(1, 0),
        const HexReserve(15, 1),
        const HexReserve(15, 1)
      ]);
      final next = HexRules.play(
          game, HexMove.place(const HexCell(2, 0), PieceType.flat))!;
      expect(next.winner, HexSeat.ivory);
      expect(next.reason, 'Road');
    });
    test('total reserves include caps; only exposed flats score', () {
      final game = playing({
        const HexCell(0, 0): [i, ch],
        const HexCell(1, 0): [cap],
        const HexCell(-1, 0): [wall],
        const HexCell(0, 1): [cu]
      });
      expect(HexRules.flatCounts(game), [0, 1, 1]);
      expect(
          HexRules.resolve(
                  game.copyWith(reserves: [
                    const HexReserve(0, 1),
                    const HexReserve(15, 1),
                    const HexReserve(15, 1)
                  ]),
                  HexSeat.ivory)
              .finished,
          isFalse);
      final drawn = HexRules.resolve(
          game.copyWith(reserves: [
            const HexReserve(0, 0),
            const HexReserve(15, 1),
            const HexReserve(15, 1)
          ]),
          HexSeat.ivory);
      expect(drawn.finished, isTrue);
      expect(drawn.winner, isNull);
    });
    test('full board scores unique leader; two-way and three-way ties draw',
        () {
      final cells = HexGame.initial().cells.toList();
      for (final flatPieces in [
        [i, i, ch, cu],
        [i, ch],
        <HexStone>[]
      ]) {
        final game = playing({
          for (var n = 0; n < cells.length; n++)
            cells[n]: n < flatPieces.length ? [flatPieces[n]] : [wall]
        });
        final result = HexRules.resolve(game, HexSeat.copper);
        expect(result.finished, isTrue);
        expect(result.winner, flatPieces.length == 4 ? HexSeat.ivory : null);
      }
    });
    test('rotating board and seats by 120 degrees preserves a road', () {
      final game = playing({
        for (var q = -2; q <= 2; q++) HexCell(q, 0): [i]
      });
      final rotated = playing({
        for (final entry in game.board.entries)
          HexCell(entry.key.r, entry.key.s): [
            const HexStone(HexSeat.copper, PieceType.flat)
          ]
      });
      expect(HexRules.road(game, HexSeat.ivory).length,
          HexRules.road(rotated, HexSeat.copper).length);
    });
  });

  test('AI takes an immediate road win', () {
    final game = playing({
      for (var q = -2; q <= 1; q++) HexCell(q, 0): [i]
    });
    final move = HexAI.choose(game)!;
    expect(HexRules.play(game, move)!.winner, HexSeat.ivory);
  });

  test('seeded generated play preserves conservation and legal turn cycling',
      () {
    final random = Random(3);
    var game = HexGame.initial();
    for (var turn = 0; turn < 50 && !game.finished; turn++) {
      final moves = HexRules.legalMoves(game).toList();
      expect(moves, isNotEmpty);
      for (final move in moves) {
        expect(HexRules.play(game, move), isNotNull);
      }
      final current = game.current;
      game = HexRules.play(game, moves[random.nextInt(moves.length)])!;
      expect(game.current, current.next);
      for (final seat in HexSeat.values) {
        final pieces = game.board.values
            .expand((stack) => stack)
            .where((piece) => piece.seat == seat)
            .toList();
        expect(
            pieces.where((piece) => piece.type != PieceType.capstone).length +
                game.reserves[seat.index].stones,
            15);
        expect(
            pieces.where((piece) => piece.type == PieceType.capstone).length +
                game.reserves[seat.index].caps,
            1);
      }
    }
  });
}
