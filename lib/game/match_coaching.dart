import 'match_ai.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Explain observable effects and the search's heuristic, without claiming proof.
class MatchCoaching {
  static String explain(MatchState before, MatchMove move) {
    final after = MatchRules.play(before, move);
    if (after == null) return 'This move is no longer legal.';
    final player = before.current;
    final action = move.direction == null
        ? 'place ${move.type!.name} at (${move.from.x}, ${move.from.y})'
        : 'move ${move.carry} pieces ${move.direction!.name}, dropping ${move.drops.join(' → ')}';
    if (before.opening) {
      return '${player.label}: $action. The opening places ${before.config.next(player).label}’s flat; look for space to develop your own road next.';
    }
    if (after.result?.winner == player) {
      return '${player.label}: $action. This wins by ${after.result!.reason.name}.';
    }
    final oldCost = MatchAI.pathCost(before, player);
    final newCost = MatchAI.pathCost(after, player);
    final oldFlats = MatchRules.flatCounts(before)[player]!;
    final newFlats = MatchRules.flatCounts(after)[player]!;
    final road = newCost < oldCost
        ? 'It improves your cheapest route between opposite sides.'
        : newCost > oldCost
            ? 'It trades some road potential for position.'
            : 'Your estimated road distance stays the same.';
    final blocked = before.config.ids
        .where((id) =>
            id != player &&
            MatchAI.pathCost(after, id) > MatchAI.pathCost(before, id))
        .map((id) => id.label)
        .toList();
    return '${player.label}: $action. $road '
        '${blocked.isEmpty ? '' : 'It makes ${blocked.join(' and ')}’s cheapest route harder. '}'
        '${newFlats == oldFlats ? '' : 'Your exposed flat count changes from $oldFlats to $newFlats. '}'
        'This is a bounded search estimate, not a guaranteed best move.';
  }
}
