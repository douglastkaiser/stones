import '../services/ai/search_budget.dart';
import '../models/piece.dart';
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
int _roadSpan(MatchState game) => game.config.shape == BoardShape.square
    ? game.config.size
    : 2 * game.config.size + 1;

int _stoneCount(MatchState game, SeatId seat) => game.board.values.fold<int>(
    0,
    (count, stack) =>
        count + stack.where((stone) => stone.seat == seat).length);

bool _flatEndingPossible(MatchState game) =>
    game.board.length + game.geometry.carryLimit >=
        game.geometry.cells.length ||
    game.reserves.values.any((reserve) => reserve.total <= 1);

bool aiMayWinInOne(MatchState game, SeatId seat) {
  if (game.finished) return false;
  if (_flatEndingPossible(game)) return true;
  return _stoneCount(game, seat) + 1 >= _roadSpan(game);
}

/// Exact pruning, not a move preference: spreads add no material, so they
/// cannot complete a road with fewer stones than the board's span. A spread
/// can fill several empty cells; possible flat endings retain every legal move.
Iterable<MatchMove> aiWinCandidates(MatchState game) sync* {
  if (game.opening ||
      _flatEndingPossible(game) ||
      _stoneCount(game, game.current) >= _roadSpan(game)) {
    yield* MatchRules.legalMoves(game);
    return;
  }
  final reserve = game.reserves[game.current]!;
  for (final cell in game.geometry.cells) {
    if (game.topAt(cell) != null) continue;
    for (final type in [PieceType.flat, PieceType.capstone]) {
      if (reserve.has(type)) yield MatchMove.place(cell, type);
    }
  }
}

Future<List<MatchMove>> aiWinningMoves(
    MatchState game, SeatId seat, SearchBudget budget,
    {int? stopAfter}) async {
  final initialPause = budget.pauseIfNeeded();
  if (initialPause != null) await initialPause;
  if (!aiMayWinInOne(game, seat)) return const [];
  final turn = aiTurnFor(game, seat);
  final wins = <MatchMove>[];
  for (final move in aiWinCandidates(turn)) {
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
