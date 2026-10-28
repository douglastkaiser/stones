import 'match_config.dart';

/// Friendly starting points; custom games still use the same configuration.
enum MatchPreset {
  learn('Learn with the computer',
      'Court Mode · easy computer · hints, Tak! warnings and takebacks · unrated practice'),
  computer('Play the computer',
      'Easy computer · no hints · eligible signed-in games are rated'),
  sameDevice('Same-device game', 'Take turns with friends on this device'),
  online('Online friend game', 'Create a table and invite your friends');

  const MatchPreset(this.label, this.description);
  final String label;
  final String description;

  MatchConfig configuration(BoardShape shape) {
    final defaults = MatchConfig.defaults(shape);
    final control = switch (this) {
      learn || computer => SeatControl.ai,
      sameDevice => SeatControl.localHuman,
      online => SeatControl.onlineHuman,
    };
    return defaults.copyWith(
      court: this == learn,
      seats: [
        defaults.seats.first,
        for (final seat in defaults.seats.skip(1))
          seat.copyWith(control: control),
      ],
    );
  }
}
