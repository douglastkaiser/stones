import '../models/models.dart';
import '../providers/game_provider.dart';

/// Apply one recorded square move through the gameplay authority. Replay must
/// validate the record's turn and pickup count as well as its geometry.
bool applyOnlineMove(
    GameStateNotifier game, GameState state, OnlineGameMove move) {
  if (move.player != state.currentPlayer ||
      state.isGameOver ||
      !OnlineGameMove.isValidNotation(move.notation)) {
    return false;
  }
  final size = state.boardSize;
  Position position(String col, String row) =>
      Position(size - int.parse(row), col.codeUnitAt(0) - 97);
  final placement = RegExp(r'^(S|C)?([a-z])(\d+)$').firstMatch(move.notation);
  if (placement != null) {
    final type = switch (placement.group(1)) {
      'S' => PieceType.standing,
      'C' => PieceType.capstone,
      _ => PieceType.flat,
    };
    return game.placePiece(
        position(placement.group(2)!, placement.group(3)!), type);
  }
  final spread =
      RegExp(r'^(\d+)?([a-z])(\d+)([<>+-])(\d+)?$').firstMatch(move.notation);
  if (spread == null) return false;
  final picked = int.parse(spread.group(1) ?? '1');
  final drops = spread.group(5)?.split('').map(int.parse).toList() ?? [picked];
  if (drops.any((drop) => drop <= 0) ||
      drops.fold<int>(0, (sum, drop) => sum + drop) != picked) {
    return false;
  }
  final direction = switch (spread.group(4)) {
    '+' => Direction.up,
    '-' => Direction.down,
    '<' => Direction.left,
    _ => Direction.right,
  };
  return game.moveStack(
      position(spread.group(2)!, spread.group(3)!), direction, drops);
}
