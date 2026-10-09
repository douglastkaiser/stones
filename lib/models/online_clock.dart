import 'online_game.dart';
import 'piece.dart';

/// Recover honest-client clocks from durable move balances and the server's
/// last-move timestamp. Time keeps passing while a browser is closed.
class OnlineClockBalance {
  const OnlineClockBalance(this.white, this.black);
  final int white;
  final int black;

  static OnlineClockBalance at(OnlineGameSession session, DateTime now) {
    final initial = session.chessClockSeconds ?? 300;
    var white = initial;
    var black = initial;
    for (var i = 0; i < session.moves.length; i++) {
      final move = session.moves[i];
      if (move.whiteSeconds != null && move.blackSeconds != null) {
        white = move.whiteSeconds!;
        black = move.blackSeconds!;
      } else if (i > 0) {
        // Legacy rooms only have client move timestamps, so these balances are
        // approximate. New moves checkpoint both balances for future recovery.
        final before = session.moves[i - 1].timestamp;
        final after = move.timestamp;
        if (before != null && after != null) {
          final elapsed = after.difference(before).inSeconds.clamp(0, 86400);
          if (move.player == PlayerColor.white) {
            white -= elapsed;
          } else {
            black -= elapsed;
          }
        }
      }
    }
    if (session.status == OnlineStatus.playing &&
        session.moves.isNotEmpty &&
        session.lastMoveAt != null) {
      final elapsed =
          now.difference(session.lastMoveAt!).inSeconds.clamp(0, 86400);
      if (session.currentTurn == PlayerColor.white) {
        white -= elapsed;
      } else {
        black -= elapsed;
      }
    }
    return OnlineClockBalance(white.clamp(0, initial), black.clamp(0, initial));
  }
}
