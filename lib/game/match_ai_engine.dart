import 'dart:math' as math;
import '../models/piece.dart';
import '../services/ai/search_budget.dart';
import 'board_geometry.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// A shared search: zero-sum minimax for two seats, MaxN for independent rivals.
/// Branching and depth are bounded; every adopted iteration finishes all roots.
class MatchSearchStats {
  int completedDepth = 0, evaluatedRoots = 0, elapsedMs = 0;
  bool timedOut = false;
  String stage = 'roots';
}

class MatchAI {
  MatchAI(this.level, {this.yieldDuringSearch = true, this.onSearchComplete});
  final void Function(MatchSearchStats)? onSearchComplete;
  final BotLevel level;
  final bool yieldDuringSearch;
  int get depth => [1, 1, 2, 3][level.index];
  int get branching => [4, 8, 12, 16][level.index];
  Duration get thinkingLimit =>
      Duration(milliseconds: [200, 500, 1200, 2200][level.index]);

  Future<MatchMove?> choose(MatchState game,
      {bool Function()? cancelled}) async {
    if (game.finished) return null;
    final first = MatchRules.legalMoves(game).firstOrNull;
    if (first == null) return null;
    var best = first;
    final stats = MatchSearchStats();
    final watch = Stopwatch()..start();
    var bestRootScore = double.negativeInfinity;
    final budget = SearchBudget(
        enabled: yieldDuringSearch,
        cancelled: cancelled,
        thinkingLimit: thinkingLimit);
    try {
      final roots = await _ranked(game, budget, onRoot: (move, score) {
        stats.evaluatedRoots++;
        if (score > bestRootScore) {
          bestRootScore = score;
          best = move;
        }
      });
      if (roots.isEmpty) return best;
      best = roots.first.$1;
      if (roots.first.$2.result?.winner == game.current) return best;
      stats.stage = 'defense';
      // MaxN's positional score alone can overlook another seat's imminent
      // victory. Before pruning, retain moves that prevent any rival from
      // winning in one, including stack spreads rather than only
      // empty-cell road gaps.
      var candidates = roots;
      if (!game.opening && await _rivalWin(game, game.current, budget)) {
        final safe = <(MatchMove, MatchState, double)>[];
        for (final root in roots) {
          if ((!root.$2.finished &&
                  !await _rivalWin(root.$2, game.current, budget)) ||
              root.$2.result?.winner == game.current) {
            safe.add(root);
            if (safe.length == 1) best = root.$1;
          }
        }
        if (safe.isNotEmpty) candidates = safe;
      }
      if (level == BotLevel.easy && !game.opening) {
        // A forgiving opponent chooses among plausible moves, with stable replay behavior.
        final seed = game.ply * 31 +
            game.board.keys.fold<int>(0, (sum, c) => sum + c.x * 7 + c.y * 13);
        return candidates
            .take(6)
            .toList()[seed.abs() % math.min(6, candidates.length)]
            .$1;
      }
      var completedScores = <(MatchMove, double)>[];
      stats.stage = 'search';
      for (var iteration = 1; iteration <= depth; iteration++) {
        final iterationScores = <(MatchMove, double)>[];
        MatchMove? iterationMove;
        var score = double.negativeInfinity;
        for (final (move, next, _) in candidates.take(branching)) {
          final double value;
          if (game.config.seats.length == 2) {
            value = await _duelSearch(next, iteration - 1, game.current, budget,
                score, double.infinity);
          } else {
            final values = await _search(next, iteration - 1, budget);
            value = _utility(game, values, game.current);
          }
          iterationScores.add((move, value));
          if (value > score) {
            iterationMove = move;
            score = value;
          }
        }
        if (iterationMove != null) {
          best = iterationMove;
          stats.completedDepth = iteration;
          completedScores = iterationScores;
        }
      }
      if (level == BotLevel.medium &&
          completedScores.length > 1 &&
          (game.ply ~/ game.config.seats.length) % 3 == 1) {
        completedScores.sort((a, b) => b.$2.compareTo(a.$2));
        final top = completedScores.first.$2;
        // Lower tiers occasionally choose a near-equal positional alternative.
        // Never trade away a searched forced win or choose outside safe defenses.
        if (top.abs() < 100000 && completedScores[1].$2 >= top - 24) {
          best = completedScores[1].$1;
        }
      }
    } on SearchTimedOut {
      stats.timedOut = true;
      // Return the last completed iteration, never a partially searched root.
    } on SearchCancelled {
      return null;
    } finally {
      stats.elapsedMs = watch.elapsedMilliseconds;
      onSearchComplete?.call(stats);
    }
    return best;
  }

