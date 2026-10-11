import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/legacy_square_adapter.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/models/board.dart';
import 'package:stones/models/game_rules.dart';
import 'package:stones/models/game_state.dart';
import 'package:stones/models/piece.dart';

MatchConfig config(BoardShape shape, int size, int count, {SeatId? starter}) =>
    MatchConfig(
        shape: shape,
        size: size,
        seats: SeatId.values.take(count).map(SeatConfig.new).toList(),
        starter: starter ?? SeatId.ivory);

void main() {
  test('every player shares every opposite pair at every size and seat count',
      () {
    for (final shape in BoardShape.values) {
      for (final size in MatchConfig.sizesFor(shape)) {
        for (var count = 2; count <= 4; count++) {
          final setup = config(shape, size, count);
          final empty = MatchState.initial(setup);
          for (final seat in setup.ids) {
            for (var axis = 0; axis < empty.geometry.axisCount; axis++) {
              final path = <Cell>[];
              if (shape == BoardShape.square) {
                for (var i = 0; i < size; i++) {
                  path.add(axis == 0 ? Cell(i, 1) : Cell(1, i));
                }
              } else {
                for (var i = -size; i <= size; i++) {
                  path.add(switch (axis) {
                    0 => Cell(i, 0),
                    1 => Cell(0, i),
                    _ => Cell(i, -i),
                  });
                }
              }
              // s-axis traverses from (-size,0) to (size,0), reversing q.
              if (shape == BoardShape.hex && axis == 2) {
                path.clear();
                for (var i = -size; i <= size; i++) {
                  path.add(Cell(0, -i));
                }
              }
              final road = empty.copyWith(ply: count, board: {
                for (final cell in path) cell: [Stone(seat, PieceType.flat)],
              });
              expect(MatchRules.roadOnAxis(road, seat, axis), isNotEmpty,
                  reason:
                      '$shape size $size players $count seat $seat axis $axis');
              expect(MatchRules.resolve(road, seat).result!.winner, seat);
              final blocked = road.copyWith(board: {
                ...road.board,
                path[path.length ~/ 2]: [Stone(seat, PieceType.standing)]
              });
              expect(MatchRules.roadOnAxis(blocked, seat, axis), isEmpty);
            }
          }
        }
      }
    }
  });
  test(
      'all seat kinds, sizes and starters serialize and exchange once per seat',
      () {
    var cases = 0;
    for (final shape in BoardShape.values) {
      for (final size in MatchConfig.sizesFor(shape)) {
        for (var count = 2; count <= 4; count++) {
          for (var pattern = 0; pattern < pow(3, count); pattern++) {
            final seats = List.generate(
                count,
                (i) => SeatConfig(SeatId.values[i],
                    control: SeatControl.values[(pattern ~/ pow(3, i)) % 3]));
            for (final starter in SeatId.values.take(count)) {
              final setup = MatchConfig(
                  shape: shape, size: size, seats: seats, starter: starter);
              final decoded = MatchConfig.fromMap(setup.toMap());
              expect(decoded.toMap(), setup.toMap());
              var game = MatchState.initial(decoded);
              final supply = Reserve.initial(decoded);
              for (var ply = 0; ply < count; ply++) {
                final owner = decoded.next(game.current);
                final cell = game.geometry.cells[ply];
                expect(
                    MatchRules.play(
                        game, MatchMove.place(cell, PieceType.standing)),
                    isNull);
                game = MatchRules.play(
                    game, MatchMove.place(cell, PieceType.flat))!;
                expect(game.topAt(cell)!.seat, owner);
              }
              expect(game.opening, isFalse);
              expect(game.current, starter);
              for (final reserve in game.reserves.values) {
                expect(reserve.stones, supply.stones - 1);
                expect(reserve.caps, supply.caps);
              }
              cases++;
            }
          }
        }
      }
    }
    expect(cases, 9 * (9 * 2 + 27 * 3 + 81 * 4));
  });

  test('configuration retains identities through add/remove and shape switches',
      () {
    var setup = MatchConfig.defaults(BoardShape.hex).addPlayer();
    setup = setup.copyWith(starter: SeatId.jade);
    setup = setup.removePlayer(SeatId.charcoal);
    expect(setup.ids, [SeatId.ivory, SeatId.copper, SeatId.jade]);
    expect(setup.turnAt(1), SeatId.ivory);
    expect(setup.addPlayer().ids.last, SeatId.charcoal);
    setup = setup.copyWith(size: 4, shape: BoardShape.hex);
    expect(setup.copyWith(shape: BoardShape.square).size, 8);
    expect(() => config(BoardShape.square, 9, 2), throwsArgumentError);
    expect(() => MatchConfig.fromMap({...setup.toMap(), 'version': 99}),
        throwsFormatException);
  });

  for (final shape in BoardShape.values) {
    for (var count = 2; count <= 4; count++) {
      test(
          '${shape.name} $count seats preserve bottom-first crushing and reject atomically',
          () {
        final setup = config(shape, shape == BoardShape.square ? 5 : 2, count);
        final initial = MatchState.initial(setup);
        final game = initial.copyWith(ply: count, board: {
          const Cell(0, 0): const [
            Stone(SeatId.charcoal, PieceType.flat),
            Stone(SeatId.ivory, PieceType.capstone)
          ],
          const Cell(2, 0): const [Stone(SeatId.charcoal, PieceType.standing)],
        });
        final result = MatchRules.play(
            game, MatchMove.spread(const Cell(0, 0), Step.east, [1, 1]))!;
        expect(result.topAt(const Cell(1, 0)),
            const Stone(SeatId.charcoal, PieceType.flat));
        expect(result.stackAt(const Cell(2, 0)), const [
          Stone(SeatId.charcoal, PieceType.flat),
          Stone(SeatId.ivory, PieceType.capstone)
        ]);
        expect(
            MatchRules.play(
                game, MatchMove.spread(const Cell(0, 0), Step.east, [2, 0])),
            isNull);
        expect(game.topAt(const Cell(2, 0))!.type, PieceType.standing);
        expect(() => game.board.clear(), throwsUnsupportedError);
        expect(() => game.stackAt(const Cell(0, 0)).clear(),
            throwsUnsupportedError);
        final before = game.board.values.expand((s) => s).length;
        expect(result.board.values.expand((s) => s).length, before);
      });
    }
  }

  test(
      'four-seat square simultaneous opponent roads draw and mover has priority',
      () {
    final setup = config(BoardShape.square, 3, 4);
    final game = MatchState.initial(setup).copyWith(ply: 4, board: {
      for (var x = 0; x < 3; x++)
        Cell(x, 0): const [Stone(SeatId.charcoal, PieceType.flat)],
      for (var x = 0; x < 3; x++)
        Cell(x, 2): const [Stone(SeatId.jade, PieceType.flat)],
    });
    expect(MatchRules.resolve(game, SeatId.ivory).result!.draw, isTrue);
    expect(MatchRules.resolve(game, SeatId.jade).result!.winner, SeatId.jade);
    expect(MatchRules.resolve(game, SeatId.ivory).result!.reason,
        ResultReason.road);
    final capped = game.copyWith(board: {
      ...game.board,
      const Cell(1, 0): const [Stone(SeatId.charcoal, PieceType.standing)]
    });
    expect(
        MatchRules.resolve(capped, SeatId.ivory).result!.winner, SeatId.jade);
  });

  test(
      'four-seat flat tie draws; remaining cap prevents exhaustion; road first',
      () {
    final setup = config(BoardShape.square, 5, 4);
    final initial = MatchState.initial(setup);
    final game = initial.copyWith(ply: 4, board: {
      const Cell(0, 0): const [Stone(SeatId.ivory, PieceType.flat)],
      const Cell(1, 1): const [Stone(SeatId.jade, PieceType.flat)],
    }, reserves: {
      ...initial.reserves,
      SeatId.copper: const Reserve(0, 1)
    });
    expect(MatchRules.resolve(game, SeatId.ivory).finished, isFalse);
    final exhausted = game.copyWith(
        reserves: {...game.reserves, SeatId.copper: const Reserve(0, 0)});
    expect(MatchRules.resolve(exhausted, SeatId.ivory).result!.draw, isTrue);
    final road = exhausted.copyWith(board: {
      ...exhausted.board,
      for (var x = 0; x < 5; x++)
        Cell(x, 4): const [Stone(SeatId.jade, PieceType.flat)]
    });
    expect(MatchRules.resolve(road, SeatId.ivory).result!.reason,
        ResultReason.road);
    expect(MatchRules.resolve(road, SeatId.ivory).result!.winner, SeatId.jade);
    expect(
        MatchRules.legalMoves(MatchRules.resolve(road, SeatId.ivory)), isEmpty);
  });

  test(
      'seeded square positions compare every legal generated move with legacy validator',
      () {
    final random = Random(421);
    for (final size in [3, 5, 8]) {
      var legacy = GameState.initial(size);
      for (var ply = 0; ply < 40; ply++) {
        final game = LegacySquareAdapter.read(legacy);
        final moves = MatchRules.legalMoves(game).toList();
        if (moves.isEmpty) break;
        for (final move in moves) {
          final old = move.type != null
              ? GameRules.tryPlacePiece(
                  legacy, Position(move.from.y, move.from.x), move.type!)
              : GameRules.tryMoveStack(
                  legacy,
                  Position(move.from.y, move.from.x),
                  Direction.values.firstWhere((d) =>
                      LegacySquareAdapter.direction(d) == move.direction),
                  move.drops);
          expect(old, isNotNull);
          final shared = MatchRules.apply(game, move)!;
          final restored = LegacySquareAdapter.writeApplied(legacy, shared);
          expect(restored.board, old!.board);
          expect(restored.whitePieces, old.whitePieces);
          expect(restored.blackPieces, old.blackPieces);
        }
        final move = moves[random.nextInt(moves.length)];
        legacy = LegacySquareAdapter.writeApplied(
                legacy, MatchRules.apply(game, move)!)
            .nextTurn();
        if (MatchRules.play(game, move)!.finished) break;
      }
    }
  });

  test('seeded Hex v1/v2 full replay and legal move sets match existing engine',
      () {
    final random = Random(92);
    for (final version in [1, 2]) {
      for (final radius in [2, 3, 4]) {
        var hex = HexGame.initial(radius: radius, rulesVersion: version);
        var game = MatchState.initial(MatchConfig(
            shape: BoardShape.hex,
            size: radius,
            seats: const [
              SeatConfig(SeatId.ivory),
              SeatConfig(SeatId.charcoal),
              SeatConfig(SeatId.copper)
            ],
            profile: version == 1
                ? RulesProfile.legacyHex
                : RulesProfile.sharedRoads));
        for (var ply = 0; ply < 40 && !hex.finished; ply++) {
          final old = HexRules.legalMoves(hex).toList();
          String key(Map<String, dynamic> map) =>
              '${map['q']},${map['r']}/${map['type']}/${map['direction']}/${map['drops']}';
          final newMoves = MatchRules.legalMoves(game).toList();
          expect(
              newMoves
                  .map((m) =>
                      '${m.from.x},${m.from.y}/${m.type?.index ?? -1}/${m.direction?.index ?? -1}/${m.drops}')
                  .toSet(),
              old.map((m) => key(m.toMap(hex.current))).toSet());
          final move = old[random.nextInt(old.length)];
          final shared = move.type != null
              ? MatchMove.place(Cell(move.from.q, move.from.r), move.type!)
              : MatchMove.spread(Cell(move.from.q, move.from.r),
                  Step.values[move.direction!.index], move.drops);
          game = MatchRules.play(game, shared)!;
          hex = HexRules.play(hex, move)!;
          expect(game.finished, hex.finished);
          expect(game.result?.winner?.index, hex.winner?.index);
          for (final cell in hex.cells) {
            expect(
                game
                    .stackAt(Cell(cell.q, cell.r))
                    .map((s) => '${s.seat.index}:${s.type.index}')
                    .toList(),
                hex
                    .stackAt(cell)
                    .map((s) => '${s.seat.index}:${s.type.index}')
                    .toList());
          }
          expect(game.reserves.values.map((r) => [r.stones, r.caps]).toList(),
              hex.reserves.map((r) => [r.stones, r.caps]).toList());
        }
      }
    }
  });
}
