import 'dart:math' as math;

import '../models/piece.dart';
import '../services/ai/search_budget.dart';
import 'ai_position.dart';
import 'ai_search_cache.dart';
import 'ai_duel_tactics.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Work counters are cumulative; completed depth describes only committed work.
class AiDuelStats {
  int nodes = 0, generatedMoves = 0, evaluations = 0, cutoffs = 0;
  int extensionNodes = 0, tacticalChecks = 0, completedDepth = 0;
  int completedRoots = 0;
  int orderingMicros = 0, evaluationMicros = 0, tacticalMicros = 0;
  String stage = 'duel roots';
}

class AiDuelIteration {
  const AiDuelIteration(this.move, this.score, this.scores, this.exactScores);
  final MatchMove move;
  final double score;
  final List<(MatchMove, double)> scores;
  final bool exactScores;
}

class _Entry {
  const _Entry(this.score, this.bound);
  final double score;
  final AiBound bound;
}

/// Exhaustive finite-horizon minimax. Ordering changes work, never coverage.
/// Tactical proofs at leaves may look beyond nominal depth; neither heuristics
/// nor an interrupted enumeration can establish a forced result.
class AiDuelSearch {
  AiDuelSearch({
    required this.budget,
    required this.evaluate,
    required this.root,
    this.cache,
    this.extensions = true,
    this.tactics = true,
    this.exactRootScores = false,
    this.requiresExactAlternative,
    this.nodeLimit,
    this.reverseOrder = false,
  });

  final SearchBudget budget;
  final double Function(MatchState, SeatId) evaluate;
  final SeatId root;
  final AiSearchCache? cache;
  final bool extensions, tactics, exactRootScores;
  final bool Function(MatchState)? requiresExactAlternative;
  // Deterministic resource/order controls for oracle and interruption checks.
  final int? nodeLimit;
  final bool reverseOrder;
  final stats = AiDuelStats();
  final _keys = Expando<String>();
  String _key(MatchState game) => _keys[game] ??= aiDecisionPositionKey(game);

  static String moveKey(MatchMove move) =>
      '${move.from.x},${move.from.y}:${move.type?.index}:'
      '${move.direction?.index}:${move.drops.join(',')}';

  Future<void>? _pause() {
    if (nodeLimit != null && stats.nodes >= nodeLimit!) {
      throw const SearchTimedOut();
    }
    return budget.pauseIfNeeded();
  }

  static double terminal(MatchState game, SeatId root) =>
      game.result!.winner == null
          ? 0
          : game.result!.winner == root
              ? 200000 - game.ply.toDouble()
              : -200000 + game.ply.toDouble();

  double _winAt(SeatId winner, int ply) =>
      winner == root ? 200000 - ply.toDouble() : -200000 + ply.toDouble();

  Future<bool> _wins(MatchState game, SeatId seat) async {
    final key = 'fw:win:${_key(game)}:${seat.name}';
    final old = cache?.get<bool>(key);
    if (old != null) return old;
    stats.tacticalChecks++;
    final watch = Stopwatch()..start();
    final bool result;
    try {
      result = (await aiDuelWinningMoves(game, seat, budget, stopAfter: 1))
          .isNotEmpty;
    } finally {
      stats.tacticalMicros += watch.elapsedMicroseconds;
    }
    cache?.put(key, result);
    return result;
  }

  int _priority(MatchState game, MatchMove move) {
    if (move.type == null) {
      var score = 0;
      var cell = move.from;
      for (final drop in move.drops) {
        cell = cell.step(move.direction!);
        final top = game.topAt(cell);
        if (top != null && top.seat != game.current) score += 16;
        if (drop > 0 && top?.type == PieceType.standing) score += 8;
      }
      return score;
    }
    var score = 0;
    for (final direction in game.geometry.directions) {
      final top = game.topAt(move.from.step(direction));
      if (top != null) score += top.seat == game.current ? 4 : 2;
    }
    return score;
  }

