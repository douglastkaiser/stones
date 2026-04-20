part of '../scenario.dart';

/// Stack placed at a concrete position for a scenario setup.
class PositionedStack {
  final Position position;
  final PieceStack stack;

  const PositionedStack({required this.position, required this.stack});
}

GameState _buildScenarioState({
  required int boardSize,
  required List<PositionedStack> stacks,
  required PlayerColor currentPlayer,
  int turnNumber = 4,
  GamePhase phase = GamePhase.playing,
  int? whiteFlatStones,
  int? whiteCapstones,
  int? blackFlatStones,
  int? blackCapstones,
}) {
  var board = Board.empty(boardSize);
  var whitePieces = PlayerPieces.initial(PlayerColor.white, boardSize);
  var blackPieces = PlayerPieces.initial(PlayerColor.black, boardSize);

  for (final entry in stacks) {
    board = board.setStack(entry.position, entry.stack);
    for (final piece in entry.stack.pieces) {
      if (piece.color == PlayerColor.white) {
        whitePieces = _consumePiece(whitePieces, piece.type);
      } else {
        blackPieces = _consumePiece(blackPieces, piece.type);
      }
    }
  }

  // Override piece counts if specified
  if (whiteFlatStones != null || whiteCapstones != null) {
    whitePieces = PlayerPieces(
      color: PlayerColor.white,
      flatStones: whiteFlatStones ?? whitePieces.flatStones,
      capstones: whiteCapstones ?? whitePieces.capstones,
    );
  }
  if (blackFlatStones != null || blackCapstones != null) {
    blackPieces = PlayerPieces(
      color: PlayerColor.black,
      flatStones: blackFlatStones ?? blackPieces.flatStones,
      capstones: blackCapstones ?? blackPieces.capstones,
    );
  }

  return GameState(
    board: board,
    currentPlayer: currentPlayer,
    whitePieces: whitePieces,
    blackPieces: blackPieces,
    turnNumber: turnNumber,
    phase: phase,
  );
}

PlayerPieces _consumePiece(PlayerPieces pieces, PieceType type) {
  switch (type) {
    case PieceType.flat || PieceType.standing:
      return pieces.copyWith(flatStones: pieces.flatStones - 1);
    case PieceType.capstone:
      return pieces.copyWith(capstones: pieces.capstones - 1);
  }
}

