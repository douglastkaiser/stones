import 'hex_game.dart';

enum HexSeatKind { localHuman, remoteHuman, ai }

/// A versioned room log. No square notation or two-player session is reused.
class HexRoom {
  HexRoom(
      {required this.code,
      required this.host,
      required this.radius,
      required List<HexSeatKind> kinds,
      required List<String?> owners,
      this.starter = HexSeat.ivory,
      List<Map<String, dynamic>> moves = const []})
      : kinds = List.unmodifiable(kinds),
        owners = List.unmodifiable(owners),
        moves = List.unmodifiable(
            moves.map((move) => Map<String, dynamic>.unmodifiable({
                  ...move,
                  'drops': List<int>.unmodifiable(
                      (move['drops'] as List).cast<int>()),
                }))) {
    if (kinds.length != 3 ||
        owners.length != 3 ||
        host.isEmpty ||
        radius < 2 ||
        radius > 4) {
      throw const FormatException('Invalid hex room');
    }
    for (var seat = 0; seat < 3; seat++) {
      if ((kinds[seat] == HexSeatKind.ai && owners[seat] != null) ||
          (kinds[seat] == HexSeatKind.localHuman && owners[seat] != host)) {
        throw const FormatException('Invalid hex seat ownership');
      }
    }
  }

  final String code;
  final String host;
  final int radius;
  final List<HexSeatKind> kinds;
  final List<String?> owners;
  final HexSeat starter;
  final List<Map<String, dynamic>> moves;
  bool get ready =>
      List.generate(3, (i) => kinds[i] == HexSeatKind.ai || owners[i] != null)
          .every((filled) => filled);
  Set<HexSeat> controlledBy(String uid) => HexSeat.values
      .where((seat) =>
          kinds[seat.index] != HexSeatKind.ai && owners[seat.index] == uid)
      .toSet();
  bool canSubmit(String uid, HexGame game) =>
      ready &&
      !game.finished &&
      (owners[game.current.index] == uid ||
          (kinds[game.current.index] == HexSeatKind.ai && host == uid));

  HexGame replay() {
    var game = HexGame.initial(radius: radius, starter: starter);
    for (final record in moves) {
      if (record['seat'] != game.current.index) {
        throw const FormatException('Hex log has a move out of turn');
      }
      final next = HexRules.play(game, HexMove.fromMap(record));
      if (next == null) {
        throw const FormatException('Hex log has an illegal move');
      }
      game = next;
    }
    return game;
  }

  HexRoom join(String uid) {
    if (uid.isEmpty) throw ArgumentError('Sign in before joining');
    if (uid == host || owners.contains(uid)) return this;
    final seat = List.generate(3, (i) => i)
        .where((i) => kinds[i] == HexSeatKind.remoteHuman && owners[i] == null)
        .firstOrNull;
    if (seat == null || moves.isNotEmpty) throw StateError('This room is full');
    final joined = List<String?>.from(owners)..[seat] = uid;
    return HexRoom(
        code: code,
        host: host,
        radius: radius,
        kinds: kinds,
        owners: joined,
        starter: starter,
        moves: moves);
  }

  HexRoom append(String uid, int expectedPly, HexMove move) {
    final game = replay();
    if (expectedPly != game.ply) {
      throw StateError('The turn changed; try again');
    }
    if (!canSubmit(uid, game)) throw StateError('It is not your turn');
    if (HexRules.play(game, move) == null) throw StateError('Illegal hex move');
    return HexRoom(
        code: code,
        host: host,
        radius: radius,
        kinds: kinds,
        owners: owners,
        starter: starter,
        moves: [...moves, move.toMap(game.current)]);
  }

  Map<String, dynamic> toMap() => {
        'version': 1,
        'code': code,
        'host': host,
        'radius': radius,
        'starter': starter.index,
        'ply': moves.length,
        'kinds': {for (var i = 0; i < 3; i++) '$i': kinds[i].name},
        'owners': {for (var i = 0; i < 3; i++) '$i': owners[i]},
        'moves': {for (var i = 0; i < moves.length; i++) '$i': moves[i]},
      };

  factory HexRoom.fromMap(Map<String, dynamic> data) {
    if (data['version'] != 1) {
      throw const FormatException('Unsupported hex rules version');
    }
    final kinds = Map<String, dynamic>.from(data['kinds'] as Map);
    final owners = Map<String, dynamic>.from(data['owners'] as Map);
    final log = Map<String, dynamic>.from(data['moves'] as Map);
    final count = data['ply'] as int;
    if (count < 0 ||
        log.length != count ||
        kinds.length != 3 ||
        owners.length != 3) {
      throw const FormatException('Incomplete hex room');
    }
    return HexRoom(
        code: data['code'] as String,
        host: data['host'] as String,
        radius: data['radius'] as int,
        starter: HexSeat.values[data['starter'] as int],
        kinds: List.generate(
            3, (i) => HexSeatKind.values.byName(kinds['$i'] as String)),
        owners: List.generate(3, (i) => owners['$i'] as String?),
        moves: List.generate(
            count, (i) => Map<String, dynamic>.from(log['$i'] as Map)));
  }
}
