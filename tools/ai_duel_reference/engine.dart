// Frozen v3 reference from ec5d3dcef52d5e7c5d6f995819b7cd179b49b8fc. Do not tune.
import 'dart:convert';
import 'package:stones/game/ai_position.dart';
import 'package:stones/game/ai_search_cache.dart';
import 'package:stones/game/ai_material.dart';
import 'package:stones/game/ai_tactics.dart';
import 'dart:math' as math;
import 'package:stones/models/piece.dart';
import 'package:stones/services/ai/search_budget.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';

/// Experimental final-choice policies. Production retains deterministic play.
enum AiMoveVariation { deterministic, ties, weighted }

/// A shared search: zero-sum minimax for two seats, MaxN for independent rivals.
/// Branching and depth are bounded; every adopted iteration finishes all roots.
class MatchSearchStats {
  // Depth is measured in individual moves; completedRounds records full cycles.
  int completedDepth = 0,
      completedRounds = 0,
      completedRootWidth = 0,
      evaluatedRoots = 0,
      elapsedMs = 0;
  final consideredSeats = <SeatId>{};
  int cacheHits = 0, cacheEntries = 0, cacheEvictions = 0, forksProven = 0;
  bool timedOut = false;
  String stage = 'roots';
  String? timeoutStage;
  int? decisionSeed;
  List<Map<String, Object?>> alternatives = const [];
}

class MatchAI {
  MatchAI(this.level,
      {this.yieldDuringSearch = true,
      this.onSearchComplete,
      this.useCaches = true,
      this.cacheCapacity = 10000,
      this.variation = AiMoveVariation.deterministic,
      this.materialWeights = const AiMaterialWeights()});
  final AiMoveVariation variation;
  math.Random? _random;
  final bool useCaches;
  final int cacheCapacity;
  final AiMaterialWeights materialWeights;
  AiSearchCache? _cache;
  Expando<String> _keys = Expando<String>();
  Expando<String> _moveKeys = Expando<String>();
  Map<String, int> _recent = {};
  bool _v3(MatchState game) => game.config.aiEngine == 'shared-search-v3';
  String _key(MatchState game) =>
      _cache == null ? '' : (_keys[game] ??= aiDecisionPositionKey(game));
  String _moveKey(MatchState game, MatchMove move) =>
      _moveKeys[move] ??= jsonEncode(move.toMap(game.current));

  MatchMove _rootChoice(MatchState game, List<(MatchMove, double)> scores,
      {bool allowVariation = true}) {
    scores.sort((a, b) => b.$2.compareTo(a.$2));
    if (!_v3(game) || scores.first.$2.abs() >= 100000) {
      return scores.first.$1;
    }
    final plausible =
        scores.where((s) => s.$2 >= scores.first.$2 - 24).toList();
    int repeats(MatchMove move) =>
        _recent[aiPositionKey(MatchRules.play(game, move)!)] ?? 0;
    final least = plausible.map((s) => repeats(s.$1)).reduce(math.min);
    final pool = plausible.where((s) => repeats(s.$1) == least).toList();
    if (allowVariation && variation != AiMoveVariation.deterministic) {
      final best = pool.first.$2;
      final margin = variation == AiMoveVariation.ties ? 0.0 : 4.0;
      final close = pool.where((s) => s.$2 >= best - margin).toList();
      final weights = close.map((s) => 1 / (1 + best - s.$2)).toList();
      var draw = _random!.nextDouble() * weights.reduce((a, b) => a + b);
      for (var i = 0; i < close.length; i++) {
        draw -= weights[i];
        if (draw <= 0) return close[i].$1;
      }
      return close.last.$1;
    }
    if (level == BotLevel.easy && !game.opening) {
      final seed = game.ply * 31 +
          game.board.keys.fold<int>(0, (sum, c) => sum + c.x * 7 + c.y * 13);
      return pool[seed.abs() % pool.length].$1;
    }
    return pool.first.$1;
  }

  void _rememberPv(MatchState game, MatchMove move) {
    _cache?.put('pv:${_key(game)}', _moveKey(game, move));
  }

