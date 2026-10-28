// Isolate immutable transition cost; no search strength claim follows from this.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:stones/game/ai_duel_position.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'ai_qualification.dart' show sha;

Future<void> main() async {
  final totals = <String, int>{'canonicalMicros': 0, 'sharedMicros': 0};
  var transitions = 0;
  var checksum = 0;
  for (final shape in BoardShape.values) {
    final cfg = MatchConfig(
        shape: shape,
        size: shape == BoardShape.square ? 5 : 2,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    for (var seed = 0; seed < 12; seed++) {
      final rng = Random(9000 + seed);
      var game = MatchState.initial(cfg);
      for (var ply = 0; ply < 32 && !game.finished; ply++) {
        final legal = MatchRules.legalMoves(game).toList();
        if (ply >= 4 && ply % 4 == 0) {
          final shared = AiDuelPosition.from(game);
          final sums = <int>[];
          // Rotate order to avoid assigning one arm all warmup costs.
          for (final fast in seed.isEven ? [true, false] : [false, true]) {
            var sum = 0;
            final watch = Stopwatch()..start();
            for (var repeat = 0; repeat < 8; repeat++) {
              for (final move in legal) {
                final next = MatchRules.play(fast ? shared : game, move)!;
                sum += next.board.length + (next.result?.winner?.index ?? 4);
              }
            }
            totals[fast ? 'sharedMicros' : 'canonicalMicros'] =
                totals[fast ? 'sharedMicros' : 'canonicalMicros']! +
                    watch.elapsedMicroseconds;
            sums.add(sum);
          }
          if (sums[0] != sums[1]) {
            throw StateError('Transition checksum differs');
          }
          checksum += sums.first;
          transitions += legal.length * 8;
        }
        game = MatchRules.play(game, legal[rng.nextInt(legal.length)])!;
      }
    }
  }
  stdout.writeln(jsonEncode({
    'scope':
        'Sequential native canonical-rule transition microbenchmark, not game strength',
    'runtime': Platform.version,
    'transitionsPerArm': transitions,
    'checksum': checksum,
    ...totals,
    'speedup': totals['canonicalMicros']! / totals['sharedMicros']!,
    'sourceSha256': await sha('lib/game/ai_duel_position.dart'),
    'runnerSha256': await sha('tools/ai_position_benchmark.dart')
  }));
}
