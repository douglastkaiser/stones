// Bounded calibration evidence, not a claim that a difficulty is established.
// flutter test tools/ai_balance_probe_test.dart --reporter expanded
// --dart-define=AI_SHAPE=hex --dart-define=AI_PLAYERS=3
// --dart-define=AI_SIZE=2 --dart-define=AI_MAX_PLIES=100
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_ai_engine.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

void main() {
  final shape = BoardShape.values
      .byName(const String.fromEnvironment('AI_SHAPE', defaultValue: 'square'));
  const players = int.fromEnvironment('AI_PLAYERS', defaultValue: 2);
  const requestedSize = int.fromEnvironment('AI_SIZE');
  final size = requestedSize == 0
      ? shape == BoardShape.square
          ? 5
          : 2
      : requestedSize;
  const maxPlies = int.fromEnvironment('AI_MAX_PLIES', defaultValue: 100);
  if (players < 2 || players > 4 || maxPlies < 1 || maxPlies > 300) {
    throw ArgumentError('Use 2–4 players and 1–300 plies');
  }
  // Rotate levels and the starting seat. No changes to shared public AI ratings.
  for (var rotation = 0; rotation < 4; rotation++) {
    test('calibration ${shape.name} $players seats rotation $rotation',
        () async {
      final config = MatchConfig(
          shape: shape,
          size: size,
          starter: SeatId.values[rotation % players],
          seats: [
            for (var seat = 0; seat < players; seat++)
              SeatConfig(SeatId.values[seat],
                  control: SeatControl.ai,
                  level: BotLevel.values[(seat + rotation) % 4]),
          ]);
      var game = MatchState.initial(config);
      final elapsed = <int>[];
      final moves = <Map<String, dynamic>>[];
      final positions = <String, int>{};
      var repetitions = 0;
      while (!game.finished && game.ply < maxPlies) {
        final watch = Stopwatch()..start();
        final move =
            await MatchAI(config.seat(game.current).level).choose(game);
        elapsed.add(watch.elapsedMilliseconds);
        expect(move, isNotNull);
        final next = MatchRules.play(game, move!);
        expect(next, isNotNull, reason: 'Illegal move at ply ${game.ply}');
        moves.add(move.toMap(game.current));
        game = next!;
        final signature =
            '${game.current.name}|${game.geometry.cells.map((c) => game.stackAt(c).map((s) => '${s.seat.name}:${s.type.name}').join(',')).join('|')}';
        final count = (positions[signature] ?? 0) + 1;
        positions[signature] = count;
        if (count == 3) repetitions++;
      }
      elapsed.sort();
      // Keep full replay evidence for investigating awkward or repetitive games.
      // ignore: avoid_print
      print('AI_BALANCE ${jsonEncode({
            'config': config.toMap(),
            'ply': game.ply,
            'winner': game.result?.winner?.name,
            'reason': game.result?.reason.name ?? 'probe-limit',
            'repeatedPositions': repetitions,
            'p95SearchMs': elapsed[(elapsed.length * .95).ceil() - 1],
            'moves': moves,
            'scope':
                'Named CI runner; device and human difficulty calibration pending',
          })}');
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