  Iterable<(MatchMove, MatchState, double)> _ordered(MatchState game,
      List<(MatchMove, MatchState, double)> ranked, int count) {
    if (!_v3(game)) return ranked.take(count);
    final selected = ranked.take(count).toList();
    final pv = _cache?.get<String>('pv:${_key(game)}');
    if (pv != null) {
      final index =
          selected.indexWhere((entry) => _moveKey(game, entry.$1) == pv);
      if (index > 0) selected.insert(0, selected.removeAt(index));
    }
    return selected;
  }

  final void Function(MatchSearchStats)? onSearchComplete;
  final BotLevel level;
  final bool yieldDuringSearch;
  // Targets are full rounds for v3; saved v2 games retain individual-move depth.
  int get depth => [1, 2, 2, 3][level.index];
  int get branching => [4, 8, 12, 16][level.index];
  int _branching(MatchState game) =>
      game.config.seats.length > 2 ? [4, 8, 8, 10][level.index] : branching;
  // Establish the same completed lower-depth result before adding width or
  // depth. Otherwise additional root moves can make a stronger tier
  // fall back to the weaker, selective baseline more often.
  int _rootWidth(MatchState game, int stage) => _v3(game) &&
          game.config.seats.length == 2 &&
          level == BotLevel.expert &&
          stage <= 2
      ? 12
      : _branching(game);
  Duration get thinkingLimit =>
      Duration(milliseconds: [200, 500, 1200, 2200][level.index]);

