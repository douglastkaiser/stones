// Resumable native qualification. Each worker stays alive; decisions run sequentially.
// See docs/AI_UPGRADES.md for the matrix and gates. Never labels unfinished as draws.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

class Worker {
  Worker(this.process)
      : lines = StreamIterator(process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
    process.stderr.listen(stderr.add);
  }
  final Process process;
  final StreamIterator<String> lines;
  Future<Map<String, dynamic>> ask(Map<String, Object?> request) async {
    process.stdin.writeln(jsonEncode(request));
    if (!await lines.moveNext()) {
      throw StateError('Worker exited: ${await process.exitCode}');
    }
    final response = jsonDecode(lines.current) as Map<String, dynamic>;
    if (response.containsKey('error')) {
      throw StateError(response['error'].toString());
    }
    if (response['id'] != request['id']) {
      throw StateError('Worker response mismatch');
    }
    return response;
  }

  Future<void> close() async {
    await process.stdin.close();
    await process.exitCode;
    await lines.cancel();
  }
}

const profiles = [
  (BoardShape.square, 5, 2),
  (BoardShape.hex, 2, 3),
  (BoardShape.square, 8, 2),
  (BoardShape.square, 8, 3),
  (BoardShape.square, 8, 4),
  (BoardShape.hex, 4, 2),
  (BoardShape.hex, 4, 3),
  (BoardShape.hex, 4, 4)
];
String profileKey((BoardShape, int, int) p) => '${p.$1.name}-${p.$2}-${p.$3}';
Future<String> sha(String path) async {
  final result = await Process.run('sha256sum', [path]);
  if (result.exitCode != 0) throw StateError('Cannot hash $path');
  return result.stdout.toString().split(' ').first;
}

// Keep full replay evidence on disk, retaining only gate inputs in memory.
Map<String, dynamic> compactTrial(Map<String, dynamic> row) => {
      for (final key in [
        'id',
        'group',
        'players',
        'targetSeats',
        'finished',
        'winner',
        'targetWon'
      ])
        key: row[key],
      'candidateTimes': [
        for (final d in row['decisions'] as List)
          if (d['paired'] == true) d['candidate']['elapsedMs']
      ],
      'baselineTimes': [
        for (final d in row['decisions'] as List)
          if (d['paired'] == true) d['baseline']['elapsedMs']
      ],
    };

/// A crash may leave a partial final write. Only newline-committed games resume;
/// malformed complete records still fail loudly rather than changing evidence.
Future<List<Map<String, dynamic>>> load(File file) async {
  if (!file.existsSync()) return [];
  final handle = file.openSync(mode: FileMode.append);
  try {
    final length = handle.lengthSync();
    if (length > 0) {
      handle.setPositionSync(length - 1);
      if (handle.readByteSync() != 10) {
        var cursor = length;
        var committedEnd = 0;
        while (cursor > 0) {
          final start = max(0, cursor - 65536);
          handle.setPositionSync(start);
          final chunk = handle.readSync(cursor - start);
          final newline = chunk.lastIndexOf(10);
          if (newline >= 0) {
            committedEnd = start + newline + 1;
            break;
          }
          cursor = start;
        }
        handle.truncateSync(committedEnd);
      }
    }
  } finally {
    handle.closeSync();
  }
  final rows = <Map<String, dynamic>>[];
  await for (final line in file
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    if (line.isNotEmpty) {
      rows.add(compactTrial(jsonDecode(line) as Map<String, dynamic>));
    }
  }
  return rows;
}

double percentile(List<num> values, double fraction) {
  if (values.isEmpty) return double.nan;
  final sorted = values.toList()..sort();
  return sorted[max(0, (sorted.length * fraction).ceil() - 1)].toDouble();
}

