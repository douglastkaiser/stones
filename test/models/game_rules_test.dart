import 'package:flutter_test/flutter_test.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/game_provider.dart';
import 'package:stones/providers/ui_state_provider.dart';
import 'package:stones/services/ai/ai.dart';

const _whiteFlat = Piece(type: PieceType.flat, color: PlayerColor.white);
const _blackFlat = Piece(type: PieceType.flat, color: PlayerColor.black);
const _whiteWall = Piece(type: PieceType.standing, color: PlayerColor.white);
const _blackWall = Piece(type: PieceType.standing, color: PlayerColor.black);
const _whiteCap = Piece(type: PieceType.capstone, color: PlayerColor.white);
const _blackCap = Piece(type: PieceType.capstone, color: PlayerColor.black);

GameState _playing(Board board, {PlayerColor player = PlayerColor.white}) {
  var state = GameState.initial(board.size).copyWith(
    board: board,
    phase: GamePhase.playing,
    currentPlayer: player,
    turnNumber: 4,
  );
  for (final position in board.occupiedPositions) {
    for (final piece in board.stackAt(position).pieces) {
      state = state.updatePieces(
        piece.color,
        state.piecesFor(piece.color).usePiece(piece.type),
      );
    }
  }
  return state;
}

GameState _capstoneSpread() => _playing(
      Board.empty(5)
          .setStack(
            const Position(2, 0),
            const PieceStack([_whiteFlat, _blackFlat, _whiteCap]),
          )
          .placePiece(const Position(2, 1), _blackFlat)
          .placePiece(const Position(2, 2), _blackWall),
    );