  Future<MatchMove?> choose(MatchState game,
      {bool Function()? cancelled,
      int? decisionSeed,
      List<String> recentPositionKeys = const []}) async {
    if (game.finished) return null;
    final effectiveSeed = variation == AiMoveVariation.deterministic
        ? null
        : decisionSeed ?? math.Random().nextInt(0x7fffffff);
    _random = effectiveSeed == null ? null : math.Random(effectiveSeed);
    _cache =
        _v3(game) && useCaches ? AiSearchCache(capacity: cacheCapacity) : null;
    _keys = Expando<String>();
    _moveKeys = Expando<String>();
    _recent = {};
    for (final key in recentPositionKeys
        .skip(math.max(0, recentPositionKeys.length - 64))) {
      _recent.update(key, (n) => n + 1, ifAbsent: () => 1);
    }
    final first = MatchRules.legalMoves(game).firstOrNull;
    if (first == null) return null;
    var best = first;
    final roundSearch = game.config.aiEngine == 'shared-search-v3';
    var roundCandidates = <(MatchMove, MatchState, double)>[];
    final stats = MatchSearchStats()..decisionSeed = effectiveSeed;
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
        best = await _oneRound(game, candidates, stats, cancelled,
            allowVariation: level == BotLevel.easy);
        // Fork proof is opportunistic: only a complete enumeration of joint
        // defenses can promote a move to a forced win. Deadline exhaustion is unknown.
        stats.stage = 'fork proof';
        for (final candidate in candidates.take(2)) {
          if (await aiVerifyFork(candidate.$2, game.current, budget,
                  onTimeout: () {
                stats.timedOut = true;
                stats.timeoutStage = 'fork proof';
              }) ==
              AiForkStatus.proven) {
            stats.forksProven++;
            return candidate.$1;
          }
        }
        if (level == BotLevel.easy) return best;
      }
      stats.stage = 'search';
      final targetDepth = !roundSearch ||
              game.config.seats.length > 2 && level == BotLevel.medium
          ? [1, 1, 2, 3][level.index]
          : depth;
      final widenDuel = roundSearch &&
          game.config.seats.length == 2 &&
          level == BotLevel.expert &&
          targetDepth >= 2 &&
          candidates.length > 12;
      for (var iteration = 1;
          iteration <= targetDepth + (widenDuel ? 1 : 0);
          iteration++) {
        final rounds = widenDuel && iteration > 2 ? iteration - 1 : iteration;
        final plies = roundSearch ? rounds * game.config.seats.length : rounds;
        final beam = roundSearch ? (level == BotLevel.medium ? 2 : 3) : null;
        final iterationScores = <(MatchMove, double)>[];
        MatchMove? iterationMove;
        var score = double.negativeInfinity;
        final selected = candidates.take(_rootWidth(game, iteration)).toList();
        final principal =
            selected.indexWhere((entry) => identical(entry.$1, best));
        if (roundSearch && game.config.seats.length == 2 && principal > 0) {
          selected.insert(0, selected.removeAt(principal));
        }
        final exactAlternatives = roundSearch &&
            (variation != AiMoveVariation.deterministic ||
                selected.any(
                    (entry) => _recent.containsKey(aiPositionKey(entry.$2))));
        for (final (move, next, _) in selected) {
          final double value;
          if (game.config.seats.length == 2) {
            value = await _duelSearch(
                next,
                plies - 1,
                game.current,
                budget,
                exactAlternatives ? double.negativeInfinity : score,
                double.infinity,
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
          stats.alternatives = [
            for (final (move, value) in iterationScores)
              {
                'move': move.toMap(game.current),
                'score': value,
                'exact': exactAlternatives
              }
          ];
          best = exactAlternatives
              ? _rootChoice(game, iterationScores)
              : iterationMove;
          stats.completedDepth = plies;
          stats.completedRootWidth = selected.length;
          if (roundSearch) stats.completedRounds = rounds;
          completedScores = iterationScores;
        }
      }
      if (!roundSearch &&
          level == BotLevel.medium &&
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
      stats.timeoutStage ??= stats.stage;
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
      stats.cacheHits = _cache?.hits ?? 0;
      stats.cacheEntries = _cache?.weight ?? 0;
      stats.cacheEvictions = _cache?.evictions ?? 0;
      _cache = null;
      _keys = Expando<String>();
      _moveKeys = Expando<String>();
      _recent.clear();
      _random = null;
      onSearchComplete?.call(stats);
    }
    return best;
  }

  Future<MatchMove> _oneRound(
      MatchState game,
      List<(MatchMove, MatchState, double)> candidates,
      MatchSearchStats stats,
      bool Function()? cancelled,
      {bool allowVariation = false}) async {
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
    for (final (move, position, _) in ordered.take(_rootWidth(game, 0))) {
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
    stats.completedRootWidth = scores.length;
    stats.alternatives = [
      for (final (move, value) in scores)
        {
          'move': move.toMap(game.current),
          'score': value,
          'exact': false,
          'model': 'selective-baseline'
        }
    ];
    return _rootChoice(game, scores, allowVariation: allowVariation);
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
    final initialPause = budget.pauseIfNeeded();
    if (initialPause != null) await initialPause;
    if (_v3(game) && !aiMayWinInOne(game, game.current)) return false;
    final key = 'win:${_key(game)}';
    final cached = _cache?.get<bool>(key);
    if (cached != null) return cached;
    final moves =
        _v3(game) ? aiWinCandidates(game) : MatchRules.legalMoves(game);
    for (final move in moves) {
      final pause = budget.pauseIfNeeded();
      if (pause != null) await pause;
      if (MatchRules.play(game, move)!.result?.winner == game.current) {
        _cache?.put(key, true);
        return true;
      }
    }
    _cache?.put(key, false);
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
    final initialPause = budget.pauseIfNeeded();
    if (initialPause != null) await initialPause;
    final cacheKey = 'rank:${_key(game)}:$moveLimit';
    final cached = _cache?.get<List<(MatchMove, MatchState, double)>>(cacheKey);
    if (cached != null) {
      for (final (move, next, score) in cached) {
        onRoot?.call(move, next, score);
      }
      return cached;
    }
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
        final result = [(move, next, 100000.0)];
        _cache?.put(cacheKey, result);
        return result;
      }
      var score = _utility(game, _evaluate(next), game.current);
      if (_v3(game) && move.type == null && !next.finished) {
        // Exact result boards identify captures and wall crushes. A modest
        // ordering bonus also puts legal recaptures ahead of quiet shuffles.
        var captures = 0;
        for (final entry in next.board.entries) {
          final old = game.topAt(entry.key);
          if (old != null &&
              old.seat != game.current &&
              entry.value.last.seat == game.current) {
            captures++;
          }
        }
        score += math.min(2, captures) * 2;
      }
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
    ranked.sort((a, b) {
      final order = b.$3.compareTo(a.$3);
      return order != 0 || !_v3(game)
          ? order
          : _moveKey(game, a.$1).compareTo(_moveKey(game, b.$1));
    });
    _cache?.put(cacheKey, ranked, cost: math.max(1, ranked.length));
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
      {int? beam, bool extend = true}) async {
    final initialPause = budget.pauseIfNeeded();
    if (initialPause != null) await initialPause;
    final key = 'duel:${_key(game)}:$depth:${root.name}:$beam:$extend';
    final entry = _cache?.get<AiDuelEntry>(key);
    if (entry != null) {
      if (entry.bound == AiBound.exact ||
          entry.bound == AiBound.lower && entry.score >= beta ||
          entry.bound == AiBound.upper && entry.score <= alpha) {
        return entry.score;
      }
    }
    final result = await _duelBody(game, depth, root, budget, alpha, beta,
        beam: beam, extend: extend);
    _cache?.put(
        key,
        AiDuelEntry(
            result,
            result <= alpha
                ? AiBound.upper
                : result >= beta
                    ? AiBound.lower
                    : AiBound.exact));
    return result;
  }

  Future<double> _duelBody(MatchState game, int depth, SeatId root,
      SearchBudget budget, double alpha, double beta,
      {int? beam, bool extend = true}) async {
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
      if ((_v3(game) ||
              pathCost(game, game.current) <= 1 ||
              game.reserves[game.current]!.total <= 1 ||
              game.board.length + 1 >= game.geometry.cells.length) &&
          await _immediateWin(game, budget)) {
        return game.current == root
            ? 200000 - game.ply.toDouble()
            : -200000 + game.ply.toDouble();
      }
      if (_v3(game) && extend) {
        final forcing = await _forcing(game, budget);
        if (forcing.threatened && forcing.replies.isEmpty) {
          // Every legal defense was checked. A rival that can win after each
          // reply has a forced win, even though this position is not terminal
          // yet. An interrupted enumeration throws rather than proving a loss.
          return game.current == root
              ? -200000 + game.ply.toDouble() + 2
              : 200000 - game.ply.toDouble() - 2;
        }
        if (forcing.replies.isNotEmpty) {
          var value =
              game.current == root ? double.negativeInfinity : double.infinity;
          for (final (_, next, _) in forcing.replies.take(beam ?? branching)) {
            final score = await _duelSearch(
                next, game.config.seats.length - 1, root, budget, alpha, beta,
                beam: beam, extend: false);
            value = game.current == root
                ? math.max(value, score)
                : math.min(value, score);
          }
          return value;
        }
      }
      return _utility(game, _evaluate(game), root);
    }
    final maximize = game.current == root;
    var best = maximize ? double.negativeInfinity : double.infinity;
    MatchMove? principal;
    final ranked = await _ranked(game, budget);
    for (final (move, next, _) in _ordered(game, ranked, beam ?? branching)) {
      final value = await _duelSearch(
          next, depth - 1, root, budget, alpha, beta,
          beam: beam, extend: extend);
      if (maximize) {
        if (value > best) principal = move;
        best = math.max(best, value);
        alpha = math.max(alpha, best);
      } else {
        if (value < best) principal = move;
        best = math.min(best, value);
        beta = math.min(beta, best);
      }
      if (beta <= alpha) break;
    }
    if (_v3(game) && principal != null) _rememberPv(game, principal);
    return best.isFinite ? best : _utility(game, _evaluate(game), root);
  }

