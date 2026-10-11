import 'dart:math' as math;
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import '../models/piece.dart';
import '../services/ai/search_budget.dart';
import 'board_geometry.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

Future<MatchMove?> selectMatchMove(MatchState game, BotLevel level,
        {bool Function()? cancelled}) =>
    kIsWeb
        ? MatchAI(level).choose(game, cancelled: cancelled)
        : compute(_selectMove, (game, level));

Future<MatchMove?> _selectMove((MatchState, BotLevel) request) =>
    MatchAI(request.$2, yieldDuringSearch: false).choose(request.$1);

/// A shared search: zero-sum minimax for two seats, MaxN for independent rivals.
/// Branching and depth are bounded; every adopted iteration finishes all roots.
class MatchAI {
  MatchAI(this.level, {this.yieldDuringSearch = true});
  final BotLevel level;
  final bool yieldDuringSearch;
  int get depth => [2, 3, 4, 5][level.index];
  int get branching => [6, 10, 12, 14][level.index];
  Duration get thinkingLimit =>
      Duration(milliseconds: [350, 600, 1000, 1500][level.index]);

  Future<MatchMove?> choose(MatchState game,
      {bool Function()? cancelled}) async {
    if (game.finished) return null;
    final first = MatchRules.legalMoves(game).firstOrNull;
    if (first == null) return null;
    var best = first;
    final budget = SearchBudget(
        enabled: yieldDuringSearch,
        cancelled: cancelled,
        thinkingLimit: thinkingLimit);
    try {
      final roots = await _ranked(game, budget);
      if (roots.isEmpty) return best;
      best = roots.first.$1;
      if (roots.first.$2.result?.winner == game.current) return best;
      // MaxN's positional score alone can overlook another seat's imminent
      // victory. Before pruning, retain moves that actually prevent the next
      // player from winning in one, including stack spreads rather than only
      // empty-cell road gaps.
      var candidates = roots;
      if (!game.opening &&
          await _immediateWin(game.copyWith(ply: game.ply + 1), budget)) {
        final safe = <(MatchMove, MatchState, double)>[];
        for (final root in roots) {
          if (root.$2.finished || !await _immediateWin(root.$2, budget)) {
            safe.add(root);
            if (safe.length == 1) best = root.$1;
          }
        }
        if (safe.isNotEmpty) candidates = safe;
      }
      for (var iteration = 1; iteration <= depth; iteration++) {
        MatchMove? iterationMove;
        var score = double.negativeInfinity;
        for (final (move, next, _) in candidates.take(branching)) {
          final values = await _search(next, iteration - 1, budget);
          final value = _utility(game, values, game.current);
          if (value > score) {
            iterationMove = move;
            score = value;
          }
        }
        if (iterationMove != null) best = iterationMove;
      }
    } on SearchTimedOut {
      // Return the last completed iteration, never a partially searched root.
    } on SearchCancelled {
      return null;
    }
    return best;
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
          : scores[seat]!;

  Future<List<(MatchMove, MatchState, double)>> _ranked(
      MatchState game, SearchBudget budget) async {
    final ranked = <(MatchMove, MatchState, double)>[];
    for (final move in MatchRules.legalMoves(game)) {
      final pause = budget.pauseIfNeeded();
      if (pause != null) await pause;
      final next = MatchRules.play(game, move)!;
      if (next.result?.winner == game.current) {
        return [(move, next, 100000)];
      }
      ranked.add((move, next, _utility(game, evaluate(next), game.current)));
    }
    ranked.sort((a, b) => b.$3.compareTo(a.$3));
    return ranked;
  }

  Future<Map<SeatId, double>> _search(
      MatchState game, int depth, SearchBudget budget) async {
    final pause = budget.pauseIfNeeded();
    if (pause != null) await pause;
    if (game.finished || depth == 0) return evaluate(game);
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
        seat: -80 * pathCost(game, seat) + flats[seat]! * 4.0
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
