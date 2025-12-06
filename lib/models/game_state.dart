import 'board.dart';
import 'piece.dart';
import 'player.dart';

/// Possible game outcomes
enum GameResult {
  whiteWins,
  blackWins,
  draw,
}

/// Why the game ended
enum WinReason {
  road,
  flats,
}

/// Current phase of the game
enum GamePhase {
  /// First two turns: players place opponent's flat stone
  opening,
  /// Normal gameplay
  playing,
  /// Game has ended
  finished,
}

/// The complete game state
class GameState {
  final Board board;
  final PlayerColor currentPlayer;
  final PlayerPieces whitePieces;
  final PlayerPieces blackPieces;
  final int turnNumber;
  final GamePhase phase;
  final GameResult? result;
  final WinReason? winReason;

  const GameState({
    required this.board,
    required this.currentPlayer,
    required this.whitePieces,
    required this.blackPieces,
    required this.turnNumber,
    required this.phase,
    this.result,
    this.winReason,
  });

  /// Create initial game state
  factory GameState.initial(int boardSize) {
    return GameState(
      board: Board.empty(boardSize),
      currentPlayer: PlayerColor.white,
      whitePieces: PlayerPieces.initial(PlayerColor.white, boardSize),
      blackPieces: PlayerPieces.initial(PlayerColor.black, boardSize),
      turnNumber: 1,
      phase: GamePhase.opening,
      result: null,
    );
  }

  /// Board size
  int get boardSize => board.size;

  /// Is the game over?
  bool get isGameOver => phase == GamePhase.finished;

  /// Is this the opening phase (first two moves)?
  bool get isOpeningPhase => phase == GamePhase.opening;

  /// Get pieces for a player
  PlayerPieces piecesFor(PlayerColor color) {
    return color == PlayerColor.white ? whitePieces : blackPieces;
  }

  /// Get pieces for current player
  PlayerPieces get currentPlayerPieces => piecesFor(currentPlayer);

  /// Get the opponent's color
  PlayerColor get opponent =>
      currentPlayer == PlayerColor.white ? PlayerColor.black : PlayerColor.white;

  /// Create a copy with modified fields
  GameState copyWith({
    Board? board,
    PlayerColor? currentPlayer,
    PlayerPieces? whitePieces,
    PlayerPieces? blackPieces,
    int? turnNumber,
    GamePhase? phase,
    GameResult? result,
    WinReason? winReason,
  }) {
    return GameState(
      board: board ?? this.board,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      whitePieces: whitePieces ?? this.whitePieces,
      blackPieces: blackPieces ?? this.blackPieces,
      turnNumber: turnNumber ?? this.turnNumber,
      phase: phase ?? this.phase,
      result: result ?? this.result,
      winReason: winReason ?? this.winReason,
    );
  }

  /// Switch to the next player's turn
  GameState nextTurn() {
    final nextPlayer = opponent;
    final nextTurnNumber = currentPlayer == PlayerColor.black
        ? turnNumber + 1
        : turnNumber;

    // After turn 1 (both players moved), switch to playing phase
    final nextPhase = (phase == GamePhase.opening && turnNumber == 1 && nextPlayer == PlayerColor.white)
        ? GamePhase.playing
        : phase;

    return copyWith(
      currentPlayer: nextPlayer,
      turnNumber: nextTurnNumber,
      phase: nextPhase,
    );
  }

  /// Update pieces for a player
  GameState updatePieces(PlayerColor color, PlayerPieces pieces) {
    return color == PlayerColor.white
        ? copyWith(whitePieces: pieces)
        : copyWith(blackPieces: pieces);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameState &&
          board == other.board &&
          currentPlayer == other.currentPlayer &&
          whitePieces == other.whitePieces &&
          blackPieces == other.blackPieces &&
          turnNumber == other.turnNumber &&
          phase == other.phase &&
          result == other.result &&
          winReason == other.winReason;

  @override
  int get hashCode => Object.hash(
        board,
        currentPlayer,
        whitePieces,
        blackPieces,
        turnNumber,
        phase,
        result,
        winReason,
      );

  @override
  String toString() =>
      'GameState(turn: $turnNumber, player: ${currentPlayer.name}, phase: ${phase.name})';
}
