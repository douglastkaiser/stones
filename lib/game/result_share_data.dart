import 'match_clock.dart';
import 'match_config.dart';
import 'match_controller.dart';
import 'match_standings.dart';
import 'match_state.dart';
import 'rating_submission.dart';

const stonesPlayUrl = 'https://www.douglastkaiser.com/stones/';

class ResultShareData {
  ResultShareData(this.session,
      {required this.names, required this.viewer, required this.rating});
  final MatchSession session;
  final Map<SeatId, String> names;
  final SeatId? viewer;
  final RatingSubmission rating;
  MatchState get game => session.game!;
  MatchStandings? get standings => MatchStandings.forGame(game);

  String name(SeatId id) {
    final seat = game.config.seat(id);
    var value = seat.control == SeatControl.ai
        ? '${seat.level.name[0].toUpperCase()}${seat.level.name.substring(1)} AI'
        : names[id]?.trim() ?? id.label;
    value = value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
    if (value.isEmpty) value = id.label;
    if (value.runes.length > 40) {
      value = '${String.fromCharCodes(value.runes.take(39))}…';
    }
    final same = game.config.seats.where((other) =>
        other.id != id &&
        (seat.control == SeatControl.ai
            ? other.control == SeatControl.ai && other.level == seat.level
            : names[other.id]?.trim() == names[id]?.trim() &&
                names[id] != null));
    return same.isEmpty ? value : '$value (${id.label})';
  }

  static String joinNames(List<String> values) => switch (values.length) {
        0 => '',
        1 => values.single,
        2 => '${values[0]} and ${values[1]}',
        _ => '${values.take(values.length - 1).join(', ')} and ${values.last}',
      };

  String get outcome {
    final positions = standings;
    if (positions == null) return 'Match ended';
    if (viewer == null) {
      final leaders =
          positions.ordered.where((id) => positions.ranks[id] == 1).toList();
      return leaders.length > 1
          ? '${joinNames(leaders.map(name).toList())} tied for first'
          : '${name(leaders.single)} won';
    }
    final others = positions.ordered.where((id) => id != viewer);
    final lost = others
        .where((id) => positions.score(viewer!, id) == 0)
        .map(name)
        .toList();
    final beat = others
        .where((id) => positions.score(viewer!, id) == 1)
        .map(name)
        .toList();
    final tied = others
        .where((id) => positions.score(viewer!, id) == .5)
        .map(name)
        .toList();
    return [
      if (lost.isNotEmpty) 'Lost to ${joinNames(lost)}',
      if (beat.isNotEmpty) 'Beat ${joinNames(beat)}',
      if (tied.isNotEmpty) 'Tied with ${joinNames(tied)}',
    ].join(' · ');
  }

  static String ordinal(int value) => switch (value) {
        1 => '1st',
        2 => '2nd',
        3 => '3rd',
        _ => '${value}th',
      };

  String get placement {
    final positions = standings;
    if (viewer == null || positions == null) {
      return '${game.config.seats.length} players';
    }
    final rank = positions.ranks[viewer]!;
    final tied =
        positions.ranks.values.where((value) => value == rank).length > 1;
    return '${tied ? 'Tied ' : ''}${ordinal(rank)} of ${game.config.seats.length}';
  }

  String get boardLabel => game.config.shape == BoardShape.square
      ? 'Square ${game.config.size}×${game.config.size}'
      : 'Hex radius ${game.config.size}';

  String get reason => switch (game.result?.reason) {
        ResultReason.road => 'Road',
        ResultReason.flats => 'Flats',
        ResultReason.resignation => 'Resignation',
        ResultReason.time => 'Time',
        ResultReason.abandoned || null => 'Match ended',
      };

  /// Only acknowledged/frozen clocks supply a duration. Never use share time.
  Duration? get duration {
    final clock = session.clock;
    if (clock == null || !game.finished) return null;
    DateTime? finish;
    if (session.room != null) {
      if (![ResultReason.road, ResultReason.flats]
          .contains(game.result!.reason)) {
        return null;
      }
      final starts = clock.started.values.whereType<DateTime>().toList()
        ..sort();
      if (starts.isEmpty) return null;
      finish = starts.last;
    } else if (clock.started.values.any((value) => value != null)) {
      return null;
    }
    return _consumed(clock, finish ?? DateTime.fromMillisecondsSinceEpoch(0));
  }

  Duration _consumed(MatchClock clock, DateTime finish) => Duration(
      milliseconds: game.config.ids.fold(
          0,
          (sum, id) =>
              sum +
              game.config.clockSeconds * 1000 -
              clock.remaining(id, finish)));

  String? get durationLabel {
    final elapsed = duration;
    if (elapsed == null) return null;
    final seconds = elapsed.inSeconds;
    return seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m ${seconds % 60}s';
  }

  String get stats => [
        boardLabel,
        placement,
        reason,
        '${game.ply} moves',
        if (durationLabel != null) durationLabel!,
        if (viewer != null)
          rating.labelFor(viewer)
        else if (rating.state == RatingSubmissionState.unrated)
          'Unrated',
      ].join(' · ');

  String get text => 'Stones · $outcome\n$stats\nPlay: $stonesPlayUrl';
}
