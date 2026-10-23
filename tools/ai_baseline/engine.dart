// Frozen pre-upgrade v3 engine. Do not tune this benchmark reference.
import 'dart:math' as math;
import 'package:stones/models/piece.dart';
import 'package:stones/services/ai/search_budget.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

/// A shared search: zero-sum minimax for two seats, MaxN for independent rivals.
/// Branching and depth are bounded; every adopted iteration finishes all roots.
class BaselineSearchStats {
  // Depth is measured in individual moves; completedRounds records full cycles.
  int completedDepth = 0,
      completedRounds = 0,
      evaluatedRoots = 0,
      elapsedMs = 0;
  final consideredSeats = <SeatId>{};
  bool timedOut = false;
  String stage = 'roots';
}

class BaselineMatchAI {
  BaselineMatchAI(this.level, {this.yieldDuringSearch = true, this.onSearchComplete});
  final void Function(BaselineSearchStats)? onSearchComplete;
  final BotLevel level;
  final bool yieldDuringSearch;
  // Targets are full rounds for v3; saved v2 games retain individual-move depth.
  int get depth => [1, 1, 2, 3][level.index];
  int get branching => [4, 8, 12, 16][level.index];
  int _branching(MatchState game) =>
      game.config.seats.length > 2 ? [4, 8, 8, 10][level.index] : branching;
  Duration get thinkingLimit =>
      Duration(milliseconds: [200, 500, 1200, 2200][level.index]);

