import '../models/piece.dart';
import 'board_geometry.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Composed visual study, deliberately not a saved/achievement-eligible game.
MatchState examplePosition(BoardShape shape, int players, {bool won = false}) {
  final config = MatchConfig.defaults(shape).copyWith(
      seats: SeatId.values.take(players).map(SeatConfig.new).toList());
  Cell cell(int x, int y) =>
      shape == BoardShape.square ? Cell(x + 2, y + 2) : Cell(x, y);
  final ids = config.ids;
  final board = <Cell, List<Stone>>{
    cell(0, 0): [
      for (var i = 0; i < 7; i++) Stone(ids[i % players], PieceType.flat),
      const Stone(SeatId.ivory, PieceType.flat),
    ],
    cell(-1, -1): [const Stone(SeatId.ivory, PieceType.capstone)],
    cell(1, 0): [const Stone(SeatId.charcoal, PieceType.flat)],
    cell(0, 1): [const Stone(SeatId.charcoal, PieceType.standing)],
    cell(-1, 1): [Stone(ids.last, PieceType.flat)],
    cell(1, -1): [const Stone(SeatId.ivory, PieceType.flat)],
  };
  if (won) {
    for (var x = -2; x <= 2; x++) {
      board[cell(x, 0)] = [const Stone(SeatId.ivory, PieceType.flat)];
    }
  }
  final reserves = {for (final id in ids) id: Reserve.initial(config)};
  for (final stone in board.values.expand((stack) => stack)) {
    reserves[stone.seat] = reserves[stone.seat]!.use(stone.type);
  }
  final position = MatchState(
      config: config, board: board, reserves: reserves, ply: players * 4);
  return won ? MatchRules.resolve(position, SeatId.ivory) : position;
}

