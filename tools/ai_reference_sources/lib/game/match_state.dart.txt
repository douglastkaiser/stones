import '../models/piece.dart' show PieceType;
import '../models/player.dart' show PieceCounts;
import 'board_geometry.dart';
import 'match_config.dart';

class Stone {
  const Stone(this.seat, this.type);
  final SeatId seat;
  final PieceType type;
  @override
  bool operator ==(Object other) =>
      other is Stone && seat == other.seat && type == other.type;
  @override
  int get hashCode => Object.hash(seat, type);
}

class Reserve {
  const Reserve(this.stones, this.caps);
  final int stones;
  final int caps;
  int get total => stones + caps;
  bool has(PieceType type) =>
      type == PieceType.capstone ? caps > 0 : stones > 0;
  Reserve use(PieceType type) => type == PieceType.capstone
      ? Reserve(stones, caps - 1)
      : Reserve(stones - 1, caps);

  factory Reserve.initial(MatchConfig config) {
    if (config.shape == BoardShape.square) {
      final counts = PieceCounts.forBoardSize(config.size);
      return Reserve(counts.flatStones, counts.capstones);
    }
    return switch (config.size) {
      2 => const Reserve(15, 1),
      3 => const Reserve(25, 1),
      4 => const Reserve(40, 2),
      _ => throw ArgumentError('Unsupported Hex radius'),
    };
  }
}

enum ResultReason { road, flats, resignation, abandoned, time }

class MatchResult {
  const MatchResult(this.winner, this.reason);
  final SeatId? winner;
  final ResultReason reason;
  bool get draw => winner == null && reason != ResultReason.abandoned;
}

class MatchState {
  MatchState({
    required this.config,
    required Map<Cell, List<Stone>> board,
    required Map<SeatId, Reserve> reserves,
    this.ply = 0,
    this.result,
    BoardGeometry? geometry,
  })  : geometry = geometry ?? BoardGeometry.forConfig(config),
        board = Map.unmodifiable(board.map(
            (cell, stack) => MapEntry(cell, List<Stone>.unmodifiable(stack)))),
        reserves = Map.unmodifiable(reserves) {
    if (ply < 0 ||
        reserves.length != config.seats.length ||
        config.ids.any((id) => !reserves.containsKey(id)) ||
        reserves.values
            .any((reserve) => reserve.stones < 0 || reserve.caps < 0) ||
        board.keys.any((cell) => !this.geometry.contains(cell)) ||
        board.values.any((stack) =>
            stack.isEmpty ||
            stack.any((stone) => !reserves.containsKey(stone.seat))) ||
        (result?.winner != null && !reserves.containsKey(result!.winner))) {
      throw ArgumentError('Invalid match position');
    }
  }

  factory MatchState.initial(MatchConfig config) => MatchState(
      config: config,
      board: const {},
      reserves: {for (final id in config.ids) id: Reserve.initial(config)});

  final MatchConfig config;
  final BoardGeometry geometry;
  final Map<Cell, List<Stone>> board;
  final Map<SeatId, Reserve> reserves;
  final int ply;
  final MatchResult? result;
  MatchState._trusted(
      {required this.config,
      required this.geometry,
      required this.board,
      required this.reserves,
      required this.ply,
      required this.result});
  SeatId get current => config.turnAt(ply);
  bool get opening => ply < config.seats.length;
  bool get finished => result != null;
  List<Stone> stackAt(Cell cell) => board[cell] ?? const [];
  Stone? topAt(Cell cell) => stackAt(cell).isEmpty ? null : stackAt(cell).last;

  MatchState copyWith({
    Map<Cell, List<Stone>>? board,
    Map<SeatId, Reserve>? reserves,
    int? ply,
    MatchResult? result,
  }) {
    final nextPly = ply ?? this.ply;
    final nextResult = result ?? this.result;
    if (board == null && reserves == null) {
      if (nextPly < 0 ||
          (nextResult?.winner != null &&
              !this.reserves.containsKey(nextResult!.winner))) {
        throw ArgumentError('Invalid turn or winner');
      }
      return MatchState._trusted(
          config: config,
          geometry: geometry,
          board: this.board,
          reserves: this.reserves,
          ply: nextPly,
          result: nextResult);
    }
    return MatchState(
        config: config,
        geometry: geometry,
        board: board ?? this.board,
        reserves: reserves ?? this.reserves,
        ply: nextPly,
        result: nextResult);
  }
}

class MatchMove {
  MatchMove.place(this.from, PieceType pieceType)
      : type = pieceType,
        direction = null,
        drops = const [];
  MatchMove.spread(this.from, Step step, List<int> distribution)
      : type = null,
        direction = step,
        drops = List.unmodifiable(distribution);
  final Cell from;
  final PieceType? type;
  final Step? direction;
  final List<int> drops;
  int get carry => drops.fold(0, (sum, drop) => sum + drop);
  Cell get end {
    var cell = from;
    for (final _ in drops) {
      cell = cell.step(direction!);
    }
    return cell;
  }

  Map<String, dynamic> toMap(SeatId mover) => {
        'seat': mover.name,
        'x': from.x,
        'y': from.y,
        'type': type?.name,
        'direction': direction?.name,
        'drops': drops,
      };

  factory MatchMove.fromMap(Map<String, dynamic> map) {
    final cell = Cell(map['x'] as int, map['y'] as int);
    final drops = (map['drops'] as List).cast<int>();
    if (map['type'] != null && map['direction'] == null && drops.isEmpty) {
      return MatchMove.place(
          cell, PieceType.values.byName(map['type'] as String));
    }
    if (map['type'] == null && map['direction'] != null && drops.isNotEmpty) {
      return MatchMove.spread(
          cell, Step.values.byName(map['direction'] as String), drops);
    }
    throw const FormatException('Invalid recorded move');
  }
}
