/// Types of pieces in the game
enum PieceType {
  flat,
  standing, // wall
  capstone,
}

/// Player colors
enum PlayerColor {
  white,
  black,
}

/// A single game piece
class Piece {
  final PieceType type;
  final PlayerColor color;

  const Piece({
    required this.type,
    required this.color,
  });

  /// A flat stone can be stacked upon
  bool get canBeStackedUpon => type == PieceType.flat;

  /// Only capstones can flatten standing stones
  bool get canFlattenWalls => type == PieceType.capstone;

  /// Create a copy with different type (for flattening walls)
  Piece copyWith({PieceType? type}) {
    return Piece(
      type: type ?? this.type,
      color: color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Piece && type == other.type && color == other.color;

  @override
  int get hashCode => Object.hash(type, color);

  @override
  String toString() => 'Piece(${color.name} ${type.name})';
}
