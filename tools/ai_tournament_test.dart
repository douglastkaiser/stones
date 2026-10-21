// Reproducible adjacent-tier calibration; never writes public AI ratings.
// flutter test tools/ai_tournament_test.dart --dart-define=AI_PAIRS=50
import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_ai_engine.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

void main() {
  const pairs = int.fromEnvironment('AI_PAIRS', defaultValue: 50);
  const only = String.fromEnvironment('AI_TOURNAMENT_SHAPE');
  const players = int.fromEnvironment('AI_PLAYERS', defaultValue: 2);
  if (players < 2 || players > 4) throw ArgumentError('Use 2–4 AI players');
  for (final shape in BoardShape.values
      .where((shape) => only.isEmpty || shape.name == only)) {
    for (var tier = 0; tier < 3; tier++) {
      const selectedTier =
          int.fromEnvironment('AI_TOURNAMENT_TIER', defaultValue: -1);
      if (selectedTier >= 0 && tier != selectedTier) continue;
      test(
          '${shape.name} ${BotLevel.values[tier].name} vs ${BotLevel.values[tier + 1].name}',
          () async {
        var strongerWins = 0, weakerWins = 0, draws = 0, unfinished = 0;
        final depths = <String, List<int>>{};
        final timeouts = <String, int>{};
        for (var seed = 0; seed < pairs; seed++) {
          for (var swap = 0; swap < players; swap++) {
            final stronger = players == 2
                ? (swap == 0 ? SeatId.charcoal : SeatId.ivory)
                : SeatId.values[swap];
            final config = MatchConfig(
                shape: shape,
                size: shape == BoardShape.square ? 3 : 2,
                seats: [
                  for (final id in SeatId.values.take(players))
                    SeatConfig(id,
                        control: SeatControl.ai,
                        level:
                            BotLevel.values[id == stronger ? tier + 1 : tier]),
                ]);
            var game = MatchState.initial(config);
            final random = Random(seed);
            for (var opening = 0; opening < players; opening++) {
              final legal = MatchRules.legalMoves(game).toList();
              game =
                  MatchRules.play(game, legal[random.nextInt(legal.length)])!;
            }
            final moves = <Map<String, dynamic>>[];
            while (!game.finished && game.ply < 80) {
              final level = config.seat(game.current).level;
              final move = await MatchAI(level, yieldDuringSearch: false,
                  onSearchComplete: (stats) {
                depths
                    .putIfAbsent(level.name, () => [])
                    .add(stats.completedDepth);
                if (stats.timedOut) {
                  timeouts.update('${level.name}:${stats.stage}', (v) => v + 1,
                      ifAbsent: () => 1);
                }
              }).choose(game);
              expect(move, isNotNull);
              moves.add(move!.toMap(game.current));
              game = MatchRules.play(game, move)!;
            }
            if (!game.finished) {
              unfinished++;
            } else if (game.result!.winner == null) {
              draws++;
            } else if (game.result!.winner == stronger) {
              strongerWins++;
            } else {
              weakerWins++;
            }
            // ignore: avoid_print
            print('AI_GAME ${jsonEncode({
                  'shape': shape.name,
                  'tier': tier,
                  'seed': seed,
                  'swap': swap,
                  'winner': game.result?.winner?.name,
                  'stronger': stronger.name,
                  'moves': moves
                })}');
          }
        }
        final decisive = strongerWins + weakerWins;
        // ignore: avoid_print
        print('AI_TOURNAMENT ${jsonEncode({
              'shape': shape.name,
              'tier': tier,
              'pairs': pairs,
              'players': players,
              'strongerWins': strongerWins,
              'weakerWins': weakerWins,
              'draws': draws,
              'unfinished': unfinished,
              'strongerWinRate': decisive == 0 ? null : strongerWins / decisive,
              'perSeatWinShare': decisive == 0
                  ? null
                  : strongerWins / (strongerWins + weakerWins / (players - 1)),
              'averageCompletedDepth': depths.map(
                  (k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length)),
              'timeouts': timeouts
            })}');
        if (pairs >= 50) {
          expect(decisive, greaterThan(0));
          expect(strongerWins / (strongerWins + weakerWins / (players - 1)),
              greaterThan(.6));
        }
      }, timeout: const Timeout(Duration(hours: 3)));
    }
  }
}
