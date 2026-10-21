import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/completed_match.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_elapsed.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/match_threats.dart';
import 'package:stones/game/rating_recovery.dart';
import 'package:stones/game/rating_submission.dart';
import 'package:stones/game/result_share_data.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/providers/elite_theme_provider.dart';
import 'package:stones/services/match_chat_service.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

void main() {
  test('Hex fits actual cell extents on every size and viewport', () {
    for (final radius in [2, 3, 4]) {
      for (final size in [
        const Size(240, 240),
        const Size(390, 390),
        const Size(760, 600)
      ]) {
        final geometry = HexGeometry(radius);
        final layout = BoardLayout(size, geometry);
        Rect? extent;
        for (final cell in geometry.cells) {
          final rect = layout.polygon(cell).getBounds();
          extent = extent?.expandToInclude(rect) ?? rect;
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }
        expect(
            (extent!.height / size.height > .85) ||
                (extent.width / size.width > .85),
            isTrue);
      }
    }
  });
  test('active duration freezes, resumes, and ignores time away', () {
    final start = DateTime.utc(2026);
    final first = MatchElapsed(runningSince: start)
        .frozen(start.add(const Duration(seconds: 10)));
    final loaded = MatchElapsed.fromMap(first.toMap());
    expect(loaded.at(start.add(const Duration(hours: 4))).inSeconds, 10);
    final resumed = loaded.resumed(start.add(const Duration(hours: 4)));
    expect(
        resumed.at(start.add(const Duration(hours: 4, seconds: 5))).inSeconds,
        15);
    expect(() => MatchElapsed.fromMap({'milliseconds': -1}),
        throwsFormatException);
  });
  test(
      'unlimited finished games share frozen duration and every spectator delta',
      () {
    final game = MatchState.initial(MatchConfig.defaults(BoardShape.square))
        .copyWith(
            result: const MatchResult(SeatId.ivory, ResultReason.resignation));
    final session = MatchSession(
        id: 'result',
        game: game,
        elapsed: const MatchElapsed(milliseconds: 65000));
    final share = ResultShareData(session,
        names: const {SeatId.ivory: 'A', SeatId.charcoal: 'B'},
        viewer: null,
        rating: const RatingSubmission(
            RatingSubmissionState.confirmed, 'Recorded',
            skillBased: true,
            deltas: {
              SeatId.ivory: RatingDelta(1200, 1210),
              SeatId.charcoal: RatingDelta(1200, 1190)
            }));
    expect(share.text, contains('1m 5s'));
    expect(share.text, contains('A: Overall +10'));
    expect(share.text, contains('B: Overall -10'));
    final saved = CompletedMatch.capture(session, []);
    expect(CompletedMatch.fromMap(saved.toMap()).durationMs, 65000);
  });
  test('completed duration is identical after durable local recovery',
      () async {
    final storage = MemoryMatchStorage();
    final controller = MatchController(
        storage: storage,
        authenticate: () async => 'host',
        store: () => MemoryMatchRoomStore());
    await controller.start(MatchConfig.defaults(BoardShape.square));
    await controller.resign(SeatId.ivory);
    final duration = controller.state.elapsed!.milliseconds;
    expect(storage.snapshot!['elapsed']['milliseconds'], duration);
    final before = CompletedMatch.capture(controller.state, []);
    await controller.resumeLocal();
    final after = CompletedMatch.capture(controller.state, []);
    expect(after.durationMs, before.durationMs);
    controller.dispose();
  });
  test('new AI identity is versioned; missing saved metadata stays v1', () {
    final current = MatchConfig.defaults(BoardShape.hex);
    expect(current.aiEngine, 'shared-search-v2');
    expect(MatchConfig.fromMap(current.toMap()).aiEngine, 'shared-search-v2');
    final old = current.toMap()..remove('aiEngine');
    expect(MatchConfig.fromMap(old).aiEngine, 'shared-search-v1');
  });
  test('top decile excludes provisional, includes ties and small populations',
      () {
    expect(
        topDecileEligible(established: false, population: 100, rank: 1), false);
    expect(topDecileEligible(established: true, population: 0, rank: 1), false);
    expect(topDecileEligible(established: true, population: 1, rank: 1), true);
    expect(
        topDecileEligible(established: true, population: 101, rank: 11), true);
    expect(
        topDecileEligible(established: true, population: 100, rank: 11), false);
  });
  test('chat filter intentionally masks substrings and markup stays plain text',
      () {
    expect(filterChatText('CLASS and SHIT'), 'CL*** and ****');
    expect(filterChatText('<script>alert(1)</script>'),
        '<script>alert(1)</script>');
  });
  test('rating recovery retains partial receipts and stops at confirmation',
      () async {
    final updates = <RatingSubmission>[];
    var calls = 0;
    await recoverRating(
        isCurrent: () => true,
        onResult: updates.add,
        delays: List.filled(5, Duration.zero),
        submit: () async {
          calls++;
          if (calls == 1) {
            return const RatingSubmission(
                RatingSubmissionState.failed, 'Format pending',
                skillBased: true,
                deltas: {SeatId.ivory: RatingDelta(1200, 1210)});
          }
          if (calls == 2) throw TimeoutException('offline');
          return const RatingSubmission(
              RatingSubmissionState.confirmed, 'Recorded');
        });
    expect(calls, 3);
    expect(updates[1].deltas[SeatId.ivory]!.delta, 10);
  });
  test(
      'rating permission denial stops retries and account switches discard result',
      () async {
    var calls = 0;
    await recoverRating(
        isCurrent: () => true,
        onResult: (_) {},
        delays: List.filled(3, Duration.zero),
        submit: () async {
          calls++;
          throw FirebaseException(
              plugin: 'firestore', code: 'permission-denied');
        });
    expect(calls, 1);
    var current = true;
    await recoverRating(
        isCurrent: () => current,
        onResult: (_) => fail('stale account result'),
        submit: () async {
          current = false;
          return const RatingSubmission.unrated();
        });
  });
  for (final shape in BoardShape.values) {
    test('Court detects road and flat wins on $shape only', () async {
      final config = MatchConfig(
          shape: shape,
          size: shape == BoardShape.square ? 3 : 2,
          court: true,
          seats: const [
            SeatConfig(SeatId.ivory),
            SeatConfig(SeatId.charcoal, control: SeatControl.ai)
          ]);
      final initial = MatchState.initial(config);
      final road = initial.copyWith(ply: 2, board: {
        for (var x = shape == BoardShape.square ? 0 : -2; x < 2; x++)
          Cell(x, 0): const [Stone(SeatId.ivory, PieceType.flat)]
      });
      expect(await findMatchThreats(road), contains(SeatId.ivory));
      final flats = initial.copyWith(ply: 2, reserves: {
        SeatId.ivory: const Reserve(1, 0),
        SeatId.charcoal: const Reserve(5, 0)
      });
      expect(await findMatchThreats(flats), contains(SeatId.ivory));
      expect(
          await findMatchThreats(
              MatchState.initial(config.copyWith(court: false))),
          isEmpty);
    });
  }
  testWidgets('a wall selection resets on the next turn', (tester) async {
    final controller = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => MemoryMatchRoomStore());
    await controller.start(MatchConfig.defaults(BoardShape.square));
    await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    await controller.play(MatchMove.place(const Cell(1, 0), PieceType.flat));
    await tester.pumpWidget(ProviderScope(
        overrides: [matchProvider.overrideWith((_) => controller)],
        child: const MaterialApp(home: MatchScreen())));
    await tester.pump();
    await tester.ensureVisible(find.text('Wall'));
    await tester.tap(find.text('Wall'));
    await tester.pump();
    expect(
        tester
            .widget<ChoiceChip>(find.ancestor(
                of: find.text('Wall'), matching: find.byType(ChoiceChip)))
            .selected,
        true);
    await controller
        .play(MatchMove.place(const Cell(2, 0), PieceType.standing));
    await tester.pump();
    expect(
        tester
            .widget<ChoiceChip>(find.ancestor(
                of: find.text('Flat'), matching: find.byType(ChoiceChip)))
            .selected,
        true);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
