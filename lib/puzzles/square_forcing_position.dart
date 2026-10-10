import '../models/board.dart';
import '../models/game_rules.dart';
import '../models/game_state.dart';
import '../models/piece.dart';
import '../services/ai/ai.dart';
import '../services/ai/board_analysis.dart';
import 'forcing_search.dart';

class SquareForcingPosition extends ForcingPosition<GameState, AIMove> {
  @override
  GameState learnerTurn(GameState state, int learner) =>
      state.copyWith(currentPlayer: PlayerColor.values[learner]);
  @override
  int player(GameState state) => state.currentPlayer.index;
  @override
  bool finished(GameState state) => state.isGameOver;
  @override
  int? winner(GameState state) => switch (state.result) {
        GameResult.whiteWins => PlayerColor.white.index,
        GameResult.blackWins => PlayerColor.black.index,
        _ => null,
      };
  @override
  Iterable<AIMove> moves(GameState state) =>
      const AIMoveGenerator().generateMoves(state);
  @override
  GameState play(GameState state, AIMove move) {
    final applied = switch (move) {
      AIPlacementMove() =>
        GameRules.tryPlacePiece(state, move.position, move.pieceType),
      AIStackMove() =>
        GameRules.tryMoveStack(state, move.from, move.direction, move.drops),
    };
    if (applied == null) throw StateError('Illegal puzzle move');
    var next = applied.nextTurn();
    final road =
        BoardAnalysis.getRoadWinner(next, lastMover: state.currentPlayer);
    final result = road == null
        ? GameRules.flatResult(next)
        : road == PlayerColor.white
            ? GameResult.whiteWins
            : GameResult.blackWins;
    if (result != null) {
      next = next.copyWith(
          phase: GamePhase.finished,
          result: result,
          winReason: road == null ? WinReason.flats : WinReason.road);
    }
    return next;
  }

  @override
  String moveKey(AIMove move) => switch (move) {
        AIPlacementMove() =>
          'p:${move.position.row},${move.position.col}:${move.pieceType.index}',
        AIStackMove() =>
          's:${move.from.row},${move.from.col}:${move.direction.index}:${move.drops.join(',')}',
      };
  static AIMove decode(String key) {
    final parts = key.split(':');
    final coordinate = parts[1].split(',').map(int.parse).toList();
    final position = Position(coordinate[0], coordinate[1]);
    return parts[0] == 'p'
        ? AIPlacementMove(position, PieceType.values[int.parse(parts[2])])
        : AIStackMove(position, Direction.values[int.parse(parts[2])],
            parts[3].split(',').map(int.parse).toList());
  }

  @override
  String key(GameState state) {
    final buffer = StringBuffer(
        '${state.currentPlayer.index}/${state.phase.index}/${state.whitePieces.flatStones},${state.whitePieces.capstones},${state.blackPieces.flatStones},${state.blackPieces.capstones}/');
    for (final position in state.board.allPositions) {
      for (final stone in state.board.stackAt(position).pieces) {
        buffer.write('${stone.color.index}${stone.type.index}');
      }
      buffer.write('/');
    }
    return buffer.toString();
  }
}
