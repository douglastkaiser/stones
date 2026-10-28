import '../services/ai/search_budget.dart';
import 'ai_duel_tactics.dart';
import 'ai_position.dart';
import 'ai_road_connections.dart';
import 'ai_search_cache.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Exact finite-horizon forced-win objective. A refutation says a defense
/// exists within this horizon, not that the position is eventually drawn.
/// Exhaustion throws; an incomplete proof can never veto a move.
class AiDuelSafety {
  AiDuelSafety(this.budget,
      {this.cache, this.nodeLimit, this.orderMoves = true});
  final SearchBudget budget;
  final AiSearchCache? cache;
  final int? nodeLimit;
  final bool orderMoves;
  int nodes = 0;

  Future<bool> forced(MatchState game, SeatId attacker, int remaining) async {
    final pause = budget.pauseIfNeeded();
    if (pause != null) await pause;
    if (nodeLimit != null && nodes >= nodeLimit!) throw const SearchTimedOut();
    nodes++;
    if (game.config.seats.length != 2 ||
        !game.config.ids.contains(attacker) ||
        remaining < 0) {
      throw ArgumentError('A duel and nonnegative horizon required');
    }
    if (game.finished) return game.result!.winner == attacker;
    if (remaining == 0) return false;
    final key =
        'safety:${aiDecisionPositionKey(game)}:${attacker.name}:$remaining';
    final old = cache?.get<bool>(key);
    if (old != null) return old;
    bool remember(bool result) {
      cache?.put(key, result);
      return result;
    }

    final stones = game.board.values.expand((s) => s);
    final noFlats = stones.length + remaining < game.geometry.cells.length &&
        game.reserves.values.every((r) => r.total > remaining);
    final own = stones.where((s) => s.seat == attacker).length;
    final turns = [
      for (var i = 0; i < remaining; i++)
        if (game.config.turnAt(game.ply + i) == attacker) i
    ].length;
    if (!game.opening && noFlats && own + turns < game.geometry.carryLimit) {
      return remember(false);
    }
    final attack = game.current == attacker;
    final winKey = 'safety-immediate:${aiDecisionPositionKey(game)}';
    var immediate = cache?.get<bool>(winKey);
    if (immediate == null) {
      immediate =
          (await aiDuelWinningMoves(game, game.current, budget, stopAfter: 1))
              .isNotEmpty;
      cache?.put(winKey, immediate);
    }
    // The mover can end the game now: this proves an attack or refutes it
    // irrespective of the unused horizon. No speculative pruning is involved.
    if (immediate) return remember(attack);
    if (attack && remaining == 1) return remember(false);
    // If every remaining attacker turn must add a stone, a spread cannot
    // attain the minimum road span. Flat endings bypass this sound bound.
    final mustPlace = attack &&
        !game.opening &&
        noFlats &&
        own + turns == game.geometry.carryLimit;
    var any = false;
    for (final move in await _ordered(game, attacker, remaining)) {
      if (mustPlace && move.type == null) continue;
      any = true;
      final result =
          await forced(MatchRules.play(game, move)!, attacker, remaining - 1);
      if (attack && result || !attack && !result) return remember(result);
    }
    return remember(!attack && any);
  }

  Future<Iterable<MatchMove>> _ordered(
      MatchState game, SeatId attacker, int remaining) async {
    if (!orderMoves || remaining == 1) return MatchRules.legalMoves(game);
    final initialPause = budget.pauseIfNeeded();
    if (initialPause != null) await initialPause;
    final road = AiRoadConnections(game, attacker);
    final partners = road.pairContinuations;
    final critical = road.continuations.criticalCells;
    final ranked = <(MatchMove, int, int)>[];
    var index = 0;
    for (final move in MatchRules.legalMoves(game)) {
      final pause = budget.pauseIfNeeded();
      if (pause != null) await pause;
      var score = 0;
      if (move.type != null) {
        if (road.winningCells.contains(move.from)) score += 1000;
        if (critical.contains(move.from)) score += 100;
        score += (partners[move.from] ?? 0) * 20;
        for (final direction in game.geometry.directions) {
          final top = game.topAt(move.from.step(direction));
          if (top?.seat == attacker) score += 4;
        }
      } else {
        var cell = move.from;
        for (final drop in move.drops) {
          cell = cell.step(move.direction!);
          final top = game.topAt(cell);
          if (drop > 0 && top != null && top.seat != game.current) score += 30;
        }
      }
      ranked.add((move, score, index++));
    }
    ranked.sort(
        (a, b) => a.$2 == b.$2 ? a.$3.compareTo(b.$3) : b.$2.compareTo(a.$2));
    return ranked.map((r) => r.$1);
  }
}
