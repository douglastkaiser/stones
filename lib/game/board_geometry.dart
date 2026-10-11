import 'match_config.dart';

/// Square uses (column,row); Hex uses axial (q,r). Neither contains pixels.
class Cell {
  const Cell(this.x, this.y);
  final int x;
  final int y;
  int get s => -x - y;
  Cell step(Step direction) => Cell(x + direction.x, y + direction.y);
  @override
  bool operator ==(Object other) =>
      other is Cell && x == other.x && y == other.y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => '$x,$y';
}

enum Step {
  east(1, 0),
  northEast(1, -1),
  northWest(0, -1),
  west(-1, 0),
  southWest(-1, 1),
  southEast(0, 1);

  const Step(this.x, this.y);
  final int x;
  final int y;
}

abstract class BoardGeometry {
  BoardGeometry(this.size);
  factory BoardGeometry.forConfig(MatchConfig config) =>
      config.shape == BoardShape.square
          ? SquareGeometry(config.size)
          : HexGeometry(config.size);
  final int size;
  late final List<Cell> cells = List.unmodifiable(generateCells());
  List<Step> get directions;
  int get axisCount;
  int get carryLimit;
  bool contains(Cell cell);
  Iterable<Cell> generateCells();
  bool boundary(Cell cell, int axis, bool positive);
}

class SquareGeometry extends BoardGeometry {
  SquareGeometry(super.size);
  @override
  List<Step> get directions =>
      const [Step.east, Step.northWest, Step.west, Step.southEast];
  @override
  int get axisCount => 2;
  @override
  int get carryLimit => size;
  @override
  bool contains(Cell cell) =>
      cell.x >= 0 && cell.x < size && cell.y >= 0 && cell.y < size;
  @override
  Iterable<Cell> generateCells() sync* {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        yield Cell(x, y);
      }
    }
  }

  @override
  bool boundary(Cell cell, int axis, bool positive) =>
      (axis == 0 ? cell.x : cell.y) == (positive ? size - 1 : 0);
}

class HexGeometry extends BoardGeometry {
  HexGeometry(super.size);
  @override
  List<Step> get directions => Step.values;
  @override
  int get axisCount => 3;
  @override
  int get carryLimit => 2 * size + 1;
  @override
  bool contains(Cell cell) =>
      cell.x.abs() <= size && cell.y.abs() <= size && cell.s.abs() <= size;
  @override
  Iterable<Cell> generateCells() sync* {
    for (var x = -size; x <= size; x++) {
      for (var y = -size; y <= size; y++) {
        final cell = Cell(x, y);
        if (contains(cell)) yield cell;
      }
    }
  }

  @override
  bool boundary(Cell cell, int axis, bool positive) =>
      [cell.x, cell.y, cell.s][axis] == (positive ? size : -size);
}
