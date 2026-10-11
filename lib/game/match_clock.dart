import 'match_config.dart';

/// A clock bank is debited from two acknowledged timestamps when a seat next
/// starts. This avoids trusting a client's estimate of server processing time.
class MatchClock {
  MatchClock(
      {required Map<SeatId, int> bank,
      required Map<SeatId, DateTime?> started,
      required Map<SeatId, DateTime?> stopped})
      : bank = Map.unmodifiable(bank),
        started = Map.unmodifiable(started),
        stopped = Map.unmodifiable(stopped) {
    if (bank.values.any((ms) => ms < 0) ||
        bank.length != started.length ||
        bank.length != stopped.length ||
        bank.keys.any(
            (id) => !started.containsKey(id) || !stopped.containsKey(id)) ||
        bank.keys.any((id) =>
            started[id] != null &&
            stopped[id] != null &&
            stopped[id]!.isBefore(started[id]!))) {
      throw const FormatException('Invalid match clock');
    }
  }
  factory MatchClock.initial(MatchConfig config) => MatchClock(
      bank: {for (final id in config.ids) id: config.clockSeconds * 1000},
      started: {for (final id in config.ids) id: null},
      stopped: {for (final id in config.ids) id: null});
  final Map<SeatId, int> bank;
  final Map<SeatId, DateTime?> started, stopped;
  int remaining(SeatId id, DateTime now) {
    final start = started[id];
    final elapsed = start == null
        ? 0
        : (stopped[id] ?? now).difference(start).inMilliseconds;
    return (bank[id]! - elapsed).clamp(0, bank[id]!);
  }

  bool expired(SeatId id, DateTime now) =>
      started[id] != null && stopped[id] == null && remaining(id, now) == 0;
  MatchClock advance(SeatId current, SeatId next, DateTime now) => MatchClock(
      bank: {...bank, next: remaining(next, now)},
      started: {...started, next: now},
      stopped: {...stopped, current: now, next: null});
  MatchClock frozen(DateTime now) => MatchClock(
      bank: {for (final id in bank.keys) id: remaining(id, now)},
      started: {for (final id in bank.keys) id: null},
      stopped: {for (final id in bank.keys) id: null});
  MatchClock begin(SeatId seat, DateTime now) => MatchClock(
      bank: bank,
      started: {...started, seat: now},
      stopped: {...stopped, seat: null});
  Map<String, dynamic> toMap() => {
        'bank': {for (final e in bank.entries) e.key.name: e.value},
        'started': {
          for (final e in started.entries)
            e.key.name: e.value?.toUtc().toIso8601String()
        },
        'stopped': {
          for (final e in stopped.entries)
            e.key.name: e.value?.toUtc().toIso8601String()
        },
      };
  factory MatchClock.fromMap(Map<String, dynamic> map) {
    Map<SeatId, DateTime?> times(String key) =>
        Map<String, dynamic>.from(map[key]).map((id, value) => MapEntry(
            SeatId.values.byName(id),
            value == null ? null : DateTime.parse(value as String)));
    return MatchClock(
        bank: Map<String, dynamic>.from(map['bank'])
            .map((id, ms) => MapEntry(SeatId.values.byName(id), ms as int)),
        started: times('started'),
        stopped: times('stopped'));
  }
}
