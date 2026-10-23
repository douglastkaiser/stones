import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_ai.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

class ExpiredAI extends MatchAI {
  ExpiredAI(super.level, {super.onSearchComplete})
      : super(yieldDuringSearch: false);
  @override
  Duration get thinkingLimit => Duration.zero;
}

void main() {
  for (final shape in BoardShape.values) {
    for (var count = 2; count <= 4; count++) {
      for (final level in BotLevel.values) {
        test('$shape $count seats $level searches at least one whole round',
            () async {
          final config = MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 3 : 2,
              seats: SeatId.values.take(count).map(SeatConfig.new).toList());
          final game = MatchState.initial(config).copyWith(ply: count);
          late MatchSearchStats stats;
          final move = await MatchAI(level,
              yieldDuringSearch: false,
              onSearchComplete: (value) => stats = value).choose(game);
          expect(move, isNotNull);
          expect(MatchRules.play(game, move!), isNotNull);
          expect(stats.consideredSeats, unorderedEquals(config.ids));
          expect(stats.completedRounds, greaterThanOrEqualTo(1));
          expect(stats.completedDepth, stats.completedRounds * count);
          if (level == BotLevel.easy) expect(stats.completedRounds, 1);
        });
      }
      for (final starter in SeatId.values.take(count)) {
        test('$shape $count seats Easy includes every rival after $starter',
            () async {
          final config = MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 3 : 2,
              seats: SeatId.values.take(count).map(SeatConfig.new).toList(),
              starter: starter);
          late MatchSearchStats stats;
          final game = MatchState.initial(config).copyWith(ply: count);
          await MatchAI(BotLevel.easy,
              yieldDuringSearch: false,
              onSearchComplete: (value) => stats = value).choose(game);
          expect(stats.consideredSeats, unorderedEquals(config.ids));
          expect(stats.completedDepth, count);
        });
      }
    }
    for (final level in BotLevel.values) {
      for (final count in [3, 4]) {
        test('$shape $count seats $level completes the round after a deadline',
            () async {
          final config = MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 8 : 4,
              seats: SeatId.values.take(count).map(SeatConfig.new).toList());
          late MatchSearchStats stats;
          final game = MatchState.initial(config).copyWith(ply: count);
          final move =
              await ExpiredAI(level, onSearchComplete: (value) => stats = value)
                  .choose(game);
          expect(MatchRules.play(game, move!), isNotNull);
          expect(stats.timedOut, isTrue);
          expect(stats.consideredSeats, unorderedEquals(config.ids));
          expect(stats.completedDepth, count);
          expect(stats.completedRounds, 1);
        });
      }
    }
  }

  test('cancelling the mandatory round still returns no move', () async {
    final game = MatchState.initial(MatchConfig.defaults(BoardShape.hex));
    var checks = 0;
    final move = await ExpiredAI(BotLevel.easy)
        .choose(game, cancelled: () => ++checks > 5);
    expect(move, isNull);
  });

  test('saved v2 Easy keeps its original strategy', () async {
    final config = MatchConfig(
        shape: BoardShape.square,
        size: 3,
        aiEngine: 'shared-search-v2',
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    late MatchSearchStats stats;
    final move = await MatchAI(BotLevel.easy,
            yieldDuringSearch: false,
            onSearchComplete: (value) => stats = value)
        .choose(MatchState.initial(config).copyWith(ply: 2));
    expect(move, isNotNull);
    expect(stats.completedRounds, 0);
    expect(stats.consideredSeats, isEmpty);
  });
}
