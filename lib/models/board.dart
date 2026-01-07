import 'piece.dart';

/// A position on the board
class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  /// Get adjacent positions (up, down, left, right)
  List<Position> adjacentPositions(int boardSize) {
    final positions = <Position>[];
    if (row > 0) positions.add(Position(row - 1, col));
    if (row < boardSize - 1) positions.add(Position(row + 1, col));
    if (col > 0) positions.add(Position(row, col - 1));
    if (col < boardSize - 1) positions.add(Position(row, col + 1));
    return positions;
  }

  /// Check if position is within board bounds
  bool isValid(int boardSize) {
    return row >= 0 && row < boardSize && col >= 0 && col < boardSize;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position && row == other.row && col == other.col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row, $col)';
}

/// Direction for moving stacks
enum Direction {
  up(-1, 0),
  down(1, 0),
  left(0, -1),
  right(0, 1);

  final int rowDelta;
  final int colDelta;

  const Direction(this.rowDelta, this.colDelta);

  Position apply(Position pos) {
    return Position(pos.row + rowDelta, pos.col + colDelta);
  }
}

/// A stack of pieces on a single cell
class PieceStack {
  final List<Piece> pieces;

  const PieceStack([this.pieces = const []]);

  /// Empty stack
  static const empty = PieceStack();

  bool get isEmpty => pieces.isEmpty;
  bool get isNotEmpty => pieces.isNotEmpty;
  int get height => pieces.length;

  /// The piece on top of the stack (controls the cell)
  Piece? get topPiece => pieces.isNotEmpty ? pieces.last : null;

  /// Who controls this cell (owner of top piece)
  PlayerColor? get controller => topPiece?.color;

  /// Can a piece be placed on this stack?
  bool get canPlaceOn => isEmpty;

  /// Can a stack move onto this cell?
  bool canMoveOnto(Piece movingPiece) {
    if (isEmpty) return true;
    final top = topPiece!;
    // Can't move onto standing stones unless moving piece is capstone
    if (top.type == PieceType.standing) {
      return movingPiece.canFlattenWalls;
    }
    // Can't move onto capstones
    if (top.type == PieceType.capstone) return false;
    return true;
  }

  /// Add a piece to the top
  PieceStack push(Piece piece) {
    return PieceStack([...pieces, piece]);
  }

  /// Add multiple pieces to the top
  PieceStack pushAll(List<Piece> newPieces) {
    return PieceStack([...pieces, ...newPieces]);
  }

  /// Remove the top n pieces
  (PieceStack remaining, List<Piece> taken) pop(int count) {
    assert(count <= height && count > 0);
    final splitIndex = pieces.length - count;
    return (
      PieceStack(pieces.sublist(0, splitIndex)),
      pieces.sublist(splitIndex),
    );
  }

  /// Flatten the top piece if it's a standing stone (for capstone moves)
  PieceStack flattenTop() {
    if (isEmpty || topPiece!.type != PieceType.standing) return this;
    final newPieces = [...pieces];
    newPieces[newPieces.length - 1] = topPiece!.copyWith(type: PieceType.flat);
    return PieceStack(newPieces);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PieceStack && _listEquals(pieces, other.pieces);

  @override
  int get hashCode => Object.hashAll(pieces);

  @override
  String toString() => 'Stack($pieces)';
}

/// The game board with copy-on-write semantics for performance
class Board {
  final int size;
  final List<List<PieceStack>> cells;

  const Board._({required this.size, required this.cells});

  /// Create an empty board of given size
  factory Board.empty(int size) {
    assert(size >= 3 && size <= 8);
    // Create a single empty row and reuse it for all rows (structural sharing)
    final emptyRow = List<PieceStack>.filled(size, PieceStack.empty);
    final cells = List.generate(size, (_) => emptyRow);
    return Board._(size: size, cells: cells);
  }

  /// Get the stack at a position
  PieceStack stackAt(Position pos) {
    assert(pos.isValid(size));
    return cells[pos.row][pos.col];
  }

  /// Check if a position is valid
  bool isValidPosition(Position pos) => pos.isValid(size);

  /// Set the stack at a position (returns new board)
  /// Uses copy-on-write: only copies the modified row, shares unchanged rows
  Board setStack(Position pos, PieceStack stack) {
    assert(pos.isValid(size));

    // Early return if stack is unchanged
    if (cells[pos.row][pos.col] == stack) {
      return this;
    }

    // Copy-on-write: only copy the row that changed, share other rows
    // This reduces O(n²) to O(n) per modification
    final newRow = List<PieceStack>.of(cells[pos.row]);
    newRow[pos.col] = stack;

    final newCells = List<List<PieceStack>>.of(cells);
    newCells[pos.row] = newRow;

    return Board._(size: size, cells: newCells);
  }

  /// Place a piece at a position
  Board placePiece(Position pos, Piece piece) {
    final stack = stackAt(pos);
    assert(stack.canPlaceOn);
    return setStack(pos, stack.push(piece));
  }

  /// Get all positions on the board
  Iterable<Position> get allPositions sync* {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        yield Position(r, c);
      }
    }
  }

  /// Get all non-empty positions
  Iterable<Position> get occupiedPositions =>
      allPositions.where((pos) => stackAt(pos).isNotEmpty);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Board && size == other.size && _boardEquals(cells, other.cells);

  @override
  int get hashCode => Object.hash(size, Object.hashAll(cells.expand((r) => r)));
}

// Helper functions for equality
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _boardEquals(List<List<PieceStack>> a, List<List<PieceStack>> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (!_listEquals(a[i], b[i])) return false;
  }
  return true;
}
