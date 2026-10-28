// Certify the actual recorded AI replies, rather than assume perfect defense.
import 'dart:convert';
import 'dart:io';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'ai_qualification.dart' show Worker, sha, binaryProvenance;

bool impossibleByMaterial(MatchState game, SeatId attacker, int remaining) {
  final stones = game.board.values.expand((s) => s).toList();
  final turns = [
    for (var i = 0; i < remaining; i++)
      if (game.config.turnAt(game.ply + i) == attacker) i
  ].length;
  return !game.opening &&
      stones.length + remaining < game.geometry.cells.length &&
      game.reserves.values.every((r) => r.total > remaining) &&
      stones.where((s) => s.seat == attacker).length + turns <
          game.geometry.carryLimit;
}

String moveKey(MatchState game, MatchMove move) =>
    jsonEncode(move.toMap(game.current));

/// Independent checker: only the shared game rules and certificate, no AI
/// evaluator, move ordering, tactical kernel or search cache are consulted.
bool verifyPolicy(MatchState game, SeatId attacker, int remaining, Map node) {
  if (node['position'] != aiPositionKey(game)) {
    throw StateError('Certificate position differs');
  }
  switch (node['kind']) {
    case 'end':
      if (!game.finished && remaining != 0) throw StateError('Premature end');
      return game.result?.winner != attacker;
    case 'material':
      if (!impossibleByMaterial(game, attacker, remaining)) {
        throw StateError('Invalid material certificate');
      }
      return true;
    case 'last-attacks':
      if (remaining != 1 || game.current != attacker) {
        throw StateError('Invalid attack frontier');
      }
      final expected = {
        for (final move in MatchRules.legalMoves(game))
          if (MatchRules.play(game, move)!.result?.winner == attacker)
            moveKey(game, move)
      };
      final actual = (node['winningMoves'] as List).cast<String>().toSet();
      if (actual.length != expected.length || !actual.containsAll(expected)) {
        throw StateError('Incomplete final attacks');
      }
      return expected.isEmpty;
    case 'choice':
      if (game.current == attacker || remaining <= 0) {
        throw StateError('Incorrect AI turn');
      }
      final move = MatchMove.fromMap(Map<String, dynamic>.from(node['move']));
      final response = node['response'];
      if (response is! Map ||
          response['position'] != aiPositionKey(game) ||
          moveKey(
                  game,
                  MatchMove.fromMap(
                      Map<String, dynamic>.from(response['move']))) !=
              moveKey(game, move)) {
        throw StateError('Recorded worker reply differs from certificate');
      }
      final next = MatchRules.play(game, move);
      if (next == null) throw StateError('Illegal AI reply');
      return verifyPolicy(next, attacker, remaining - 1, node['child'] as Map);
    case 'attacks':
      if (game.current != attacker || remaining <= 1) {
        throw StateError('Incorrect attack turn');
      }
      final children = node['children'] as List;
      final expected = {
        for (final move in MatchRules.legalMoves(game)) moveKey(game, move)
      };
      final actual = <String>{};
      var safe = true;
      for (final child in children) {
        final move =
            MatchMove.fromMap(Map<String, dynamic>.from(child['move']));
        if (!actual.add(moveKey(game, move))) {
          throw StateError('Duplicate attack');
        }
        final next = MatchRules.play(game, move);
        if (next == null) throw StateError('Illegal attack');
        if (!verifyPolicy(
            next, attacker, remaining - 1, child['node'] as Map)) {
          safe = false;
        }
      }
      if (actual.length != expected.length || !actual.containsAll(expected)) {
        throw StateError('Missing legal attack');
      }
      return safe;
    default:
      throw StateError('Unknown certificate node');
  }
}

