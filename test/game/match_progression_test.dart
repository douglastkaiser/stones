import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/match_completed.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/achievement.dart';
import 'package:stones/providers/achievements_provider.dart';
import 'package:stones/services/ai/ai.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('specialist AI awards require a standard unassisted Square duel', () {
    for (final level in BotLevel.values) {
      for (final shape in BoardShape.values) {
        for (var count = 2; count <= 4; count++) {
          final config = MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 5 : 2,
              seats: [
                const SeatConfig(SeatId.ivory),
                for (final id in SeatId.values.skip(1).take(count - 1))
                  SeatConfig(id, control: SeatControl.ai, level: level)
              ]);
          MatchCompleted event(MatchConfig value, SeatId? winner) =>
              MatchCompleted(MatchSession(
                  id: 'ai-duel',
                  game: MatchState.initial(value).copyWith(
                      result: MatchResult(winner, ResultReason.road))));
          expect(event(config, SeatId.ivory).defeatedAILevel,
              shape == BoardShape.square && count == 2 ? level : null);
          expect(event(config, SeatId.charcoal).defeatedAILevel, isNull);
          expect(event(config, null).defeatedAILevel, isNull);
          expect(
              event(config.copyWith(court: true), SeatId.ivory).defeatedAILevel,
              isNull);
        }
      }
    }
  });
  test(
      'win ledger commits reward and counts once across concurrent replay and restart',
      () async {
    SharedPreferences.setMockInitialValues({
      AchievementKeys.totalWins: 9,
      '${AchievementKeys.prefix}${AchievementType.student.name}': true,
    });
    final awards = AchievementNotifier();
    await awards.load();
    Future<List<AchievementType>> record() => awards.recordWin(
        matchId: 'room:17:road',
        isOnline: true,
        aiDifficulty: AIDifficulty.easy,
        byTime: false,
        byFlats: false);
    await Future.wait([record(), record(), record()]);
    expect(awards.state.totalWins, 10);
    expect(awards.state.onlineWins, 1);
    expect(
        awards.state.unlockedAchievements,
        containsAll([
          AchievementType.student,
          AchievementType.dedicated,
          AchievementType.connected,
          AchievementType.firstSteps,
        ]));
    awards.dispose();
    final fresh = AchievementNotifier();
    await fresh.load();
    expect(
        await fresh.recordWin(
            matchId: 'room:17:road',
            isOnline: true,
            aiDifficulty: null,
            byTime: false,
            byFlats: false),
        isEmpty);
    expect(fresh.state.totalWins, 10);
    await fresh.resetAll();
    expect(fresh.state.totalWins, 0);
    fresh.dispose();
  });

  test(
      'result eligibility excludes observer, AI winner, practice, guest and shared-device wins',
      () {
    for (final shape in BoardShape.values) {
      final defaults = MatchConfig.defaults(shape);
      final single = defaults.copyWith(seats: [
        defaults.seats.first,
        for (final seat in defaults.seats.skip(1))
          seat.copyWith(control: SeatControl.ai)
      ]);
      MatchCompleted result(MatchConfig config, SeatId? winner) =>
          MatchCompleted(MatchSession(
              id: 'local-id',
              game: MatchState.initial(config)
                  .copyWith(result: MatchResult(winner, ResultReason.road))));
      expect(result(single, SeatId.ivory).eligibleWin, isTrue);
      expect(result(single, SeatId.charcoal).eligibleWin, isFalse);
      expect(result(single, null).eligibleWin, isFalse);
      expect(result(single.copyWith(court: true), SeatId.ivory).eligibleWin,
          isFalse);
      expect(result(defaults, SeatId.ivory).eligibleWin, isFalse);
    }
    final config = MatchConfig.defaults(BoardShape.hex).copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal),
      SeatConfig(SeatId.copper, control: SeatControl.onlineHuman),
    ]);
    final room = MatchRoom(
        code: 'UABCDEF',
        host: 'host',
        config: config,
        owners: const {
          SeatId.ivory: 'host',
          SeatId.charcoal: 'host',
          SeatId.copper: 'guest'
        });
    MatchCompleted result(SeatId winner, String uid) => MatchCompleted(
        MatchSession(
            id: room.code,
            room: room,
            uid: uid,
            game: MatchState.initial(config)
                .copyWith(result: MatchResult(winner, ResultReason.road))));
    expect(result(SeatId.ivory, 'host').eligibleWin, isTrue);
    expect(result(SeatId.charcoal, 'host').eligibleWin, isFalse);
    expect(result(SeatId.copper, 'host').eligibleWin, isFalse);
    expect(result(SeatId.copper, 'guest').eligibleWin, isTrue);
  });
}
