import 'dart:math' as math;

/// Elapsed playing time, independent of a player's countdown bank.
class MatchElapsed {
  const MatchElapsed({this.milliseconds = 0, this.runningSince});
  final int milliseconds;
  final DateTime? runningSince;
  Duration at(DateTime now) => Duration(
      milliseconds: milliseconds +
          (runningSince == null
              ? 0
              : math.max(0, now.difference(runningSince!).inMilliseconds)));
  MatchElapsed frozen(DateTime now) =>
      MatchElapsed(milliseconds: at(now).inMilliseconds);
  MatchElapsed resumed(DateTime now) => runningSince == null
      ? MatchElapsed(milliseconds: milliseconds, runningSince: now)
      : this;
  Map<String, dynamic> toMap() => {'milliseconds': milliseconds};
  factory MatchElapsed.fromMap(Map<String, dynamic> map) {
    final value = map['milliseconds'];
    if (value is! int || value < 0) {
      throw const FormatException('Invalid elapsed time');
    }
    return MatchElapsed(milliseconds: value);
  }
  static String label(Duration duration) {
    final seconds = duration.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
