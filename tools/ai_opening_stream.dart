// Select distinct initial openings before observing any engine outcomes.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'ai_qualification.dart' show sha;

Future<void> main(List<String> args) async {
  String option(String key, String fallback) =>
      args
          .where((s) => s.startsWith('--$key='))
          .map((s) => s.substring(key.length + 3))
          .firstOrNull ??
      fallback;
  final output = File(option('output', ''));
  final start = int.parse(option('seed-start', '400000'));
  final count = int.parse(option('count', '50'));
  if (output.path.isEmpty || output.existsSync() || count < 1 || start < 0) {
    throw ArgumentError(
        'New output, positive count and nonnegative seed required');
  }
  final profiles = <Map<String, Object?>>[];
  for (final shape in BoardShape.values) {
    final cfg = MatchConfig(
        shape: shape,
        size: shape == BoardShape.square ? 5 : 2,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
    final selected = <Map<String, Object?>>[];
    final duplicates = <int>[];
    final seen = <String>{};
    for (var seed = start; selected.length < count; seed++) {
      if (seed - start > 10000) throw StateError('Opening stream exhausted');
      var game = MatchState.initial(cfg);
      final rng = Random(seed);
      final moves = <Map<String, dynamic>>[];
      for (var p = 0; p < 2; p++) {
        final legal = MatchRules.legalMoves(game).toList();
        final move = legal[rng.nextInt(legal.length)];
        moves.add(move.toMap(game.current));
        game = MatchRules.play(game, move)!;
      }
      final key = jsonEncode(moves);
      if (!seen.add(key)) {
        duplicates.add(seed);
        continue;
      }
      selected.add({'seed': seed, 'moves': moves});
    }
    profiles.add({
      'shape': shape.name,
      'size': cfg.size,
      'selected': selected,
      'duplicateSeedsExcludedBeforeOutcomes': duplicates
    });
  }
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('${jsonEncode({
        'scope':
            'First distinct two-move openings in a preregistered seed stream; selection never uses game outcomes',
        'seedStart': start,
        'distinctPerBoard': count,
        'profiles': profiles,
        'runtime': Platform.version,
        'runnerSha256': await sha('tools/ai_opening_stream.dart'),
        'rulesSha256': await sha('lib/game/match_rules.dart')
      })}\n');
  stdout
      .writeln(jsonEncode({'selectedPerBoard': count, 'output': output.path}));
}