Future<void> main(List<String> args) async {
  String option(String key, String fallback) =>
      args
          .where((s) => s.startsWith('--$key='))
          .map((s) => s.substring(key.length + 3))
          .firstOrNull ??
      fallback;
  final verify = option('verify', '');
  if (verify.isNotEmpty) {
    final report = jsonDecode(File(verify).readAsStringSync()) as Map;
    if (report['rulesSha256'] != await sha('lib/game/match_rules.dart')) {
      throw StateError('Certificate rules differ');
    }
    var game = MatchState.initial(
        MatchConfig.fromMap(Map<String, dynamic>.from(report['config'])));
    for (final move in report['moves'] as List) {
      game = MatchRules.play(
              game, MatchMove.fromMap(Map<String, dynamic>.from(move))) ??
          (throw StateError('Illegal certificate prefix'));
    }
    final safe = verifyPolicy(
        game,
        SeatId.values.byName(report['attacker'] as String),
        report['horizon'] as int,
        report['tree'] as Map);
    if (safe != report['verifiedRecordedPolicySafe']) {
      throw StateError('Certificate claim differs');
    }
    stdout.writeln(jsonEncode(
        {'verifiedRecordedPolicySafe': safe, 'certificate': verify}));
    if (!safe) exitCode = 1;
    return;
  }
  final replay =
      File(option('replay', 'docs/qa/ai-balance-hex-counterexample.jsonl'));
  final row =
      jsonDecode(replay.readAsLinesSync()[int.parse(option('game', '0'))])
          as Map;
  var initial = MatchState.initial(
      MatchConfig.fromMap(Map<String, dynamic>.from(row['config'])));
  final records = [
    for (final m in (row['moves'] as List).take(int.parse(option('ply', '5'))))
      Map<String, dynamic>.from(m)
  ];
  for (final record in records) {
    initial = MatchRules.play(initial, MatchMove.fromMap(record))!;
  }
  final attacker =
      SeatId.values.byName(option('attacker', initial.config.starter.name));
  final horizon = int.parse(option('plies', '4'));
  final output = File(option('output', '/tmp/stones-policy-certificate.json'));
  final binary = option('candidate', '');
  if (initial.config.seats.length != 2 || horizon < 1 || output.existsSync()) {
    throw ArgumentError(
        'Unfinished duel, positive horizon and new output required');
  }
  final provenance = await binaryProvenance(binary);
  if (provenance == null ||
      provenance['sourceFiles']['lib/game/match_rules.dart'] !=
          await sha('lib/game/match_rules.dart')) {
    throw StateError('Policy/rules provenance differs');
  }
  final worker = Worker(await Process.start(binary, []));
  var calls = 0;
  Future<Map<String, dynamic>> visit(
      MatchState game, int remaining, List<Map<String, dynamic>> moves) async {
    final node = <String, dynamic>{'position': aiPositionKey(game)};
    if (game.finished || remaining == 0) return {...node, 'kind': 'end'};
    if (impossibleByMaterial(game, attacker, remaining)) {
      return {...node, 'kind': 'material'};
    }
    if (game.current != attacker) {
      final response = await worker.ask({
        'id': 'policy-${calls++}',
        'config': game.config.toMap(),
        'moves': moves,
        'level': option('level', 'hard')
      });
      if (response['position'] != aiPositionKey(game)) {
        throw StateError('Worker position differs');
      }
      final move =
          MatchMove.fromMap(Map<String, dynamic>.from(response['move'] as Map));
      final next = MatchRules.play(game, move);
      if (next == null) throw StateError('Illegal policy move');
      return {
        ...node,
        'kind': 'choice',
        'move': move.toMap(game.current),
        'response': response,
        'child': await visit(
            next, remaining - 1, [...moves, move.toMap(game.current)])
      };
    }
    if (remaining == 1) {
      return {
        ...node,
        'kind': 'last-attacks',
        'winningMoves': [
          for (final move in MatchRules.legalMoves(game))
            if (MatchRules.play(game, move)!.result?.winner == attacker)
              moveKey(game, move)
        ]
      };
    }
    final children = <Map<String, dynamic>>[];
    for (final move in MatchRules.legalMoves(game)) {
      children.add({
        'move': move.toMap(game.current),
        'node': await visit(MatchRules.play(game, move)!, remaining - 1,
            [...moves, move.toMap(game.current)])
      });
    }
    return {...node, 'kind': 'attacks', 'children': children};
  }

  late Map<String, dynamic> tree;
  try {
    tree = await visit(initial, horizon, records);
  } finally {
    await worker.close();
  }
  final passed = verifyPolicy(initial, attacker, horizon, tree);
  final report = {
    'scope':
        'Complete bounded certificate of the actual recorded AI replies against all legal attacks. Timed policy can vary on another run; not an unbounded game solution.',
    'config': initial.config.toMap(),
    'moves': records,
    'attacker': attacker.name,
    'horizon': horizon,
    'level': option('level', 'hard'),
    'binarySha256': await sha(binary),
    'provenance': provenance,
    'runnerSha256': await sha('tools/ai_policy_check.dart'),
    'rulesSha256': await sha('lib/game/match_rules.dart'),
    'aiDecisions': calls,
    'verifiedRecordedPolicySafe': passed,
    'tree': tree
  };
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('${jsonEncode(report)}\n');
  stdout.writeln(jsonEncode({
    'verifiedRecordedPolicySafe': passed,
    'aiDecisions': calls,
    'output': output.path
  }));
  if (!passed) exitCode = 1;
}
