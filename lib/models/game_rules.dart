import 'board.dart';
import 'game_state.dart';
import 'piece.dart';
import '../game/board_geometry.dart';
import '../game/legacy_square_adapter.dart';
import '../game/match_config.dart';
import '../game/match_rules.dart';
import '../game/match_state.dart';

/// Compatibility API for old square providers and room codecs.
/// Validation and move generation live in the shared MatchRules engine.
class GameRules {
  static GameState? tryPlacePiece(
      GameState state, Position position, PieceType type) {
    final next = MatchRules.apply(LegacySquareAdapter.read(state),
        MatchMove.place(Cell(position.col, position.row), type));
    return next == null ? null : LegacySquareAdapter.writeApplied(state, next);
  }

  static GameState? tryMoveStack(
      GameState state, Position from, Direction direction, List<int> drops) {
    final next = MatchRules.apply(
        LegacySquareAdapter.read(state),
        MatchMove.spread(Cell(from.col, from.row),
            LegacySquareAdapter.direction(direction), drops));
    return next == null ? null : LegacySquareAdapter.writeApplied(state, next);
  }

  static Iterable<List<int>> legalStackDrops(
          GameState state, Position from, Direction direction, int pickedUp) =>
      MatchRules.spreads(
              LegacySquareAdapter.read(state), Cell(from.col, from.row),
              direction: LegacySquareAdapter.direction(direction),
              pickup: pickedUp)
          .map((move) => move.drops);

  /// Old callers check roads first; tied flats remain a draw.
  static GameResult? flatResult(GameState state) {
    final result = MatchRules.flatResult(LegacySquareAdapter.read(state));
    if (result == null) return null;
    return switch (result.winner) {
      SeatId.ivory => GameResult.whiteWins,
      SeatId.charcoal => GameResult.blackWins,
      _ => GameResult.draw,
    };
  }
}
