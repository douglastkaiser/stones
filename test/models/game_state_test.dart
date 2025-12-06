import 'package:flutter_test/flutter_test.dart';
import 'package:stones/models/models.dart';

void main() {
  group('PieceCounts', () {
    test('returns correct counts for each board size', () {
      expect(PieceCounts.forBoardSize(3).flatStones, 10);
      expect(PieceCounts.forBoardSize(3).capstones, 0);
      expect(PieceCounts.forBoardSize(5).flatStones, 21);
      expect(PieceCounts.forBoardSize(5).capstones, 1);
      expect(PieceCounts.forBoardSize(8).flatStones, 50);
      expect(PieceCounts.forBoardSize(8).capstones, 2);
    });

    test('throws for invalid board size', () {
      expect(() => PieceCounts.forBoardSize(2), throwsArgumentError);
      expect(() => PieceCounts.forBoardSize(9), throwsArgumentError);
    });
  });

  group('Piece', () {
    test('flat stones can be stacked upon', () {
      const flat = Piece(type: PieceType.flat, color: PlayerColor.white);
      expect(flat.canBeStackedUpon, true);
    });

    test('standing stones cannot be stacked upon', () {
      const standing = Piece(type: PieceType.standing, color: PlayerColor.white);
      expect(standing.canBeStackedUpon, false);
    });

    test('only capstones can flatten walls', () {
      const flat = Piece(type: PieceType.flat, color: PlayerColor.white);
      const cap = Piece(type: PieceType.capstone, color: PlayerColor.white);
      expect(flat.canFlattenWalls, false);
      expect(cap.canFlattenWalls, true);
    });
  });

  group('PlayerPieces', () {
    test('initial pieces match board size', () {
      final pieces5 = PlayerPieces.initial(PlayerColor.white, 5);
      expect(pieces5.flatStones, 21);
      expect(pieces5.capstones, 1);
    });

    test('hasPiece returns correct value', () {
      final pieces = PlayerPieces(
        color: PlayerColor.white,
        flatStones: 1,
        capstones: 0,
      );
      expect(pieces.hasPiece(PieceType.flat), true);
      expect(pieces.hasPiece(PieceType.standing), true); // Uses flat count
      expect(pieces.hasPiece(PieceType.capstone), false);
    });

    test('usePiece decrements correct count', () {
      final pieces = PlayerPieces(
        color: PlayerColor.white,
        flatStones: 5,
        capstones: 1,
      );

      final afterFlat = pieces.usePiece(PieceType.flat);
      expect(afterFlat.flatStones, 4);
      expect(afterFlat.capstones, 1);

      final afterCap = pieces.usePiece(PieceType.capstone);
      expect(afterCap.flatStones, 5);
      expect(afterCap.capstones, 0);
    });
  });

  group('Position', () {
    test('adjacentPositions returns valid neighbors', () {
      const center = Position(2, 2);
      final adjacent = center.adjacentPositions(5);
      expect(adjacent, hasLength(4));
      expect(adjacent, contains(const Position(1, 2)));
      expect(adjacent, contains(const Position(3, 2)));
      expect(adjacent, contains(const Position(2, 1)));
      expect(adjacent, contains(const Position(2, 3)));
    });

    test('corner position has 2 neighbors', () {
      const corner = Position(0, 0);
      final adjacent = corner.adjacentPositions(5);
      expect(adjacent, hasLength(2));
    });
  });

  group('PieceStack', () {
    test('empty stack properties', () {
      const stack = PieceStack.empty;
      expect(stack.isEmpty, true);
      expect(stack.height, 0);
      expect(stack.topPiece, null);
      expect(stack.controller, null);
    });

    test('push adds piece to top', () {
      const piece = Piece(type: PieceType.flat, color: PlayerColor.white);
      final stack = PieceStack.empty.push(piece);
      expect(stack.height, 1);
      expect(stack.topPiece, piece);
      expect(stack.controller, PlayerColor.white);
    });

    test('pop removes pieces from top', () {
      const p1 = Piece(type: PieceType.flat, color: PlayerColor.white);
      const p2 = Piece(type: PieceType.flat, color: PlayerColor.black);
      final stack = PieceStack.empty.push(p1).push(p2);

      final (remaining, taken) = stack.pop(1);
      expect(remaining.height, 1);
      expect(taken, [p2]);
    });

    test('canMoveOnto rules', () {
      const flat = Piece(type: PieceType.flat, color: PlayerColor.white);
      const standing = Piece(type: PieceType.standing, color: PlayerColor.black);
      const cap = Piece(type: PieceType.capstone, color: PlayerColor.white);

      final emptyStack = PieceStack.empty;
      final flatStack = emptyStack.push(flat);
      final standingStack = emptyStack.push(standing);
      final capStack = emptyStack.push(cap);

      // Any piece can move onto empty
      expect(emptyStack.canMoveOnto(flat), true);

      // Any piece can move onto flat
      expect(flatStack.canMoveOnto(flat), true);
      expect(flatStack.canMoveOnto(standing), true);

      // Only capstone can move onto standing
      expect(standingStack.canMoveOnto(flat), false);
      expect(standingStack.canMoveOnto(cap), true);

      // Nothing can move onto capstone
      expect(capStack.canMoveOnto(flat), false);
      expect(capStack.canMoveOnto(cap), false);
    });
  });

  group('Board', () {
    test('empty board has all empty stacks', () {
      final board = Board.empty(5);
      for (final pos in board.allPositions) {
        expect(board.stackAt(pos).isEmpty, true);
      }
    });

    test('placePiece adds piece to board', () {
      var board = Board.empty(5);
      const pos = Position(2, 2);
      const piece = Piece(type: PieceType.flat, color: PlayerColor.white);

      board = board.placePiece(pos, piece);
      expect(board.stackAt(pos).topPiece, piece);
    });

    test('setStack replaces stack', () {
      var board = Board.empty(5);
      const pos = Position(2, 2);
      const piece = Piece(type: PieceType.flat, color: PlayerColor.white);
      final stack = PieceStack.empty.push(piece);

      board = board.setStack(pos, stack);
      expect(board.stackAt(pos), stack);
    });
  });

  group('GameState', () {
    test('initial state has correct properties', () {
      final state = GameState.initial(5);
      expect(state.boardSize, 5);
      expect(state.currentPlayer, PlayerColor.white);
      expect(state.turnNumber, 1);
      expect(state.phase, GamePhase.opening);
      expect(state.isGameOver, false);
    });

    test('nextTurn switches player', () {
      var state = GameState.initial(5);
      expect(state.currentPlayer, PlayerColor.white);

      state = state.nextTurn();
      expect(state.currentPlayer, PlayerColor.black);

      state = state.nextTurn();
      expect(state.currentPlayer, PlayerColor.white);
      expect(state.turnNumber, 2);
    });

    test('opening phase transitions to playing after both players move', () {
      var state = GameState.initial(5);
      expect(state.phase, GamePhase.opening);

      state = state.nextTurn(); // White to Black
      expect(state.phase, GamePhase.opening);

      state = state.nextTurn(); // Black to White
      expect(state.phase, GamePhase.playing);
    });
  });
}
