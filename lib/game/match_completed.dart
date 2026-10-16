import '../models/piece.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_controller.dart';
import 'match_state.dart';

/// Result attribution is independent of rendering and room replay frequency.
class MatchCompleted {
  MatchCompleted(MatchSession session,
      {this.moves = const []})
      : id =
            session.id ?? 'unattributed',
        game = session.game!,
        uid = session.uid,
        owners = session.room?.owners,
        host = session.room?.host;
  final String id;
  final List<Map<String, dynamic>> moves;
  final MatchState game;
  final String? uid;
  final String? host;
  final Map<SeatId, String?>? owners;
  bool get online => owners != null;

  /// Existing specialist unlocks describe standard, unassisted Square duels.
  /// Multiplayer variants contribute general wins without borrowing that label.
  BotLevel? get defeatedAILevel {
    if (!eligibleWin ||
        online ||
        game.config.profile != RulesProfile.standardTak ||
        game.config.shape != BoardShape.square ||
        game.config.seats.length != 2) {
      return null;
    }
    return game.config.seats
        .where((seat) => seat.control == SeatControl.ai)
        .firstOrNull
        ?.level;
  }

  SeatId? get participant {
    if (game.config.court) return null;
    final humans = game.config.seats.where((s) => s.control != SeatControl.ai);
    if (online) {
      if (uid == null) return null;
      final owned = humans.where((s) => owners![s.id] == uid).toList();
      // An individual award requires an individually attributable seat.
      return owned.length == 1 ? owned.single.id : null;
    }
    return humans.length == 1 ? humans.single.id : null;
  }

  bool get eligibleWin => participant != null &&
      game.result?.winner == participant;

  bool get boardWin => game.result?.reason == ResultReason.road ||
      game.result?.reason == ResultReason.flats;

  bool get independentSeats {
    if (!online) return true;
    final humans = game.config.seats.where((s) => s.control != SeatControl.ai);
    final identities = humans.map((s) => owners![s.id]).toList();
    return !identities.contains(null) && identities.toSet().length == identities.length;
  }

  Set<String> get opponentIds => {
    if (online)
      for (final seat in game.config.seats)
        if (seat.control != SeatControl.ai && owners![seat.id] != null &&
            owners![seat.id] != uid) owners![seat.id]!
  };

  BotLevel? get oppositionLevel {
    final opponents = game.config.seats.where((s) => s.id != participant).toList();
    if (opponents.isEmpty || opponents.any((s) => s.control != SeatControl.ai)) return null;
    return opponents.map((s) => s.level).reduce((a, b) => a.index < b.index ? a : b);
  }

  bool get hardDuel => participant != null && !online &&
      game.config.profile == RulesProfile.standardTak &&
      game.config.size >= 5 && (oppositionLevel?.index ?? -1) >= BotLevel.hard.index;

  /// Replay confirmed history once at completion. No statistics come from a
  /// preview, study position, fabricated terminal flag or incomplete old save.
  Map<String, int>? verifiedMetrics() {
    if (id == 'unattributed' || participant == null || !independentSeats ||
        !game.finished || game.result?.reason == ResultReason.abandoned ||
        (game.config.shape == BoardShape.square && game.config.size < 5) ||
        moves.length != game.ply || moves.isEmpty) return null;
    var replay = MatchState.initial(game.config);
    MatchState? beforeLast;
    MatchMove? lastMove;
    for (final record in moves) {
      if (record['seat'] != replay.current.name) return null;
      final move = MatchMove.fromMap(record);
      beforeLast = replay;
      lastMove = move;
      final next = MatchRules.play(replay, move);
      if (next == null) return null;
      replay = next;
    }
    if (replay.ply != game.ply || replay.board.length != game.board.length ||
        replay.reserves.entries.any((e) => e.value.stones != game.reserves[e.key]!.stones ||
            e.value.caps != game.reserves[e.key]!.caps) ||
        replay.board.entries.any((e) {
          final other = game.stackAt(e.key);
          return e.value.length != other.length ||
              List.generate(other.length, (i) => e.value[i] != other[i]).any((x) => x);
        }) || (boardWin && (replay.result?.winner != game.result?.winner ||
            replay.result?.reason != game.result?.reason))) return null;
    final wins = eligibleWin && (boardWin ||
        (online && game.ply >= game.config.seats.length * 4));
    final metrics = <String, int>{};
    if (hardDuel) metrics['streakResult'] = wins && boardWin ? 1 : -1;
    if (!wins) return metrics;
    metrics['wins'] = 1;
    if (online && opponentIds.isNotEmpty) metrics['onlineWins'] = 1;
    if (!boardWin) return metrics;
    final level = oppositionLevel;
    final hard = level != null && level.index >= BotLevel.hard.index;
    if (hard) {
      metrics[game.config.shape == BoardShape.square ? 'squareHardWins' : 'hexHardWins'] = 1;
      if (game.config.seats.length == 3) metrics['threeHardWins'] = 1;
      if (game.config.seats.length == 4) metrics['fourHardWins'] = 1;
      if (game.config.shape == BoardShape.square ? game.config.size >= 7 : game.config.size == 4) {
        metrics['largeHardWins'] = 1;
      }
    }
    final duel = defeatedAILevel;
    if (duel != null) {
      for (final difficulty in BotLevel.values.where((l) => l.index <= duel.index)) {
        metrics['${difficulty.name}Wins'] = 1;
      }
    }
    final craft = game.config.seats.where((s) => s.id != participant).every((s) =>
        s.control != SeatControl.ai || s.level.index >= BotLevel.medium.index);
    if (!craft) return metrics;
    if (game.config.clockSeconds > 0) metrics['timedWins'] = 1;
    if (game.result!.reason == ResultReason.flats) metrics['flatWins'] = 1;
    if (game.result!.reason == ResultReason.road) {
      metrics['roadWins'] = 1;
      final road = MatchRules.road(game, participant!);
      if (road.any((cell) => game.stackAt(cell).last.type == PieceType.capstone)) {
        metrics['capRoadWins'] = 1;
      }
      if (beforeLast!.current == participant && lastMove!.type == null) {
        if (lastMove.drops.length >= 3) metrics['spreadWins'] = 1;
        if (beforeLast.board.entries.any((e) =>
            e.value.last.type == PieceType.standing &&
            e.value.last.seat != participant && game.stackAt(e.key).length > e.value.length &&
            game.stackAt(e.key).last.seat == participant &&
            game.stackAt(e.key)[e.value.length - 1].type == PieceType.flat)) {
          metrics['crushingWins'] = 1;
        }
      }
    }
    return metrics;
  }
}
