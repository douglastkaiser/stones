import 'board.dart';
import 'piece.dart';

/// Represents a game move (either placement or stack movement)
sealed class GameMove {
  const GameMove();

  /// Convert move to Portable Tak Notation (PTN)
  String toNotation(int boardSize);
}

/// A piece placement move
class PlacementMove extends GameMove {
  final Position position;
  final PieceType pieceType;
  final PlayerColor player;

  const PlacementMove({
    required this.position,
    required this.pieceType,
    required this.player,
  });

  @override
  String toNotation(int boardSize) {
    final col = String.fromCharCode('a'.codeUnitAt(0) + position.col);
    final row = boardSize - position.row;
    final prefix = switch (pieceType) {
      PieceType.flat => '',
      PieceType.standing => 'S',
      PieceType.capstone => 'C',
    };
    return '$prefix$col$row';
  }

  @override
  String toString() => 'Place ${pieceType.name} at ${position}';
}

/// A stack movement move
class StackMove extends GameMove {
  final Position from;
  final Direction direction;
  final List<int> drops;
  final int piecesPickedUp;
  final bool flattenedWall;

  const StackMove({
    required this.from,
    required this.direction,
    required this.drops,
    required this.piecesPickedUp,
    this.flattenedWall = false,
  });

  @override
  String toNotation(int boardSize) {
    final col = String.fromCharCode('a'.codeUnitAt(0) + from.col);
    final row = boardSize - from.row;
    final countStr = piecesPickedUp > 1 ? '$piecesPickedUp' : '';
    final dirChar = switch (direction) {
      Direction.up => '+',
      Direction.down => '-',
      Direction.left => '<',
      Direction.right => '>',
    };
    final dropStr = drops.length > 1 ? drops.join('') : '';
    final flatten = flattenedWall ? '*' : '';
    return '$countStr$col$row$dirChar$dropStr$flatten';
  }

  @override
  String toString() => 'Move ${piecesPickedUp} from ${from} ${direction.name} drops:${drops}';
}

/// A complete move record with notation and effect
class MoveRecord {
  final GameMove move;
  final String notation;
  final int turnNumber;
  final PlayerColor player;

  const MoveRecord({
    required this.move,
    required this.notation,
    required this.turnNumber,
    required this.player,
  });
}
