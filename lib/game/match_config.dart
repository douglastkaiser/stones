/// Match identity and control are independent of board shape and piece paint.
enum BoardShape { square, hex }

enum SeatControl { localHuman, onlineHuman, ai }

enum BotLevel { easy, medium, hard, expert }

enum RulesProfile { standardTak, sharedRoads, legacyHex }

enum SeatId {
  ivory,
  charcoal,
  copper,
  jade;

  String get label => switch (this) {
        ivory => 'Ivory',
        charcoal => 'Charcoal',
        copper => 'Copper',
        jade => 'Jade',
      };
  String get symbol => ['I', 'Ch', 'Cu', 'J'][index];
}

class SeatConfig {
  const SeatConfig(this.id,
      {this.control = SeatControl.localHuman, this.level = BotLevel.easy});
  final SeatId id;
  final SeatControl control;
  final BotLevel level;

  SeatConfig copyWith({SeatControl? control, BotLevel? level}) => SeatConfig(id,
      control: control ?? this.control, level: level ?? this.level);

  Map<String, dynamic> toMap() =>
      {'id': id.name, 'control': control.name, 'level': level.name};

  factory SeatConfig.fromMap(Map<String, dynamic> map) =>
      SeatConfig(SeatId.values.byName(map['id'] as String),
          control: SeatControl.values.byName(map['control'] as String),
          level: BotLevel.values.byName(map['level'] as String));
}

class MatchConfig {
  MatchConfig({
    required this.shape,
    required this.size,
    required List<SeatConfig> seats,
    this.starter = SeatId.ivory,
    RulesProfile? profile,
  })  : seats = List.unmodifiable(seats),
        profile = profile ??
            (shape == BoardShape.square && seats.length == 2
                ? RulesProfile.standardTak
                : RulesProfile.sharedRoads) {
    if (!sizesFor(shape).contains(size) ||
        seats.length < 2 ||
        seats.length > 4 ||
        seats.map((seat) => seat.id).toSet().length != seats.length ||
        !seats.any((seat) => seat.id == starter)) {
      throw ArgumentError('Invalid board, player count, identity or starter');
    }
    if (this.profile == RulesProfile.standardTak &&
        (shape != BoardShape.square || seats.length != 2)) {
      throw ArgumentError('Standard Tak requires two players on square');
    }
    if (this.profile == RulesProfile.legacyHex &&
        (shape != BoardShape.hex ||
            seats.length != 3 ||
            seats.any((seat) => seat.id == SeatId.jade))) {
      throw ArgumentError('Legacy Hex requires its original three identities');
    }
  }

  factory MatchConfig.defaults(BoardShape shape) => MatchConfig(
      shape: shape,
      size: shape == BoardShape.square ? 5 : 2,
      seats: SeatId.values
          .take(shape == BoardShape.square ? 2 : 3)
          .map(SeatConfig.new)
          .toList());

  /// Version of the new wire format; old room versions are decoded separately.
  static const wireVersion = 1;
  final BoardShape shape;
  final int size;
  final List<SeatConfig> seats;
  final SeatId starter;
  final RulesProfile profile;
  bool get online =>
      seats.any((seat) => seat.control == SeatControl.onlineHuman);
  late final List<SeatId> ids = List.unmodifiable(seats.map((seat) => seat.id));
  SeatId turnAt(int ply) =>
      seats[(ids.indexOf(starter) + ply) % seats.length].id;
  SeatId next(SeatId seat) => seats[(ids.indexOf(seat) + 1) % seats.length].id;
  SeatConfig seat(SeatId id) => seats.firstWhere((seat) => seat.id == id);

  static List<int> sizesFor(BoardShape shape) =>
      shape == BoardShape.square ? const [3, 4, 5, 6, 7, 8] : const [2, 3, 4];

  MatchConfig copyWith({
    BoardShape? shape,
    int? size,
    List<SeatConfig>? seats,
    SeatId? starter,
  }) {
    final newShape = shape ?? this.shape;
    final newSeats = seats ?? this.seats;
    final newStarter = starter ?? this.starter;
    return MatchConfig(
        shape: newShape,
        size: size ??
            (newShape == this.shape
                ? this.size
                : newShape == BoardShape.square
                    ? (2 * this.size + 1).clamp(3, 8)
                    : ((this.size - 1) ~/ 2).clamp(2, 4)),
        seats: newSeats,
        profile: newShape == this.shape && newSeats.length == this.seats.length
            ? profile
            : null,
        starter: newSeats.any((seat) => seat.id == newStarter)
            ? newStarter
            : newSeats.first.id);
  }

  MatchConfig addPlayer() {
    if (seats.length == 4) return this;
    final id = SeatId.values.firstWhere((id) => !ids.contains(id));
    return copyWith(seats: [...seats, SeatConfig(id)]);
  }

  MatchConfig removePlayer(SeatId id) {
    if (seats.length == 2) return this;
    return copyWith(seats: seats.where((seat) => seat.id != id).toList());
  }

  Map<String, dynamic> toMap() => {
        'version': wireVersion,
        'shape': shape.name,
        'size': size,
        'seats': seats.map((seat) => seat.toMap()).toList(),
        'starter': starter.name,
        'profile': profile.name,
      };

  factory MatchConfig.fromMap(Map<String, dynamic> map) {
    if (map['version'] != wireVersion) {
      throw const FormatException('Unsupported match configuration version');
    }
    return MatchConfig(
        shape: BoardShape.values.byName(map['shape'] as String),
        size: map['size'] as int,
        seats: (map['seats'] as List)
            .map((seat) => SeatConfig.fromMap(Map<String, dynamic>.from(seat)))
            .toList(),
        starter: SeatId.values.byName(map['starter'] as String),
        profile: RulesProfile.values.byName(map['profile'] as String));
  }
}
