import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Final placements shared by result presentation and rating settlement.
class MatchStandings {
  MatchStandings._(this.ranks, this.flats);

  final Map<SeatId, int> ranks;
  final Map<SeatId, int> flats;

  static MatchStandings? forGame(MatchState game) {
    final result = game.result;
    if (result == null || result.reason == ResultReason.abandoned) return null;
    final counts = MatchRules.flatCounts(game);
    if (game.config.ratingVersion == 1) {
      return MatchStandings._(
          Map.unmodifiable({
            for (final id in game.config.ids)
              id: result.winner == null || result.winner == id ? 1 : 2
          }),
          Map.unmodifiable(counts));
    }
    final leaders = result.winner != null
        ? {result.winner!}
        : result.reason == ResultReason.road
            ? game.config.ids
                .where((seat) => MatchRules.road(game, seat).isNotEmpty)
                .toSet()
            : counts.entries
                .where((entry) =>
                    entry.value ==
                    counts.values.reduce((a, b) => a > b ? a : b))
                .map((entry) => entry.key)
                .toSet();
    final ranks = <SeatId, int>{};
    for (final seat in game.config.ids) {
      ranks[seat] = leaders.contains(seat)
          ? 1
          : 1 +
              leaders.length +
              game.config.ids
                  .where((other) =>
                      !leaders.contains(other) &&
                      counts[other]! > counts[seat]!)
                  .length;
    }
    return MatchStandings._(Map.unmodifiable(ranks), Map.unmodifiable(counts));
  }

  double score(SeatId player, SeatId opponent) =>
      ranks[player]! == ranks[opponent]!
          ? 0.5
          : ranks[player]! < ranks[opponent]!
              ? 1
              : 0;

  List<SeatId> get ordered => ranks.keys.toList()
    ..sort((a, b) {
      final order = ranks[a]!.compareTo(ranks[b]!);
      return order == 0 ? a.index.compareTo(b.index) : order;
    });
}