void main() {
  group('official setup and placement', () {
    const supplies = {
      3: (10, 0),
      4: (15, 0),
      5: (21, 1),
      6: (30, 1),
      7: (40, 2), // USTA convention; omitted from publisher tables.
      8: (50, 2),
    };
    for (final entry in supplies.entries) {
      test('${entry.key}x${entry.key} has the documented reserves', () {
        final state = GameState.initial(entry.key);
        expect(state.board.occupiedPositions, isEmpty);
        for (final color in PlayerColor.values) {
          expect(state.piecesFor(color).flatStones, entry.value.$1);
          expect(state.piecesFor(color).capstones, entry.value.$2);
        }
      });
    }

    test('both opening placements use the opponent reserve and color', () {
      final notifier = GameStateNotifier();
      addTearDown(notifier.dispose);
      expect(notifier.placePiece(const Position(0, 0), PieceType.flat), isTrue);
      expect(notifier.state.board.stackAt(const Position(0, 0)).topPiece,
          _blackFlat);
      expect(notifier.state.blackPieces.flatStones, 20);
      expect(notifier.state.whitePieces.flatStones, 21);
      expect(notifier.placePiece(const Position(0, 1), PieceType.flat), isTrue);
      expect(notifier.state.board.stackAt(const Position(0, 1)).topPiece,
          _whiteFlat);
      expect(notifier.state.whitePieces.flatStones, 20);
      expect(notifier.state.phase, GamePhase.playing);
      expect(notifier.state.currentPlayer, PlayerColor.white);
      expect(notifier.state.turnNumber, 2);
    });

    test('opening rejects walls, capstones and stack movement atomically', () {
      final notifier = GameStateNotifier();
      addTearDown(notifier.dispose);
      final before = notifier.state;
      expect(notifier.placePiece(const Position(0, 0), PieceType.standing),
          isFalse);
      expect(notifier.placePiece(const Position(0, 0), PieceType.capstone),
          isFalse);
      expect(notifier.moveStack(const Position(0, 0), Direction.right, [1]),
          isFalse);
      expect(notifier.state, before);
      expect(notifier.canUndo, isFalse);
    });

    test('walls share the flat reserve and new pieces cannot cover a stack',
        () {
      final state = _playing(Board.empty(5));
      final placed = GameRules.tryPlacePiece(
        state,
        const Position(2, 2),
        PieceType.standing,
      )!;
      expect(placed.whitePieces.flatStones, 20);
      expect(placed.whitePieces.capstones, 1);
      expect(
          GameRules.tryPlacePiece(placed, const Position(2, 2), PieceType.flat),
          isNull);
      expect(placed.board.stackAt(const Position(2, 2)).topPiece, _whiteWall);
    });

    test('an exhausted flat reserve still allows the remaining capstone', () {
      final state = _playing(Board.empty(5)).copyWith(
        whitePieces: const PlayerPieces(
          color: PlayerColor.white,
          flatStones: 0,
          capstones: 1,
        ),
      );
      expect(
          GameRules.tryPlacePiece(state, const Position(2, 2), PieceType.flat),
          isNull);
      expect(
          GameRules.tryPlacePiece(
              state, const Position(2, 2), PieceType.standing),
          isNull);
      expect(
          GameRules.tryPlacePiece(
              state, const Position(2, 2), PieceType.capstone),
          isNotNull);
      expect(GameRules.flatResult(state), isNull);
    });

    test('out-of-bounds placement returns false without history changes', () {
      final notifier = GameStateNotifier();
      addTearDown(notifier.dispose);
      for (final position in [const Position(-1, 0), const Position(5, 0)]) {
        expect(notifier.placePiece(position, PieceType.flat), isFalse);
      }
      expect(notifier.state, GameState.initial(5));
      expect(notifier.canUndo, isFalse);
    });
  });

  group('official stack movement examples', () {
    test('a five-stone spread drops bottom first and carries the wall last',
        () {
      final state = _playing(
        Board.empty(5)
            .setStack(
              const Position(2, 0),
              const PieceStack([
                _blackFlat,
                _whiteFlat,
                _blackFlat,
                _whiteFlat,
                _whiteWall,
              ]),
            )
            .placePiece(const Position(2, 1), _blackFlat)
            .placePiece(const Position(2, 2), _blackFlat)
            .placePiece(const Position(2, 3), _blackFlat),
      );
      final moved = GameRules.tryMoveStack(
        state,
        const Position(2, 0),
        Direction.right,
        [2, 2, 1],
      )!;
      expect(moved.board.stackAt(const Position(2, 0)).isEmpty, isTrue);
      expect(moved.board.stackAt(const Position(2, 1)).pieces,
          [_blackFlat, _blackFlat, _whiteFlat]);
      expect(moved.board.stackAt(const Position(2, 2)).pieces,
          [_blackFlat, _blackFlat, _whiteFlat]);
      expect(moved.board.stackAt(const Position(2, 3)).pieces,
          [_blackFlat, _whiteWall]);
      expect(moved.whitePieces, state.whitePieces);
      expect(moved.blackPieces, state.blackPieces);
      expect(state.board.stackAt(const Position(2, 0)).height, 5);
    });

    test('publisher capstone example preserves the exposed opponent stones',
        () {
      final state = _playing(
        Board.empty(5)
            .setStack(
                const Position(4, 2),
                const PieceStack([
                  _blackFlat,
                  _blackFlat,
                  _whiteFlat,
                  _whiteFlat,
                  _blackCap,
                ]))
            .placePiece(const Position(3, 2), _blackFlat)
            .placePiece(const Position(2, 2), _whiteWall),
        player: PlayerColor.black,
      );
      final moved = GameRules.tryMoveStack(
        state,
        const Position(4, 2),
        Direction.up,
        [2, 1],
      )!;
      expect(moved.board.stackAt(const Position(4, 2)).pieces,
          [_blackFlat, _blackFlat]);
      expect(moved.board.stackAt(const Position(3, 2)).controller,
          PlayerColor.white);
      expect(moved.board.stackAt(const Position(2, 2)).pieces,
          [_whiteFlat, _blackCap]);
    });

    for (final wall in [_whiteWall, _blackWall]) {
      test('a lone capstone flattens a ${wall.color.name} wall', () {
        final state = _playing(Board.empty(5)
            .placePiece(const Position(2, 0), _whiteCap)
            .placePiece(const Position(2, 1), wall));
        final moved = GameRules.tryMoveStack(
          state,
          const Position(2, 0),
          Direction.right,
          [1],
        )!;
        expect(moved.board.stackAt(const Position(2, 1)).pieces,
            [wall.copyWith(type: PieceType.flat), _whiteCap]);
      });
    }

    test('stack height is unrestricted but pickup obeys the carry limit', () {
      final state = _playing(Board.empty(5).setStack(
        const Position(2, 0),
        PieceStack(List.filled(7, _whiteFlat)),
      ));
      expect(
          GameRules.tryMoveStack(
              state, const Position(2, 0), Direction.right, [6]),
          isNull);
      final moved = GameRules.tryMoveStack(
        state,
        const Position(2, 0),
        Direction.right,
        [5],
      )!;
      expect(moved.board.stackAt(const Position(2, 0)).height, 2);
      expect(moved.board.stackAt(const Position(2, 1)).height, 5);
    });

    test('blocked and malformed moves do not change board or undo history', () {
      final notifier = GameStateNotifier();
      addTearDown(notifier.dispose);
      final state = _playing(Board.empty(5)
          .setStack(
              const Position(2, 0), const PieceStack([_whiteFlat, _whiteCap]))
          .placePiece(const Position(2, 1), _blackWall)
          .placePiece(const Position(3, 0), _blackCap));
      notifier.loadState(state);
      var historyNotifications = 0;
      notifier.onHistoryChanged = (_) => historyNotifications++;
      for (final drops in <List<int>>[
        [],
        [0],
        [-1],
        [1, 0],
        [0, 1],
        [2]
      ]) {
        expect(notifier.moveStack(const Position(2, 0), Direction.right, drops),
            isFalse,
            reason: 'Reject $drops onto a wall.');
      }
      expect(notifier.moveStack(const Position(2, 0), Direction.down, [1]),
          isFalse);
      expect(notifier.moveStack(const Position(2, 0), Direction.left, [1]),
          isFalse);
      expect(
          notifier.moveStack(const Position(5, 0), Direction.up, [1]), isFalse);
      expect(
          notifier.moveStack(const Position(3, 0), Direction.up, [1]), isFalse);
      expect(notifier.state, state);
      expect(notifier.canUndo, isFalse);
      expect(historyNotifications, 0);
    });

    test('play cannot resume after the game has finished', () {
      final state =
          _playing(Board.empty(5).placePiece(const Position(2, 0), _whiteFlat))
              .copyWith(
        phase: GamePhase.finished,
        result: GameResult.whiteWins,
      );
      expect(
          GameRules.tryPlacePiece(state, const Position(0, 0), PieceType.flat),
          isNull);
      expect(
          GameRules.tryMoveStack(
              state, const Position(2, 0), Direction.right, [1]),
          isNull);
      expect(const AIMoveGenerator().generateMoves(state), isEmpty);
    });
  });

  group('previews follow capstone rules', () {
    test('a whole capstone stack cannot land on an adjacent wall', () {
      final state = _playing(Board.empty(5)
          .setStack(
              const Position(2, 0), const PieceStack([_whiteFlat, _whiteCap]))
          .placePiece(const Position(2, 1), _blackWall));
      const selection = UIState(
        selectedPosition: Position(2, 0),
        mode: InteractionMode.movingStack,
        piecesPickedUp: 2,
      );
      expect(selection.getValidMoveDestinations(state),
          isNot(contains(const Position(2, 1))));
      expect(
          selection.copyWith(piecesPickedUp: 1).getValidMoveDestinations(state),
          contains(const Position(2, 1)));
    });

    test('wall is reachable as a final step but never as a transit square', () {
      const selection = UIState(
        selectedPosition: Position(2, 0),
        mode: InteractionMode.movingStack,
        piecesPickedUp: 3,
      );
      final destinations =
          selection.getValidMoveDestinations(_capstoneSpread());
      expect(destinations, contains(const Position(2, 2)));
      expect(destinations, isNot(contains(const Position(2, 3))));
    });

    test('continuing to the wall requires leaving only the capstone in hand',
        () {
      final state = _capstoneSpread();
      const spread = UIState(
        selectedPosition: Position(2, 0),
        selectedDirection: Direction.right,
        mode: InteractionMode.droppingPieces,
        piecesPickedUp: 3,
      );
      expect(spread.canContinueDropping(state), isFalse);
      final legalSpread = spread.copyWith(pendingDropCount: 2);
      expect(legalSpread.canContinueDropping(state), isTrue);
      expect(legalSpread.getValidDropDestinations(state),
          contains(const Position(2, 2)));
      final finalStep = legalSpread.copyWith(drops: [2], piecesPickedUp: 1);
      final preview = finalStep.getPreviewStacks(state)!;
      expect(preview[const Position(2, 2)]!.$1.topPiece, _blackFlat);
      expect(preview[const Position(2, 2)]!.$2, [_whiteCap]);
    });
  });

  test('every generated scenario move is accepted by gameplay validation', () {
    final states = [
      GameState.initial(5),
      _capstoneSpread(),
      ...tutorialAndPuzzleLibrary
          .map((scenario) => scenario.buildInitialState()),
    ];
    for (final state in states) {
      for (final move in const AIMoveGenerator().generateMoves(state)) {
        final notifier = GameStateNotifier();
        notifier.loadState(state);
        try {
          final accepted = switch (move) {
            AIPlacementMove() =>
              notifier.placePiece(move.position, move.pieceType),
            AIStackMove() =>
              notifier.moveStack(move.from, move.direction, move.drops),
          };
          expect(accepted, isTrue,
              reason: 'AI generated an illegal move: $move');
          expect(notifier.state.currentPlayer, state.opponent);
          if (state.isOpeningPhase && move is AIPlacementMove) {
            expect(notifier.state.board.stackAt(move.position).topPiece?.color,
                state.opponent);
          }
        } finally {
          notifier.dispose();
        }
      }
    }
  });
}
