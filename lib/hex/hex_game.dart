import '../models/piece.dart' show PieceType;

/// Experimental three-seat variant. Deliberately independent of PlayerColor,
/// GameState, Position and the square game's four-direction movement.
enum HexSeat { ivory, charcoal, copper }

/// The three opposite boundary pairs are shared by every color in version 2.
enum HexAxis {
  q,
  r,
  s;

  int coordinate(HexCell cell) => switch (this) {
        q => cell.q,
        r => cell.r,
        s => cell.s,
      };
  String get marker => ['A', 'B', 'C'][index];
}

extension HexSeatInfo on HexSeat {
  String get label => switch (this) {
        HexSeat.ivory => 'Ivory',
        HexSeat.charcoal => 'Charcoal',
        HexSeat.copper => 'Copper',
      };
  HexSeat get next => HexSeat.values[(index + 1) % 3];

  /// Screen directions for the fixed pointy-top board. A and B are opposite
  /// goals, never the two colored fragments at a single corner.
  String edgeName(bool positive) => switch (this) {
        HexSeat.ivory => positive ? 'upper right' : 'lower left',
        HexSeat.charcoal => positive ? 'bottom' : 'top',
        HexSeat.copper => positive ? 'upper left' : 'lower right',
      };
  String get goalLabel => '${edgeName(false)} to ${edgeName(true)}';
  int axis(HexCell cell) => switch (this) {
        HexSeat.ivory => cell.q,
        HexSeat.charcoal => cell.r,
        HexSeat.copper => cell.s,
      };
}

class HexCell {
  const HexCell(this.q, this.r);
  final int q;
  final int r;
  int get s => -q - r;
  HexCell step(HexDirection direction) =>
      HexCell(q + direction.dq, r + direction.dr);
  bool inside(int radius) =>
      q.abs() <= radius && r.abs() <= radius && s.abs() <= radius;
  String get key => '$q,$r';
  @override
  bool operator ==(Object other) =>
      other is HexCell && q == other.q && r == other.r;
  @override
  int get hashCode => Object.hash(q, r);
  @override
  String toString() => key;
}

enum HexDirection {
  east(1, 0),
  northEast(1, -1),
  northWest(0, -1),
  west(-1, 0),
  southWest(-1, 1),
  southEast(0, 1);

  const HexDirection(this.dq, this.dr);
  final int dq;
  final int dr;
}

class HexStone {
  const HexStone(this.seat, this.type);
  final HexSeat seat;
  final PieceType type;
}

class HexReserve {
  const HexReserve(this.stones, this.caps);
  final int stones;
  final int caps;
  int get total => stones + caps;
  bool has(PieceType type) =>
      type == PieceType.capstone ? caps > 0 : stones > 0;
  HexReserve use(PieceType type) => type == PieceType.capstone
      ? HexReserve(stones, caps - 1)
      : HexReserve(stones - 1, caps);
}

class HexMove {
  HexMove.place(this.from, PieceType pieceType)
      : type = pieceType,
        direction = null,
        drops = const [];
  HexMove.spread(this.from, HexDirection movement, List<int> distribution)
      : direction = movement,
        type = null,
        drops = List.unmodifiable(distribution);
  final HexCell from;
  final PieceType? type;
  final HexDirection? direction;
  final List<int> drops;

  Map<String, dynamic> toMap(HexSeat mover) => {
        'seat': mover.index,
        'q': from.q,
        'r': from.r,
        'type': type?.index ?? -1,
        'direction': direction?.index ?? -1,
        'drops': drops,
      };

  static HexMove fromMap(Map<String, dynamic> map) {
    final cell = HexCell(map['q'] as int, map['r'] as int);
    final type = map['type'] as int;
    final direction = map['direction'] as int;
    final drops = (map['drops'] as List).cast<int>();
    if (type >= 0 &&
        type < PieceType.values.length &&
        direction == -1 &&
        drops.isEmpty) {
      return HexMove.place(cell, PieceType.values[type]);
    }
    if (type == -1 &&
        direction >= 0 &&
        direction < HexDirection.values.length) {
      return HexMove.spread(cell, HexDirection.values[direction], drops);
    }
    throw const FormatException('Invalid hex move');
  }
}