  Future<List<MatchMove>> _ordered(MatchState game,
      {bool retain = false}) async {
    final watch = Stopwatch()..start();
    try {
      return await _orderBody(game, retain);
    } finally {
      stats.orderingMicros += watch.elapsedMicroseconds;
    }
  }

  Future<List<MatchMove>> _orderBody(MatchState game, bool retain) async {
    final key = 'fw:moves:${_key(game)}';
    var moves = retain ? cache?.get<List<MatchMove>>(key) : null;
    if (moves == null) {
      final ranked = <(MatchMove, int, String)>[];
      for (final move in MatchRules.legalMoves(game)) {
        final pause = _pause();
        if (pause != null) await pause;
        stats.generatedMoves++;
        ranked.add((move, _priority(game, move), moveKey(move)));
      }
      ranked.sort((a, b) {
        final priority = b.$2.compareTo(a.$2);
        final result = priority == 0 ? a.$3.compareTo(b.$3) : priority;
        return reverseOrder ? -result : result;
      });
      moves = List.unmodifiable(ranked.map((entry) => entry.$1));
      if (retain) cache?.put(key, moves, cost: math.max(1, moves.length));
    }
    final pv = cache?.get<MatchMove>('fw:pv:${_key(game)}');
    if (retain) {
      final previous =
          cache?.get<Map<String, double>>('fw:root-order:${_key(game)}');
      if (previous != null) {
        moves = moves.toList()
          ..sort((a, b) => (previous[moveKey(b)] ?? double.negativeInfinity)
              .compareTo(previous[moveKey(a)] ?? double.negativeInfinity));
      }
    }
    if (pv == null) return moves;
    final index = moves.indexWhere((move) => moveKey(move) == moveKey(pv));
    if (index <= 0) return moves;
    return [moves[index], ...moves.take(index), ...moves.skip(index + 1)];
  }

  /// One complete root iteration, or an exception with no adopted root result.
  Future<AiDuelIteration> iteration(MatchState game, int depth,
      {int? extensionPlies}) async {
    if (game.finished ||
        game.config.seats.length != 2 ||
        depth < 1 ||
        game.current != root) {
      throw ArgumentError(
          'An unfinished duel at the root and positive depth required');
    }
    stats.stage = 'duel roots';
    final scores = <(MatchMove, double)>[];
    MatchMove? best;
    var score = double.negativeInfinity;
    final moves = await _ordered(game, retain: true);
    var exact = exactRootScores;
    if (!exact && requiresExactAlternative != null) {
      for (final move in moves) {
        final pause = _pause();
        if (pause != null) await pause;
        if (requiresExactAlternative!(MatchRules.play(game, move)!)) {
          exact = true;
          break;
        }
      }
    }
    for (final move in moves) {
      final pause = _pause();
      if (pause != null) await pause;
      final next = MatchRules.play(game, move)!;
      final value = await valueAt(next, depth - 1,
          alpha: exact ? double.negativeInfinity : score,
          extensionPlies: extensionPlies);
      scores.add((move, value));
      if (value > score) {
        score = value;
        best = move;
      }
      // This is the earliest possible terminal victory, a sound global bound.
      if (next.result?.winner == root) break;
    }
    final pause = _pause();
    if (pause != null) await pause;
    if (best == null) throw StateError('Unfinished duel has no legal move');
    cache?.put('fw:pv:${_key(game)}', best);
    cache?.put('fw:root-order:${_key(game)}',
        {for (final (move, value) in scores) moveKey(move): value},
        cost: math.max(1, scores.length));
    stats.completedDepth = depth;
    stats.completedRoots = scores.length;
    return AiDuelIteration(best, score, List.unmodifiable(scores), exact);
  }

