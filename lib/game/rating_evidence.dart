import 'match_config.dart';
import 'match_controller.dart';
import 'match_rules.dart';
import 'match_state.dart';
import 'rating_pool.dart';
import 'match_standings.dart';

/// Local replay is an honesty check, not remote attestation of client code.
class RatingEvidence {
  RatingEvidence._(this.game, this.humans, this.winner);
  final MatchState game;
  final List<String> humans;
  final int winner;
  String get pool => RatingPool.forConfig(game.config).id;
  static const engine = 'shared-search-v1';

  MatchStandings get standings => MatchStandings.forGame(game)!;
  List<String> get participants => [
        for (final seat in game.config.seats)
          seat.control == SeatControl.ai
              ? 'ai_${game.config.aiEngine}_${seat.level.name}'
              : humans[game.config.seats
                  .where((s) => s.control != SeatControl.ai)
                  .toList()
                  .indexOf(seat)]
      ];
  List<int> get ranks =>
      [for (final seat in game.config.ids) standings.ranks[seat]!];

  static RatingEvidence? verify(
      MatchSession session, List<Map<String, dynamic>> moves, String uid) {
    if (session.game?.config.ratingVersion == 1) {
      return _verifyLegacy(session, moves, uid);
    }
    final game = session.game;
    if (session.id == null ||
        game == null ||
        !game.finished ||
        game.config.court ||
        game.config.profile == RulesProfile.legacyHex ||
        game.result!.reason == ResultReason.abandoned ||
        game.ply > 4096 ||
        moves.length != game.ply ||
        moves.length < game.config.seats.length) {
      return null;
    }
    try {
      var replay = MatchState.initial(game.config);
      for (final record in moves) {
        if (replay.finished || record['seat'] != replay.current.name) {
          return null;
        }
        final next = MatchRules.play(replay, MatchMove.fromMap(record));
        if (next == null) return null;
        replay = next;
      }
      if (!same(
              replay.board.map((cell, stack) => MapEntry('$cell',
                  stack.map((s) => '${s.seat.name}:${s.type.name}').toList())),
              game.board.map((cell, stack) => MapEntry(
                  '$cell',
                  stack
                      .map((s) => '${s.seat.name}:${s.type.name}')
                      .toList()))) ||
          game.config.ids.any((id) =>
              replay.reserves[id]!.stones != game.reserves[id]!.stones ||
              replay.reserves[id]!.caps != game.reserves[id]!.caps)) {
        return null;
      }
      final room = session.room;
      final humanSeats =
          game.config.seats.where((s) => s.control != SeatControl.ai).toList();
      List<String> humans;
      if (room != null) {
        if (session.id != room.code ||
            session.uid != uid ||
            !room.ready ||
            !same(room.config.toMap(), game.config.toMap()) ||
            !same(moves, room.moves)) {
          return null;
        }
        final owners = humanSeats.map((seat) => room.owners[seat.id]).toList();
        if (owners.contains(null) ||
            owners.toSet().length != owners.length ||
            !owners.contains(uid)) {
          return null;
        }
        humans = owners.cast<String>();
        replay = room.replay();
      } else {
        if (game.config.online ||
            humanSeats.length > 1 ||
            (humanSeats.isEmpty && game.config.ratingVersion < 3) ||
            session.uid != uid) {
          return null;
        }
        humans = humanSeats.isEmpty ? [] : [uid];
        if (!replay.finished) {
          if (game.config.seats.length != 2 ||
              ![ResultReason.resignation, ResultReason.time]
                  .contains(game.result!.reason) ||
              game.result!.winner == null) {
            return null;
          }
          replay = replay.copyWith(result: game.result);
        }
      }
      if (replay.result?.winner != game.result!.winner ||
          replay.result?.reason != game.result!.reason ||
          MatchStandings.forGame(game) == null) {
        return null;
      }
      return RatingEvidence._(
          game,
          humans,
          game.result!.winner == null
              ? -1
              : game.config.ids.indexOf(game.result!.winner!));
    } on Object {
      return null;
    }
  }

  static RatingEvidence? _verifyLegacy(
      MatchSession session, List<Map<String, dynamic>> moves, String uid) {
    final game = session.game;
    if (session.id == null ||
        game == null ||
        !game.finished ||
        game.config.court ||
        game.config.profile == RulesProfile.legacyHex ||
        game.result!.reason == ResultReason.abandoned ||
        moves.length != game.ply ||
        moves.length < game.config.seats.length) {
      return null;
    }
    var replay = MatchState.initial(game.config);
    try {
      for (final record in moves) {
        if (record['seat'] != replay.current.name || replay.finished) {
          return null;
        }
        final next = MatchRules.play(replay, MatchMove.fromMap(record));
        if (next == null) return null;
        replay = next;
      }
    } on Object {
      return null;
    }
    final room = session.room;
    if (room != null) {
      if (!same(moves, room.moves) || !room.owners.values.contains(uid)) {
        return null;
      }
      final result = room.replay().result;
      if (result?.winner != game.result!.winner ||
          result?.reason != game.result!.reason) {
        return null;
      }
    } else if (game.config.online ||
        replay.result?.winner != game.result!.winner ||
        replay.result?.reason != game.result!.reason) {
      return null;
    }
    final ai =
        game.config.seats.where((s) => s.control == SeatControl.ai).toList();
    if (ai.isNotEmpty) {
      // Community estimates use natural, untimed duels, never concessions/Court.
      if (game.config.seats.length != 2 ||
          ai.length != 1 ||
          game.config.clockSeconds != 0 ||
          replay.result == null) {
        return null;
      }
      final human =
          game.config.seats.firstWhere((s) => s.control != SeatControl.ai);
      if (room != null && room.owners[human.id] != uid) return null;
      return RatingEvidence._(
          game,
          [uid],
          game.result!.winner == null
              ? -1
              : game.result!.winner == ai.single.id
                  ? 1
                  : 0);
    }
    if (room == null || !room.ready) return null;
    final humans = game.config.ids.map((id) => room.owners[id]).toList();
    if (humans.contains(null) || humans.toSet().length != humans.length) {
      return null;
    }
    return RatingEvidence._(
        game,
        humans.cast<String>(),
        game.result!.winner == null
            ? -1
            : game.config.ids.indexOf(game.result!.winner!));
  }

  static bool same(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((key) => b.containsKey(key) && same(a[key], b[key]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => same(a[i], b[i]));
    }
    return a == b;
  }
}
