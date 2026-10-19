import 'match_config.dart';

enum RatingSubmissionState { pending, confirmed, unrated, failed }

class RatingDelta {
  const RatingDelta(this.before, this.after);
  final int before, after;
  int get delta => after - before;
  String get label => delta == 0
      ? '±0'
      : delta > 0
          ? '+$delta'
          : '$delta';
}

/// A receipt belongs to one match, never to a difference between live profiles.
class RatingSubmission {
  const RatingSubmission(this.state, this.message,
      {this.deltas = const {},
      this.formatDeltas = const {},
      this.skillBased = false});
  const RatingSubmission.pending([String message = 'Checking game result…'])
      : this(RatingSubmissionState.pending, message);
  const RatingSubmission.unrated([String message = 'Unrated'])
      : this(RatingSubmissionState.unrated, message);
  const RatingSubmission.failed(
      [String message =
          'Rating update could not finish. Retry when connected.'])
      : this(RatingSubmissionState.failed, message);

  final RatingSubmissionState state;
  final String message;
  final Map<SeatId, RatingDelta> deltas;
  final Map<SeatId, RatingDelta> formatDeltas;
  final bool skillBased;
  bool get retryable =>
      state == RatingSubmissionState.pending ||
      state == RatingSubmissionState.failed;

  String labelFor(SeatId? seat) {
    final value = deltas[seat];
    if (value != null) {
      return skillBased
          ? 'Overall ${value.label} · Format ${formatDeltas[seat]?.label ?? "pending"}'
          : 'Elo ${value.label}';
    }
    return switch (state) {
      RatingSubmissionState.unrated => 'Unrated',
      RatingSubmissionState.confirmed => 'Elo recorded',
      RatingSubmissionState.pending ||
      RatingSubmissionState.failed =>
        'Elo pending',
    };
  }
}
