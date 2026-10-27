// Exact bounded duel proof, independent of the production evaluator/beam.
import 'dart:convert';
import 'dart:io';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'ai_qualification.dart' show sha;

enum DuelProof { proven, refuted, unknown }

class BoundedDuelProof {
  BoundedDuelProof(
      {this.maxNodes = 200000, this.timeLimit = const Duration(seconds: 30)});
  final int maxNodes;
  final Duration timeLimit;
  final _cache = <String, DuelProof>{};
  final _watch = Stopwatch();
  late SeatId _attacker;
  int expandedNodes = 0, cacheHits = 0;
  int get elapsedMs => _watch.elapsedMilliseconds;

  DuelProof solve(MatchState game, SeatId attacker, int plies) {
    if (game.config.seats.length != 2 ||
        !game.config.ids.contains(attacker) ||
        plies < 0) {
      throw ArgumentError(
          'A duel, participating attacker and nonnegative horizon are required');
    }
    _attacker = attacker;
    _cache.clear();
    expandedNodes = cacheHits = 0;
    _watch
      ..reset()
      ..start();
    final result = _visit(game, plies);
    _watch.stop();
    return result;
  }

  DuelProof _visit(MatchState game, int remaining) {
    if (game.finished) {
      return game.result!.winner == _attacker
          ? DuelProof.proven
          : DuelProof.refuted;
    }
    if (remaining == 0) return DuelProof.refuted;
    final key = '$remaining:${aiDecisionPositionKey(game)}';
    final cached = _cache[key];
    if (cached != null) {
      cacheHits++;
      return cached;
    }
    if (expandedNodes >= maxNodes || _watch.elapsed >= timeLimit) {
      return DuelProof.unknown;
    }
    expandedNodes++;
    DuelProof remember(DuelProof result) {
      _cache[key] = result;
      return result;
    }

    // A placement adds at most one stone. These bounds include buried stones
    // and conservatively exclude both reserve and board-fill flat endings.
    final stones = game.board.values.expand((s) => s).toList();
    final noFlats = stones.length + remaining < game.geometry.cells.length &&
        game.reserves.values.every((r) => r.total > remaining);
    final own = stones.where((s) => s.seat == _attacker).length;
    final turns = [
      for (var i = 0; i < remaining; i++)
        if (game.config.turnAt(game.ply + i) == _attacker) i
    ].length;
    final span = game.config.shape == BoardShape.square
        ? game.config.size
        : 2 * game.config.size + 1;
    if (!game.opening && noFlats && own + turns < span) {
      return remember(DuelProof.refuted);
    }
    final attack = game.current == _attacker;
    final mustPlace = attack && !game.opening && noFlats && own + turns == span;
    var unknown = false, anyMove = false;
    for (final move in MatchRules.legalMoves(game)) {
      if (mustPlace && move.type == null) continue;
      anyMove = true;
      final result = _visit(MatchRules.play(game, move)!, remaining - 1);
      if (attack && result == DuelProof.proven ||
          !attack && result == DuelProof.refuted) {
        return remember(result);
      }
      if (result == DuelProof.unknown) unknown = true;
    }
    if (unknown) return DuelProof.unknown;
    return remember(attack || !anyMove ? DuelProof.refuted : DuelProof.proven);
  }
}

Future<void> main(List<String> args) async {
  String option(String key, String fallback) =>
      args
          .where((s) => s.startsWith('--$key='))
          .map((s) => s.substring(key.length + 3))
          .firstOrNull ??
      fallback;
  final replay = File(option('replay', ''));
  final row =
      jsonDecode(replay.readAsLinesSync()[int.parse(option('game', '0'))])
          as Map;
  final moves = row['moves'] as List;
  final ply = int.parse(option('ply', '3'));
  var remaining = int.parse(option('plies', '6'));
  final attacker = SeatId.values.byName(option('attacker', 'ivory'));
  if (ply < 0 || ply > moves.length || remaining < 0) {
    throw ArgumentError('Invalid replay/horizon');
  }
  var game = MatchState.initial(
      MatchConfig.fromMap(Map<String, dynamic>.from(row['config'] as Map)));
  for (final record in moves.take(ply)) {
    final map = Map<String, dynamic>.from(record as Map);
    if (map['seat'] != game.current.name) {
      throw StateError('Replay turn mismatch');
    }
    game = MatchRules.play(game, MatchMove.fromMap(map)) ??
        (throw StateError('Illegal replay'));
  }
  Map<String, dynamic>? counter;
  if (option('after', '').isNotEmpty) {
    if (remaining == 0) {
      throw ArgumentError('No horizon remains for a counter move');
    }
    final parts = option('after', '').split(':');
    final xy = parts[0].split(',').map(int.parse).toList();
    final move =
        MatchMove.place(Cell(xy[0], xy[1]), PieceType.values.byName(parts[1]));
    counter = move.toMap(game.current);
    game = MatchRules.play(game, move) ??
        (throw ArgumentError('Illegal counter move'));
    remaining--;
  }
  final proof = BoundedDuelProof(
      maxNodes: int.parse(option('max-nodes', '200000')),
      timeLimit: Duration(seconds: int.parse(option('seconds', '30'))));
  final result = proof.solve(game, attacker, remaining);
  final report = {
    'scope': 'Exact finite-horizon objective, not an unbounded game solution',
    'attacker': attacker.name,
    'replayPly': ply,
    'counter': counter,
    'fromPly': game.ply,
    'remainingPlies': remaining,
    'config': game.config.toMap(),
    'replayGame': int.parse(option('game', '0')),
    'replaySha256': await sha(replay.path),
    'maxNodes': proof.maxNodes,
    'timeLimitMs': proof.timeLimit.inMilliseconds,
    'verdict': result.name,
    'expandedNodes': proof.expandedNodes,
    'cacheHits': proof.cacheHits,
    'elapsedMs': proof.elapsedMs,
    'position': aiDecisionPositionKey(game),
    'rulesSha256': await sha('lib/game/match_rules.dart'),
    'solverSha256': await sha('tools/ai_balance_proof.dart'),
  };
  final encoded = const JsonEncoder.withIndent('  ').convert(report);
  if (option('output', '').isNotEmpty) {
    File(option('output', '')).writeAsStringSync('$encoded\n');
  }
  stdout.writeln(encoded);
}
