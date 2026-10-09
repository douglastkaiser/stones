import 'dart:math';

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
    final costs = HexSeat.values.map((seat) => _roadCost(game, seat)).toList();
    return List.generate(3, (i) {
      final opponents = [costs[(i + 1) % 3], costs[(i + 2) % 3]];
      return flats[i] * 2 - costs[i] * 12 + opponents.reduce(min) * 3;
    });
  }

  // Weighted shortest path between this seat's assigned edges. Buried colors
  // give no connection; walls/caps owned by others are expensive blockers.
  static double _roadCost(HexGame game, HexSeat seat) {
    double cost(HexCell cell) {
      final top = game.topAt(cell);
      if (top == null) return 1;
      if (top.seat == seat && top.type != PieceType.standing) return 0;
      return top.type == PieceType.flat ? 3 : 6;
    }

    final distances = <HexCell, double>{};
    final remaining = game.cells.toSet();
    for (final cell in remaining) {
      distances[cell] = seat.axis(cell) == -game.radius ? cost(cell) : 1000;
    }
    while (remaining.isNotEmpty) {
      final cell =
          remaining.reduce((a, b) => distances[a]! < distances[b]! ? a : b);
      final distance = distances[cell]!;
      if (seat.axis(cell) == game.radius) return distance;
      remaining.remove(cell);
      for (final direction in HexDirection.values) {
        final neighbor = cell.step(direction);
        if (!remaining.contains(neighbor)) continue;
        final next = distance + cost(neighbor);
        if (next < distances[neighbor]!) distances[neighbor] = next;
      }
    }
    return 1000;
  }
}