  Future<bool> _rivalWin(
      MatchState game, SeatId root, SearchBudget budget) async {
    for (final rival in game.config.ids.where((id) => id != root)) {
      var delta = 0;
      while (game.config.turnAt(game.ply + delta) != rival) {
        delta++;
      }
      if (await _immediateWin(game.copyWith(ply: game.ply + delta), budget)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _immediateWin(MatchState game, SearchBudget budget) async {
    if (game.finished) return false;
    for (final move in MatchRules.legalMoves(game)) {
      final pause = budget.pauseIfNeeded();
      if (pause != null) await pause;
      if (MatchRules.play(game, move)!.result?.winner == game.current) {
        return true;
      }
    }
    return false;
  }

  double _utility(MatchState game, Map<SeatId, double> scores, SeatId seat) =>
      game.config.seats.length == 2
          ? scores[seat]! - scores[game.config.next(seat)]!
          : scores[seat]! -
              .35 *
                  game.config.ids
                      .where((id) => id != seat)
                      .map((id) => scores[id]!)
                      .reduce(math.max);

  Future<List<(MatchMove, MatchState, double)>> _ranked(
      MatchState game, SearchBudget budget,
      {void Function(MatchMove, double)? onRoot}) async {
    final ranked = <(MatchMove, MatchState, double)>[];
    for (final move in MatchRules.legalMoves(game)) {
      final pause = budget.pauseIfNeeded();
      if (pause != null) await pause;
      final next = MatchRules.play(game, move)!;
      if (next.result?.winner == game.current) {
        onRoot?.call(move, 100000);
        return [(move, next, 100000)];
      }
      final score = _utility(game, evaluate(next), game.current);
      onRoot?.call(move, score);
      ranked.add((move, next, score));
    }
    ranked.sort((a, b) => b.$3.compareTo(a.$3));
    return ranked;
  }

  /// Alpha-beta keeps two-player search from spending the whole budget on
  /// branches that an opponent would never choose.
  Future<double> _duelSearch(MatchState game, int depth, SeatId root,
      SearchBudget budget, double alpha, double beta) async {
    final pause = budget.pauseIfNeeded();
    if (pause != null) await pause;
    if (game.finished) {
      if (game.result!.winner == null) return 0;
      return game.result!.winner == root
          ? 200000 - game.ply.toDouble()
          : -200000 + game.ply.toDouble();
    }
    if (depth == 0) {
      // Resolve a win at the horizon instead of evaluating a terminal threat
      // as an ordinary cheap path. Includes spreads and flat-scoring wins.
      if ((pathCost(game, game.current) <= 1 ||
              game.reserves[game.current]!.total <= 1 ||
              game.board.length + 1 >= game.geometry.cells.length) &&
          await _immediateWin(game, budget)) {
        return game.current == root
            ? 200000 - game.ply.toDouble()
            : -200000 + game.ply.toDouble();
      }
      return _utility(game, evaluate(game), root);
    }
    final maximize = game.current == root;
    var best = maximize ? double.negativeInfinity : double.infinity;
    for (final (_, next, _) in (await _ranked(game, budget)).take(branching)) {
      final value =
          await _duelSearch(next, depth - 1, root, budget, alpha, beta);
      if (maximize) {
        best = math.max(best, value);
        alpha = math.max(alpha, best);
      } else {
        best = math.min(best, value);
        beta = math.min(beta, best);
      }
      if (beta <= alpha) break;
    }
    return best.isFinite ? best : _utility(game, evaluate(game), root);
  }

  Future<Map<SeatId, double>> _search(
      MatchState game, int depth, SearchBudget budget) async {
    final pause = budget.pauseIfNeeded();
    if (pause != null) await pause;
    if (game.finished) return evaluate(game);
    if (depth == 0) {
      if ((pathCost(game, game.current) <= 1 ||
              game.reserves[game.current]!.total <= 1 ||
              game.board.length + 1 >= game.geometry.cells.length) &&
          await _immediateWin(game, budget)) {
        return {
          for (final id in game.config.ids)
            id: id == game.current ? 100000 : -100000
        };
      }
      return evaluate(game);
    }
    Map<SeatId, double>? best;
    var score = double.negativeInfinity;
    for (final (_, next, _) in (await _ranked(game, budget)).take(branching)) {
      final values = await _search(next, depth - 1, budget);
      final value = _utility(game, values, game.current);
      if (value > score) {
        best = values;
        score = value;
      }
    }
    return best ?? evaluate(game);
  }

  static Map<SeatId, double> evaluate(MatchState game) {
    if (game.finished) {
      return {
        for (final id in game.config.ids)
          id: game.result!.winner == null
              ? 0
              : game.result!.winner == id
                  ? 100000
                  : -100000
      };
    }
    final flats = MatchRules.flatCounts(game);
    return {
      for (final seat in game.config.ids)
        seat: -80 * pathCost(game, seat) +
            flats[seat]! * 4.0 +
            game.board.values.where((stack) => stack.last.seat == seat).fold(
                0.0,
                (sum, stack) =>
                    sum +
                    math.min(4, stack.length - 1) * 2 +
                    (stack.last.type == PieceType.capstone ? 5 : 0))
    };
  }

  /// Bounded integer Dijkstra, shared by both topologies and coaching features.
  static double pathCost(MatchState game, SeatId seat) {
    final axes = game.config.profile == RulesProfile.legacyHex
        ? [seat.index]
        : List.generate(game.geometry.axisCount, (i) => i);
    return axes.map((axis) => _axisCost(game, seat, axis)).reduce(math.min);
  }

  static double _axisCost(MatchState game, SeatId seat, int axis) {
    final costs = <Cell, int>{};
    for (final cell in game.geometry.cells) {
      final top = game.topAt(cell);
      costs[cell] = top == null
          ? 1
          : top.seat == seat && top.type != PieceType.standing
              ? 0
              : top.type == PieceType.flat
                  ? 3
                  : 6;
    }
    final distances = <Cell, int>{};
    final buckets = List.generate(costs.length * 6 + 1, (_) => <Cell>[]);
    for (final cell in costs.keys) {
      if (game.geometry.boundary(cell, axis, false)) {
        distances[cell] = costs[cell]!;
        buckets[costs[cell]!].add(cell);
      }
    }
    for (var distance = 0; distance < buckets.length; distance++) {
      final bucket = buckets[distance];
      for (var n = 0; n < bucket.length; n++) {
        final cell = bucket[n];
        if (distances[cell] != distance) continue;
        if (game.geometry.boundary(cell, axis, true)) {
          return distance.toDouble();
        }
        for (final direction in game.geometry.directions) {
          final neighbor = cell.step(direction);
          final cost = costs[neighbor];
          if (cost == null) continue;
          final next = distance + cost;
          if (next < (distances[neighbor] ?? 1000)) {
            distances[neighbor] = next;
            buckets[next].add(neighbor);
          }
        }
      }
    }
    return 1000;
  }
}
