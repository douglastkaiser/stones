import 'dart:math';

/// Version 3 uses weighted Glicko-1 observations from a single completed game.
/// Losing seats are unordered: they supply no observations about one another.
class SkillEstimate {
  const SkillEstimate({this.mean = 1200, this.deviation = 350});

  final double mean;
  final double deviation;
  int get rating => mean.round();
  int get lower => (mean - 1.96 * deviation).round();
  int get upper => (mean + 1.96 * deviation).round();

  Map<String, dynamic> toMap() => {'mean': mean, 'deviation': deviation};
  factory SkillEstimate.fromMap(Map<String, dynamic> data) => SkillEstimate(
      mean: (data['mean'] as num?)?.toDouble() ?? 1200,
      deviation: (data['deviation'] as num?)?.toDouble() ?? 350);
}

class SkillObservation {
  const SkillObservation(this.opponent, this.score, {this.weight = 1});
  final SkillEstimate opponent;
  final double score, weight;
}

class SkillCalculator {
  static final double q = log(10) / 400;
  static const double minimumDeviation = 50;

  /// All observations use pre-match estimates. One multiplayer game carries
  /// at most one duel's evidence; repeated AI seats do not multiply certainty.
  static SkillEstimate update(
      SkillEstimate before, Iterable<SkillObservation> observations) {
    if (!before.mean.isFinite ||
        !before.deviation.isFinite ||
        before.deviation <= 0) {
      throw ArgumentError('Invalid skill estimate');
    }
    var gradient = 0.0;
    var information = 0.0;
    for (final observation in observations) {
      final opponent = observation.opponent;
      if (![0.0, 0.5, 1.0].contains(observation.score) ||
          !observation.weight.isFinite ||
          observation.weight <= 0 ||
          !opponent.mean.isFinite ||
          !opponent.deviation.isFinite ||
          opponent.deviation <= 0) {
        throw ArgumentError('Invalid skill observation');
      }
      final g =
          1 / sqrt(1 + 3 * q * q * pow(opponent.deviation, 2) / (pi * pi));
      final expected =
          1 / (1 + pow(10, -g * (before.mean - opponent.mean) / 400));
      gradient += observation.weight * g * (observation.score - expected);
      information += observation.weight * g * g * expected * (1 - expected);
    }
    final variance = 1 / (1 / pow(before.deviation, 2) + q * q * information);
    return SkillEstimate(
        mean: before.mean + q * variance * gradient,
        deviation: max(minimumDeviation, sqrt(variance)));
  }

  static Map<String, SkillEstimate> forMatch({
    required List<String> participants,
    required int winner,
    required Map<String, SkillEstimate> estimates,
  }) {
    final count = participants.length;
    if (count < 2 ||
        count > 4 ||
        winner < -1 ||
        winner >= count ||
        participants.any((id) => !estimates.containsKey(id))) {
      throw ArgumentError('Invalid skill match');
    }
    return {
      for (final id in participants.toSet())
        id: update(estimates[id]!, [
          for (var i = 0; i < count; i++)
            if (participants[i] == id)
              for (var j = 0; j < count; j++)
                if (participants[j] != id &&
                    (winner == -1 || winner == i || winner == j))
                  SkillObservation(
                      estimates[participants[j]]!,
                      winner == -1
                          ? .5
                          : winner == i
                              ? 1
                              : 0,
                      weight: 1 /
                          ((count - 1) *
                              participants.where((p) => p == id).length)),
        ])
    };
  }
}