Map<String, Object?> summarize(
    List<Map<String, dynamic>> games, int seeds, String mode) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final game in games) {
    groups.putIfAbsent(game['group'] as String, () => []).add(game);
  }
  var allPassed = groups.isNotEmpty;
  var targetPerSeatWins = 0.0, otherPerSeatWins = 0.0;
  final summaries = <Map<String, Object?>>[];
  for (final entry in groups.entries) {
    final rows = entry.value;
    final players = rows.first['players'] as int;
    final finished = rows.where((r) => r['finished'] == true).length;
    final decisive = rows.where((r) => r['winner'] != null).length;
    final wins = rows.where((r) => r['targetWon'] == true).length;
    final losses = decisive - wins;
    final targetSeats = rows.first['targetSeats'] as int;
    targetPerSeatWins += wins / targetSeats;
    otherPerSeatWins += losses / (players - targetSeats);
    final share = decisive == 0
        ? 0.0
        : (wins / targetSeats) /
            (wins / targetSeats + losses / (players - targetSeats));
    final candidateTimes = <num>[], baselineTimes = <num>[];
    for (final row in rows) {
      if (row.containsKey('candidateTimes')) {
        candidateTimes.addAll((row['candidateTimes'] as List).cast<num>());
        baselineTimes.addAll((row['baselineTimes'] as List).cast<num>());
        continue;
      }
      for (final decision in row['decisions'] as List) {
        if (decision['paired'] == true) {
          candidateTimes.add(decision['candidate']['elapsedMs'] as num);
          baselineTimes.add(decision['baseline']['elapsedMs'] as num);
        }
      }
    }
    final enough = seeds >= 50 && rows.length >= seeds * players;
    final strength = mode == 'adjacent'
        ? share > .6
        : mode == 'regression'
            ? share >= .5
            : false;
    final latency = candidateTimes.length >= 50 &&
        percentile(candidateTimes, .95) <= percentile(baselineTimes, .95);
    final passed = enough &&
        finished >= (rows.length * .8).ceil() &&
        decisive >= (rows.length * .5).ceil() &&
        strength;
    allPassed = allPassed && passed;
    summaries.add({
      'group': entry.key,
      'games': rows.length,
      'finished': finished,
      'decisive': decisive,
      'wins': wins,
      'losses': losses,
      'unfinished': rows.length - finished,
      'normalizedShare': share,
      'strengthGate': passed,
      'pairedDecisions': candidateTimes.length,
      'candidateP95Ms':
          candidateTimes.isEmpty ? null : percentile(candidateTimes, .95),
      'baselineP95Ms':
          baselineTimes.isEmpty ? null : percentile(baselineTimes, .95),
      'latencyGate': latency
    });
  }
  final expectedGroups = mode == 'adjacent'
      ? 24
      : mode == 'regression'
          ? 26
          : 0;
  final complete = expectedGroups > 0 && groups.length == expectedGroups;
  final aggregateImproved = targetPerSeatWins > otherPerSeatWins;
  final allLatency = summaries.isNotEmpty &&
      summaries.every((row) => row['latencyGate'] == true);
  return {
    'matrixComplete': complete,
    'aggregateImproved': aggregateImproved,
    'allSelectedLatencyGatesPassed': allLatency,
    'qualified': complete &&
        allPassed &&
        allLatency &&
        (mode != 'regression' || aggregateImproved),
    'mode': mode,
    'sample': seeds >= 50 ? 'qualification-candidate' : 'exploratory',
    'allSelectedStrengthGatesPassed': allPassed,
    'groups': summaries
  };
}

