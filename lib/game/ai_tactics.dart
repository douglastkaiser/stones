import '../services/ai/search_budget.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

MatchState aiTurnFor(MatchState game, SeatId seat) {
  var ply = game.ply;
  while (game.config.turnAt(ply) != seat) {
    ply++;
  }
  return game.copyWith(ply: ply);
}

/// A sound material lower bound, unlike path distance: count buried stones too.
/// A move can add at most one stone; a road must span the board. Flat endings
/// bypass this shortcut. Standing stones deliberately overestimate possibilities.
bool aiMayWinInOne(MatchState game, SeatId seat) {
  if (game.finished) return false;
  if (game.board.length + 1 >= game.geometry.cells.length ||
      game.reserves.values.any((reserve) => reserve.total <= 1)) {
    return true;
  }
  final span = game.config.shape == BoardShape.square
      ? game.config.size
      : 2 * game.config.size + 1;
  final stones = game.board.values.fold<int>(
      0,
      (count, stack) =>
          count + stack.where((stone) => stone.seat == seat).length);
  return stones + 1 >= span;
}

Future<List<MatchMove>> aiWinningMoves(
    MatchState game, SeatId seat, SearchBudget budget,
    {int? stopAfter}) async {
  final initialPause = budget.pauseIfNeeded();
  if (initialPause != null) await initialPause;
  if (!aiMayWinInOne(game, seat)) return const [];
  final turn = aiTurnFor(game, seat);
  final wins = <MatchMove>[];
  for (final move in MatchRules.legalMoves(turn)) {
    final pause = budget.pauseIfNeeded();
    if (pause != null) await pause;
    if (MatchRules.play(turn, move)!.result?.winner == seat) {
      wins.add(move);
      if (stopAfter != null && wins.length >= stopAfter) break;
    }
  }
  return wins;
}

enum AiForkStatus { proven, refuted, unknown }

/// A fork is a forced win only if *every* joint defense fails in real turn order.
Future<AiForkStatus> aiVerifyFork(
    MatchState afterMove, SeatId attacker, SearchBudget budget,
    {int maxNodes = 128, void Function()? onTimeout}) async {
  if (afterMove.finished) {
    return afterMove.result!.winner == attacker
        ? AiForkStatus.proven
        : AiForkStatus.refuted;
  }
  var nodes = 0;
  Future<AiForkStatus> visit(MatchState game) async {
    if (++nodes > maxNodes) return AiForkStatus.unknown;
    final pause = budget.pauseIfNeeded();
    if (pause != null) await pause;
    if (game.finished) {
      return game.result!.winner == attacker
          ? AiForkStatus.proven
          : AiForkStatus.refuted;
    }
    if (game.current == attacker) {
      return (await aiWinningMoves(game, attacker, budget, stopAfter: 1))
              .isNotEmpty
          ? AiForkStatus.proven
          : AiForkStatus.refuted;
    }
    var unknown = false;
    var anyReply = false;
    for (final reply in MatchRules.legalMoves(game)) {
      anyReply = true;
      final result = await visit(MatchRules.play(game, reply)!);
      if (result == AiForkStatus.refuted) return result;
      if (result == AiForkStatus.unknown) unknown = true;
      if (nodes > maxNodes) return AiForkStatus.unknown;
    }
    return !anyReply || unknown ? AiForkStatus.unknown : AiForkStatus.proven;
  }

  try {
    if ((await aiWinningMoves(afterMove, attacker, budget, stopAfter: 2))
            .length <
        2) {
      return AiForkStatus.refuted;
    }
    return await visit(afterMove);
  } on SearchTimedOut {
    onTimeout?.call();
    return AiForkStatus.unknown;
  }
}