class HexGame {
  HexGame({
    required this.radius,
    required Map<HexCell, List<HexStone>> board,
    required List<HexReserve> reserves,
    this.ply = 0,
    this.starter = HexSeat.ivory,
    this.rulesVersion = 2,
    this.finished = false,
    this.winner,
    this.reason,
  })  : board = Map.unmodifiable(board.map((cell, stack) =>
            MapEntry(cell, List<HexStone>.unmodifiable(stack)))),
        reserves = List.unmodifiable(reserves) {
    if (radius < 2 ||
        radius > 4 ||
        reserves.length != 3 ||
        (rulesVersion != 1 && rulesVersion != 2)) {
      throw ArgumentError('Hex games require radius 2–4 and three reserves');
    }
  }

  factory HexGame.initial(
      {int radius = 2, HexSeat starter = HexSeat.ivory, int rulesVersion = 2}) {
    final (stones, caps) = switch (radius) {
      2 => (15, 1),
      3 => (25, 1),
      4 => (40, 2),
      _ => throw ArgumentError('Hex radius must be 2, 3 or 4'),
    };
    return HexGame(
        radius: radius,
        rulesVersion: rulesVersion,
        board: const {},
        reserves: List.generate(3, (_) => HexReserve(stones, caps)),
        starter: starter);
  }

  final int radius;
  final int rulesVersion;
  Iterable<HexAxis> roadAxes(HexSeat seat) =>
      rulesVersion == 1 ? [HexAxis.values[seat.index]] : HexAxis.values;
  final Map<HexCell, List<HexStone>> board;
  final List<HexReserve> reserves;
  final int ply;
  final HexSeat starter;
  final bool finished;
  final HexSeat? winner;
  final String? reason;
  HexSeat get current => HexSeat.values[(starter.index + ply) % 3];
  bool get opening => ply < 3;
  int get carryLimit => 2 * radius + 1;
  List<HexStone> stackAt(HexCell cell) => board[cell] ?? const [];
  HexStone? topAt(HexCell cell) {
    final stack = stackAt(cell);
    return stack.isEmpty ? null : stack.last;
  }

  Iterable<HexCell> get cells sync* {
    for (var q = -radius; q <= radius; q++) {
      for (var r = -radius; r <= radius; r++) {
        final cell = HexCell(q, r);
        if (cell.inside(radius)) yield cell;
      }
    }
  }

  HexGame copyWith(
          {Map<HexCell, List<HexStone>>? board,
          List<HexReserve>? reserves,
          int? ply,
          bool? finished,
          HexSeat? winner,
          String? reason}) =>
      HexGame(
          radius: radius,
          rulesVersion: rulesVersion,
          board: board ?? this.board,
          reserves: reserves ?? this.reserves,
          ply: ply ?? this.ply,
          starter: starter,
          finished: finished ?? this.finished,
          winner: winner ?? this.winner,
          reason: reason ?? this.reason);
}

/// Variant-only rule authority. Every move is atomic; adjudication happens once
/// after the whole spread, never between drops.
class HexRules {
  static HexGame? play(HexGame game, HexMove move) {
    final moved = _apply(game, move);
    return moved == null ? null : resolve(moved, game.current);
  }