  Future<Map<SeatId, double>> _search(
      MatchState game, int depth, SearchBudget budget,
      {int? beam, bool extend = true}) async {
    final initialPause = budget.pauseIfNeeded();
    if (initialPause != null) await initialPause;
    final key = 'maxn:${_key(game)}:$depth:$beam:$extend';
    final cached = _cache?.get<Map<SeatId, double>>(key);
    if (cached != null) return cached;
    final result =
        await _searchBody(game, depth, budget, beam: beam, extend: extend);
    _cache?.put(key, result);
    return result;
  }

  // Extend only forced defensive sequences; quiet captures get ordering credit
  // below, avoiding an unbounded capture search in a multiplayer free-for-all.
  Future<({bool threatened, List<(MatchMove, MatchState, double)> replies})>
      _forcing(MatchState game, SearchBudget budget) async {
    if (!await _rivalWin(game, game.current, budget)) {
      return (threatened: false, replies: <(MatchMove, MatchState, double)>[]);
    }
    final replies = <(MatchMove, MatchState, double)>[];
    for (final candidate in await _ranked(game, budget)) {
      if (candidate.$2.result?.winner == game.current ||
          candidate.$2.result?.draw == true ||
          !candidate.$2.finished &&
              !await _rivalWin(candidate.$2, game.current, budget)) {
        replies.add(candidate);
      }
    }
    return (threatened: true, replies: replies);
  }

