import '../models/board.dart';
import '../models/game_state.dart';
import '../models/piece.dart';
import '../models/player.dart';
import 'board_geometry.dart';
import 'match_config.dart';
import 'match_state.dart';

/// Compatibility for existing square rooms, puzzles and public provider APIs.
/// The old white/black schema never grows additional colors.
class LegacySquareAdapter {
  static MatchState read(GameState state) {
    final roundPly = (state.turnNumber - 1) * 2;
    final ply = state.isOpeningPhase
        ? state.currentPlayer.index
        : (roundPly < 2 ? 2 : roundPly) + state.currentPlayer.index;
    return MatchState(
        config: MatchConfig(
            shape: BoardShape.square,
            size: state.boardSize,
            seats: const [
              SeatConfig(SeatId.ivory),
              SeatConfig(SeatId.charcoal)
            ]),
        board: {
          for (final position in state.board.occupiedPositions)
            Cell(position.col, position.row): state.board
                .stackAt(position)
                .pieces
                .map((piece) =>
                    Stone(SeatId.values[piece.color.index], piece.type))
                .toList(),
        },
        reserves: {
          SeatId.ivory: Reserve(
              state.whitePieces.flatStones, state.whitePieces.capstones),
          SeatId.charcoal: Reserve(
              state.blackPieces.flatStones, state.blackPieces.capstones),
        },
        ply: ply,
        result: state.isGameOver
            ? MatchResult(
                switch (state.result) {
                  GameResult.whiteWins => SeatId.ivory,
                  GameResult.blackWins => SeatId.charcoal,
                  GameResult.draw || null => null,
                },
                switch (state.winReason) {
                  WinReason.road => ResultReason.road,
                  WinReason.time => ResultReason.time,
                  WinReason.flats || null => ResultReason.flats,
                })
            : null);
  }

  static Step direction(Direction direction) => switch (direction) {
        Direction.up => Step.northWest,
        Direction.down => Step.southEast,
        Direction.left => Step.west,
        Direction.right => Step.east,
      };

  /// Apply transformed board/reserves without advancing legacy caller's turn.
  static GameState writeApplied(GameState original, MatchState transformed) {
    var board = original.board;
    for (final position in original.board.allPositions) {
      final stack = transformed.stackAt(Cell(position.col, position.row));
      final previous = original.board.stackAt(position).pieces;
      if (previous.length == stack.length &&
          List.generate(
              stack.length,
              (i) =>
                  previous[i].color.index == stack[i].seat.index &&
                  previous[i].type == stack[i].type).every((same) => same)) {
        continue;
      }
      board = board.setStack(
          position,
          PieceStack(stack
              .map((stone) => Piece(
                  type: stone.type,
                  color: PlayerColor.values[stone.seat.index]))
              .toList()));
    }
    PlayerPieces supply(PlayerColor color) {
      final reserve = transformed.reserves[SeatId.values[color.index]]!;
      return PlayerPieces(
          color: color, flatStones: reserve.stones, capstones: reserve.caps);
    }

    return original.copyWith(
        board: board,
        whitePieces: supply(PlayerColor.white),
        blackPieces: supply(PlayerColor.black));
  }
}
