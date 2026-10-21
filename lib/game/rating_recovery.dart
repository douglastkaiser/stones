import 'rating_submission.dart';

/// Bounded, identity-scoped recovery. Durable receipts make retries idempotent.
Future<void> recoverRating(
    {required Future<RatingSubmission> Function() submit,
    required bool Function() isCurrent,
    required void Function(RatingSubmission) onResult,
    List<Duration> delays = const [
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
      Duration(seconds: 30)
    ]}) async {
  RatingSubmission? previous;
  for (final delay in delays) {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!isCurrent()) return;
    RatingSubmission next;
    try {
      next = await submit();
    } catch (error) {
      next = RatingSubmission(
          RatingSubmissionState.failed, ratingFailureMessage(error),
          failure: ratingFailure(error));
    }
    if (!isCurrent()) return;
    next = next.retainConfirmed(previous);
    onResult(next);
    previous = next;
    if (!next.retryable) return;
  }
}
