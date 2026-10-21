import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_history_provider.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/rating_evidence.dart';
import 'package:stones/game/rating_submission.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/providers/achievements_provider.dart';
import 'package:stones/providers/elo_provider.dart';
import 'package:stones/services/account_service.dart';
import '../game/match_controller_test.dart' show MemoryMatchStorage;
import '../support/fake_account_service.dart';
import 'rating_system_test.dart' show FakeRatings;

class RecordingRatings extends FakeRatings {
  final submitted = Completer<RatingEvidence>();
  int calls = 0;
  @override
  Future<RatingSubmission> submitResult(
      MatchSession session, List<Map<String, dynamic>> moves) async {
    calls++;
    final evidence = RatingEvidence.verify(session, moves, 'reporter')!;
    if (!submitted.isCompleted) submitted.complete(evidence);
    return const RatingSubmission(
        RatingSubmissionState.confirmed, 'Overall and format ratings recorded',
        skillBased: true);
  }
}

void main() {
  test('a completed AI-only save submits once and gives its observer no win',
      () async {
    SharedPreferences.setMockInitialValues({});
    final config =
        MatchConfig.defaults(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory, control: SeatControl.ai, level: BotLevel.expert),
      SeatConfig(SeatId.charcoal, control: SeatControl.ai),
    ]);
    var game = MatchState.initial(config);
    final moves = <Map<String, dynamic>>[];
    for (final (x, y) in [
      (4, 0),
      (0, 0),
      (0, 1),
      (4, 1),
      (0, 2),
      (4, 2),
      (0, 3),
      (3, 1),
      (0, 4),
    ]) {
      final move = MatchMove.place(Cell(x, y), PieceType.flat);
      moves.add(move.toMap(game.current));
      game = MatchRules.play(game, move)!;
    }
    final storage = MemoryMatchStorage()
      ..snapshot = {
        'id': 'local-ai-completed',
        'ratingUid': 'reporter',
        'config': config.toMap(),
        'moves': moves,
      };
    final account = FakeAccount()
      ..current = const AccountIdentity(uid: 'reporter', guest: false);
    final ratings = RecordingRatings();
    final container = ProviderContainer(overrides: [
      accountServiceProvider.overrideWithValue(account),
      localMatchStorageProvider.overrideWithValue(storage),
      ratingRepositoryProvider.overrideWithValue(ratings),
    ]);
    addTearDown(() async {
      container.dispose();
      await account.events.close();
    });
    await container.read(accountProvider.notifier).initialize();
    await container.read(achievementProvider.notifier).load();
    final controller = container.read(matchProvider.notifier);
    expect(await controller.resumeLocal(), isTrue);
    final evidence =
        await ratings.submitted.future.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);
    expect(evidence.humans, isEmpty);
    expect(evidence.participants,
        ['ai_shared-search-v2_expert', 'ai_shared-search-v2_easy']);
    expect(container.read(ratingStatusProvider)?.$2.state,
        RatingSubmissionState.confirmed);
    expect(container.read(achievementProvider).totalWins, 0);
    expect(await container.read(completedMatchStorageProvider).list('reporter'),
        hasLength(1));
    expect(await controller.resumeLocal(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(ratings.calls, 1);
  });
}
