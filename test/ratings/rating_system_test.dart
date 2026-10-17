import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/rating_pool.dart';
import 'package:stones/models/elo_rating.dart';
import 'package:stones/providers/elo_provider.dart';
import 'package:stones/screens/leaderboard_screen.dart';
import 'package:stones/screens/player_detail_screen.dart';
import 'package:stones/services/rating_repository.dart';

class FakeRatings implements RatingRepository {
  final streams = <String, StreamController<EloRating?>>{};
  Completer<List<EloRating>>? pending;
  bool fail = false;
  List<EloRating> values = [];
  @override
  Stream<EloRating?> watchPlayer(String pool, String uid) =>
      (streams[uid] ??= StreamController<EloRating?>.broadcast()).stream;
  @override
  Future<List<EloRating>> leaders(String pool) async {
    if (fail) throw StateError('offline');
    return pending != null ? await pending!.future : values;
  }

  @override
  Future<List<EloRating>> bots(String pool) async => [];
  @override
  Future<int> rank(String pool, int rating) async => 2;
  @override
  Future<List<EloHistoryEntry>> history(String pool, String uid) async => [
        EloHistoryEntry(
            rating: 1200,
            timestamp: DateTime(2026, 10),
            score: 1,
            opponentName: 'A rival'),
        EloHistoryEntry(
            rating: 1220,
            timestamp: DateTime(2026, 10, 2),
            score: 1,
            opponentName: 'Another rival'),
      ];
  @override
  Future<MatchMove?> botMove(String id, MatchConfig config,
          List<Map<String, dynamic>> moves) async =>
      null;
  @override
  Future<String> completeCalibration(String id, MatchConfig config,
          List<Map<String, dynamic>> moves) async =>
      'practice';
}

