import '../game/board_geometry.dart';
import '../game/legacy_hex_adapter.dart';
import '../game/match_config.dart';
import '../game/match_rules.dart';
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

/// Compatibility facade for immutable three-seat legacy room formats.
/// Shared MatchRules preserves version-one assigned and version-two shared goals.
class HexRules {
  static HexGame? play(HexGame game, HexMove move) {
    final next = MatchRules.play(
        LegacyHexAdapter.read(game), LegacyHexAdapter.move(move));
    return next == null ? null : LegacyHexAdapter.write(game, next);
  }

  static Set<HexCell> road(HexGame game, HexSeat seat) =>
      MatchRules.road(LegacyHexAdapter.read(game), SeatId.values[seat.index])
          .map((c) => HexCell(c.x, c.y))
          .toSet();
  static Set<HexCell> roadOnAxis(HexGame game, HexSeat seat, HexAxis axis) =>
      MatchRules.roadOnAxis(LegacyHexAdapter.read(game),
              SeatId.values[seat.index], axis.index)
          .map((c) => HexCell(c.x, c.y))
          .toSet();
  static HexGame resolve(HexGame game, HexSeat lastMover) => game.finished
      ? game
      : LegacyHexAdapter.write(
          game,
          MatchRules.resolve(
              LegacyHexAdapter.read(game), SeatId.values[lastMover.index]));
  static List<int> flatCounts(HexGame game) {
    final counts = MatchRules.flatCounts(LegacyHexAdapter.read(game));
    return [
      for (final seat in HexSeat.values) counts[SeatId.values[seat.index]]!
    ];
  }

  static Iterable<HexMove> spreads(HexGame game, HexCell from,
          {int? pickup, HexDirection? direction}) =>
      MatchRules.spreads(LegacyHexAdapter.read(game), Cell(from.q, from.r),
              pickup: pickup,
              direction:
                  direction == null ? null : Step.values[direction.index])
          .map(LegacyHexAdapter.writeMove);
  static Iterable<HexMove> legalMoves(HexGame game) =>
      MatchRules.legalMoves(LegacyHexAdapter.read(game))
          .map(LegacyHexAdapter.writeMove);
}
