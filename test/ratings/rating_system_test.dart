import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/services/account_service.dart';
import 'package:stones/services/sound_manager.dart';
import 'package:stones/screens/main_menu_screen.dart';
import '../support/fake_account_service.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
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
  int standing = 2;
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
  Future<int> rank(String pool, int rating) async => standing;
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
  Future<String> submitResult(MatchSession session,
          List<Map<String, dynamic>> moves) async => 'practice';

}

class QuietRatingSound extends SoundManager {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> setMuted(bool muted) async {}
}
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('a stalled leaderboard reaches a visible bounded failure', () async {
    final repo = FakeRatings()..pending = Completer<List<EloRating>>();
    final controller = EloController(repo,
        requestTimeout: const Duration(milliseconds: 1));
    await controller.fetchLeaderboard();
    expect(controller.state.loading, isFalse);
    expect(controller.state.errorMessage, isNotNull);
    expect(controller.state.personalLabel, 'Rating unavailable');
    repo.pending!.complete([]);
    controller.dispose();
  });
  test('refresh updates standing even when the personal rating is unchanged', () async {
    final repo = FakeRatings();
    final controller = EloController(repo)..bind('alice', guest: false);
    repo.streams['alice']!.add(const EloRating(
        id: 'alice', displayName: 'Alice', gamesPlayed: 10, wins: 10));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.rank, 2);
    repo.standing = 7;
    await controller.fetchLeaderboard();
    expect(controller.state.rank, 7);
    controller.dispose();
  });
  for (final brightness in Brightness.values) {
    testWidgets('signed-in menu stays usable on phone at 200% text $brightness', (tester) async {
      tester.view.physicalSize = const Size(320,700); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeAccount()..current = const AccountIdentity(uid:'alice',guest:false,name:'A player with a very long name');
      final account = AccountController(service,hasActiveRoom:()=>false);
      await account.initialize();
      final repo = FakeRatings(); final ratings = EloController(repo)..bind('alice',guest:false);
      repo.streams['alice']!.add(const EloRating(id:'alice',displayName:'Alice',gamesPlayed:10,wins:10));
      await tester.pumpWidget(ProviderScope(overrides:[eloProvider.overrideWith((ref)=>ratings),
        accountProvider.overrideWith((ref)=>account), soundManagerProvider.overrideWithValue(QuietRatingSound())],
        child:MaterialApp(theme:ThemeData(brightness:brightness),builder:(context,child)=>MediaQuery(
          data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(2)),child:child!),
          home:const MainMenuScreen())));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      expect(find.byTooltip('Leaderboard'),findsOneWidget);
    });
  }

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
        for (var i = 0; i < 15; i++) {
          final title = find.text('Rating History');
          if (title.evaluate().isNotEmpty &&
              tester.getCenter(title).dy < size.height - 100) {
            break;
          }
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
