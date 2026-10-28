import '../models/piece.dart';
import '../services/ai/search_budget.dart';
import 'ai_road_connections.dart';
import 'ai_tactics.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Value/order-equivalent to aiWinningMoves on the same position. Placements
/// join existing road components instead of rebuilding a board for every gap.
/// The canonical transformer and flat adjudicator still own all game rules.
Future<List<MatchMove>> aiDuelWinningMoves(
    MatchState game, SeatId seat, SearchBudget budget,
    {int? stopAfter}) async {
  final pause = budget.pauseIfNeeded();
  if (pause != null) await pause;
  if (!aiMayWinInOne(game, seat)) return const [];
  final turn = aiTurnFor(game, seat);
  // Opening stones belong to the next seat, rather than to the mover.
  if (turn.opening) {
    return aiWinningMoves(game, seat, budget, stopAfter: stopAfter);
  }
  final connections = AiRoadConnections(turn, seat);
  final placementCanEnd = turn.board.length + 1 == turn.geometry.cells.length ||
      turn.reserves[seat]!.total == 1 ||
      turn.reserves.values.any((r) => r.total == 0);
  bool? existingRivalRoad;
  bool rivalRoad(MatchState position) => position.config.ids
      .where((id) => id != seat)
      .any((id) => AiRoadConnections(position, id, placements: false).hasRoad);
  final wins = <MatchMove>[];
  for (final move in aiWinCandidates(turn)) {
    final check = budget.pauseIfNeeded();
    if (check != null) await check;
    bool winsMove;
    if (move.type != null) {
      winsMove = connections.hasRoad ||
          move.type != PieceType.standing &&
              connections.winningCells.contains(move.from);
      if (!winsMove && placementCanEnd) {
        final next = MatchRules.apply(turn, move)!;
        // A placement cannot remove an existing rival road. Roads precede
        // flat scoring, while a mover's own road wins simultaneous roads.
        winsMove = MatchRules.flatResult(next)?.winner == seat &&
            !(existingRivalRoad ??= rivalRoad(turn));
      }
    } else {
      final next = MatchRules.apply(turn, move)!;
      winsMove = AiRoadConnections(next, seat, placements: false).hasRoad ||
          MatchRules.flatResult(next)?.winner == seat && !rivalRoad(next);
    }
    if (winsMove) {
      wins.add(move);
      if (stopAfter != null && wins.length >= stopAfter) break;
    }
  }
  return wins;
}
