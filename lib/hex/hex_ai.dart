import 'dart:math';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/piece.dart' show PieceType;

import 'hex_game.dart';
import '../services/ai/search_budget.dart';

/// Three-player MaxN: each seat maximizes its own score vector, rather than
/// treating the other two independent players as a single minimax opponent.
class HexAI {
  static HexMove? choose(HexGame game) {
    HexMove? best;
    var bestScore = double.negativeInfinity;
    for (final (move, score) in _options(game)) {
      if (score > bestScore) {
        bestScore = score;
        best = move;
      }
    }
    return best;
  }

  /// Web compute runs on the UI thread. Yield between root candidates so
  /// painting, navigation and cancellation can run during the search.
  static Future<HexMove?> chooseResponsive(HexGame game,
      {bool Function()? cancelled}) async {
    if (game.finished) return null;
    final budget = SearchBudget(enabled: true, cancelled: cancelled);
    HexMove? best;
    var bestScore = double.negativeInfinity;
    try {
      for (final (move, next, _)
          in (await _rankedResponsive(game, budget)).take(4)) {
        if (next.finished && next.winner == game.current) return move;
        final score =
            (await _searchResponsive(next, 2, budget))[game.current.index];
        if (score > bestScore) {
          bestScore = score;
          best = move;
        }
      }
    } on SearchCancelled {
      return null;
    }
    return best;
  }

  static Future<List<(HexMove, HexGame, double)>> _rankedResponsive(
      HexGame game, SearchBudget budget) async {
    final moves = <(HexMove, HexGame, double)>[];
    for (final move in HexRules.legalMoves(game)) {
      final pause = budget.pauseIfNeeded();
      if (pause != null) await pause;
      final next = HexRules.play(game, move)!;
      moves.add((move, next, _evaluate(next)[game.current.index]));
    }
    moves.sort((a, b) => b.$3.compareTo(a.$3));
    return moves;
  }

  static Future<List<double>> _searchResponsive(
      HexGame game, int depth, SearchBudget budget) async {
    final pause = budget.pauseIfNeeded();
    if (pause != null) await pause;
    if (game.finished || depth == 0) return _evaluate(game);
    List<double>? best;
    for (final (_, next, _)
        in (await _rankedResponsive(game, budget)).take(4)) {
      final scores = await _searchResponsive(next, depth - 1, budget);
      if (best == null ||
          scores[game.current.index] > best[game.current.index]) {
        best = scores;
      }
    }
    return best ?? _evaluate(game);
  }

  static Iterable<(HexMove, double)> _options(HexGame game) sync* {
    if (game.finished) return;
    for (final (move, next, _) in _ranked(game).take(4)) {
      if (next.finished && next.winner == game.current) {
        yield (move, 100000);
        return;
      }
      // Look through both opponents' turns, each choosing independently.
      yield (move, _search(next, 2)[game.current.index]);
    }
  }

  static List<(HexMove, HexGame, double)> _ranked(HexGame game) {
    final moves = <(HexMove, HexGame, double)>[];
    for (final move in HexRules.legalMoves(game)) {
      final next = HexRules.play(game, move)!;
      moves.add((move, next, _evaluate(next)[game.current.index]));
    }
    moves.sort((a, b) => b.$3.compareTo(a.$3));
    return moves;
  }

  static List<double> _search(HexGame game, int depth) {
    if (game.finished || depth == 0) return _evaluate(game);
    List<double>? best;
    for (final (_, next, _) in _ranked(game).take(4)) {
      final scores = _search(next, depth - 1);
      if (best == null ||
          scores[game.current.index] > best[game.current.index]) {
        best = scores;
      }
    }
    return best ?? _evaluate(game);
  }

  static List<double> _evaluate(HexGame game) {
    if (game.finished) {
      return List.generate(
          3,
          (i) => game.winner == null
              ? 0
              : game.winner!.index == i
                  ? 100000.0
                  : -100000.0);
    }
    final flats = HexRules.flatCounts(game);
    final costs = HexSeat.values.map((seat) => roadCost(game, seat)).toList();
    return List.generate(3, (i) {
      final opponents = [costs[(i + 1) % 3], costs[(i + 2) % 3]];
      return flats[i] * 2 - costs[i] * 12 + opponents.reduce(min) * 3;
    });
  }

  // Cheapest of the permitted opposite-side crossings. Buried colors
  // give no connection; walls/caps owned by others are expensive blockers.
  @visibleForTesting
  static double roadCost(HexGame game, HexSeat seat) {
    return game
        .roadAxes(seat)
        .map((axis) => _axisCost(game, seat, axis))
        .reduce(min);
  }

  static double _axisCost(HexGame game, HexSeat seat, HexAxis axis) {
    // All weights are small nonnegative integers. Bucketed Dijkstra avoids
    // repeatedly scanning every remaining cell for each of three shared pairs.
    final costs = <HexCell, int>{};
    for (final cell in game.cells) {
      final top = game.topAt(cell);
      costs[cell] = top == null
          ? 1
          : top.seat == seat && top.type != PieceType.standing
              ? 0
              : top.type == PieceType.flat
                  ? 3
                  : 6;
    }
    final distances = <HexCell, int>{};
    final buckets = List.generate(costs.length * 6 + 1, (_) => <HexCell>[]);
    for (final cell in costs.keys) {
      if (axis.coordinate(cell) == -game.radius) {
        final distance = costs[cell]!;
        distances[cell] = distance;
        buckets[distance].add(cell);
      }
    }
    for (var distance = 0; distance < buckets.length; distance++) {
      final bucket = buckets[distance];
      for (var n = 0; n < bucket.length; n++) {
        final cell = bucket[n];
        if (distances[cell] != distance) continue;
        if (axis.coordinate(cell) == game.radius) return distance.toDouble();
        for (final direction in HexDirection.values) {
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
