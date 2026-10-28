// Same-position four-arm diagnostics. Game qualification is a separate runner.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:stones/game/ai_position.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

import 'ai_qualification.dart' show Worker, percentile, sha;

Future<void> main(List<String> args) async {
  String option(String key, String fallback) =>
      args
          .where((arg) => arg.startsWith('--$key='))
          .map((arg) => arg.substring(key.length + 3))
          .firstOrNull ??
      fallback;
  final directory = option('binaries', '/tmp/stones-ai-duel');
  final output = File(option('output', '/tmp/stones-ai-duel-benchmark.jsonl'));
  final samples = int.parse(option('samples', '2'));
  final levels = option('levels', 'easy,medium,hard,expert')
      .split(',')
      .map(BotLevel.values.byName)
      .toList();
  final heldOut = args.contains('--held-out');
  final counterOnly = args.contains('--counterexample-only');
  final selected = option('profile', 'all');
  final caseInput = option('input', '');
  final targetPlies =
      option('plies', '2,10,24').split(',').map(int.parse).toList();
  final sortedPlies = targetPlies.toList()..sort();
  if (caseInput.isNotEmpty && heldOut ||
      targetPlies.isEmpty ||
      targetPlies.any((p) => p < 0) ||
      targetPlies.toSet().length != targetPlies.length ||
      targetPlies.join(',') != sortedPlies.join(',') ||
      samples < 1 ||
      levels.isEmpty ||
      levels.toSet().length != levels.length ||
      heldOut && counterOnly ||
      output.existsSync() ||
      File('${output.path}.manifest.json').existsSync()) {
    throw ArgumentError('Invalid selection or output already exists');
  }
  final profiles = [
    (BoardShape.square, 5, 2),
    (BoardShape.hex, 2, 2),
    (BoardShape.square, 8, 2),
    (BoardShape.hex, 4, 2),
  ];
  String profileKey((BoardShape, int, int) p) => '${p.$1.name}-${p.$2}-${p.$3}';
  if (!profiles.any((p) => selected == 'all' || selected == profileKey(p))) {
    throw ArgumentError('Unknown duel profile');
  }
  final manifests = <String, Map<String, dynamic>>{};
  for (final arm in option('arms', 'R,S,E,SE').split(',')) {
    final manifest =
        jsonDecode(File('$directory/$arm.manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    if (manifest['arm'] != arm ||
        manifest['binarySha256'] != await sha('$directory/$arm')) {
      throw StateError('Binary provenance mismatch: $arm');
    }
    manifests[arm] = manifest;
  }
  final cases = <Map<String, dynamic>>[];
  if (!heldOut && caseInput.isEmpty) {
    final row = jsonDecode(File('docs/qa/ai-balance-hex-counterexample.jsonl')
        .readAsStringSync()) as Map;
    final original =
        MatchConfig.fromMap(Map<String, dynamic>.from(row['config']));
    for (var rotation = 0; rotation < 6; rotation++) {
      for (final swap in [false, true]) {
        Cell rotate(Cell c) {
          for (var i = 0; i < rotation; i++) {
            c = Cell(-c.y, c.x + c.y);
          }
          return c;
        }

        SeatId color(SeatId id) => !swap
            ? id
            : id == SeatId.ivory
                ? SeatId.charcoal
                : SeatId.ivory;
        final config = original.copyWith(starter: color(original.starter));
        final moves = [
          for (final raw in (row['moves'] as List).take(5))
            {
              ...Map<String, dynamic>.from(raw),
              'seat': color(SeatId.values.byName(raw['seat'] as String)).name,
              'x': rotate(Cell(raw['x'] as int, raw['y'] as int)).x,
              'y': rotate(Cell(raw['x'] as int, raw['y'] as int)).y
            }
        ];
        cases.add({
          'profile': 'hex-2-2',
          'case': 'quiet-defense',
          'rotation': rotation,
          'colorSwap': swap,
          'seed': null,
          'config': config.toMap(),
          'moves': moves
        });
      }
    }
  }
  if (!counterOnly && caseInput.isEmpty) {
    for (final profile in profiles
        .where((p) => selected == 'all' || selected == profileKey(p))) {
      final config = MatchConfig(
          shape: profile.$1,
          size: profile.$2,
          seats: SeatId.values.take(2).map(SeatConfig.new).toList());
      for (var seed = 0; seed < samples; seed++) {
        final actualSeed =
            int.parse(option('seed-start', heldOut ? '200000' : '10000')) +
                seed;
        final random = Random(actualSeed);
        var game = MatchState.initial(config);
        final moves = <Map<String, dynamic>>[];
        for (final targetPly in targetPlies) {
          while (!game.finished && game.ply < targetPly) {
            final legal = MatchRules.legalMoves(game).toList();
            final move = legal[random.nextInt(legal.length)];
            moves.add(move.toMap(game.current));
            game = MatchRules.play(game, move)!;
          }
          if (game.finished) break;
          cases.add({
            'profile': profileKey(profile),
            'case': 'ply-$targetPly',
            'seed': actualSeed,
            'config': config.toMap(),
            'moves': List.of(moves)
          });
        }
      }
    }
  }
  if (caseInput.isNotEmpty) {
    for (final line in File(caseInput).readAsLinesSync()) {
      cases.add(Map<String, dynamic>.from(jsonDecode(line) as Map));
    }
  }
  output.parent.createSync(recursive: true);
  File('${output.path}.manifest.json').writeAsStringSync(jsonEncode({
    'runtime': Platform.version,
    if (caseInput.isNotEmpty) 'caseInputSha256': await sha(caseInput),
    'runnerSha256': await sha('tools/ai_duel_benchmark.dart'),
    'arms': manifests,
    'heldOut': heldOut,
    'samples': samples,
    'plies': targetPlies,
    'seedStart': int.parse(option('seed-start', heldOut ? '200000' : '10000')),
    'levels': levels.map((l) => l.name).toList(),
    'profile': selected,
    'scope': 'Same-position diagnostics, not game-strength qualification',
  }));
  final workers = <String, Worker>{};
  final rows = <Map<String, dynamic>>[];
  final log = output.openWrite();
  try {
    for (final arm in manifests.keys) {
      workers[arm] = Worker(await Process.start('$directory/$arm', []));
    }
    for (var index = 0; index < cases.length; index++) {
      final position = cases[index];
      var game = MatchState.initial(
          MatchConfig.fromMap(position['config'] as Map<String, dynamic>));
      for (final move in position['moves'] as List) {
        game = MatchRules.play(
            game, MatchMove.fromMap(Map<String, dynamic>.from(move)))!;
      }
      for (final level in levels) {
        final responses = <String, Map<String, dynamic>>{};
        final arms = manifests.keys.toList();
        // Balance fixed ordering effects; never run decisions concurrently.
        final start = (index + level.index) % arms.length;
        for (var n = 0; n < arms.length; n++) {
          final arm = arms[(start + n) % arms.length];
          final response = await workers[arm]!.ask({
            'id': '$index:${level.name}:$arm',
            'config': position['config'],
            'moves': position['moves'],
            'level': level.name,
          });
          if (response['position'] != aiPositionKey(game) ||
              MatchRules.play(
                      game,
                      MatchMove.fromMap(Map<String, dynamic>.from(
                          response['move'] as Map))) ==
                  null) {
            throw StateError('Worker position or move mismatch');
          }
          if (arm != 'R' && arm != 'RT') {
            final settings = manifests[arm]!['buildSettings'] as Map;
            final actual = response['experiment'] as Map;
            if (settings.length != actual.length ||
                settings.entries.any((e) => e.value is List
                    ? jsonEncode(actual[e.key]) != jsonEncode(e.value)
                    : actual[e.key] != e.value)) {
              throw StateError('Compiled experiment settings mismatch: $arm');
            }
          }
          responses[arm] = response;
        }
        final row = {...position, 'level': level.name, 'responses': responses};
        rows.add(row);
        log.writeln(jsonEncode(row));
        await log.flush();
        stdout.writeln(
            'AI_DUEL_CASE $index ${position['profile']} ${level.name} '
            '${responses.map((a, r) => MapEntry(a, '${r['elapsedMs']}ms/d${r['depth']}'))}');
      }
    }
  } finally {
    await log.close();
    for (final worker in workers.values) {
      await worker.close();
    }
  }
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    groups.putIfAbsent('${row['profile']}:${row['level']}', () => []).add(row);
  }
  final comparisons = {
    'S-R': ('S', 'R'),
    'E-R': ('E', 'R'),
    'SE-R': ('SE', 'R'),
    'SE-S': ('SE', 'S'),
    'F-R': ('F', 'R'),
    'RT-R': ('RT', 'R'),
    'G-R': ('G', 'R'),
    'G-RT': ('G', 'RT'),
    'G-F': ('G', 'F')
  };
  final summaries = [
    for (final group in groups.entries)
      for (final pair in comparisons.entries)
        if (manifests.containsKey(pair.value.$1) &&
            manifests.containsKey(pair.value.$2))
          {
            'group': group.key,
            'comparison': pair.key,
            'positions': group.value.length,
            'candidateP95Ms': percentile([
              for (final row in group.value)
                (row['responses'] as Map)[pair.value.$1]['elapsedMs'] as num
            ], .95),
            'referenceP95Ms': percentile([
              for (final row in group.value)
                (row['responses'] as Map)[pair.value.$2]['elapsedMs'] as num
            ], .95),
            'candidateEmergencyFallbacks': group.value
                .where((row) =>
                    (row['responses'] as Map)[pair.value.$1]
                        ['emergencyFallback'] ==
                    true)
                .length,
          }
  ];
  File('${output.path}.summary.json').writeAsStringSync(jsonEncode({
    'sample': heldOut ? 'held-out' : 'development',
    'cases': rows.length,
    'duelTimingCoverageComplete': heldOut &&
        caseInput.isEmpty &&
        samples >= 50 &&
        selected == 'all' &&
        levels.length == 4 &&
        ['R', 'S', 'E', 'SE'].every(manifests.containsKey),
    'qualificationComplete': false,
    'strengthQualified': false,
    'selectedPairedP95Passed': summaries.every((row) =>
        (row['candidateP95Ms'] as num) <= (row['referenceP95Ms'] as num)),
    'comparisons': summaries,
  }));
}
