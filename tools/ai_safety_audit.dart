// Independently audit every recorded veto in games or same-position benchmarks.
import 'dart:convert';
import 'dart:io';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'ai_balance_proof.dart';
import 'ai_qualification.dart' show sha;

Future<void> main(List<String> args) async {
  final inputs = args
      .where((s) => s.startsWith('--input='))
      .map((s) => s.substring(8))
      .toList();
  final output =
      File(args.singleWhere((s) => s.startsWith('--output=')).substring(9));
  if (inputs.isEmpty || output.existsSync()) {
    throw ArgumentError('Inputs and new output required');
  }
  final records = <Map<String, Object?>>[];
  final sources = <Map<String, Object?>>[];
  final openings = <String, Set<String>>{};
  var games = 0, positions = 0;
  void audit(MatchState game, Map decision, MatchMove chosen,
      Map<String, Object?> context) {
    if ((decision['safetyVetoes'] as int? ?? 0) == 0) return;
    if (jsonEncode(chosen.toMap(game.current)) !=
        jsonEncode(decision['move'])) {
      throw StateError('Measured choice differs from replay');
    }
    final proposed = MatchMove.fromMap(
        Map<String, dynamic>.from(decision['safetyReplacedMove']));
    final old = MatchRules.play(game, proposed);
    final next = MatchRules.play(game, chosen);
    if (old == null || next == null) {
      throw StateError('Illegal counterfactual');
    }
    final rival = game.config.next(game.current);
    final horizon = decision['safetyPlies'] as int? ?? 3;
    final oldProof = BoundedDuelProof(maxNodes: 1000000);
    final oldResult = oldProof.solve(old, rival, horizon);
    final newProof = BoundedDuelProof(maxNodes: 1000000);
    final newResult = newProof.solve(next, rival, horizon);
    records.add({
      ...context,
      'ply': game.ply,
      'horizon': horizon,
      'position': aiPositionKey(game),
      'proposed': proposed.toMap(game.current),
      'chosen': chosen.toMap(game.current),
      'oldForcedQuickLoss': oldResult.name,
      'newForcedQuickLoss': newResult.name,
      'oldProofNodes': oldProof.expandedNodes,
      'newProofNodes': newProof.expandedNodes
    });
  }

  for (final input in inputs) {
    sources.add({
      'path': input,
      'sha256': await sha(input),
      'manifestSha256': await sha('$input.manifest.json')
    });
    for (final line in File(input).readAsLinesSync()) {
      final row = jsonDecode(line) as Map;
      final cfg = MatchConfig.fromMap(Map<String, dynamic>.from(row['config']));
      var game = MatchState.initial(cfg);
      final moves = row['moves'] as List;
      final opening = jsonEncode([
        cfg.shape.name,
        cfg.size,
        moves.take(2).map((m) => [m['x'], m['y'], m['type']]).toList()
      ]);
      final context = <String, Object?>{
        'input': input,
        'seed': row['seed'],
        'rotation': row['rotation']
      };
      if (row.containsKey('responses')) {
        for (final raw in moves) {
          game = MatchRules.play(
                  game, MatchMove.fromMap(Map<String, dynamic>.from(raw))) ??
              (throw StateError('Illegal sampled replay'));
        }
        for (final entry in (row['responses'] as Map).entries) {
          final response = entry.value as Map;
          if (response['position'] != aiPositionKey(game)) {
            throw StateError('Position differs');
          }
          audit(game, response,
              MatchMove.fromMap(Map<String, dynamic>.from(response['move'])), {
            ...context,
            'arm': entry.key,
            'level': row['level'],
            'case': row['case']
          });
        }
        openings
            .putIfAbsent('${row['profile']}/${row['level']}', () => {})
            .add(opening);
        positions++;
      } else {
        final decisions = {
          for (final raw in row['decisions'] as List) (raw as Map)['ply']: raw
        };
        for (final raw in moves) {
          final chosen = MatchMove.fromMap(Map<String, dynamic>.from(raw));
          final decision = decisions[game.ply];
          if (decision != null) audit(game, decision, chosen, context);
          game = MatchRules.play(game, chosen) ??
              (throw StateError('Illegal replay'));
        }
        if (!game.finished ||
            row['finished'] != true ||
            game.result?.winner?.name != row['winner'] ||
            aiPositionKey(game) != row['finalPosition']) {
          throw StateError('Replay completion differs from shared rules');
        }
        openings
            .putIfAbsent(
                '${cfg.shape.name}-${cfg.size}/${cfg.seats.first.level.name}',
                () => {})
            .add(opening);
        games++;
      }
    }
  }
  final passed = records.isNotEmpty &&
      records.every((r) =>
          r['oldForcedQuickLoss'] == 'proven' &&
          r['newForcedQuickLoss'] == 'refuted');
  final report = {
    'scope':
        'Every recorded replacement removes a proven finite-horizon forced-loss continuation; not eventual strength or intrinsic initiative.',
    'gamesReplayed': games,
    'positionsReplayed': positions,
    'distinctOpenings': openings.map((k, v) => MapEntry(k, v.length)),
    'changedDecisions': records.length,
    'passed': passed,
    'inputs': sources,
    'records': records,
    'runnerSha256': await sha('tools/ai_safety_audit.dart'),
    'independentSolverSha256': await sha('tools/ai_balance_proof.dart'),
    'rulesSha256': await sha('lib/game/match_rules.dart')
  };
  output.writeAsStringSync('${jsonEncode(report)}\n');
  stdout.writeln(jsonEncode({
    'gamesReplayed': games,
    'positionsReplayed': positions,
    'changedDecisions': records.length,
    'passed': passed
  }));
  if (!passed) exitCode = 1;
}
