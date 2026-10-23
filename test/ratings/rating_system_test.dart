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
import 'package:stones/game/rating_submission.dart';
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
  List<EloRating> botValues = [];
  @override
  Stream<EloRating?> watchPlayer(String pool, String uid) =>
      (streams[uid] ??= StreamController<EloRating?>.broadcast()).stream;
  @override
  Future<List<EloRating>> leaders(String pool) async {
    if (fail) throw StateError('offline');
    return pending != null ? await pending!.future : values;
  }

  @override
  Future<List<EloRating>> bots(String pool) async => botValues;
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
  Future<RatingSubmission> submitResult(
          MatchSession session, List<Map<String, dynamic>> moves) async =>
      const RatingSubmission.unrated('practice');
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
    final controller =
        EloController(repo, requestTimeout: const Duration(milliseconds: 1));
    await controller.fetchLeaderboard();
    expect(controller.state.loading, isFalse);
    expect(controller.state.errorMessage, isNotNull);
    expect(controller.state.personalLabel, 'Rating unavailable');
    repo.pending!.complete([]);
    controller.dispose();
  });
  test('refresh updates standing even when the personal rating is unchanged',
      () async {
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
    testWidgets('signed-in menu stays usable on phone at 200% text $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeAccount()
        ..current = const AccountIdentity(
            uid: 'alice', guest: false, name: 'A player with a very long name');
      final account = AccountController(service, hasActiveRoom: () => false);
      await account.initialize();
      final repo = FakeRatings();
      final ratings = EloController(repo)..bind('alice', guest: false);
      repo.streams['alice']!.add(const EloRating(
          id: 'alice', displayName: 'Alice', gamesPlayed: 10, wins: 10));
      await tester.pumpWidget(ProviderScope(
          overrides: [
            eloProvider.overrideWith((ref) => ratings),
            accountProvider.overrideWith((ref) => account),
            soundManagerProvider.overrideWithValue(QuietRatingSound())
          ],
          child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: const MainMenuScreen())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Leaderboard'), findsOneWidget);
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
  test('human and AI ratings share neutral priors and provisional policy', () {
    const unrated = EloRating(id: 'a', displayName: 'Alice');
    expect(unrated.ratingLabel, 'Unrated');
    expect(unrated.copyWith(gamesPlayed: 1).ratingLabel, '1200?');
    const bot = EloRating(id: 'bot', displayName: 'Bot', isAi: true);
    expect(bot.ratingLabel, 'Unrated');
    expect(bot.copyWith(gamesPlayed: 30).calibrated, isTrue);
    const calibrated = EloRating(
        id: 'bot',
        displayName: 'Bot',
        isAi: true,
        gamesPlayed: 30,
        opponents: 10);
    expect(calibrated.calibrated, isTrue);
    expect(EloRating.fromMap('bot', calibrated.toMap()).opponents, 10);
  });
  test('human ranks skip AI and provisional players and preserve ties', () {
    const players = [
      EloRating(id: 'new', displayName: 'New', rating: 2200),
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
  testWidgets('AI outside the top 50 stays visible without a human rank',
      (tester) async {
    final repo = FakeRatings()
      ..standing = 87
      ..values = List.generate(
          50,
          (i) => EloRating(
              id: 'human-$i',
              displayName: 'Human $i',
              rating: 2000 - i,
              gamesPlayed: 10))
      ..botValues = [
        const EloRating(
            id: 'ai_shared-search-v2_expert',
            displayName: 'Expert AI',
            rating: 1400,
            gamesPlayed: 40,
            isAi: true,
            aiDifficulty: 'expert')
      ];
    final controller = EloController(repo);
    await tester.pumpWidget(ProviderScope(overrides: [
      ratingRepositoryProvider.overrideWithValue(repo),
      eloProvider.overrideWith((ref) => controller),
    ], child: const MaterialApp(home: LeaderboardScreen())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('AI'));
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Expert AI'));
    expect(find.textContaining(RegExp(r'^#')), findsNothing);
    await tester.tap(find.text('Expert AI'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerDetailScreen), findsOneWidget);
    expect(find.textContaining('Rank #'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('home, leaderboard and own profile share the human rank',
      (tester) async {
    final accountService = FakeAccount()
      ..current =
          const AccountIdentity(uid: 'alice', guest: false, name: 'Alice');
    final account =
        AccountController(accountService, hasActiveRoom: () => false);
    await account.initialize();
    const alice = EloRating(
        id: 'alice',
        displayName: 'Alice',
        pool: 'overall',
        rating: 1500,
        gamesPlayed: 20);
    final repo = FakeRatings()
      ..standing = 1
      ..values = [
        const EloRating(
            id: 'ai_shared-search-v2_expert',
            displayName: 'Expert AI',
            pool: 'overall',
            rating: 2000,
            gamesPlayed: 40,
            isAi: true),
        alice,
      ];
    final controller = EloController(repo)..bind('alice', guest: false);
    repo.streams['alice']!.add(alice);
    await tester.pumpWidget(ProviderScope(overrides: [
      accountProvider.overrideWith((ref) => account),
      ratingRepositoryProvider.overrideWithValue(repo),
      eloProvider.overrideWith((ref) => controller),
      soundManagerProvider.overrideWithValue(QuietRatingSound()),
    ], child: const MaterialApp(home: MainMenuScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Overall · 1500 · #1'), findsOneWidget);
    await tester.tap(find.byTooltip('Leaderboard'));
    await tester.pumpAndSettle();
    expect(find.text('1500 · Rank #1'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsNothing);
    await tester.tap(find.text('Your standing'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerDetailScreen), findsOneWidget);
    expect(
        tester
            .widget<PlayerDetailScreen>(find.byType(PlayerDetailScreen))
            .player
            .id,
        'alice');
    expect(find.text('Rank #1'), findsOneWidget);
    final personalProfile = tester.widget<PlayerDetailScreen>(
      find.byType(PlayerDetailScreen),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Alice (You)'));
    await tester.tap(find.text('Alice (You)'));
    await tester.pumpAndSettle();
    final rowProfile = tester.widget<PlayerDetailScreen>(
      find.byType(PlayerDetailScreen),
    );
    expect(rowProfile.player.id, personalProfile.player.id);
    expect(rowProfile.player.pool, personalProfile.player.pool);
    expect(find.text('Rank #1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interleaved AI preserve human numbers across filters', (
    tester,
  ) async {
    final repo = FakeRatings()
      ..values = const [
        EloRating(
          id: 'ai_shared-search-v2_expert',
          displayName: 'Expert AI',
          rating: 2000,
          gamesPlayed: 40,
          isAi: true,
        ),
        EloRating(id: 'a', displayName: 'Alice', rating: 1800, gamesPlayed: 20),
        EloRating(
          id: 'ai_shared-search-v2_hard',
          displayName: 'Hard AI',
          rating: 1700,
          gamesPlayed: 40,
          isAi: true,
        ),
        EloRating(id: 'b', displayName: 'Bob', rating: 1600, gamesPlayed: 20),
        EloRating(id: 'c', displayName: 'Carol', rating: 1600, gamesPlayed: 20),
        EloRating(id: 'new', displayName: 'New', rating: 1500, gamesPlayed: 1),
        EloRating(id: 'd', displayName: 'Dana', rating: 1400, gamesPlayed: 20),
      ];
    final controller = EloController(repo);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ratingRepositoryProvider.overrideWithValue(repo),
          eloProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: LeaderboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    Finder card(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(Card));
    void expectHumanRanks() {
      for (final entry in {
        'Alice': 1,
        'Bob': 2,
        'Carol': 2,
        'Dana': 4,
      }.entries) {
        expect(
          find.descendant(
            of: card(entry.key),
            matching: find.text('#${entry.value}'),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: card('New'), matching: find.textContaining('#')),
        findsNothing,
      );
    }

    expectHumanRanks();
    for (final ai in ['Expert AI', 'Hard AI']) {
      expect(
        find.descendant(of: card(ai), matching: find.textContaining('#')),
        findsNothing,
      );
    }
    expect(
      tester.getTopLeft(card('Expert AI')).dy,
      lessThan(tester.getTopLeft(card('Alice')).dy),
    );
    expect(
      tester.getTopLeft(card('Alice')).dy,
      lessThan(tester.getTopLeft(card('Hard AI')).dy),
    );
    await tester.ensureVisible(find.text('Humans'));
    await tester.tap(find.text('Humans'));
    await tester.pumpAndSettle();
    expectHumanRanks();
    expect(find.text('Expert AI'), findsNothing);
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^#')), findsNothing);
    expect(find.text('Expert AI'), findsOneWidget);
    expect(find.text('Hard AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unrated standing opens own profile in the selected pool',
      (tester) async {
    final repo = FakeRatings();
    final controller = EloController(repo)
      ..bind('new-player', guest: false)
      ..selectPool(RatingPool.standard);
    await tester.pumpWidget(ProviderScope(overrides: [
      ratingRepositoryProvider.overrideWithValue(repo),
      eloProvider.overrideWith((ref) => controller),
    ], child: const MaterialApp(home: LeaderboardScreen())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Your standing'));
    await tester.tap(find.text('Your standing'));
    await tester.pumpAndSettle();
    final profile =
        tester.widget<PlayerDetailScreen>(find.byType(PlayerDetailScreen));
    expect(profile.player.id, 'new-player');
    expect(profile.player.pool, RatingPool.standard.id);
    expect(find.text('Unrated'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

        await reveal(find.text('AI'));
        await tester.tap(find.text('AI'));
        await tester.pumpAndSettle();
        await reveal(find.text('Easy AI'));
        expect(find.text('Unrated'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
