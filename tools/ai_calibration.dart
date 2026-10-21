// Native release calibration uses the same engine, budgets and rules as play.
import 'dart:convert';
import 'dart:math';
import 'package:stones/game/match_ai_engine.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

const calibrationPairs = int.fromEnvironment('AI_PAIRS', defaultValue: 50);
const calibrationShape = String.fromEnvironment('AI_TOURNAMENT_SHAPE');
const calibrationTier =
    int.fromEnvironment('AI_TOURNAMENT_TIER', defaultValue: -1);
const calibrationPlayers = int.fromEnvironment('AI_PLAYERS');
const calibrationSize = int.fromEnvironment('AI_SIZE');
const calibrationMaxPlies =
    int.fromEnvironment('AI_MAX_PLIES', defaultValue: 160);

void validateCalibrationSelection() {
  if (calibrationPairs < 1 ||
      calibrationMaxPlies < 1 ||
      calibrationTier < -1 ||
      calibrationTier > 2 ||
      (calibrationPlayers != 0 &&
          (calibrationPlayers < 2 || calibrationPlayers > 4)) ||
      (calibrationShape.isNotEmpty &&
          !BoardShape.values.any((s) => s.name == calibrationShape))) {
    throw ArgumentError('Invalid AI calibration selection');
  }
}

Future<Map<String, Object?>> calibrateAi(BoardShape shape, int tier) async {
  final defaults = MatchConfig.defaults(shape);
  final players =
      calibrationPlayers == 0 ? defaults.seats.length : calibrationPlayers;
  final size = calibrationSize == 0 ? defaults.size : calibrationSize;
  const pairs = calibrationPairs, maxPlies = calibrationMaxPlies;
  if (pairs < 1 || players < 2 || players > 4 || tier < 0 || tier > 2) {
    throw ArgumentError('Use positive pairs, 2–4 seats and adjacent tiers 0–2');
  }
  var strongerWins = 0, weakerWins = 0, draws = 0, unfinished = 0;
  final depths = <String, List<int>>{};
  final timeouts = <String, int>{};
  for (var seed = 0; seed < pairs; seed++) {
    for (var swap = 0; swap < players; swap++) {
      final stronger = players == 2
          ? (swap == 0 ? SeatId.charcoal : SeatId.ivory)
          : SeatId.values[swap];
      final config = MatchConfig(shape: shape, size: size, seats: [
        for (final id in SeatId.values.take(players))
          SeatConfig(id,
              control: SeatControl.ai,
              level: BotLevel.values[id == stronger ? tier + 1 : tier]),
      ]);
      var game = MatchState.initial(config);
      final random = Random(seed);
      for (var opening = 0; opening < players; opening++) {
        final legal = MatchRules.legalMoves(game).toList();
        game = MatchRules.play(game, legal[random.nextInt(legal.length)])!;
      }
      final moves = <Map<String, dynamic>>[];
      while (!game.finished && game.ply < maxPlies) {
        final level = config.seat(game.current).level;
        final move = await MatchAI(level, yieldDuringSearch: false,
            onSearchComplete: (stats) {
          depths.putIfAbsent(level.name, () => []).add(stats.completedDepth);
          if (stats.timedOut) {
            timeouts.update('${level.name}:${stats.stage}', (v) => v + 1,
                ifAbsent: () => 1);
          }
        }).choose(game);
        if (move == null) throw StateError('AI returned no move');
        moves.add(move.toMap(game.current));
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
            'size': size,
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
  final result = <String, Object?>{
    'sample': pairs >= 50 ? 'qualification-candidate' : 'exploratory',
    'engine': MatchConfig.currentAiEngine,
    'shape': shape.name,
    'size': size,
    'tier': tier,
    'pairs': pairs,
    'players': players,
    'maxPlies': maxPlies,
    'strongerWins': strongerWins,
    'weakerWins': weakerWins,
    'draws': draws,
    'unfinished': unfinished,
    'strongerWinRate': decisive == 0 ? null : strongerWins / decisive,
    'perSeatWinShare': decisive == 0
        ? null
        : strongerWins / (strongerWins + weakerWins / (players - 1)),
    'averageCompletedDepth':
        depths.map((k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length)),
    'timeouts': timeouts
  };
  print('AI_TOURNAMENT ${jsonEncode(result)}');
  return result;
}

void qualifyAi(Map<String, Object?> result) {
  final trials = (result['pairs']! as int) * (result['players']! as int);
  final wins = result['strongerWins']! as int;
  final losses = result['weakerWins']! as int;
  final draws = result['draws']! as int;
  if ((result['pairs']! as int) < 50 ||
      wins + losses + draws < (trials * .8).ceil() ||
      wins + losses < (trials * .5).ceil() ||
      ((result['perSeatWinShare'] as double?) ?? 0) <= .6) {
    throw StateError(
        'Adjacent-tier qualification requires 50 seeded rotations, '
        '80% completion, 50% decisive trials and >60% per-seat win share: $result');
  }
}

Future<void> main() async {
  validateCalibrationSelection();
  var failed = false;
  for (final shape in BoardShape.values
      .where((s) => calibrationShape.isEmpty || s.name == calibrationShape)) {
    for (var tier = 0; tier < 3; tier++) {
      if (calibrationTier >= 0 && tier != calibrationTier) continue;
      final result = await calibrateAi(shape, tier);
      if (calibrationPairs >= 50) {
        try {
          qualifyAi(result);
        } catch (error) {
          failed = true;
          print(error);
        }
      }
    }
  }
  if (failed) {
    throw StateError('AI qualification failed; see AI_TOURNAMENT records.');
  }
}
