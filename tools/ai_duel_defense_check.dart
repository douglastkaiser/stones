// Independent finite-horizon certificates for measured counterexample choices.
import 'dart:convert';
import 'dart:io';

import 'package:stones/game/ai_position.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

import 'ai_balance_proof.dart';
import 'ai_qualification.dart' show sha;

typedef DefenseClassification = ({
  SeatId attacker,
  DuelProof verdict,
  int nodes,
  int cacheHits,
  int elapsedMs
});

DefenseClassification classifyQuickLoss(MatchState game, MatchMove move) {
  final next = MatchRules.play(game, move);
  if (next == null) throw StateError('Illegal measured choice');
  final attacker = game.config.next(game.current);
  final solver = BoundedDuelProof();
  final verdict = solver.solve(next, attacker, 3);
  return (
    attacker: attacker,
    verdict: verdict,
    nodes: solver.expandedNodes,
    cacheHits: solver.cacheHits,
    elapsedMs: solver.elapsedMs
  );
}

Future<void> main(List<String> args) async {
  String option(String key, String fallback) =>
      args
          .where((arg) => arg.startsWith('--$key='))
          .map((arg) => arg.substring(key.length + 3))
          .firstOrNull ??
      fallback;
  final input = File(option('input', ''));
  final output =
      File(option('output', '/tmp/stones-ai-duel-defense-proof.json'));
  if (!input.existsSync() || output.existsSync()) {
    throw ArgumentError('Input required and output must be new');
  }
  final allCases = args.contains('--all-cases');
  final expectedCases = int.parse(option('expected-cases', '12'));
  final manifest =
      jsonDecode(File('${input.path}.manifest.json').readAsStringSync()) as Map;
  final rulesHash = await sha('lib/game/match_rules.dart');
  for (final source in (manifest['arms'] as Map).values) {
    if (source['sourceFiles']['lib/game/match_rules.dart'] != rulesHash) {
      throw StateError('Proof rules differ from measured engine rules');
    }
  }
  final records = <Map<String, dynamic>>[];
  final identities = <String>{};
  final groups = <String, Map<String, int>>{};
  for (final line in input.readAsLinesSync()) {
    final row = jsonDecode(line) as Map;
    if (!allCases && row['case'] != 'quiet-defense') continue;
    final config =
        MatchConfig.fromMap(Map<String, dynamic>.from(row['config']));
    var game = MatchState.initial(config);
    for (final move in row['moves'] as List) {
      game = MatchRules.play(
          game, MatchMove.fromMap(Map<String, dynamic>.from(move)))!;
    }
    if (config.seats.length != 2 ||
        (!allCases &&
            (game.ply != 5 ||
                config.shape.name != 'hex' ||
                config.size != 2))) {
      throw StateError('Expected the five-ply Hex counterexample');
    }
    for (final entry in (row['responses'] as Map).entries) {
      final arm = entry.key as String;
      final response = entry.value as Map;
      if (response['position'] != aiPositionKey(game)) {
        throw StateError('Measured position mismatch');
      }
      final identity =
          '$arm:${row['level']}:${row['profile']}:${row['seed']}:${row['case']}:${row['rotation']}:${row['colorSwap']}';
      if (!identities.add(identity)) {
        throw StateError('Duplicate counterexample identity');
      }
      final classified = classifyQuickLoss(
          game,
          MatchMove.fromMap(
              Map<String, dynamic>.from(response['move'] as Map)));
      final verdict = classified.verdict;
      final group = groups.putIfAbsent('$arm:${row['level']}',
          () => {'proven': 0, 'refuted': 0, 'unknown': 0});
      group[verdict.name] = group[verdict.name]! + 1;
      records.add({
        'arm': arm,
        'level': row['level'],
        'rotation': row['rotation'],
        'colorSwap': row['colorSwap'],
        'attacker': classified.attacker.name,
        'move': response['move'],
        'remainingPlies': 3,
        'verdict': verdict.name,
        'expandedNodes': classified.nodes,
        'cacheHits': classified.cacheHits,
        'elapsedMs': classified.elapsedMs,
        'binarySha256': manifest['arms'][arm]['binarySha256']
      });
    }
  }
  final covered = [
    for (final arm in option('arms', 'S,E,SE').split(','))
      for (final level in ['hard', 'expert']) '$arm:$level'
  ];
  final passed = covered.every((key) =>
      groups[key]?['refuted'] == expectedCases &&
      groups[key]?['proven'] == 0 &&
      groups[key]?['unknown'] == 0);
  final report = {
    'scope': allCases
        ? 'Three-ply forced-loss objectives on measured candidate moves; not eventual strength'
        : 'Refutes only the recorded ninth-move win, not an eventual game result',
    'inputSha256': await sha(input.path),
    'manifestSha256': await sha('${input.path}.manifest.json'),
    'rulesSha256': rulesHash,
    'solverSha256': await sha('tools/ai_balance_proof.dart'),
    'runnerSha256': await sha('tools/ai_duel_defense_check.dart'),
    'runtime': Platform.version,
    'requiredTransformedDefenseGatePassed': passed,
    'groups': groups,
    'records': records,
  };
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('${jsonEncode(report)}\n');
  stdout.writeln(jsonEncode(
      {'requiredTransformedDefenseGatePassed': passed, 'groups': groups}));
  if (!passed) exitCode = 1;
}
