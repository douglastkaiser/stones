import 'board.dart';
import 'game_state.dart';
import 'piece.dart';

/// Pure move validation shared by gameplay, AI simulation and move previews.
/// Successful moves update the board/reserves without advancing the turn;
/// callers advance the turn and check the resulting win conditions.
class GameRules {
  static GameState? tryPlacePiece(
    GameState state,
    Position position,
    PieceType type,
  ) {
    if (state.isGameOver || !position.isValid(state.boardSize)) return null;
    if (!state.board.stackAt(position).canPlaceOn) return null;
    if (state.isOpeningPhase && type != PieceType.flat) return null;

    final color = state.isOpeningPhase ? state.opponent : state.currentPlayer;
    final reserve = state.piecesFor(color);
    if (!reserve.hasPiece(type)) return null;
    return state
        .copyWith(
          board:
              state.board.placePiece(position, Piece(type: type, color: color)),
        )
        .updatePieces(color, reserve.usePiece(type));
  }

  static GameState? tryMoveStack(
    GameState state,
    Position from,
    Direction direction,
    List<int> drops,
  ) {
    if (state.isGameOver || state.isOpeningPhase) return null;
    if (!from.isValid(state.boardSize)) return null;
    if (drops.isEmpty || drops.any((drop) => drop <= 0)) return null;
    final stack = state.board.stackAt(from);
    if (stack.isEmpty || stack.controller != state.currentPlayer) return null;
    final totalPicked = drops.fold(0, (sum, drop) => sum + drop);
    if (totalPicked > stack.height || totalPicked > state.boardSize) {
      return null;
    }

    final (remaining, pickedUp) = stack.pop(totalPicked);
    var board = state.board.setStack(from, remaining);
    var position = from;
    var pieceIndex = 0;
    for (final drop in drops) {
      position = direction.apply(position);
      if (!position.isValid(state.boardSize)) return null;
      var target = board.stackAt(position);
      final bottomPiece = pickedUp[pieceIndex];
      if (!target.canMoveOnto(bottomPiece)) return null;
      if (target.topPiece?.type == PieceType.standing) {
        // Flattening is the final step, performed by a lone capstone.
        if (drop != 1 || pieceIndex != pickedUp.length - 1) return null;
        target = target.flattenTop();
      }
      board = board.setStack(
        position,
        target.pushAll(pickedUp.sublist(pieceIndex, pieceIndex + drop)),
      );
      pieceIndex += drop;
    }
    return state.copyWith(board: board);
  }

  /// All legal spreads for an exact pickup count in one direction.
  static Iterable<List<int>> legalStackDrops(
    GameState state,
    Position from,
    Direction direction,
    int pickedUp,
  ) sync* {
    if (state.isGameOver || state.isOpeningPhase) return;
    if (!from.isValid(state.boardSize) || pickedUp <= 0) return;
    final stack = state.board.stackAt(from);
    if (stack.controller != state.currentPlayer ||
        pickedUp > stack.height ||
        pickedUp > state.boardSize) {
      return;
    }

    var position = from;
    for (var distance = 1; distance <= pickedUp; distance++) {
      position = direction.apply(position);
      if (!position.isValid(state.boardSize)) break;
      final targetType = state.board.stackAt(position).topPiece?.type;
      if (targetType == PieceType.capstone) break;
      for (final drops in _distributions(pickedUp, distance)) {
        if (tryMoveStack(state, from, direction, drops) != null) yield drops;
      }
      // A wall is either flattened at the end or blocks the entire path.
      if (targetType == PieceType.standing) break;
    }
  }

  static Iterable<List<int>> _distributions(int pieces, int spaces) sync* {
    if (spaces == 1) {
      yield [pieces];
      return;
    }
    for (var drop = 1; drop <= pieces - spaces + 1; drop++) {
      for (final rest in _distributions(pieces - drop, spaces - 1)) {
        yield [drop, ...rest];
      }
    }
  }

  /// Flat result when reserves are exhausted or the board is full.
  /// Callers must check road victories first.
  static GameResult? flatResult(GameState state) {
    final boardFull = state.board.allPositions
        .every((position) => state.board.stackAt(position).isNotEmpty);
    if (!boardFull &&
        state.whitePieces.total > 0 &&
        state.blackPieces.total > 0) {
      return null;
    }
    var whiteFlats = 0;
    var blackFlats = 0;
    for (final position in state.board.allPositions) {
      final top = state.board.stackAt(position).topPiece;
      if (top?.type != PieceType.flat) continue;
      if (top!.color == PlayerColor.white) {
        whiteFlats++;
      } else {
        blackFlats++;
      }
    }
    if (whiteFlats > blackFlats) return GameResult.whiteWins;
    if (blackFlats > whiteFlats) return GameResult.blackWins;
    return GameResult.draw;
  }
}
