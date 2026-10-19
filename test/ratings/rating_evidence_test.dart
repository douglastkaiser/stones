import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/rating_evidence.dart';
import 'package:stones/models/piece.dart';
import '../fixtures/achievement_matches.dart';
import '../game/match_controller_test.dart' show MemoryMatchStorage;

void main() {
  MatchConfig config(
          {bool online = false, bool court = false, int clock = 0}) =>
      MatchConfig(
          shape: BoardShape.square,
          size: 3,
          court: court,
          clockSeconds: clock,
          seats: [
            const SeatConfig(SeatId.ivory),
            SeatConfig(SeatId.charcoal,
                control: online ? SeatControl.onlineHuman : SeatControl.ai)
          ]);
  (MatchState, List<Map<String, dynamic>>) finish(MatchConfig c) {
    var game = MatchState.initial(c);
    final moves = <Map<String, dynamic>>[];
    for (final cell in [
      const Cell(2, 2),
      const Cell(0, 0),
      const Cell(0, 1),
      const Cell(2, 1),
      const Cell(0, 2)
    ]) {
      final move = MatchMove.place(cell, PieceType.flat);
      moves.add(move.toMap(game.current));
      game = MatchRules.play(game, move)!;
    }
    expect(game.result!.winner, SeatId.ivory);
    return (game, moves);
  }

  test('local AI evidence is replayed without network or an assumed AI rating',
      () {
    final (game, moves) = finish(config());
    final evidence = RatingEvidence.verify(
        MatchSession(game: game, id: 'local-1', uid: 'alice'), moves, 'alice');
    expect(evidence!.winner, 0);
    expect(evidence.humans, ['alice']);
    expect(evidence.pool, 'square-3-2-standardTak-open');
    final forged = moves.map((m) => Map<String, dynamic>.from(m)).toList();
    forged[2]['x'] = 2;
    forged[2]['y'] = 2;
    expect(RatingEvidence.verify(MatchSession(game: game), forged, 'alice'),
        isNull);
    expect(
        RatingEvidence.verify(
            MatchSession(game: game), moves.sublist(1), 'alice'),
        isNull);
  });
  test('Court and fabricated terminal flags cannot produce ratings', () {
    for (final c in [config(court: true)]) {
      final (game, moves) = finish(c);
      expect(RatingEvidence.verify(MatchSession(game: game), moves, 'alice'),
          isNull);
    }
    final (game, moves) = finish(config());
    final forged = game.copyWith(
        result: const MatchResult(SeatId.charcoal, ResultReason.road));
    expect(RatingEvidence.verify(MatchSession(game: forged), moves, 'alice'),
        isNull);
    final extra = [...moves, moves.last];
    expect(
        RatingEvidence.verify(
            MatchSession(game: game.copyWith(ply: 6)), extra, 'alice'),
        isNull);
  });
  test('timed AI and multiplayer AI games contribute to the same rating system',
      () {
    final (game, moves) = finish(config(clock: 60));
    final evidence = RatingEvidence.verify(
        MatchSession(game: game, id: 'local-clock', uid: 'alice'),
        moves,
        'alice');
    expect(evidence!.participants, ['alice', 'ai_shared-search-v1_easy']);
    expect(evidence.ranks, [1, 2]);
    expect(
        RatingEvidence.verify(
            MatchSession(game: game, id: 'local-clock', uid: 'bob'),
            moves,
            'alice'),
        isNull);
  });
  test('independent human seats must own the same replayed room and outcome',
      () {
    final c = config(online: true);
    final (game, moves) = finish(c);
    final room = MatchRoom(
        code: 'UAAAAAA',
        host: 'alice',
        config: c,
        owners: {SeatId.ivory: 'alice', SeatId.charcoal: 'bob'},
        moves: moves);
    final session =
        MatchSession(game: game, room: room, id: room.code, uid: 'bob');
    expect(
        RatingEvidence.verify(session, moves, 'bob')!.humans, ['alice', 'bob']);
    expect(RatingEvidence.verify(session, moves, 'stranger'), isNull);
    expect(
        RatingEvidence.verify(session, moves.reversed.toList(), 'bob'), isNull);
    final bad = MatchSession(
        game:
            game.copyWith(result: const MatchResult(null, ResultReason.flats)),
        room: room);
    expect(RatingEvidence.verify(bad, moves, 'bob'), isNull);
  });
  for (final count in [3, 4]) {
    test('$count-seat legal AI history attributes every global opponent', () {
      final event = roadMatch(count: count);
      final evidence = RatingEvidence.verify(
          MatchSession(game: event.game, id: 'local-$count', uid: 'alice'),
          event.moves,
          'alice');
      expect(evidence, isNotNull);
      expect(evidence!.participants,
          ['alice', ...List.filled(count - 1, 'ai_shared-search-v1_hard')]);
      expect(evidence.ranks.first, 1);
    });
  }
  test('a replayed mixed online match binds each human and AI seat', () {
    final event = roadMatch(count: 3);
    final mixed = event.game.config.copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman),
      SeatConfig(SeatId.copper, control: SeatControl.ai, level: BotLevel.hard),
    ]);
    var game = MatchState.initial(mixed);
    for (final record in event.moves) {
      game = MatchRules.play(game, MatchMove.fromMap(record))!;
    }
    final room = MatchRoom(
        code: 'UAAAAAA',
        host: 'alice',
        config: mixed,
        owners: {
          SeatId.ivory: 'alice',
          SeatId.charcoal: 'bob',
          SeatId.copper: null
        },
        moves: event.moves);
    final session =
        MatchSession(game: game, room: room, id: room.code, uid: 'bob');
    final evidence = RatingEvidence.verify(session, event.moves, 'bob');
    expect(
        evidence!.participants, ['alice', 'bob', 'ai_shared-search-v1_hard']);
    final altered =
        game.copyWith(board: {...game.board}..remove(game.board.keys.first));
    expect(
        RatingEvidence.verify(
            MatchSession(game: altered, room: room, id: room.code, uid: 'bob'),
            event.moves,
            'bob'),
        isNull);
  });
  test(
      'local rating identity survives saving and resuming under another account',
      () async {
    final storage = MemoryMatchStorage();
    MatchController controller(String uid) => MatchController(
        storage: storage,
        authenticate: () async =>
            throw StateError('local play needs no authentication request'),
        store: () => throw StateError('local play needs no room'),
        ratingIdentity: () => uid,
        botDelay: const Duration(days: 1));
    final first = controller('alice');
    await first.start(config());
    await first.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    expect(storage.snapshot!['ratingUid'], 'alice');
    first.dispose();
    final second = controller('bob');
    expect(await second.resumeLocal(), isTrue);
    expect(second.state.uid, 'alice');
    second.dispose();
  });
  test('map field ordering is irrelevant but any changed record is detected',
      () {
    expect(
        RatingEvidence.same({
          'x': 1,
          'drops': [1, 2]
        }, {
          'drops': [1, 2],
          'x': 1
        }),
        isTrue);
    expect(
        RatingEvidence.same({
          'drops': [1, 2]
        }, {
          'drops': [2, 1]
        }),
        isFalse);
  });
}
