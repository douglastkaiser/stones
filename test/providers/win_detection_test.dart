import 'package:flutter_test/flutter_test.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/game_provider.dart';
import 'package:stones/services/ai/ai.dart';
import 'package:stones/services/ai/board_analysis.dart';

Piece _flat(PlayerColor color) => Piece(type: PieceType.flat, color: color);

PlayerColor _other(PlayerColor color) =>
    color == PlayerColor.white ? PlayerColor.black : PlayerColor.white;

GameState _playing(Board board, PlayerColor mover, {int? remainingFlats}) {
  final state = GameState.initial(board.size).copyWith(
    board: board,
    currentPlayer: mover,
    phase: GamePhase.playing,
    turnNumber: 4,
  );
  return remainingFlats == null
      ? state
      : state.updatePieces(
          mover,
          state
              .piecesFor(mover)
              .copyWith(flatStones: remainingFlats, capstones: 0),
        );
}

// Moving the top piece exposes the opponent's horizontal road. If requested,
// the destination also completes the mover's road on the next row.
Board _roadExposureBoard(PlayerColor mover, {required bool doubleRoad}) {
  final opponent = _other(mover);
  var board = Board.empty(3)
      .placePiece(const Position(0, 0), _flat(opponent))
      .setStack(
        const Position(0, 1),
        PieceStack([_flat(opponent), _flat(mover)]),
      )
      .placePiece(const Position(0, 2), _flat(opponent));
  if (doubleRoad) {
    board = board
        .placePiece(const Position(1, 0), _flat(mover))
        .placePiece(const Position(1, 2), _flat(mover));
  }
  return board;
}

