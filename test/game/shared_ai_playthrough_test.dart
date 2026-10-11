import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_ai.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

void main() {
  for (final shape in BoardShape.values) {
    for (var count = 2; count <= 4; count++) {
      test('mixed AI difficulties complete a legal $shape $count-seat match',
          () async {
        final offset = shape == BoardShape.square ? 0 : 2;
        final config = MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 3 : 2,
            seats: [
              for (var index = 0; index < count; index++)
                SeatConfig(SeatId.values[index],
                    control: SeatControl.ai,
                    level: BotLevel.values[(offset + index * 3) % 4])
            ]);
        var game = MatchState.initial(config);
        final supply = game.reserves[config.starter]!.total;
        for (var ply = 0; ply < 150 && !game.finished; ply++) {
          final move =
              await selectMatchMove(game, config.seat(game.current).level);
          expect(move, isNotNull, reason: 'AI stalled at ply $ply');
          final next = MatchRules.play(game, move!);
          expect(next, isNotNull,
              reason: 'AI produced an illegal move at $ply');
          game = next!;
          expect(game.ply, ply + 1);
          for (final id in config.ids) {
            final stones = game.board.values
                .expand((stack) => stack)
                .where((stone) => stone.seat == id)
                .length;
            expect(stones + game.reserves[id]!.total, supply);
          }
        }
        expect(game.finished, isTrue,
            reason: 'The AI trial did not finish within 150 moves');
        expect(
            game.result!.reason, anyOf(ResultReason.road, ResultReason.flats));
      }, timeout: const Timeout(Duration(minutes: 4)));
    }
  }
}