void main() {
  test(
      'all configuration pools are distinct, clock and standard rules separated',
      () {
    final ids = RatingPool.all.map((p) => p.id).toSet();
    expect(ids.length, 81);
    expect(RatingPool.standard.id, 'square-5-2-standardTak-open');
    final config = MatchConfig.defaults(BoardShape.square);
    expect(
        RatingPool.forConfig(config.copyWith(clockSeconds: 300)).clock, 'fast');
    expect(
        RatingPool.forConfig(config.copyWith(clockSeconds: 600)).clock, 'long');
    expect(RatingPool.forConfig(config.addPlayer()).profile,
        RulesProfile.sharedRoads);
  });
  test(
      'neutral priors remain hidden; provisional and AI calibration are honest',
      () {
    const unrated = EloRating(id: 'a', displayName: 'Alice');
    expect(unrated.ratingLabel, 'Unrated');
    expect(unrated.copyWith(gamesPlayed: 1).ratingLabel, '1200?');
    const bot = EloRating(id: 'bot', displayName: 'Bot', isAi: true);
    expect(bot.ratingLabel, 'Uncalibrated');
    expect(bot.copyWith(gamesPlayed: 30).calibrated, isFalse);
    const calibrated = EloRating(
        id: 'bot',
        displayName: 'Bot',
        isAi: true,
        gamesPlayed: 30,
        opponents: 10);
    expect(calibrated.calibrated, isTrue);
    expect(EloRating.fromMap('bot', calibrated.toMap()).opponents, 10);
  });
  test('equal established human scores share competition rank; bots excluded',
      () {
    const players = [
      EloRating(id: 'a', displayName: 'a', rating: 1500, gamesPlayed: 10),
      EloRating(id: 'b', displayName: 'b', rating: 1500, gamesPlayed: 10),
      EloRating(id: 'c', displayName: 'c', rating: 1400, gamesPlayed: 10),
      EloRating(
          id: 'bot',
          displayName: 'bot',
          rating: 2000,
          isAi: true,
          gamesPlayed: 100)
    ];
    expect(competitionRank(1500, players), 1);
    expect(competitionRank(1400, players), 3);
  });
  test('invalid scores and counters rejected by calculator', () {
    expect(
        () => EloCalculator.calculateNewRatings(
            ratingA: 1200,
            ratingB: 1200,
            gamesPlayedA: 0,
            gamesPlayedB: 0,
            actualScoreA: 0.7),
        throwsArgumentError);
    expect(
        EloCalculator.calculateNewRatings(
            ratingA: 1200,
            ratingB: 1200,
            gamesPlayedA: 0,
            gamesPlayedB: 0,
            actualScoreA: 1),
        (1220, 1180));
  });
  test('sign out clears identity and late leaderboard cannot repaint it',
      () async {
    final repo = FakeRatings();
    final controller = EloController(repo);
    controller.bind('alice', guest: false);
    repo.streams['alice']!.add(
        const EloRating(id: 'alice', displayName: 'Alice', gamesPlayed: 10));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.localPlayerRating?.id, 'alice');
    repo.pending = Completer();
    final refresh = controller.fetchLeaderboard();
    await Future<void>.delayed(Duration.zero);
    controller.bind(null, guest: true);
    repo.pending!.complete([const EloRating(id: 'old', displayName: 'Old')]);
    await refresh;
    expect(controller.state.uid, isNull);
    expect(controller.state.localPlayerRating, isNull);
    expect(controller.state.leaderboard, isEmpty);
    controller.dispose();
  });
  test(
      'account switch replaces identity, ignores old stream, has no device-wide cached rank',
      () async {
    final repo = FakeRatings();
    final controller = EloController(repo);
    controller.bind('alice', guest: false);
    controller.bind('bob', guest: false);
    repo.streams['alice']!
        .add(const EloRating(id: 'alice', displayName: 'Alice'));
    repo.streams['bob']!.add(const EloRating(id: 'bob', displayName: 'Bob'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.localPlayerRating?.id, 'bob');
    controller.dispose();
  });
  test('network failure stays visible and never invents AI ratings', () async {
    final repo = FakeRatings()..fail = true;
    final controller = EloController(repo);
    await controller.fetchLeaderboard();
    expect(controller.state.errorMessage, isNotNull);
    expect(controller.state.aiRatings, isEmpty);
    expect(controller.state.loading, isFalse);
    repo.fail = false;
    await controller.fetchLeaderboard();
    expect(controller.state.errorMessage, isNull);
    controller.dispose();
  });
  for (final size in [const Size(320, 700), const Size(1366, 900)]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'rating profile and history fit $size $brightness at 200% text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakeRatings();
        final controller = EloController(repo);
        await tester.pumpWidget(ProviderScope(
            overrides: [
              eloProvider.overrideWith((ref) => controller),
              ratingRepositoryProvider.overrideWithValue(repo)
            ],
            child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!),
                home: const PlayerDetailScreen(
                    player: EloRating(
                        id: 'alice',
                        displayName: 'A player with a long display name',
                        gamesPlayed: 10,
                        wins: 10)))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var i = 0;
            i < 10 &&
                tester.getCenter(find.text('Rating History')).dy >
                    size.height - 100;
            i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -200));
          await tester.pumpAndSettle();
        }
        expect(find.text('Rating History'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
      testWidgets('competition fits $size $brightness at 200% text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakeRatings();
        final controller = EloController(repo);
        await tester.pumpWidget(ProviderScope(
            overrides: [eloProvider.overrideWith((ref) => controller)],
            child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!),
                home: const LeaderboardScreen())));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        Future<void> reveal(Finder finder) async {
          for (var i = 0; i < 20; i++) {
            final y = tester.getCenter(finder).dy;
            if (y > 100 && y < size.height - 80) {
              return;
            }
            await tester.drag(find.byType(ListView),
                Offset(0, y > size.height - 80 ? -250 : 250));
            await tester.pumpAndSettle();
          }
        }

        await reveal(find.text('AI benchmarks'));
        await tester.tap(find.text('AI benchmarks'));
        await tester.pumpAndSettle();
        await reveal(find.text('Easy AI'));
        expect(find.text('Uncalibrated'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