  /// Also exposed for deterministic oracle/window tests. Bound results may only
  /// be interpreted with their search window, never as alternative root scores.
  Future<double> valueAt(MatchState game, int depth,
      {double alpha = double.negativeInfinity,
      double beta = double.infinity,
      int? extensionPlies}) async {
    final pause = _pause();
    if (pause != null) await pause;
    stats.nodes++;
    if (extensions && extensionPlies == 0) stats.extensionNodes++;
    if (game.finished) return terminal(game, root);
    if (depth < 0 || alpha >= beta) {
      throw ArgumentError('Invalid horizon/window');
    }
    final allowance = extensionPlies ?? (extensions ? 2 : 0);
    final key =
        'fw:value:${_key(game)}:$depth:${root.name}:$allowance:$tactics';
    final old = cache?.get<_Entry>(key);
    if (old != null &&
        (old.bound == AiBound.exact ||
            old.bound == AiBound.lower && old.score >= beta ||
            old.bound == AiBound.upper && old.score <= alpha)) {
      return old.score;
    }
    final originalAlpha = alpha, originalBeta = beta;
    final double value;
    if (depth == 0) {
      stats.stage = 'duel tactics';
      if (tactics && await _wins(game, game.current)) {
        value = _winAt(game.current, game.ply + 1);
      } else if (tactics &&
          allowance > 0 &&
          await _wins(game, game.config.next(game.current))) {
        final rival = game.config.next(game.current);
        var best =
            game.current == root ? double.negativeInfinity : double.infinity;
        var safe = false;
        for (final move in await _ordered(game)) {
          final check = _pause();
          if (check != null) await check;
          final next = MatchRules.play(game, move)!;
          if (next.finished
              ? next.result!.winner != rival
              : !await _wins(next, rival)) {
            safe = true;
            final score = await valueAt(next, allowance - 1,
                alpha: alpha, beta: beta, extensionPlies: 0);
            if (game.current == root) {
              best = math.max(best, score);
              alpha = math.max(alpha, best);
            } else {
              best = math.min(best, score);
              beta = math.min(beta, best);
            }
            if (alpha >= beta) {
              stats.cutoffs++;
              break;
            }
          }
        }
        value = safe ? best : _winAt(rival, game.ply + 2);
      } else {
        stats.stage = 'duel evaluation';
        stats.evaluations++;
        final watch = Stopwatch()..start();
        try {
          value = evaluate(game, root);
        } finally {
          stats.evaluationMicros += watch.elapsedMicroseconds;
        }
      }
    } else {
      stats.stage = 'duel search';
      final maximize = game.current == root;
      var best = maximize ? double.negativeInfinity : double.infinity;
      MatchMove? principal;
      Future<bool> visit(MatchMove move, [MatchState? next]) async {
        final check = _pause();
        if (check != null) await check;
        final score = await valueAt(
            next ?? MatchRules.play(game, move)!, depth - 1,
            alpha: alpha, beta: beta, extensionPlies: allowance);
        if (maximize ? score > best : score < best) principal = move;
        best = maximize ? math.max(best, score) : math.min(best, score);
        if (maximize) {
          alpha = math.max(alpha, best);
        } else {
          beta = math.min(beta, best);
        }
        if (alpha >= beta) {
          stats.cutoffs++;
          return true;
        }
        return false;
      }

      // A verified transposition move is searched before generating other
      // legal moves. A sound cutoff can avoid their construction entirely.
      final preferred = cache?.get<MatchMove>('fw:pv:${_key(game)}');
      final preferredState =
          preferred == null ? null : MatchRules.play(game, preferred);
      final cutoff =
          preferredState != null && await visit(preferred!, preferredState);
      if (!cutoff) {
        for (final move in await _ordered(game)) {
          if (preferredState != null && moveKey(move) == moveKey(preferred!)) {
            continue;
          }
          if (await visit(move)) break;
        }
      }
      if (principal == null) {
        throw StateError('Unfinished duel has no legal move');
      }
      cache?.put('fw:pv:${_key(game)}', principal!);
      value = best;
    }
    final check = _pause();
    if (check != null) await check;
    cache?.put(
        key,
        _Entry(
            value,
            value <= originalAlpha
                ? AiBound.upper
                : value >= originalBeta
                    ? AiBound.lower
                    : AiBound.exact));
    return value;
  }
}
