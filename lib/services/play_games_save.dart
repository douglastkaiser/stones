import '../models/models.dart';
import '../providers/game_session_provider.dart';
import 'ai/ai.dart' show AIDifficulty;

class PlayGamesSave {
  const PlayGamesSave(
      {required this.state, required this.moveCount, required this.session});

  final GameState state;
  final int moveCount;
  final GameSessionConfig session;

  Map<String, dynamic> toJson() {
    return {
      'version': 2,
      'mode': session.mode.name,
      'difficulty': session.aiDifficulty.name,
      'humanColor': session.vsComputerPlayerColor.name,
      'state': _GameStateCodec.toJson(state),
      'moveCount': moveCount,
    };
  }

  factory PlayGamesSave.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 2 ||
        !['local', 'vsComputer'].contains(json['mode'])) {
      throw const FormatException('Unsupported cloud save');
    }
    if ((json['moveCount'] as int? ?? 0) < 0) {
      throw const FormatException('Invalid saved move count');
    }
    return PlayGamesSave(
      session: GameSessionConfig(
          mode: GameMode.values.byName(json['mode'] as String),
          aiDifficulty:
              AIDifficulty.values.byName(json['difficulty'] as String),
          vsComputerPlayerColor:
              PlayerColor.values.byName(json['humanColor'] as String)),
      state: _GameStateCodec.fromJson(json['state'] as Map<String, dynamic>),
      moveCount: json['moveCount'] as int? ?? 0,
    );
  }
}

class _GameStateCodec {
  static Map<String, dynamic> toJson(GameState state) {
    return {
      'boardSize': state.boardSize,
      'currentPlayer': state.currentPlayer.name,
      'whitePieces': _playerPiecesToJson(state.whitePieces),
      'blackPieces': _playerPiecesToJson(state.blackPieces),
      'turnNumber': state.turnNumber,
      'phase': state.phase.name,
      'result': state.result?.name,
      'winReason': state.winReason?.name,
      'cells': [
        for (int r = 0; r < state.boardSize; r++)
          [
            for (int c = 0; c < state.boardSize; c++)
              state.board.cells[r][c].pieces.map(_pieceToJson).toList(),
          ]
      ],
    };
  }

  static GameState fromJson(Map<String, dynamic> json) {
    final size = json['boardSize'] as int;
    final cells = json['cells'] as List<dynamic>;
    if (size < 3 ||
        size > 8 ||
        cells.length != size ||
        cells.any((row) => row is! List || row.length != size) ||
        (json['turnNumber'] as int) < 1) {
      throw const FormatException('Invalid saved board dimensions or turn');
    }
    var board = Board.empty(size);
    for (int r = 0; r < size; r++) {
      final row = cells[r] as List<dynamic>;
      for (int c = 0; c < size; c++) {
        final pieces = (row[c] as List<dynamic>)
            .map((e) => _pieceFromJson(e as Map<String, dynamic>))
            .toList();
        board = board.setStack(Position(r, c), PieceStack(pieces));
      }
    }

    return GameState(
      board: board,
      currentPlayer:
          PlayerColor.values.firstWhere((e) => e.name == json['currentPlayer']),
      whitePieces:
          _playerPiecesFromJson(json['whitePieces'] as Map<String, dynamic>),
      blackPieces:
          _playerPiecesFromJson(json['blackPieces'] as Map<String, dynamic>),
      turnNumber: json['turnNumber'] as int,
      phase: GamePhase.values.firstWhere((e) => e.name == json['phase']),
      result: json['result'] == null
          ? null
          : GameResult.values.firstWhere((e) => e.name == json['result']),
      winReason: json['winReason'] == null
          ? null
          : WinReason.values.firstWhere((e) => e.name == json['winReason']),
    );
  }

  static Map<String, dynamic> _playerPiecesToJson(PlayerPieces pieces) {
    return {
      'color': pieces.color.name,
      'flat': pieces.flatStones,
      'cap': pieces.capstones,
    };
  }

  static PlayerPieces _playerPiecesFromJson(Map<String, dynamic> json) {
    return PlayerPieces(
      color: PlayerColor.values.firstWhere((e) => e.name == json['color']),
      flatStones: json['flat'] as int,
      capstones: json['cap'] as int,
    );
  }

  static Map<String, dynamic> _pieceToJson(Piece piece) {
    return {
      'type': piece.type.name,
      'color': piece.color.name,
    };
  }

  static Piece _pieceFromJson(Map<String, dynamic> json) {
    return Piece(
      type: PieceType.values.firstWhere((e) => e.name == json['type']),
      color: PlayerColor.values.firstWhere((e) => e.name == json['color']),
    );
  }
}
