import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'match_config.dart';

enum RatingFailure { connection, permission, confirmation, unknown }

RatingFailure ratingFailure(Object error) => error is TimeoutException
    ? RatingFailure.connection
    : error is FirebaseException &&
            ['permission-denied', 'unauthenticated'].contains(error.code)
        ? RatingFailure.permission
        : error is FirebaseException &&
                ['unavailable', 'deadline-exceeded', 'aborted']
                    .contains(error.code)
            ? RatingFailure.connection
            : RatingFailure.unknown;

String ratingFailureMessage(Object error) => switch (ratingFailure(error)) {
      RatingFailure.permission =>
        'Rating update was denied. Sign in again; if it persists, report this game.',
      RatingFailure.connection =>
        'Rating update lost its connection. Reconnect or retry to finish.',
      RatingFailure.confirmation =>
        'Waiting for all players to confirm the result.',
      RatingFailure.unknown =>
        'Rating update could not finish. Retry or report this game.',
    };

enum RatingSubmissionState {
  pending,
  awaitingAccounts,
  confirmed,
  unrated,
  failed
}

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
      {this.failure,
      this.deltas = const {},
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

  final RatingFailure? failure;
  final RatingSubmissionState state;
  final String message;
  final Map<SeatId, RatingDelta> deltas;
  final Map<SeatId, RatingDelta> formatDeltas;
  final bool skillBased;
  bool get retryable =>
      failure != RatingFailure.permission &&
      (state == RatingSubmissionState.pending ||
          state == RatingSubmissionState.awaitingAccounts ||
          state == RatingSubmissionState.failed);

  String labelFor(SeatId? seat) {
    final value = deltas[seat];
    if (value != null) {
      return skillBased
          ? 'Overall ${value.label} · Format ${formatDeltas[seat]?.label ?? "pending"}'
          : 'Elo ${value.label}';
    }
    return switch (state) {
      RatingSubmissionState.awaitingAccounts =>
        'Unrated · player sign-in required',
      RatingSubmissionState.unrated => 'Unrated',
      RatingSubmissionState.confirmed => 'Elo recorded',
      RatingSubmissionState.pending ||
      RatingSubmissionState.failed =>
        'Elo pending',
    };
  }
}
