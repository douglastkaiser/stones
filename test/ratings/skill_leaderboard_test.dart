import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/rating_pool.dart';
import 'package:stones/game/skill_rating.dart';
import 'package:stones/models/elo_rating.dart';
import 'package:stones/providers/elo_provider.dart';
import 'package:stones/screens/leaderboard_screen.dart';
import 'package:stones/screens/player_detail_screen.dart';
import 'package:stones/services/rating_repository.dart';
import 'rating_system_test.dart' show FakeRatings;

class LiveRatings extends FakeRatings implements LiveRatingRepository {
  final updates = <String, StreamController<List<EloRating>>>{};
  @override
  Stream<List<EloRating>> watchLeaders(String pool) =>
      (updates[pool] ??= StreamController<List<EloRating>>.broadcast()).stream;
  @override
  Future<List<EloHistoryEntry>> history(String pool, String uid) async => [
        EloHistoryEntry(
            rating: 1280,
            aiEngine: 'shared-search-v2',
            timestamp: DateTime(2026, 10),
            score: 1,
            skill: const SkillEstimate(mean: 1280, deviation: 200)),
        EloHistoryEntry(
            rating: 1300,
            aiEngine: 'shared-search-v3',
            timestamp: DateTime(2026, 10, 2),
            score: 1,
            skill: const SkillEstimate(mean: 1300, deviation: 100)),
      ];
  Future<void> close() async {
    for (final stream in updates.values) {
      await stream.close();
    }
  }
}

class RankRaceRatings extends LiveRatings {
  final rankRequests = <Completer<int>>[];
  @override
  Future<int> rank(String pool, int rating) {
    final request = Completer<int>();
    rankRequests.add(request);
    return request.future;
  }
}

void main() {
  const bot = EloRating(
      id: 'ai_shared-search-v2_easy',
      displayName: 'Easy AI',
      rating: 1300,
      gamesPlayed: 20,
      isAi: true,
      pool: 'overall',
      skill: SkillEstimate(mean: 1300, deviation: 100));

  test('late rank replies cannot overwrite newer live standings', () async {
    final repo = RankRaceRatings();
    final controller = EloController(repo);
    controller.bind('alice', guest: false);
    controller.startLive();
    repo.streams['alice']!.add(
        const EloRating(id: 'alice', displayName: 'Alice', gamesPlayed: 20));
    await Future<void>.delayed(Duration.zero);
    repo.updates['overall']!.add([bot]);
    await Future<void>.delayed(Duration.zero);
    repo.updates['overall']!.add([bot]);
    await Future<void>.delayed(Duration.zero);
    expect(repo.rankRequests, hasLength(3));
    repo.rankRequests[2].complete(3);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.rank, 3);
    repo.rankRequests[1].complete(8);
    repo.rankRequests[0].complete(12);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.rank, 3);
    controller.dispose();
    await repo.streams['alice']!.close();
    await repo.close();
  });

  test('initialization failure remains visible and retryable', () async {
    final repo = LiveRatings();
    final controller =
        EloController(repo, bootstrap: () async => throw StateError('offline'));
    await controller.fetchLeaderboard();
    expect(controller.state.errorMessage, contains('initialized'));
    expect(controller.state.leaderboard, isEmpty);
    controller.dispose();
    await repo.close();
  });

  test(
      'live overall ratings update without refresh and old scope events are ignored',
      () async {
    final repo = LiveRatings();
    final controller = EloController(repo);
    controller.startLive();
    expect(controller.state.selectedPool.isOverall, isTrue);
    repo.updates['overall']!.add([bot]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.aiRatings[bot.id]!.rating, 1300);
    controller.selectPool(RatingPool.standard);
    repo.updates['overall']!.add([bot.copyWith(rating: 1900)]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.aiRatings, isEmpty);
    repo.updates[RatingPool.standard.id]!.add([bot.copyWith(rating: 1350)]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.aiRatings[bot.id]!.rating, 1350);
    controller.stopLive();
    repo.updates[RatingPool.standard.id]!.add([bot.copyWith(rating: 1500)]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.aiRatings[bot.id]!.rating, 1350);
    controller.dispose();
    await repo.close();
  });

  testWidgets(
      'overall is default, AI changes live, format controls remain discoverable',
      (tester) async {
    final repo = LiveRatings();
    final controller = EloController(repo);
    await tester.pumpWidget(ProviderScope(overrides: [
      ratingRepositoryProvider.overrideWithValue(repo),
      eloProvider.overrideWith((ref) => controller),
    ], child: const MaterialApp(home: LeaderboardScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Overall · all rated formats'), findsOneWidget);
    expect(find.text('Board'), findsNothing);
    repo.updates['overall']!.add([bot]);
    await tester.pumpAndSettle();
    expect(find.text('1300'), findsOneWidget);
    expect(find.text('Estimated skill range 1104–1496 (95%)'), findsOneWidget);
    repo.updates['overall']!.add([bot.copyWith(rating: 1310)]);
    await tester.pumpAndSettle();
    expect(find.text('1310'), findsOneWidget);
    await tester.tap(find.text('Overall'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('By format').last);
    await tester.pumpAndSettle();
    expect(find.text('Board'), findsOneWidget);
    expect(find.text('Players'), findsOneWidget);
    expect(controller.state.selectedPool.isOverall, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.close();
  });

  testWidgets('uncertainty profile fits a small phone with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = LiveRatings();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          ratingRepositoryProvider.overrideWithValue(repo),
          eloProvider.overrideWith((ref) => EloController(repo)),
        ],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: const PlayerDetailScreen(player: bot))));
    await tester.pumpAndSettle();
    expect(find.text('Estimated skill range 1104–1496 (95%)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('AI v2'), 200);
    await tester.pumpAndSettle();
    expect(find.text('AI v2'), findsOneWidget);
    expect(find.text('AI v3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
