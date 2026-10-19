import 'dart:math';
import '../models/elo_rating.dart';

/// Seat identities can repeat for multiple instances of the same AI.
class PlacementElo {
  static Map<String, int> calculate({
    required List<String> participants,
    required List<int> ranks,
    required Map<String, int> ratings,
    required Map<String, int> gamesPlayed,
  }) {
    final count = participants.length;
    if (count < 2 ||
        count > 4 ||
        ranks.length != count ||
        ranks.any((rank) => rank < 1 || rank > count) ||
        participants.any((id) =>
            !ratings.containsKey(id) ||
            !gamesPlayed.containsKey(id) ||
            gamesPlayed[id]! < 0)) {
      throw ArgumentError('Invalid placement rating input');
    }
    if (ranks.any(
        (rank) => rank != 1 + ranks.where((other) => other < rank).length)) {
      throw ArgumentError('Placements must use competition ranks');
    }
    return {
      for (final id in participants.toSet())
        id: _rating(id, participants, ranks, ratings, gamesPlayed)
    };
  }

  static int _rating(String id, List<String> participants, List<int> ranks,
      Map<String, int> ratings, Map<String, int> gamesPlayed) {
    final count = participants.length;
    final indices = [
      for (var i = 0; i < count; i++)
        if (participants[i] == id) i
    ];
    final actual = indices
            .map((i) =>
                count -
                ranks[i] -
                .5 * (ranks.where((rank) => rank == ranks[i]).length - 1))
            .reduce((a, b) => a + b) /
        indices.length;
    final expected = participants
            .map((other) =>
                EloCalculator.expectedScore(ratings[id]!, ratings[other]!))
            .reduce((a, b) => a + b) -
        .5;
    return max(
        100,
        (ratings[id]! +
                EloCalculator.kFactor(gamesPlayed[id]!) *
                    (actual - expected) /
                    (count - 1))
            .round());
  }
}
