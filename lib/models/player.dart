import 'piece.dart';

/// Piece counts based on board size
class PieceCounts {
  final int flatStones;
  final int capstones;

  const PieceCounts({required this.flatStones, required this.capstones});

  /// Get piece counts for a given board size
  static PieceCounts forBoardSize(int size) {
    return switch (size) {
      3 => const PieceCounts(flatStones: 10, capstones: 0),
      4 => const PieceCounts(flatStones: 15, capstones: 0),
      5 => const PieceCounts(flatStones: 21, capstones: 1),
      6 => const PieceCounts(flatStones: 30, capstones: 1),
      7 => const PieceCounts(flatStones: 40, capstones: 2),
      8 => const PieceCounts(flatStones: 50, capstones: 2),
      _ => throw ArgumentError('Board size must be between 3 and 8'),
    };
  }
}

/// Represents a player's remaining pieces
class PlayerPieces {
  final PlayerColor color;
  final int flatStones;
  final int capstones;

  const PlayerPieces({
    required this.color,
    required this.flatStones,
    required this.capstones,
  });

  /// Create initial pieces for a player based on board size
  factory PlayerPieces.initial(PlayerColor color, int boardSize) {
    final counts = PieceCounts.forBoardSize(boardSize);
    return PlayerPieces(
      color: color,
      flatStones: counts.flatStones,
      capstones: counts.capstones,
    );
  }

  /// Total pieces remaining
  int get total => flatStones + capstones;

  /// Check if player has pieces of a given type
  bool hasPiece(PieceType type) {
    return switch (type) {
      PieceType.flat || PieceType.standing => flatStones > 0,
      PieceType.capstone => capstones > 0,
    };
  }

  /// Use a piece (returns new PlayerPieces with decremented count)
  PlayerPieces usePiece(PieceType type) {
    return switch (type) {
      PieceType.flat || PieceType.standing => copyWith(flatStones: flatStones - 1),
      PieceType.capstone => copyWith(capstones: capstones - 1),
    };
  }

  PlayerPieces copyWith({int? flatStones, int? capstones}) {
    return PlayerPieces(
      color: color,
      flatStones: flatStones ?? this.flatStones,
      capstones: capstones ?? this.capstones,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerPieces &&
          color == other.color &&
          flatStones == other.flatStones &&
          capstones == other.capstones;

  @override
  int get hashCode => Object.hash(color, flatStones, capstones);

  @override
  String toString() =>
      'PlayerPieces($color: $flatStones flats, $capstones caps)';
}
