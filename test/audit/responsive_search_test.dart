import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/models/models.dart';
import 'package:stones/services/ai/ai.dart';
import 'package:stones/services/ai/lookahead_ai.dart';
import 'package:stones/hex/hex_ai.dart';
import 'package:stones/hex/hex_game.dart';

void main() {
  test('cooperative square search preserves the seeded tactical decision',
      () async {
    const white = Piece(type: PieceType.flat, color: PlayerColor.white);
    const black = Piece(type: PieceType.flat, color: PlayerColor.black);
    final board = Board.empty(3)
        .placePiece(const Position(0, 0), white)
        .placePiece(const Position(1, 1), white)
        .placePiece(const Position(0, 2), black);
    final state =
        GameState.initial(3).copyWith(board: board, phase: GamePhase.playing);
    for (final cooperative in [false, true]) {
      final ai = LookaheadStonesAI(Random(1),
          searchDepth: 3,
          maxBranchingLimit: 14,
          midBranchingLimit: 10,
          deepBranchingLimit: 8,
          evaluationJitter: .03,
          yieldDuringSearch: cooperative);
      final move = await ai.selectMove(state) as AIPlacementMove;
      expect(move.position, const Position(1, 0));
      expect(move.pieceType, PieceType.flat);
    }
  });

  test('cancelled browser searches stop without applying a move', () async {
    final ai =
        LookaheadStonesAI(Random(1), searchDepth: 4, yieldDuringSearch: true);
    expect(await ai.selectMove(GameState.initial(5), cancelled: () => true),
        isNull);
    expect(
        await HexAI.chooseResponsive(HexGame.initial(), cancelled: () => true),
        isNull);
  });

  test('cooperative Hex search preserves native decisions', () async {
    for (final radius in [2, 3, 4]) {
      final game = HexGame.initial(radius: radius);
      expect((await HexAI.chooseResponsive(game))!.toMap(game.current),
          HexAI.choose(game)!.toMap(game.current));
    }
  });
}
