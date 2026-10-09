// Run separately from correctness tests: flutter test tools/performance_probe_test.dart
// VM diagnostics for comparable workloads, not phone/browser frame-rate claims.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stones/models/models.dart';
import 'package:stones/services/ai/ai.dart';
import 'package:stones/services/ai/lookahead_ai.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_ai.dart';

Future<void> measure(String label, Future<Object?> Function() work) async {
  final watch = Stopwatch()..start();
  var last = 0;
  var maxGap = 0;
  var beats = 0;
  void beat() {
    final now = watch.elapsedMicroseconds;
    maxGap = max(maxGap, now - last);
    last = now;
    beats++;
  }

  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) => beat());
  try {
    expect(await work(), isNotNull);
    beat();
  } finally {
    timer.cancel();
  }
  // ignore: avoid_print
  print('PERF ${jsonEncode({
        'workload': label,
        'elapsedMs': watch.elapsedMilliseconds,
        'maxEventLoopGapMs': maxGap / 1000,
        'heartbeats': beats
      })}');
}

void main() {
  for (final size in [5, 8]) {
    for (final difficulty in AIDifficulty.values) {
      test('$size square ${difficulty.name}', () async {
        final config = StonesAI.forDifficulty(difficulty) as LookaheadStonesAI;
        for (final cooperative in [false, true]) {
          final ai = LookaheadStonesAI(Random(39),
              searchDepth: config.searchDepth,
              maxBranchingLimit: config.maxBranchingLimit,
              midBranchingLimit: config.midBranchingLimit,
              deepBranchingLimit: config.deepBranchingLimit,
              evaluationJitter: config.evaluationJitter,
              yieldDuringSearch: cooperative,
              thinkingLimit: config.thinkingLimit);
          await measure(
              'square-$size-${difficulty.name}-${cooperative ? 'cooperative' : 'uninterrupted'}',
              () => ai.selectMove(GameState.initial(size)));
        }
      });
    }
  }
  for (final radius in [2, 3, 4]) {
    test('Hex radius $radius', () async {
      final game = HexGame.initial(radius: radius);
      await measure(
          'hex-$radius-uninterrupted', () async => HexAI.choose(game));
      await measure(
          'hex-$radius-cooperative', () => HexAI.chooseResponsive(game));
    });
  }
}