Future<void> main(List<String> args) async {
  if (args.contains('--help')) {
    stdout.writeln(
        '--mode=adjacent|regression|tune --seeds=50 --profile=all --tier=-1 --paired --pilot --max-games=0 --output=PATH --candidate=PATH --baseline=PATH --weights=0,4,4,4');
    return;
  }
  String option(String name, String fallback) =>
      args
          .where((s) => s.startsWith('--$name='))
          .firstOrNull
          ?.split('=')
          .skip(1)
          .join('=') ??
      fallback;
  final mode = option('mode', 'adjacent');
  final seeds = int.parse(option('seeds', '50'));
  final output = File(option('output', '/tmp/stones-ai-$mode.jsonl'));
  final selected = option('profile', 'all');
  final tierSelection = int.parse(option('tier', '-1'));
  final candidatePath = option('candidate', '/tmp/stones-ai-candidate');
  final baselinePath = option('baseline', '/tmp/stones-ai-baseline');
  final pilot = args.contains('--pilot');
  final paired = args.contains('--paired');
  final maxGames = int.parse(option('max-games', '0'));
  if (maxGames < 0 ||
      !['adjacent', 'regression', 'tune'].contains(mode) ||
      seeds < 1 ||
      tierSelection < -1 ||
      tierSelection > 3) {
    throw ArgumentError('Invalid matrix selection');
  }
  final matrix = profiles
      .where((p) => selected == 'all' || profileKey(p) == selected)
      .toList();
  if (matrix.isEmpty) throw ArgumentError('Unknown profile');
  final weights = option('weights', '').isEmpty
      ? null
      : option('weights', '').split(',').map(double.parse).toList();
  if (weights != null && weights.length != 4) {
    throw ArgumentError('Four material weights required');
  }
  final outputLock =
      File('${output.path}.lock').openSync(mode: FileMode.append);
  try {
    outputLock.lockSync();
    final sourceHashes = <String, String>{};
    for (final file in [
      'lib/game/match_ai_engine.dart',
      'lib/game/ai_material.dart',
      'lib/game/ai_search_cache.dart',
      'lib/game/ai_position.dart',
      'lib/game/ai_tactics.dart',
      'tools/ai_worker.dart',
      'tools/ai_worker_protocol.dart'
    ]) {
      sourceHashes[file] = await sha(file);
    }
    final manifest = <String, Object?>{
      'sourceHashes': sourceHashes,
      'runnerSha256': await sha('tools/ai_qualification.dart'),
      'protocol': 1,
      'mode': mode,
      'seeds': seeds,
      'seedStart': pilot ? 0 : 100000,
      'profile': selected,
      'tier': tierSelection,
      'paired': paired,
      'weights': weights,
      'candidateSha256': await sha(candidatePath),
      'baselineSha256': await sha(baselinePath),
      'runtime': Platform.version,
      'os': Platform.operatingSystem,
      'budgetsMs': [200, 500, 1200, 2200],
      'engine': MatchConfig.currentAiEngine,
      'sourceSha256': await sha('lib/game/match_ai_engine.dart'),
      'rulesSha256': await sha('lib/game/match_rules.dart'),
    };
    final manifestFile = File('${output.path}.manifest.json');
    if (manifestFile.existsSync() &&
        jsonEncode(jsonDecode(manifestFile.readAsStringSync())) !=
            jsonEncode(manifest)) {
      throw StateError('Resume manifest differs; use a new output file');
    }
    manifestFile.writeAsStringSync('${jsonEncode(manifest)}\n');
    final records = await load(output);
    final done = records.map((r) => r['id']).toSet();
    final candidate = Worker(await Process.start(candidatePath, []));
    final baseline = Worker(await Process.start(baselinePath, []));
    final log = output.openWrite(mode: FileMode.append);
    var added = 0;
    try {
      matrixLoop:
      for (final profile in matrix) {
        final players = profile.$3;
        final tiers = mode == 'adjacent'
            ? [0, 1, 2]
            : mode == 'regression'
                ? [2, 3]
                : [1];
        for (final tier
            in tiers.where((t) => tierSelection < 0 || t == tierSelection)) {
          final counts =
              mode == 'regression' && players > 2 ? [1, players - 1] : [1];
          for (final targetSeats in counts) {
            final group = '${profileKey(profile)}:$tier:$targetSeats';
            for (var seed = 0; seed < seeds; seed++) {
              for (var rotation = 0; rotation < players; rotation++) {
                final id = '$group:$seed:$rotation';
                if (done.contains(id)) continue;
                if (maxGames > 0 && added >= maxGames) break matrixLoop;
                final target = {
                  for (var i = 0; i < targetSeats; i++)
                    SeatId.values[(i + rotation) % players]
                };
                final cfg =
                    MatchConfig(shape: profile.$1, size: profile.$2, seats: [
                  for (final seat in SeatId.values.take(players))
                    SeatConfig(seat,
                        control: SeatControl.ai,
                        level: BotLevel.values[
                            mode == 'adjacent' && target.contains(seat)
                                ? tier + 1
                                : tier])
                ]);
                var game = MatchState.initial(cfg);
                final limit = max(
                    160,
                    2 *
                        game.reserves.values
                            .fold<int>(0, (n, r) => n + r.total));
                final moves = <Map<String, dynamic>>[];
                final decisions = <Map<String, Object?>>[];
                final history = <String>[aiPositionKey(game)];
                var repetitions = 0;
                final random = Random(seed + (pilot ? 0 : 100000));
                for (var i = 0; i < players; i++) {
                  final legal = MatchRules.legalMoves(game).toList();
                  final move = legal[random.nextInt(legal.length)];
                  moves.add(move.toMap(game.current));
                  game = MatchRules.play(game, move)!;
                  history.add(aiPositionKey(game));
                }
                while (!game.finished && game.ply < limit) {
                  final request = <String, Object?>{
                    'id': '$id:${game.ply}',
                    'config': cfg.toMap(),
                    'moves': moves,
                    'level': cfg.seat(game.current).level.name
                  };
                  final isTarget = target.contains(game.current);
                  final useCandidate =
                      mode == 'adjacent' || mode == 'tune' || isTarget;
                  Map<String, dynamic> response;
                  Map<String, dynamic>? reference;
                  if (mode == 'tune') {
                    request['weights'] = isTarget ? weights : [0, 0, 0, 0];
                  } else if (weights != null) {
                    request['weights'] = weights;
                  }
                  if (paired) {
                    // Alternate order; no concurrent decisions or unequal contexts.
                    if (game.ply.isEven) {
                      response = await candidate.ask(request);
                      reference = await baseline.ask(request);
                    } else {
                      reference = await baseline.ask(request);
                      response = await candidate.ask(request);
                    }
                  } else {
                    response = await (useCandidate ? candidate : baseline)
                        .ask(request);
                  }
                  if (response['position'] != aiPositionKey(game) ||
                      reference != null &&
                          reference['position'] != response['position']) {
                    throw StateError('Position divergence');
                  }
                  final chosen =
                      paired && !useCandidate ? reference! : response;
                  final move = MatchMove.fromMap(
                      Map<String, dynamic>.from(chosen['move'] as Map));
                  decisions.add({
                    'ply': game.ply,
                    'seat': game.current.name,
                    'paired': paired,
                    'candidate': paired || useCandidate
                        ? (Map<String, dynamic>.from(response)
                          ..remove('position'))
                        : null,
                    'baseline': paired
                        ? (Map<String, dynamic>.from(reference!)
                          ..remove('position'))
                        : !useCandidate
                            ? (Map<String, dynamic>.from(response)
                              ..remove('position'))
                            : null
                  });
                  moves.add(move.toMap(game.current));
                  game = MatchRules.play(game, move) ??
                      (throw StateError('Illegal worker move'));
                  final key = aiPositionKey(game);
                  if (history.contains(key)) repetitions++;
                  history.add(key);
                  if (history.length > 64) history.removeAt(0);
                }
                final row = <String, dynamic>{
                  'id': id,
                  'group': group,
                  'profile': profileKey(profile),
                  'players': players,
                  'targetSeats': targetSeats,
                  'seed': seed + (pilot ? 0 : 100000),
                  'rotation': rotation,
                  'target': target.map((s) => s.name).toList(),
                  'config': cfg.toMap(),
                  'maxPlies': limit,
                  'finished': game.finished,
                  'winner': game.result?.winner?.name,
                  'reason': game.result?.reason.name,
                  'targetWon': target.contains(game.result?.winner),
                  'repetitions': repetitions,
                  'finalPosition': aiPositionKey(game),
                  'moves': moves,
                  'decisions': decisions
                };
                records.add(compactTrial(row));
                log.writeln(jsonEncode(row));
                await log.flush();
                done.add(id);
                added++;
                stdout.writeln(
                    'AI_GAME $id ${game.result?.winner?.name ?? (game.finished ? 'draw' : 'unfinished')} plies=${game.ply} repeats=$repetitions');
              }
            }
          }
        }
      }
    } finally {
      await log.close();
      await candidate.close();
      await baseline.close();
    }
    final report = summarize(records, seeds, mode);
    report['seedPartition'] = pilot ? 'pilot' : 'held-out';
    if (pilot) report['qualified'] = false;
    File('${output.path}.summary.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(report)}\n');
    stdout.writeln('AI_QUALIFICATION ${jsonEncode(report)}');
    if (!pilot &&
        maxGames == 0 &&
        (report['qualified'] != true ||
            matrix.length != 8 ||
            tierSelection >= 0)) {
      exitCode = 1;
    }
  } finally {
    outputLock.closeSync();
  }
}