  static HexGame? _apply(HexGame game, HexMove move) {
    if (game.finished || !move.from.inside(game.radius)) return null;
    final board = Map<HexCell, List<HexStone>>.from(game.board);
    final reserves = List<HexReserve>.from(game.reserves);
    if (move.type != null) {
      if (game.stackAt(move.from).isNotEmpty ||
          (game.opening && move.type != PieceType.flat)) {
        return null;
      }
      final color = game.opening ? game.current.next : game.current;
      if (!reserves[color.index].has(move.type!)) return null;
      board[move.from] = [HexStone(color, move.type!)];
      reserves[color.index] = reserves[color.index].use(move.type!);
    } else {
      if (game.opening ||
          move.direction == null ||
          move.drops.isEmpty ||
          move.drops.any((drop) => drop <= 0)) {
        return null;
      }
      final stack = game.stackAt(move.from);
      if (stack.isEmpty || stack.last.seat != game.current) return null;
      final carry = move.drops.fold<int>(0, (sum, drop) => sum + drop);
      if (carry > game.carryLimit || carry > stack.length) return null;
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
        if (!cell.inside(game.radius)) return null;
        final target = List<HexStone>.from(board[cell] ?? const []);
        if (target.isNotEmpty) {
          if (target.last.type == PieceType.capstone) return null;
          if (target.last.type == PieceType.standing) {
            if (drop != 1 ||
                offset != carry - 1 ||
                hand[offset].type != PieceType.capstone) {
              return null;
            }
            target[target.length - 1] =
                HexStone(target.last.seat, PieceType.flat);
          }
        }
        target.addAll(hand.sublist(offset, offset + drop));
        board[cell] = target;
        offset += drop;
      }
    }
    return game.copyWith(board: board, reserves: reserves, ply: game.ply + 1);
  }

  static Set<HexCell> road(HexGame game, HexSeat seat) {
    for (final axis in game.roadAxes(seat)) {
      final path = roadOnAxis(game, seat, axis);
      if (path.isNotEmpty) return path;
    }
    return {};
  }

  static Set<HexCell> roadOnAxis(HexGame game, HexSeat seat, HexAxis axis) {
    bool controlled(HexCell cell) {
      final top = game.topAt(cell);
      return top != null && top.seat == seat && top.type != PieceType.standing;
    }

    final queue = game.cells
        .where((c) => axis.coordinate(c) == -game.radius && controlled(c))
        .toList();
    final parents = <HexCell, HexCell?>{for (final c in queue) c: null};
    for (var index = 0; index < queue.length; index++) {
      final cell = queue[index];
      if (axis.coordinate(cell) == game.radius) {
        final path = <HexCell>{};
        HexCell? cursor = cell;
        while (cursor != null) {
          path.add(cursor);
          cursor = parents[cursor];
        }
        return path;
      }
      for (final direction in HexDirection.values) {
        final next = cell.step(direction);
        if (next.inside(game.radius) &&
            !parents.containsKey(next) &&
            controlled(next)) {
          parents[next] = cell;
          queue.add(next);
        }
      }
    }
    return {};
  }

  static HexGame resolve(HexGame game, HexSeat lastMover) {
    if (game.finished) return game;
    final roads =
        HexSeat.values.where((seat) => road(game, seat).isNotEmpty).toList();
    if (roads.isNotEmpty) {
      final winner = roads.contains(lastMover)
          ? lastMover
          : roads.length == 1
              ? roads.single
              : null;
      return game.copyWith(
          finished: true,
          winner: winner,
          reason:
              winner == null ? 'Simultaneous opponent roads — draw' : 'Road');
    }
    if (game.reserves.any((reserve) => reserve.total == 0) ||
        game.cells.every((cell) => game.stackAt(cell).isNotEmpty)) {
      final counts = flatCounts(game);
      final highest = counts.reduce((a, b) => a > b ? a : b);
      final leaders = HexSeat.values
          .where((seat) => counts[seat.index] == highest)
          .toList();
      return game.copyWith(
          finished: true,
          winner: leaders.length == 1 ? leaders.single : null,
          reason: leaders.length == 1 ? 'Flats' : 'Tied flats — draw');
    }
    return game;
  }

  static List<int> flatCounts(HexGame game) {
    final counts = [0, 0, 0];
    for (final cell in game.cells) {
      final top = game.topAt(cell);
      if (top?.type == PieceType.flat) counts[top!.seat.index]++;
    }
    return counts;
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

  static Iterable<HexMove> spreads(HexGame game, HexCell from,
      {int? pickup, HexDirection? direction}) sync* {
    final height = game.stackAt(from).length;
    final maxCarry = height < game.carryLimit ? height : game.carryLimit;
    if (game.finished ||
        game.opening ||
        game.topAt(from)?.seat != game.current) {
      return;
    }
    for (final dir in direction == null ? HexDirection.values : [direction]) {
      for (var count = pickup ?? 1; count <= (pickup ?? maxCarry); count++) {
        if (count <= 0 || count > maxCarry) continue;
        var cell = from;
        for (var distance = 1; distance <= count; distance++) {
          cell = cell.step(dir);
          if (!cell.inside(game.radius) ||
              game.topAt(cell)?.type == PieceType.capstone) {
            break;
          }
          for (final drops in _distributions(count, distance)) {
            final move = HexMove.spread(from, dir, drops);
            if (_apply(game, move) != null) yield move;
          }
          if (game.topAt(cell)?.type == PieceType.standing) break;
        }
      }
    }
  }

  static Iterable<HexMove> legalMoves(HexGame game) sync* {
    if (game.finished) return;
    for (final cell in game.cells) {
      if (game.stackAt(cell).isEmpty) {
        for (final type in game.opening ? [PieceType.flat] : PieceType.values) {
          final move = HexMove.place(cell, type);
          if (_apply(game, move) != null) yield move;
        }
      } else {
        yield* spreads(game, cell);
      }
    }
  }
}