  Future<Map<SeatId, double>> _searchBody(
      MatchState game, int depth, SearchBudget budget,
      {int? beam, bool extend = true}) async {
    final pause = budget.pauseIfNeeded();
    if (pause != null) await pause;
    if (game.finished) return _evaluate(game);
    if (depth == 0) {
      if ((_v3(game) ||
              pathCost(game, game.current) <= 1 ||
              game.reserves[game.current]!.total <= 1 ||
              game.board.length + 1 >= game.geometry.cells.length) &&
          await _immediateWin(game, budget)) {
        return {
          for (final id in game.config.ids)
            id: id == game.current ? 100000 : -100000
        };
      }
      if (_v3(game) && extend) {
        final forcing = await _forcing(game, budget);
        if (forcing.replies.isNotEmpty) {
          Map<SeatId, double>? result;
          var score = double.negativeInfinity;
          for (final (_, next, _)
              in forcing.replies.take(beam ?? _branching(game))) {
            final values = await _search(
                next, game.config.seats.length - 1, budget,
                beam: beam, extend: false);
            final value = _utility(game, values, game.current);
            if (value > score) {
              score = value;
              result = values;
            }
          }
          return result!;
        }
      }
      return _evaluate(game);
    }
    Map<SeatId, double>? best;
    var score = double.negativeInfinity;
    MatchMove? principal;
    final ranked = await _ranked(game, budget);
    for (final (move, next, _)
        in _ordered(game, ranked, beam ?? _branching(game))) {
      final values =
          await _search(next, depth - 1, budget, beam: beam, extend: extend);
      final value = _utility(game, values, game.current);
      if (value > score ||
          _v3(game) &&
              value == score &&
              principal != null &&
              ranked.indexWhere((entry) => identical(entry.$1, move)) <
                  ranked
                      .indexWhere((entry) => identical(entry.$1, principal))) {
        best = values;
        principal = move;
        score = value;
      }
    }
    if (_v3(game) && principal != null) _rememberPv(game, principal);
    return best ?? _evaluate(game);
  }

  static Map<SeatId, double> evaluate(MatchState game) =>
      _position(game, endgame: true);

  Map<SeatId, double> _evaluate(MatchState game) {
    final key = 'eval:${_key(game)}';
    final cached = _cache?.get<Map<SeatId, double>>(key);
    if (cached != null) return cached;
    final values = _position(game, endgame: level.index >= BotLevel.hard.index);
    if (_v3(game) && !game.finished) {
      for (final id in game.config.ids) {
        values[id] = values[id]! + aiMaterialScore(game, id, materialWeights);
      }
    }
    _cache?.put(key, values);
    return values;
  }

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

  static bool _isV3(MatchState game) =>
      game.config.aiEngine == 'shared-search-v3';

  /// Diagnostic terms use the same units as the positional evaluator. Material
  /// probes are separate because callers can supply experimental weights.
  static Map<String, double> evaluationTerms(MatchState game, SeatId seat,
      {bool endgame = true}) {
    if (game.finished) return {'terminal': evaluate(game)[seat]!};
    final occupied = game.board.length / game.geometry.cells.length;
    final controlled = game.board.values.where((s) => s.last.seat == seat);
    return {
      'road': _roadScore(game, seat),
      'flats': MatchRules.flatCounts(game)[seat]! *
          (4 + (endgame ? 40 * occupied * occupied : 0)),
      'development': _isV3(game) ? _development(game, seat) : 0,
      'deployment':
          (Reserve.initial(game.config).total - game.reserves[seat]!.total) *
              8.0,
      'stackControl':
          controlled.fold(0.0, (sum, s) => sum + math.min(4, s.length - 1) * 2),
      'capMaterial': 5.0 *
          controlled.where((s) => s.last.type == PieceType.capstone).length,
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
