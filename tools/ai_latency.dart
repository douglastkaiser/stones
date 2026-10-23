// Paired, sequential same-position measurements. Native only; no cross-runtime claims.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'ai_qualification.dart'
    show Worker, profiles, profileKey, sha, percentile;

Future<void> main(List<String> args) async {
  if (args.contains('--help')) {
    stdout.writeln(
        '--samples=50 --positions=3 --levels=easy,medium,hard,expert --profile=all --output=PATH --candidate=PATH --baseline=PATH');
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
  final samples = int.parse(option('samples', '50'));
  final positions = int.parse(option('positions', '3'));
  final levels = option('levels', 'easy,medium,hard,expert')
      .split(',')
      .map(BotLevel.values.byName)
      .toList();
  final selected = option('profile', 'all');
  final candidatePath = option('candidate', '/tmp/stones-ai-candidate');
  final baselinePath = option('baseline', '/tmp/stones-ai-baseline');
  final output = File(option('output', '/tmp/stones-ai-latency.json'));
  if (samples < 1 ||
      positions < 1 ||
      !profiles.any((p) => selected == 'all' || profileKey(p) == selected)) {
    throw ArgumentError('Invalid latency selection');
  }
  final candidate = Worker(await Process.start(candidatePath, []));
  final baseline = Worker(await Process.start(baselinePath, []));
  final rows = <Map<String, Object?>>[];
  try {
    for (final profile in profiles
        .where((p) => selected == 'all' || profileKey(p) == selected)) {
      final cfg = MatchConfig(
          shape: profile.$1,
          size: profile.$2,
          seats: SeatId.values.take(profile.$3).map(SeatConfig.new).toList());
      for (var seed = 0; seed < samples; seed++) {
        final random = Random(200000 + seed);
        var game = MatchState.initial(cfg);
        final moves = <Map<String, dynamic>>[];
        for (var position = 0; position < positions; position++) {
          final targetPly = profile.$3 + position * 8;
          while (!game.finished && game.ply < targetPly) {
            final legal = MatchRules.legalMoves(game).toList();
            final move = legal[random.nextInt(legal.length)];
            moves.add(move.toMap(game.current));
            game = MatchRules.play(game, move)!;
          }
          if (game.finished) break;
          for (final level in levels) {
            final request = <String, Object?>{
              'id': '${profileKey(profile)}:$seed:$position:${level.name}',
              'config': cfg.toMap(),
              'moves': moves,
              'level': level.name
            };
            late Map<String, dynamic> next, old;
            if ((seed + position).isEven) {
              next = await candidate.ask(request);
              old = await baseline.ask(request);
            } else {
              old = await baseline.ask(request);
              next = await candidate.ask(request);
            }
            if (next['position'] != aiPositionKey(game) ||
                old['position'] != next['position']) {
              throw StateError('Context mismatch');
            }
            for (final response in [next, old]) {
              final move = MatchMove.fromMap(
                  Map<String, dynamic>.from(response['move'] as Map));
              if (MatchRules.play(game, move) == null) {
                throw StateError('Illegal measured decision');
              }
              response.remove('position');
            }
            rows.add({
              'profile': profileKey(profile),
              'seed': 200000 + seed,
              'ply': game.ply,
              'level': level.name,
              'config': cfg.toMap(),
              'moves': List.of(moves),
              'candidate': next,
              'baseline': old
            });
            stdout.writeln(
                'AI_LATENCY ${request['id']} ${next['elapsedMs']}/${old['elapsedMs']}ms');
          }
        }
      }
    }
  } finally {
    await candidate.close();
    await baseline.close();
  }
  final groups = <String, List<Map<String, Object?>>>{};
  for (final row in rows) {
    groups.putIfAbsent('${row['profile']}:${row['level']}', () => []).add(row);
  }
  final summary = [
    for (final entry in groups.entries)
      {
        'group': entry.key,
        'n': entry.value.length,
        'candidateP95Ms': percentile(
            entry.value
                .map((r) => (r['candidate'] as Map)['elapsedMs'] as num)
                .toList(),
            .95),
        'baselineP95Ms': percentile(
            entry.value
                .map((r) => (r['baseline'] as Map)['elapsedMs'] as num)
                .toList(),
            .95),
      }
  ];
  final enough = samples >= 50 && selected == 'all' && levels.length == 4;
  final passed = enough &&
      summary.every(
          (r) => (r['candidateP95Ms'] as num) <= (r['baselineP95Ms'] as num));
  output.writeAsStringSync('${jsonEncode({
        'sample': enough ? 'qualification-candidate' : 'exploratory',
        'runtime': Platform.version,
        'candidateSha256': await sha(candidatePath),
        'baselineSha256': await sha(baselinePath),
        'p95GatePassed': passed,
        'summary': summary,
        'decisions': rows
      })}\n');
  stdout.writeln('AI_LATENCY_SUMMARY ${jsonEncode(summary)}');
  if (enough && !passed) exitCode = 1;
}
