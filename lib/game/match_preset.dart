import 'match_config.dart';

/// Friendly starting points; custom games still use the same configuration.
enum MatchPreset {
  learn('Learn with the computer',
      'Court Mode · hints, Tak! warnings and takebacks · unrated practice'),
  computer(
      'Play the computer', 'No hints · eligible signed-in games are rated'),
  sameDevice('Same-device game', 'Take turns with friends on this device'),
  online('Online friend game', 'Create a table and invite your friends');

  const MatchPreset(this.label, this.description);
  final String label;
  final String description;

  MatchConfig configuration(BoardShape shape,
      {int? size, int? playerCount, BotLevel level = BotLevel.easy}) {
    final defaults = MatchConfig.defaults(shape);
    final seats = SeatId.values
        .take(playerCount ?? defaults.seats.length)
        .map(SeatConfig.new)
        .toList();
    final control = switch (this) {
      learn || computer => SeatControl.ai,
      sameDevice => SeatControl.localHuman,
      online => SeatControl.onlineHuman,
    };
    return defaults.copyWith(
      size: size,
      court: this == learn,
      seats: [
        seats.first,
        for (final seat in seats.skip(1))
          seat.copyWith(control: control, level: level),
      ],
    );
  }
}
