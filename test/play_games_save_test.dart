import 'package:flutter_test/flutter_test.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/game_session_provider.dart';
import 'package:stones/services/ai/ai.dart';
import 'package:stones/services/play_games_save.dart';

void main() {
  test('cloud save restores AI difficulty, human color and stacked pieces', () {
    final game = GameState.initial(5).copyWith(
      board: Board.empty(5).setStack(
          const Position(1, 2),
          const PieceStack([
            Piece(type: PieceType.flat, color: PlayerColor.white),
            Piece(type: PieceType.standing, color: PlayerColor.black),
          ])),
    );
    final save = PlayGamesSave(
        state: game,
        moveCount: 14,
        session: const GameSessionConfig(
            mode: GameMode.vsComputer,
            aiDifficulty: AIDifficulty.expert,
            vsComputerPlayerColor: PlayerColor.black));
    final restored = PlayGamesSave.fromJson(save.toJson());
    expect(restored.session.mode, GameMode.vsComputer);
    expect(restored.session.aiDifficulty, AIDifficulty.expert);
    expect(restored.session.vsComputerPlayerColor, PlayerColor.black);
    expect(restored.moveCount, 14);
    expect(restored.state.board.stackAt(const Position(1, 2)).pieces.length, 2);
    expect(restored.state.board.stackAt(const Position(1, 2)).topPiece?.type,
        PieceType.standing);
  });

  test('legacy saves and online sessions cannot replace the current match', () {
    for (final payload in [
      <String, dynamic>{'version': 1},
      <String, dynamic>{'version': 2, 'mode': 'online'}
    ]) {
      expect(() => PlayGamesSave.fromJson(payload), throwsFormatException);
    }
  });

  test('corrupt dimensions fail before constructing a board', () {
    final data = PlayGamesSave(
            state: GameState.initial(5),
            moveCount: 0,
            session: const GameSessionConfig())
        .toJson();
    (data['state'] as Map<String, dynamic>)['boardSize'] = 1000000;
    expect(() => PlayGamesSave.fromJson(data), throwsFormatException);
  });
}
