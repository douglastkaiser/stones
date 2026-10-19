import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_standings.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/placement_elo.dart';
import 'package:stones/game/rating_submission.dart';
import 'package:stones/game/result_share_data.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/services/result_share_service.dart';

MatchState position(
    {int players = 3,
    SeatId? winner = SeatId.ivory,
    ResultReason reason = ResultReason.road,
    List<int> flats = const [1, 3, 2, 2]}) {
  final config =
      MatchConfig(ratingVersion: 2, shape: BoardShape.square, size: 5, seats: [
    for (var i = 0; i < players; i++)
      SeatConfig(SeatId.values[i],
          control: i == 2 ? SeatControl.ai : SeatControl.localHuman,
          level: BotLevel.expert)
  ]);
  return MatchState(
      config: config,
      ply: 38,
      result: MatchResult(winner, reason),
      board: {
        for (var i = 0; i < players; i++)
          for (var x = 0; x < flats[i]; x++)
            Cell(x, i): [Stone(SeatId.values[i], PieceType.flat)]
      },
      reserves: {
        for (final id in config.ids) id: Reserve.initial(config)
      });
}

void main() {
  test('road winner is first even with fewer flats; lower ties skip ranks', () {
    final standings = MatchStandings.forGame(position(players: 4))!;
    expect(standings.ranks, {
      SeatId.ivory: 1,
      SeatId.charcoal: 2,
      SeatId.copper: 3,
      SeatId.jade: 3
    });
    expect(standings.score(SeatId.charcoal, SeatId.ivory), 0);
    expect(standings.score(SeatId.charcoal, SeatId.copper), 1);
    expect(standings.score(SeatId.copper, SeatId.jade), .5);
  });
  test('flat draws rank all tied leaders ahead of the remaining players', () {
    final standings = MatchStandings.forGame(position(
        players: 4,
        winner: null,
        reason: ResultReason.flats,
        flats: [1, 3, 3, 0]))!;
    expect(standings.ranks, {
      SeatId.ivory: 3,
      SeatId.charcoal: 1,
      SeatId.copper: 1,
      SeatId.jade: 4
    });
  });
  test('abandonment has no placements', () {
    expect(
        MatchStandings.forGame(
            position(winner: null, reason: ResultReason.abandoned)),
        isNull);
  });
  test('mixed outcome names every opponent and includes exact signed Elo', () {
    final game = position();
    final data = ResultShareData(MatchSession(game: game),
        names: {SeatId.ivory: 'Alex'},
        viewer: SeatId.charcoal,
        rating: const RatingSubmission(
            RatingSubmissionState.confirmed, 'Rating recorded',
            deltas: {SeatId.charcoal: RatingDelta(1200, 1206)}));
    expect(data.outcome, 'Lost to Alex · Beat Expert AI');
    expect(data.text, contains('2nd of 3'));
    expect(data.text, contains('38 moves'));
    expect(data.text, contains('Elo +6'));
    expect(data.text.split('\n'), hasLength(3));
    expect(data.text, endsWith(stonesPlayUrl));
  });
  test('winner groups multiple names and absent profiles use seat labels', () {
    final data = ResultShareData(MatchSession(game: position(players: 4)),
        names: {SeatId.charcoal: 'Alex', SeatId.jade: 'Karen'},
        viewer: SeatId.ivory,
        rating: const RatingSubmission.pending());
    expect(data.outcome, 'Beat Alex, Expert AI and Karen');
    expect(data.text, contains('Elo pending'));
    final fallback = ResultShareData(data.session,
        names: {},
        viewer: SeatId.ivory,
        rating: const RatingSubmission.unrated());
    expect(fallback.text, contains('Charcoal'));
    expect(fallback.text, contains('Unrated'));
  });
  test('equal placements share as tied, without claiming a win', () {
    final data = ResultShareData(MatchSession(game: position(players: 4)),
        names: {SeatId.ivory: 'Alex', SeatId.charcoal: 'Karen'},
        viewer: SeatId.jade,
        rating: const RatingSubmission.unrated());
    expect(data.outcome, 'Lost to Alex and Karen · Tied with Expert AI');
    expect(data.placement, 'Tied 3rd of 4');
  });
  test('Elo includes zero and negative deltas; failures remain pending', () {
    expect(const RatingDelta(1200, 1200).label, '±0');
    expect(const RatingDelta(1200, 1180).label, '-20');
    expect(
        const RatingSubmission.failed().labelFor(SeatId.ivory), 'Elo pending');
  });
  test('SMS body preserves newlines, Unicode, ampersands and URL', () {
    const text = 'Beat Alex & 👑\nElo +6\n$stonesPlayUrl';
    final uri = resultSmsUri(text);
    expect(uri.scheme, 'sms');
    expect(uri.queryParameters['body'], text);
    expect(resultSmsUri(text, ios: true).toString(), startsWith('sms:&body='));
  });
  test('placement Elo averages comparisons and treats AI identities equally',
      () {
    final values = PlacementElo.calculate(
        participants: ['alice', 'bot', 'bob'],
        ranks: [1, 2, 3],
        ratings: {'alice': 1200, 'bot': 1200, 'bob': 1200},
        gamesPlayed: {'alice': 0, 'bot': 0, 'bob': 0});
    expect(values, {'alice': 1220, 'bot': 1200, 'bob': 1180});
  });
  test('same AI in two seats receives one averaged rating update', () {
    final values = PlacementElo.calculate(
        participants: ['alice', 'bot', 'bot', 'bob'],
        ranks: [1, 2, 3, 4],
        ratings: {'alice': 1200, 'bot': 1200, 'bob': 1200},
        gamesPlayed: {'alice': 0, 'bot': 0, 'bob': 0});
    expect(values, {'alice': 1220, 'bot': 1200, 'bob': 1180});
  });
  test('equal placement is a draw, still adjusted for expected strength', () {
    final values = PlacementElo.calculate(
        participants: ['alice', 'bot'],
        ranks: [1, 1],
        ratings: {'alice': 1600, 'bot': 1200},
        gamesPlayed: {'alice': 30, 'bot': 30});
    expect(values['alice'], lessThan(1600));
    expect(values['bot'], greaterThan(1200));
  });
}