void main() {
  group('road outcomes', () {
    for (final mover in PlayerColor.values) {
      test('${mover.name} wins when their move creates both roads', () {
        final notifier = GameStateNotifier();
        addTearDown(notifier.dispose);
        notifier.loadState(
          _playing(_roadExposureBoard(mover, doubleRoad: true), mover),
        );
        Set<Position>? winningRoad;
        PlayerColor? animatedWinner;
        notifier.onRoadWin = (positions, winner) {
          winningRoad = positions;
          animatedWinner = winner;
        };

        expect(
          notifier.moveStack(const Position(0, 1), Direction.down, [1]),
          isTrue,
        );
        expect(notifier.state.currentPlayer, _other(mover));
        expect(notifier.state.phase, GamePhase.finished);
        expect(
          notifier.state.result,
          mover == PlayerColor.white
              ? GameResult.whiteWins
              : GameResult.blackWins,
        );
        expect(notifier.state.winReason, WinReason.road);
        expect(animatedWinner, mover);
        expect(winningRoad, {
          const Position(1, 0),
          const Position(1, 1),
          const Position(1, 2),
        });
        expect(
          BoardAnalysis.getRoadWinner(notifier.state, lastMover: mover),
          mover,
        );
      });

      test('${mover.name} loses when only the opponent gains a road', () {
        final notifier = GameStateNotifier();
        addTearDown(notifier.dispose);
        notifier.loadState(
          _playing(_roadExposureBoard(mover, doubleRoad: false), mover),
        );

        expect(
          notifier.moveStack(const Position(0, 1), Direction.down, [1]),
          isTrue,
        );
        expect(
          notifier.state.result,
          mover == PlayerColor.white
              ? GameResult.blackWins
              : GameResult.whiteWins,
        );
        expect(notifier.state.winReason, WinReason.road);
        expect(
          BoardAnalysis.getRoadWinner(notifier.state, lastMover: mover),
          _other(mover),
        );
      });

      test('road beats flat scoring on ${mover.name}\'s last placement', () {
        final notifier = GameStateNotifier();
        addTearDown(notifier.dispose);
        final opponent = _other(mover);
        final board = Board.empty(3)
            .placePiece(const Position(0, 0), _flat(mover))
            .placePiece(const Position(0, 1), _flat(mover))
            .placePiece(const Position(1, 0), _flat(opponent))
            .placePiece(const Position(1, 1), _flat(opponent));
        notifier.loadState(_playing(board, mover, remainingFlats: 1));

        expect(
          notifier.placePiece(const Position(0, 2), PieceType.flat),
          isTrue,
        );
        expect(notifier.state.piecesFor(mover).total, 0);
        expect(notifier.state.winReason, WinReason.road);
        expect(
          notifier.state.result,
          mover == PlayerColor.white
              ? GameResult.whiteWins
              : GameResult.blackWins,
        );
      });

      test('equal flats draw when ${mover.name} exhausts their reserve', () {
        final notifier = GameStateNotifier();
        addTearDown(notifier.dispose);
        final opponent = _other(mover);
        final board = Board.empty(3)
            .placePiece(const Position(0, 0), _flat(mover))
            .placePiece(const Position(2, 0), _flat(opponent))
            .placePiece(const Position(2, 2), _flat(opponent));
        notifier.loadState(_playing(board, mover, remainingFlats: 1));

        expect(
          notifier.placePiece(const Position(0, 2), PieceType.flat),
          isTrue,
        );
        expect(notifier.state.result, GameResult.draw);
        expect(notifier.state.winReason, WinReason.flats);
      });
    }
  });

  group('flat scoring', () {
    test(
      'equal flats draw on board fill without exhausting reserves',
      () async {
        final notifier = GameStateNotifier();
        addTearDown(notifier.dispose);
        var board = Board.empty(3);
        for (final pos in board.allPositions) {
          if (pos == const Position(1, 1)) continue;
          final isFlat = pos.col != 1 && pos.row != 1;
          board = board.placePiece(
            pos,
            Piece(
              type: isFlat ? PieceType.flat : PieceType.standing,
              color: pos.row == 0 ? PlayerColor.white : PlayerColor.black,
            ),
          );
        }
        notifier.loadState(_playing(board, PlayerColor.white));

        expect(
          notifier.placePiece(const Position(1, 1), PieceType.standing),
          isTrue,
        );
        expect(notifier.state.whitePieces.total, greaterThan(0));
        expect(notifier.state.blackPieces.total, greaterThan(0));
        expect(notifier.state.result, GameResult.draw);
        expect(notifier.state.winReason, WinReason.flats);

        // The simulator does not set the finished phase. Each difficulty must
        // still recognize this draw as terminal instead of moving a stack.
        final simulatedState = _playing(
          notifier.state.board,
          PlayerColor.black,
        );
        for (final difficulty in AIDifficulty.values) {
          expect(
            await StonesAI.forDifficulty(difficulty).selectMove(simulatedState),
            isNull,
            reason: '${difficulty.name} must stop at a flat draw.',
          );
        }
      },
    );

    test('capstones, walls and buried flats do not count as exposed flats', () {
      final notifier = GameStateNotifier();
      addTearDown(notifier.dispose);
      final board = Board.empty(5)
          .placePiece(const Position(0, 0), _flat(PlayerColor.white))
          .setStack(
            const Position(4, 0),
            PieceStack([
              _flat(PlayerColor.white),
              _flat(PlayerColor.white),
              _flat(PlayerColor.black),
            ]),
          )
          .placePiece(const Position(4, 4), _flat(PlayerColor.black))
          .placePiece(
            const Position(2, 2),
            const Piece(type: PieceType.capstone, color: PlayerColor.white),
          );
      notifier.loadState(_playing(board, PlayerColor.white, remainingFlats: 1));

      expect(
        notifier.placePiece(const Position(0, 4), PieceType.standing),
        isTrue,
      );
      expect(notifier.state.result, GameResult.blackWins);
      expect(notifier.state.winReason, WinReason.flats);
    });

    test(
      'play continues with no road, empty squares and remaining reserves',
      () {
        final notifier = GameStateNotifier();
        addTearDown(notifier.dispose);
        notifier.loadState(_playing(Board.empty(3), PlayerColor.white));

        expect(
          notifier.placePiece(const Position(1, 1), PieceType.flat),
          isTrue,
        );
        expect(notifier.state.isGameOver, isFalse);
        expect(notifier.state.result, isNull);
        expect(notifier.state.winReason, isNull);
        expect(
          BoardAnalysis.getRoadWinner(
            notifier.state,
            lastMover: PlayerColor.white,
          ),
          isNull,
        );
      },
    );
  });
}
