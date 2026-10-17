import 'match_config.dart';

class RatingPool {
  const RatingPool(this.shape, this.size, this.players, this.profile, this.clock);
  factory RatingPool.forConfig(MatchConfig config) => RatingPool(config.shape,
      config.size, config.seats.length, config.profile,
      config.clockSeconds == 0 ? 'open' : config.clockSeconds < 600 ? 'fast' : 'long');
  final BoardShape shape;
  final int size;
  final int players;
  final RulesProfile profile;
  final String clock;
  String get id => '${shape.name}-$size-$players-${profile.name}-$clock';
  String get label => '${shape == BoardShape.square ? "Square $size×$size" : "Hex radius $size"} · $players players · ${clock == "open" ? "Untimed" : clock == "fast" ? "Under 10 min" : "10+ min"}';
  static final standard = RatingPool.forConfig(MatchConfig.defaults(BoardShape.square));
  static List<RatingPool> get all => [
    for (final shape in BoardShape.values)
      for (final size in MatchConfig.sizesFor(shape))
        for (final players in [2, 3, 4])
          for (final clock in ['open', 'fast', 'long'])
            RatingPool(shape, size, players, shape == BoardShape.square && players == 2 ? RulesProfile.standardTak : RulesProfile.sharedRoads, clock)
  ];
}
