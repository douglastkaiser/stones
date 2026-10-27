// Native adjacent-tier regression runner. See docs/AI_UPGRADES.md.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'ai_qualification.dart' show Worker, sha;

Map<String, Object?> strengthSummary(List<Map<String, dynamic>> rows,
    {required int seeds,
    required int players,
    required bool full,
    int seedStart = 0}) {
  final expected = seeds * players;
  final ids = rows.map((r) => '${r['seed']}:${r['rotation']}').toSet();
  final finished = rows.where((r) => r['finished'] == true).length;
  final wins = rows.where((r) => r['targetWon'] == true).length;
  final decisive = rows.where((r) => r['winner'] != null).length;
  final losses = decisive - wins;
  final share = decisive == 0 ? 0.0 : wins / (wins + losses / (players - 1));
  final complete = rows.length == expected &&
      ids.length == expected &&
      rows.every((r) =>
          (r['seed'] as int) >= seedStart &&
          (r['seed'] as int) < seedStart + seeds &&
          (r['rotation'] as int) >= 0 &&
          (r['rotation'] as int) < players);
  final passed = complete &&
      (!full || seeds >= 50) &&
      finished >= (expected * .8).ceil() &&
      decisive >= (expected * .5).ceil() &&
      share > (full ? .6 : .5);
  return {
    'expectedGames': expected,
    'games': rows.length,
    'complete': complete,
    'finished': finished,
    'wins': wins,
    'losses': losses,
    'draws': finished - decisive,
    'unfinished': rows.length - finished,
    'normalizedShare': share,
    'passed': passed,
    'scope': full ? 'selected-profile-strength' : 'regression-only',
  };
}

