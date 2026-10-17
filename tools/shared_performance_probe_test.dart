// CI VM diagnostics only. Not evidence of physical phone/browser responsiveness.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_ai_engine.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

void main() {
  for (final shape in BoardShape.values) {
    for (final players in [2, 4]) {
      for (final level in BotLevel.values) {
        test('${shape.name} $players ${level.name}', () async {
          final config = MatchConfig.defaults(shape).copyWith(
              seats: SeatId.values.take(players).map(SeatConfig.new).toList());
          var game = MatchState.initial(config);
          for (var i = 0; i < players * 2; i++) {
            game = MatchRules.play(game, MatchRules.legalMoves(game).first)!;
          }
          final watch = Stopwatch()..start();
          var last = 0;
          var maximumGap = 0;
          var beats = 0;
          void beat() {
            final now = watch.elapsedMicroseconds;
            maximumGap = math.max(maximumGap, now - last);
            last = now;
            beats++;
          }

          final timer =
              Timer.periodic(const Duration(milliseconds: 1), (_) => beat());
          try {
            final move = await MatchAI(level).choose(game);
            beat();
            expect(move, isNotNull);
            expect(MatchRules.play(game, move!), isNotNull);
          } finally {
            timer.cancel();
          }
          // ignore: avoid_print
          print('SHARED_PERF ${jsonEncode({
                'shape': shape.name,
                'players': players,
                'level': level.name,
                'elapsedMs': watch.elapsedMilliseconds,
                'maxEventLoopGapMs': maximumGap / 1000,
                'heartbeats': beats,
                'scope':
                    'GitHub Actions VM; cooperative shared engine; not a device SLA',
              })}');
        });
      }
    }
  }
}