  Future<MatchMove?> choose(MatchState game,
      {bool Function()? cancelled}) async {
    if (game.finished) return null;
    final first = MatchRules.legalMoves(game).firstOrNull;
    if (first == null) return null;
    var best = first;
    final roundSearch = game.config.aiEngine == 'shared-search-v3';
    var roundCandidates = <(MatchMove, MatchState, double)>[];
    final stats = BaselineSearchStats();
    final watch = Stopwatch()..start();
    var bestRootScore = double.negativeInfinity;
    final budget = SearchBudget(
        enabled: yieldDuringSearch,
        cancelled: cancelled,
        thinkingLimit: thinkingLimit);
    try {
      final roots = await _ranked(game, budget, onRoot: (move, next, score) {
        if (roundSearch) roundCandidates.add((move, next, score));
        stats.evaluatedRoots++;
        if (score > bestRootScore) {
          bestRootScore = score;
          best = move;
        }
      });
      if (roots.isEmpty) return best;
      roundCandidates = roots;
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
            if (safe.length == 1) {
              best = root.$1;
              roundCandidates = safe;
            }
          }
        }
        if (safe.isNotEmpty) candidates = safe;
      }
      if (!roundSearch && level == BotLevel.easy && !game.opening) {
        // A forgiving opponent chooses among plausible moves, with stable replay behavior.
        final seed = game.ply * 31 +
            game.board.keys.fold<int>(0, (sum, c) => sum + c.x * 7 + c.y * 13);
        return candidates
            .take(12)
            .toList()[seed.abs() % math.min(12, candidates.length)]
            .$1;
      }
      var completedScores = <(MatchMove, double)>[];
      if (roundSearch) {
        best = await _oneRound(game, candidates, stats, cancelled);
        if (level == BotLevel.easy) return best;
      }
      stats.stage = 'search';
      for (var iteration = 1; iteration <= depth; iteration++) {
        final plies =
            roundSearch ? iteration * game.config.seats.length : iteration;
        final beam = roundSearch ? (level == BotLevel.medium ? 2 : 3) : null;
        final iterationScores = <(MatchMove, double)>[];
        MatchMove? iterationMove;
        var score = double.negativeInfinity;
        for (final (move, next, _) in candidates.take(_branching(game))) {
          final double value;
          if (game.config.seats.length == 2) {
            value = await _duelSearch(
                next, plies - 1, game.current, budget, score, double.infinity,
                beam: beam);
          } else {
            final values = await _search(next, plies - 1, budget, beam: beam);
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
          stats.completedDepth = plies;
          if (roundSearch) stats.completedRounds = iteration;
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
      // Always model every rival at least once, even when initial ranking or
      // the exhaustive defense pass used up the refinement deadline.
      if (roundSearch && stats.completedRounds == 0) {
        try {
          best = await _oneRound(game, roundCandidates, stats, cancelled);
        } on SearchCancelled {
          return null;
        }
      }
      // Return a completed round/iteration, never a partially searched root.
    } on SearchCancelled {
      return null;
    } finally {
      stats.elapsedMs = watch.elapsedMilliseconds;
      onSearchComplete?.call(stats);
    }
    return best;
  }

  Future<MatchMove> _oneRound(
      MatchState game,
      List<(MatchMove, MatchState, double)> candidates,
      BaselineSearchStats stats,
      bool Function()? cancelled) async {
    stats.stage = 'round baseline';
    final budget =
        SearchBudget(enabled: yieldDuringSearch, cancelled: cancelled);
    if (candidates.isEmpty) {
      candidates = await _ranked(game, budget,
          moveLimit: 48, onRoot: (_, __, ___) => stats.evaluatedRoots++);
    }
    final ordered = candidates.toList()..sort((a, b) => b.$3.compareTo(a.$3));
    final scores = <(MatchMove, double)>[];
    stats.consideredSeats.add(game.current);
    for (final (move, position, _) in ordered.take(_branching(game))) {
      var next = position;
      // Root move plus N-1 opponent moves is one round, ending just before
      // this seat's next turn. A terminal result legitimately ends it sooner.
      for (var reply = 1;
          reply < game.config.seats.length && !next.finished;
          reply++) {
        final pause = budget.pauseIfNeeded();
        if (pause != null) await pause;
        stats.consideredSeats.add(next.current);
        final replies = await _ranked(next, budget, moveLimit: 48);
        if (replies.isEmpty) break;
        next = replies.first.$2;
      }
      scores.add((move, _utility(game, _evaluate(next), game.current)));
    }
    scores.sort((a, b) => b.$2.compareTo(a.$2));
    stats.completedRounds = 1;
    stats.completedDepth = game.config.seats.length;
    var best = scores.first.$1;
    if (level == BotLevel.easy &&
        !game.opening &&
        scores.first.$2.abs() < 100000) {
      // Easy varies only among near-equal choices already evaluated over a
      // complete round. It never substitutes an unexamined positional move.
      final plausible =
          scores.where((entry) => entry.$2 >= scores.first.$2 - 24).toList();
      final seed = game.ply * 31 +
          game.board.keys.fold<int>(0, (sum, c) => sum + c.x * 7 + c.y * 13);
      best = plausible[seed.abs() % plausible.length].$1;
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

  double _utility(MatchState game, Map<SeatId, double> scores, SeatId seat) {
    if (game.config.seats.length == 2) {
      return scores[seat]! - scores[game.config.next(seat)]!;
    }
    final rivals =
        game.config.ids.where((id) => id != seat).map((id) => scores[id]!);
    // Looking only at the strongest rival makes disrupting one of two equal
    // threats worthless: the other still has the same maximum score. Each
    // rival's progress matters in a free-for-all.
    final opposition = game.config.aiEngine == 'shared-search-v3'
        ? rivals.fold(0.0, (sum, value) => sum + value)
        : rivals.reduce(math.max);
    return scores[seat]! - .35 * opposition;
  }

  Future<List<(MatchMove, MatchState, double)>> _ranked(
      MatchState game, SearchBudget budget,
      {void Function(MatchMove, MatchState, double)? onRoot,
      int? moveLimit}) async {
    final ranked = <(MatchMove, MatchState, double)>[];
    final threats = game.config.aiEngine == 'shared-search-v3' && !game.opening
        ? _placementThreats(game)
        : <(SeatId, Cell)>[];
    var moves =
        moveLimit == null ? MatchRules.legalMoves(game) : _sampleMoves(game);
    if (threats.isNotEmpty) {
      final cells = {
        ...threats.where((t) => t.$1 == game.current).map((t) => t.$2),
        ...threats.where((t) => t.$1 != game.current).map((t) => t.$2)
      };
      final urgent = [
        for (final cell in cells)
          for (final type in PieceType.values)
            if (MatchRules.apply(game, MatchMove.place(cell, type)) != null)
              MatchMove.place(cell, type)
      ];
      // Examine winning/blocking placements before unrelated moves without
      // materializing the potentially enormous set of stack spreads.
      moves = urgent.followedBy(moves
          .where((move) => move.type == null || !cells.contains(move.from)));
    }
    var examined = 0;
    for (final move in moves) {
      if (moveLimit != null && examined++ >= moveLimit) break;
      final pause = budget.pauseIfNeeded();
      if (pause != null) await pause;
      final next = MatchRules.play(game, move)!;
      if (next.result?.winner == game.current) {
        onRoot?.call(move, next, 100000);
        return [(move, next, 100000)];
      }
      var score = _utility(game, _evaluate(next), game.current);
      // Preserve a known placement defense even if the later exhaustive spread
      // defense pass runs out of time. Positional urgency must not override it.
      if (!next.finished &&
          threats.any((threat) =>
              threat.$1 != game.current &&
              _winsAt(next, threat.$1, threat.$2))) {
        score -= 100000;
      }
      onRoot?.call(move, next, score);
      ranked.add((move, next, score));
    }
    ranked.sort((a, b) => b.$3.compareTo(a.$3));
    return ranked;
  }

  static Iterable<MatchMove> _sampleMoves(MatchState game) sync* {
    double priority(Cell cell) {
      var value = 0.0;
      for (final direction in game.geometry.directions) {
        final top = game.topAt(cell.step(direction));
        if (top != null) value += top.seat == game.current ? 3 : 2;
      }
      final radius = game.config.shape == BoardShape.square
          ? (game.config.size - 1) / 2
          : 0.0;
      value -= ((cell.x - radius).abs() + (cell.y - radius).abs()) * .1;
      return value;
    }

    final priorities = {
      for (final cell in game.geometry.cells) cell: priority(cell)
    };
    final cells = game.geometry.cells.toList()
      ..sort((a, b) {
        final order = priorities[b]!.compareTo(priorities[a]!);
        if (order != 0) return order;
        return a.x == b.x ? a.y.compareTo(b.y) : a.x.compareTo(b.x);
      });
    // Interleave simple spreads with placements before exploring larger carries.
    for (final cell in cells) {
      if (game.topAt(cell) == null) {
        for (final type in game.opening ? [PieceType.flat] : PieceType.values) {
          final move = MatchMove.place(cell, type);
          if (MatchRules.apply(game, move) != null) yield move;
        }
      } else {
        yield* MatchRules.spreads(game, cell, pickup: 1);
      }
    }
    for (final cell in cells) {
      // Bound carry generation in the mandatory sample; refinements retain
      // every legal carry under their deadline.
      final height = math.min(3, game.stackAt(cell).length);
      for (var pickup = 2; pickup <= height; pickup++) {
        yield* MatchRules.spreads(game, cell, pickup: pickup);
      }
    }
  }

  static List<(SeatId, Cell)> _placementThreats(MatchState game) {
    final threats = <(SeatId, Cell)>[];
    for (final seat in game.config.ids) {
      if (pathCost(game, seat) > 1) continue;
      for (final cell in game.geometry.cells) {
        if (game.topAt(cell) == null && _winsAt(game, seat, cell)) {
          threats.add((seat, cell));
        }
      }
    }
    return threats;
  }

  static bool _winsAt(MatchState game, SeatId seat, Cell cell) {
    var ply = game.ply;
    while (game.config.turnAt(ply) != seat) {
      ply++;
    }
    final type = game.reserves[seat]!.has(PieceType.flat)
        ? PieceType.flat
        : PieceType.capstone;
    return MatchRules.play(game.copyWith(ply: ply), MatchMove.place(cell, type))
            ?.result
            ?.winner ==
        seat;
  }

  /// Alpha-beta keeps two-player search from spending the whole budget on
  /// branches that an opponent would never choose.
  Future<double> _duelSearch(MatchState game, int depth, SeatId root,
      SearchBudget budget, double alpha, double beta,
      {int? beam}) async {
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
      return _utility(game, _evaluate(game), root);
    }
    final maximize = game.current == root;
    var best = maximize ? double.negativeInfinity : double.infinity;
    for (final (_, next, _)
        in (await _ranked(game, budget)).take(beam ?? branching)) {
      final value = await _duelSearch(
          next, depth - 1, root, budget, alpha, beta,
          beam: beam);
      if (maximize) {
        best = math.max(best, value);
        alpha = math.max(alpha, best);
      } else {
        best = math.min(best, value);
        beta = math.min(beta, best);
      }
      if (beta <= alpha) break;
    }
    return best.isFinite ? best : _utility(game, _evaluate(game), root);
  }

  Future<Map<SeatId, double>> _search(
      MatchState game, int depth, SearchBudget budget,
      {int? beam}) async {
    final pause = budget.pauseIfNeeded();
    if (pause != null) await pause;
    if (game.finished) return _evaluate(game);
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
      return _evaluate(game);
    }
    Map<SeatId, double>? best;
    var score = double.negativeInfinity;
    for (final (_, next, _)
        in (await _ranked(game, budget)).take(beam ?? _branching(game))) {
      final values = await _search(next, depth - 1, budget, beam: beam);
      final value = _utility(game, values, game.current);
      if (value > score) {
        best = values;
        score = value;
      }
    }
    return best ?? _evaluate(game);
  }

  static Map<SeatId, double> evaluate(MatchState game) =>
      _position(game, endgame: true);

  Map<SeatId, double> _evaluate(MatchState game) =>
      _position(game, endgame: level.index >= BotLevel.hard.index);

  static Map<SeatId, double> _position(MatchState game,
      {required bool endgame}) {
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
    final supply = Reserve.initial(game.config).total;
    final occupied = game.board.length / game.geometry.cells.length;
    // Flat control becomes decisive as the board fills; a road-only heuristic
    // otherwise spends its last reserves chasing blocked paths.
    final flatWeight = 4 + (endgame ? 40 * occupied * occupied : 0);
    return {
      for (final seat in game.config.ids)
        seat: _roadScore(game, seat) +
            flats[seat]! * flatWeight +
            (game.config.aiEngine == 'shared-search-v3'
                ? _development(game, seat)
                : 0) +
            // Deploying material breaks equally-valued capture/shuffle cycles.
            // Road tactics still dominate this small positional preference.
            (supply - game.reserves[seat]!.total) * 8.0 +
            game.board.values.where((stack) => stack.last.seat == seat).fold(
                0.0,
                (sum, stack) =>
                    sum +
                    math.min(4, stack.length - 1) * 2 +
                    (stack.last.type == PieceType.capstone ? 5 : 0))
    };
  }

  static double _roadScore(MatchState game, SeatId seat) {
    final cost = pathCost(game, seat);
    if (game.config.aiEngine != 'shared-search-v3' ||
        game.config.seats.length == 2) {
      return -80 * cost;
    }
    // A rival two placements from a road must matter before the final forced
    // block. Nonlinear urgency makes a slower independent race unattractive,
    // while a seat that can finish first still has reason to pursue its road.
    final pressure = math.max(0.0, 4 - cost);
    return -80 * cost + 120 * pressure * pressure;
  }

  // Shortest-path distance alone gives an isolated stone on a remote edge the
  // same value as a supported extension. Use a small secondary preference for
  // connected road stones and central access to several axes. Road distance
  // and terminal tactics retain their much larger weights.
  static double _development(MatchState game, SeatId seat) {
    var score = 0.0;
    for (final entry in game.board.entries) {
      final top = entry.value.last;
      if (top.seat != seat || top.type == PieceType.standing) continue;
      final cell = entry.key;
      final double distance;
      final double radius;
      if (game.config.shape == BoardShape.square) {
        radius = (game.config.size - 1) / 2;
        distance = math.max((cell.x - radius).abs(), (cell.y - radius).abs());
      } else {
        radius = game.config.size.toDouble();
        distance = math
            .max(cell.x.abs(), math.max(cell.y.abs(), cell.s.abs()))
            .toDouble();
      }
      score += 4 * (1 - distance / radius);
      var neighbors = 0;
      for (final direction in game.geometry.directions) {
        final other = game.topAt(cell.step(direction));
        if (other?.seat == seat && other!.type != PieceType.standing) {
          neighbors++;
        }
      }
      // Bound the reward so compact blobs do not outweigh road progress.
      score += 4 * math.min(2, neighbors);
    }
    return score;
  }

  static final _pathGraphs = Expando<_PathGraph>();

  /// Bounded integer Dijkstra, shared by both topologies and coaching features.
  /// Cache topology, not positions: all moves in a search share one geometry.
  static double pathCost(MatchState game, SeatId seat) {
    final graph = _pathGraphs[game.geometry] ??= _PathGraph(game.geometry);
    final costs = [
      for (final cell in game.geometry.cells)
        if (game.topAt(cell) == null)
          1
        else if (game.topAt(cell)!.seat == seat &&
            game.topAt(cell)!.type != PieceType.standing)
          0
        else if (game.topAt(cell)!.type == PieceType.flat)
          3
        else
          6
    ];
    final axes = game.config.profile == RulesProfile.legacyHex
        ? [seat.index]
        : List.generate(game.geometry.axisCount, (i) => i);
    return axes.map((axis) => _axisCost(graph, costs, axis)).reduce(math.min);
  }

  static double _axisCost(_PathGraph graph, List<int> costs, int axis) {
    final distances = List<int>.filled(costs.length, 1000);
    // Most distances are never visited. Allocate only the occupied buckets.
    final buckets = List<List<int>?>.filled(costs.length * 6 + 1, null);
    for (final cell in graph.starts[axis]) {
      distances[cell] = costs[cell];
      (buckets[costs[cell]] ??= []).add(cell);
    }
    for (var distance = 0; distance < buckets.length; distance++) {
      final bucket = buckets[distance];
      if (bucket == null) continue;
      for (var n = 0; n < bucket.length; n++) {
        final cell = bucket[n];
        if (distances[cell] != distance) continue;
        if (graph.ends[axis][cell]) return distance.toDouble();
        for (final neighbor in graph.neighbors[cell]) {
          final next = distance + costs[neighbor];
          if (next < distances[neighbor]) {
            distances[neighbor] = next;
            (buckets[next] ??= []).add(neighbor);
          }
        }
      }
    }
    return 1000;
  }
}

class _PathGraph {
  _PathGraph(BoardGeometry geometry) {
    final indices = {
      for (var i = 0; i < geometry.cells.length; i++) geometry.cells[i]: i
    };
    neighbors = [
      for (final cell in geometry.cells)
        [
          for (final direction in geometry.directions)
            if (indices[cell.step(direction)] case final int index) index
        ]
    ];
    starts = [
      for (var axis = 0; axis < geometry.axisCount; axis++)
        [
          for (var i = 0; i < geometry.cells.length; i++)
            if (geometry.boundary(geometry.cells[i], axis, false)) i
        ]
    ];
    ends = [
      for (var axis = 0; axis < geometry.axisCount; axis++)
        [for (final cell in geometry.cells) geometry.boundary(cell, axis, true)]
    ];
  }
  late final List<List<int>> neighbors, starts;
  late final List<List<bool>> ends;
}
