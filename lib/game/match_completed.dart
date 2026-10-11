import 'match_config.dart';
import 'match_controller.dart';
import 'match_state.dart';

/// Result attribution is independent of rendering and room replay frequency.
class MatchCompleted {
  MatchCompleted(MatchSession session)
      : id =
            '${session.id}:${session.game!.ply}:${session.game!.result!.reason.name}',
        game = session.game!,
        uid = session.uid,
        owners = session.room?.owners,
        host = session.room?.host;
  final String id;
  final MatchState game;
  final String? uid;
  final String? host;
  final Map<SeatId, String?>? owners;
  bool get online => owners != null;
  bool get eligibleWin {
    final winner = game.result?.winner;
    if (winner == null ||
        game.config.court ||
        game.config.seat(winner).control == SeatControl.ai) {
      return false;
    }
    if (online) {
      if (owners![winner] != uid) return false;
      if (uid == host) {
        // Shared-device guests do not award the host account a personal win.
        final primary = game.config.seats
            .where((s) => s.control == SeatControl.localHuman)
            .firstOrNull;
        if (primary?.id != winner) return false;
      }
      return true;
    }
    // Pass-and-play has no individual account ownership. Award only unassisted
    // single-human play against AI, never observer or shared-device results.
    return game.config.seats
            .where((s) => s.control == SeatControl.localHuman)
            .length ==
        1;
  }
}
