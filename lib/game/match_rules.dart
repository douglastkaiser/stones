import '../models/piece.dart' show PieceType;
import 'board_geometry.dart';
import 'match_config.dart';
import 'match_state.dart';

/// One atomic move transformer for both shapes and every supported seat count.
class MatchRules {
  /// Pure preview/application. Does not advance turns or resolve outcomes.
  static MatchState? apply(MatchState game, MatchMove move) {
    if (game.finished || !game.geometry.contains(move.from)) return null;
    final board = Map<Cell, List<Stone>>.from(game.board);
    final reserves = Map<SeatId, Reserve>.from(game.reserves);
    if (move.type != null) {
      if (game.stackAt(move.from).isNotEmpty ||
          (game.opening && move.type != PieceType.flat)) {
        return null;
      }
      final owner =
          game.opening ? game.config.next(game.current) : game.current;
      if (!reserves[owner]!.has(move.type!)) return null;
      board[move.from] = [Stone(owner, move.type!)];
      reserves[owner] = reserves[owner]!.use(move.type!);
    } else {
      if (game.opening ||
          !game.geometry.directions.contains(move.direction) ||
          move.drops.isEmpty ||
          move.drops.any((drop) => drop <= 0)) {
        return null;
      }
      final stack = game.stackAt(move.from);
      final carry = move.carry;
      if (stack.isEmpty ||
          stack.last.seat != game.current ||
          carry > stack.length ||
          carry > game.geometry.carryLimit) {
        return null;
      }
      final hand = stack.sublist(stack.length - carry);
      final left = stack.sublist(0, stack.length - carry);
      if (left.isEmpty) {
        board.remove(move.from);
      } else {
        board[move.from] = left;
      }
      var cell = move.from;
      var offset = 0;
      for (final drop in move.drops) {
        cell = cell.step(move.direction!);
        if (!game.geometry.contains(cell)) return null;
        final target = List<Stone>.from(board[cell] ?? const []);
        if (target.isNotEmpty) {
          if (target.last.type == PieceType.capstone) return null;
          if (target.last.type == PieceType.standing) {
            if (drop != 1 ||
                offset != carry - 1 ||
                hand[offset].type != PieceType.capstone) {
              return null;
            }
            target[target.length - 1] = Stone(target.last.seat, PieceType.flat);
          }
        }
        target.addAll(hand.sublist(offset, offset + drop));
        board[cell] = target;
        offset += drop;
      }
    }
    return game.copyWith(board: board, reserves: reserves);
  }

  static MatchState? play(MatchState game, MatchMove move) {
    final moved = apply(game, move);
    return moved == null
        ? null
        : resolve(moved.copyWith(ply: game.ply + 1), game.current);
  }

  static Set<Cell> road(MatchState game, SeatId seat) {
    final axes = game.config.profile == RulesProfile.legacyHex
        ? [seat.index]
        : List.generate(game.geometry.axisCount, (i) => i);
    for (final axis in axes) {
      final path = roadOnAxis(game, seat, axis);
      if (path.isNotEmpty) return path;
    }
    return {};
  }

  static Set<Cell> roadOnAxis(MatchState game, SeatId seat, int axis) {
    bool controlled(Cell cell) {
      final top = game.topAt(cell);
      return top != null && top.seat == seat && top.type != PieceType.standing;
    }

    final queue = game.geometry.cells
        .where((cell) =>
            game.geometry.boundary(cell, axis, false) && controlled(cell))
        .toList();
    final parents = <Cell, Cell?>{for (final cell in queue) cell: null};
    for (var index = 0; index < queue.length; index++) {
      final cell = queue[index];
      if (game.geometry.boundary(cell, axis, true)) {
        final path = <Cell>{};
        Cell? cursor = cell;
        while (cursor != null) {
          path.add(cursor);
          cursor = parents[cursor];
        }
        return path;
      }
      for (final direction in game.geometry.directions) {
        final next = cell.step(direction);
        if (game.geometry.contains(next) &&
            !parents.containsKey(next) &&
            controlled(next)) {
          parents[next] = cell;
          queue.add(next);
        }
      }
    }
    return {};
  }

  static Map<SeatId, int> flatCounts(MatchState game) {
    final counts = {for (final id in game.config.ids) id: 0};
    for (final stack in game.board.values) {
      if (stack.last.type == PieceType.flat) {
        counts[stack.last.seat] = counts[stack.last.seat]! + 1;
      }
    }
    return counts;
  }

  static MatchState resolve(MatchState game, SeatId mover) {
    if (game.finished) return game;
    final roads =
        game.config.ids.where((id) => road(game, id).isNotEmpty).toList();
    if (roads.isNotEmpty) {
      return game.copyWith(
          result: MatchResult(
              roads.contains(mover)
                  ? mover
                  : roads.length == 1
                      ? roads.single
                      : null,
              ResultReason.road));
    }
    final flatEnding = flatResult(game);
    return flatEnding == null ? game : game.copyWith(result: flatEnding);
  }

  /// Separate flat adjudication supports legacy callers that resolve roads first.
  static MatchResult? flatResult(MatchState game) {
    if (game.reserves.values.any((reserve) => reserve.total == 0) ||
        game.board.length == game.geometry.cells.length) {
      final counts = flatCounts(game);
      final best = counts.values.reduce((a, b) => a > b ? a : b);
      final winners = counts.keys.where((id) => counts[id] == best).toList();
      return MatchResult(
          winners.length == 1 ? winners.single : null, ResultReason.flats);
    }
    return null;
  }

  static Iterable<List<int>> _distributions(int count, int spaces) sync* {
    if (spaces == 1) {
      yield [count];
      return;
    }
    for (var drop = 1; drop <= count - spaces + 1; drop++) {
      for (final rest in _distributions(count - drop, spaces - 1)) {
        yield [drop, ...rest];
      }
    }
  }

  static Iterable<MatchMove> spreads(MatchState game, Cell from,
      {int? pickup, Step? direction}) sync* {
    if (game.finished ||
        game.opening ||
        game.topAt(from)?.seat != game.current) {
      return;
    }
    final height = game.stackAt(from).length;
    final maximum =
        height < game.geometry.carryLimit ? height : game.geometry.carryLimit;
    for (final dir
        in direction == null ? game.geometry.directions : [direction]) {
      if (!game.geometry.directions.contains(dir)) continue;
      for (var count = pickup ?? 1; count <= (pickup ?? maximum); count++) {
        if (count <= 0 || count > maximum) continue;
        var cell = from;
        for (var distance = 1; distance <= count; distance++) {
          cell = cell.step(dir);
          if (!game.geometry.contains(cell) ||
              game.topAt(cell)?.type == PieceType.capstone) {
            break;
          }
          for (final drops in _distributions(count, distance)) {
            final move = MatchMove.spread(from, dir, drops);
            if (apply(game, move) != null) yield move;
          }
          if (game.topAt(cell)?.type == PieceType.standing) break;
        }
      }
    }
  }

  static Iterable<MatchMove> legalMoves(MatchState game) sync* {
    if (game.finished) return;
    for (final cell in game.geometry.cells) {
      if (game.stackAt(cell).isEmpty) {
        for (final type in game.opening ? [PieceType.flat] : PieceType.values) {
          final move = MatchMove.place(cell, type);
          if (apply(game, move) != null) yield move;
        }
      } else {
        yield* spreads(game, cell);
      }
    }
  }
}
