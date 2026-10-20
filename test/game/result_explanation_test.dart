import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/result_explanation.dart';

void main() {
  final initial = MatchState.initial(MatchConfig.defaults(BoardShape.square));
  test('road result explains priority instead of suggesting a flat win', () {
    final game = initial.copyWith(
        result: const MatchResult(SeatId.ivory, ResultReason.road));
    expect(explainResult(game, winnerName: 'Alex'),
        contains('Alex won by connecting opposite edges'));
    expect(
        explainResult(game), contains('wins before flat stones are counted'));
  });
  test('draw, concession, expiry and abandonment have distinct explanations',
      () {
    String explain(ResultReason reason, SeatId? winner) =>
        explainResult(initial.copyWith(result: MatchResult(winner, reason)));
    expect(explain(ResultReason.flats, null),
        contains('highest exposed-flat count is tied'));
    expect(explain(ResultReason.road, null),
        contains('roads for multiple opponents'));
    expect(explain(ResultReason.resignation, SeatId.charcoal),
        contains('resigned'));
    expect(
        explain(ResultReason.time, SeatId.ivory), contains('ran out of time'));
    expect(explain(ResultReason.abandoned, null),
        contains('not a competitive draw'));
    expect(explainResult(initial), isEmpty);
  });
}
