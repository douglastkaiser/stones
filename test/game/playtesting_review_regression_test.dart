import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/result_share_dialog.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/providers/elite_theme_provider.dart';
import '../support/fake_account_service.dart';
import 'package:stones/game/rating_recovery.dart';
import 'package:stones/game/rating_submission.dart';
import 'package:stones/models/elo_rating.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/providers/elo_provider.dart';
import 'package:stones/services/sound_manager.dart';
import 'package:stones/services/rating_repository.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;
import '../ratings/rating_system_test.dart' show FakeRatings;

class _RecordingSound extends SoundManager {
  final played = <GameSound>[];
  @override
  Future<void> play(GameSound sound) async {
    played.add(sound);
  }
}

class _FixtureController extends MatchController {
  _FixtureController(MatchSession session)
      : super(
            storage: MemoryMatchStorage(),
            authenticate: () async => 'guest',
            store: () => MemoryMatchRoomStore()) {
    state = session;
  }
  void update(MatchSession value) => state = value;
}

class _LiveRatings extends FakeRatings implements LiveRatingRepository {
  final leadersStream = StreamController<List<EloRating>>.broadcast();
  @override
  Stream<List<EloRating>> watchLeaders(String pool) => leadersStream.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('manual refresh and interleaved recovery preserve all known receipts',
      () {
    final status = StateController<(String, RatingSubmission)?>(null);
    const overall = RatingSubmission(
        RatingSubmissionState.failed, 'Format pending',
        skillBased: true, deltas: {SeatId.ivory: RatingDelta(1200, 1210)});
    publishRating(status, 'game', overall);
    publishRating(status, 'game', const RatingSubmission.pending());
    expect(status.state!.$2.labelFor(SeatId.ivory),
        'Overall +10 · Format pending');
    publishRating(
        status,
        'game',
        const RatingSubmission(RatingSubmissionState.confirmed, 'Done',
            formatDeltas: {SeatId.ivory: RatingDelta(1200, 1205)}));
    publishRating(status, 'game', const RatingSubmission.failed());
    expect(status.state!.$2.labelFor(SeatId.ivory), 'Overall +10 · Format +5');
    publishRating(status, 'different', const RatingSubmission.pending());
    expect(status.state!.$2.deltas, isEmpty);
    status.dispose();
  });
  test('permission failure retains a previously confirmed Overall delta',
      () async {
    final updates = <RatingSubmission>[];
    var calls = 0;
    await recoverRating(
        isCurrent: () => true,
        onResult: updates.add,
        delays: [Duration.zero, Duration.zero],
        submit: () async {
          if (calls++ == 0) {
            return const RatingSubmission(
                RatingSubmissionState.failed, 'Format offline',
                skillBased: true,
                deltas: {SeatId.ivory: RatingDelta(1200, 1210)});
          }
          throw FirebaseException(
              plugin: 'firestore', code: 'permission-denied');
        });
    expect(updates.first.deltas, isNotEmpty);
    expect(updates.last.deltas[SeatId.ivory]!.delta, 10);
  });
  test('current v2 AI replaces historical leaderboard profiles', () async {
    final repo = FakeRatings();
    const bot = EloRating(
        id: 'ai_shared-search-v2_expert',
        displayName: 'Expert AI',
        isAi: true,
        engineVersion: 'shared-search-v2',
        gamesPlayed: 1);
    repo.values = [
      bot,
      const EloRating(
          id: 'ai_shared-search-v1_expert',
          displayName: 'Expert AI',
          isAi: true)
    ];
    repo.botValues = [bot];
    final controller = EloController(repo);
    await controller.fetchLeaderboard();
    final experts = controller.state.leaderboard
        .where((e) => e.displayName == 'Expert AI')
        .toList();
    expect(experts.single.id, bot.id);
    expect(controller.state.leaderboard.where((e) => e.isAi), hasLength(4));
    controller.dispose();
  });
  test('live standings expose only the four current AI opponents', () async {
    final repo = _LiveRatings();
    final controller = EloController(repo)..startLive();
    repo.leadersStream.add(const [
      EloRating(id: 'human', displayName: 'Human'),
      EloRating(
          id: 'ai_shared-search-v1_expert',
          displayName: 'Expert AI',
          isAi: true),
      EloRating(
          id: 'ai_shared-search-v2_expert',
          displayName: 'Expert AI',
          isAi: true,
          engineVersion: 'shared-search-v2',
          gamesPlayed: 10),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.leaderboard.where((e) => e.isAi), hasLength(4));
    expect(
        controller.state.leaderboard
            .where((e) => e.displayName == 'Expert AI')
            .single
            .gamesPlayed,
        10);
    expect(controller.state.leaderboard.any((e) => e.id == 'human'), true);
    expect(controller.state.aiRatings.keys, ['ai_shared-search-v2_expert']);
    controller.dispose();
    await repo.leadersStream.close();
  });
  test('old-client terminal update clears a formerly running duration',
      () async {
    final store = MemoryMatchRoomStore();
    final config = MatchConfig(shape: BoardShape.square, size: 5, seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]);
    store.room = MatchRoom(
        code: 'UABCDEF',
        host: 'host',
        config: config,
        owners: {SeatId.ivory: 'host', SeatId.charcoal: 'guest'},
        startedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        lastMoveAt: DateTime.now().subtract(const Duration(seconds: 20)));
    final controller = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => store);
    await controller.join('UABCDEF', expectedUid: 'host');
    expect(controller.state.elapsed!.runningSince, isNotNull);
    await store.resign('UABCDEF', 'guest', SeatId.charcoal);
    expect(controller.state.game!.finished, isTrue);
    expect(controller.state.room!.elapsed(true), isNull);
    expect(controller.state.elapsed, isNull);
    controller.dispose();
    await store.updates.close();
  });
  testWidgets('same-device human turns emit one distinctive cue per turn',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sound = _RecordingSound();
    final controller = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => MemoryMatchRoomStore());
    await controller.start(MatchConfig.defaults(BoardShape.hex));
    await tester.pumpWidget(ProviderScope(overrides: [
      matchProvider.overrideWith((_) => controller),
      soundManagerProvider.overrideWithValue(sound)
    ], child: const MaterialApp(home: MatchScreen())));
    await tester.pump();
    await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    await tester.pump();
    expect(sound.played.where((s) => s == GameSound.yourTurn), hasLength(2));
    await tester.pump();
    expect(sound.played.where((s) => s == GameSound.yourTurn), hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets(
      'mixed local tables cue humans and suppress AI, paused and disconnected turns',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sound = _RecordingSound();
    final config = MatchConfig(shape: BoardShape.hex, size: 2, seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.ai),
      SeatConfig(SeatId.copper),
    ]);
    final initial = MatchState.initial(config);
    final controller =
        _FixtureController(MatchSession(id: 'mixed', game: initial));
    await tester.pumpWidget(ProviderScope(overrides: [
      matchProvider.overrideWith((_) => controller),
      soundManagerProvider.overrideWithValue(sound)
    ], child: const MaterialApp(home: MatchScreen())));
    await tester.pump();
    int cues() => sound.played.where((s) => s == GameSound.yourTurn).length;
    expect(cues(), 1);
    controller
        .update(controller.state.copyWith(game: initial.copyWith(ply: 1)));
    await tester.pump();
    expect(cues(), 1);
    controller
        .update(controller.state.copyWith(game: initial.copyWith(ply: 2)));
    await tester.pump();
    expect(cues(), 2);
    expect(find.textContaining('Copper to play'), findsOneWidget);
    controller.update(controller.state
        .copyWith(paused: true, game: initial.copyWith(ply: 3)));
    await tester.pump();
    expect(cues(), 2);
    controller.update(controller.state.copyWith(paused: false));
    await tester.pump();
    expect(cues(), 3);
    controller.update(controller.state
        .copyWith(connected: false, game: initial.copyWith(ply: 5)));
    await tester.pump();
    expect(cues(), 3);
    controller.update(controller.state.copyWith(connected: true));
    await tester.pump();
    expect(cues(), 4);
    controller.update(controller.state.copyWith(
        game: initial.copyWith(
            ply: 6,
            result: const MatchResult(SeatId.ivory, ResultReason.road))));
    await tester.pump();
    expect(cues(), 4);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('sharing uses current eligibility and responds to revocation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final config = MatchConfig(shape: BoardShape.square, size: 5, seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]);
    final room = MatchRoom(
        code: 'UABCDEF',
        host: 'host',
        config: config,
        owners: {SeatId.ivory: 'host', SeatId.charcoal: 'guest'},
        boardTheme: BoardTheme.celestial,
        resigned: SeatId.charcoal);
    final session = MatchSession(
        id: room.code, uid: 'guest', room: room, game: room.replay());
    final controller = _FixtureController(session);
    final eligibility = StreamController<bool>.broadcast();
    await tester.pumpWidget(ProviderScope(overrides: [
      matchProvider.overrideWith((_) => controller),
      accountProvider.overrideWith(
          (_) => AccountController(FakeAccount(), hasActiveRoom: () => false)),
      eliteThemeEligibilityProvider
          .overrideWith((ref, uid) => eligibility.stream),
      soundManagerProvider.overrideWithValue(_RecordingSound()),
    ], child: const MaterialApp(home: MatchScreen())));
    await tester.pump();
    await tester.pump();
    eligibility.add(true);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<BoardView>(find.byType(BoardView)).theme,
        BoardTheme.celestial);
    eligibility.add(false);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Share result'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share result'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include final board'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<ResultShareCard>(find.byType(ResultShareCard)).boardTheme,
        BoardTheme.classicWood);
    eligibility.add(true);
    await tester.pumpAndSettle();
    expect(
        tester.widget<ResultShareCard>(find.byType(ResultShareCard)).boardTheme,
        BoardTheme.celestial);
    eligibility.add(false);
    await tester.pumpAndSettle();
    expect(
        tester.widget<ResultShareCard>(find.byType(ResultShareCard)).boardTheme,
        BoardTheme.classicWood);
    expect(tester.widget<BoardView>(find.byType(BoardView).first).theme,
        BoardTheme.classicWood);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await eligibility.close();
  });
}