Future<void> main(List<String> args) async {
  String option(String key, String fallback) =>
      args
          .where((s) => s.startsWith('--$key='))
          .map((s) => s.substring(key.length + 3))
          .firstOrNull ??
      fallback;
  final shape = BoardShape.values.byName(option('shape', 'square'));
  final size =
      int.parse(option('size', shape == BoardShape.square ? '5' : '2'));
  final players = int.parse(option('players', '2'));
  final starter = SeatId.values.byName(option('starter', 'ivory'));
  final tier = int.parse(option('tier', '2'));
  final seeds = int.parse(option('seeds', '5'));
  final seedStart = int.parse(option('seed-start', '0'));
  final policy = option('policy', 'deterministic');
  final seededOpening = !args.contains('--natural-opening');
  final candidatePath = option('candidate', '/tmp/stones-ai-candidate');
  final opponentPath = option('opponent', candidatePath);
  final output = File(option('output', '/tmp/stones-ai-strength.jsonl'));
  if (players < 2 ||
      players > 4 ||
      seeds < 1 ||
      seedStart < 0 ||
      tier < 0 ||
      tier > 2 ||
      !['deterministic', 'ties', 'weighted'].contains(policy)) {
    throw ArgumentError('Invalid seeds, tier or policy');
  }
  final template = MatchConfig(
      shape: shape,
      size: size,
      starter: starter,
      seats: SeatId.values.take(players).map(SeatConfig.new).toList());
  final reference =
      opponentPath != candidatePath || args.contains('--reference');
  Map<String, dynamic> provenance(String path) {
    final file = File('$path.manifest.json');
    if (!file.existsSync()) {
      throw StateError('Missing binary provenance: ${file.path}');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  final candidateSource = provenance(candidatePath);
  final opponentSource = provenance(opponentPath);
  final manifest = {
    'engine': MatchConfig.currentAiEngine,
    'runtime': Platform.version,
    'os': Platform.operatingSystem,
    'candidateSha256': await sha(candidatePath),
    'opponentSha256': await sha(opponentPath),
    'runnerSha256': await sha('tools/ai_strength.dart'),
    'shape': shape.name,
    'size': size,
    'players': players,
    'starter': starter.name,
    'tier': tier,
    'seeds': seeds,
    'seedStart': seedStart,
    'policy': policy,
    'seededOpening': seededOpening,
    'sourceSha256': candidateSource['sourceSha256'],
    'workerSha256': candidateSource['workerSha256'],
    'candidateSource': candidateSource,
    'opponentSource': opponentSource,
    'comparison': reference ? 'same-tier-reference' : 'adjacent',
  };
  // Each shard owns a fresh output. Never silently mix different source/settings.
  if (output.existsSync()) {
    throw StateError('Output already exists: ${output.path}');
  }
  output.parent.createSync(recursive: true);
  File('${output.path}.manifest.json').writeAsStringSync(jsonEncode(manifest));
  final candidate = Worker(await Process.start(candidatePath, []));
  final opponent = Worker(await Process.start(opponentPath, []));
  final log = output.openWrite();
  final rows = <Map<String, dynamic>>[];
  try {
    for (var seed = seedStart; seed < seedStart + seeds; seed++) {
      for (var rotation = 0; rotation < players; rotation++) {
        final target = SeatId.values[rotation];
        final cfg = template.copyWith(seats: [
          for (final seat in template.ids)
            SeatConfig(seat,
                control: SeatControl.ai,
                level: BotLevel
                    .values[reference || seat == target ? tier + 1 : tier])
        ]);
        var game = MatchState.initial(cfg);
        final limit = max(
            160, 2 * game.reserves.values.fold<int>(0, (n, r) => n + r.total));
        final moves = <Map<String, dynamic>>[];
        final history = <String>[aiPositionKey(game)];
        final decisions = <Map<String, dynamic>>[];
        final random = Random(seed);
        for (var opening = 0; seededOpening && opening < players; opening++) {
          final legal = MatchRules.legalMoves(game).toList();
          final move = legal[random.nextInt(legal.length)];
          moves.add(move.toMap(game.current));
          game = MatchRules.play(game, move)!;
          history.add(aiPositionKey(game));
        }
        var repetitions = 0;
        final capPlies = <String, List<int>>{};
        while (!game.finished && game.ply < limit) {
          final isTarget = game.current == target;
          final decisionSeed = seed * 1000003 + rotation * 1009 + game.ply;
          final request = <String, Object?>{
            'id': '$seed:$rotation:${game.ply}',
            'config': cfg.toMap(),
            'moves': moves,
            'level': cfg.seat(game.current).level.name,
            'decisionSeed': decisionSeed,
            'policy': isTarget || !reference ? policy : 'deterministic',
          };
          final response = await (isTarget ? candidate : opponent).ask(request);
          if (response['position'] != aiPositionKey(game)) {
            throw StateError('Worker position divergence');
          }
          final move = MatchMove.fromMap(
              Map<String, dynamic>.from(response['move'] as Map));
          if (move.type == PieceType.capstone) {
            capPlies.putIfAbsent(game.current.name, () => []).add(game.ply);
          }
          decisions.add({
            'ply': game.ply,
            'seat': game.current.name,
            'level': cfg.seat(game.current).level.name,
            'decisionSeed': decisionSeed,
            ...(Map<String, dynamic>.from(response)..remove('position')),
          });
          moves.add(move.toMap(game.current));
          game =
              MatchRules.play(game, move) ?? (throw StateError('Illegal move'));
          final key = aiPositionKey(game);
          if (history.contains(key)) repetitions++;
          history.add(key);
          if (history.length > 64) history.removeAt(0);
        }
        final row = <String, dynamic>{
          'seed': seed,
          'rotation': rotation,
          'config': cfg.toMap(),
          'target': target.name,
          'finished': game.finished,
          'winner': game.result?.winner?.name,
          'targetWon': game.result?.winner == target,
          'reason': game.result?.reason.name,
          'maxPlies': limit,
          'repetitions': repetitions,
          'capstonePlies': capPlies,
          'moves': moves,
          'decisions': decisions,
          'finalPosition': aiPositionKey(game),
        };
        log.writeln(jsonEncode(row));
        await log.flush();
        rows.add(row);
        stdout.writeln(
            'AI_GAME seed=$seed rotation=$rotation winner=${game.result?.winner?.name ?? (game.finished ? 'draw' : 'unfinished')} plies=${game.ply}');
      }
    }
  } finally {
    await log.close();
    await candidate.close();
    await opponent.close();
  }
  final report = strengthSummary(rows,
      seeds: seeds,
      players: players,
      full: args.contains('--full'),
      seedStart: seedStart);
  File('${output.path}.summary.json').writeAsStringSync(jsonEncode(report));
  stdout.writeln(jsonEncode(report));
  if (!args.contains('--explore') && report['passed'] != true) exitCode = 1;
}
