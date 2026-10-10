import 'hex_game.dart';
import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import '../models/cosmetics.dart';

enum HexSeatKind { localHuman, remoteHuman, ai }

/// A versioned room log. No square notation or two-player session is reused.
class HexRoom {
  HexRoom(
      {required this.code,
      required this.host,
      required this.radius,
      this.rulesVersion = 2,
      required List<HexSeatKind> kinds,
      required List<String?> owners,
      this.starter = HexSeat.ivory,
      this.boardTheme = BoardTheme.classicWood,
      List<PieceStyle> pieceStyles = const [
        PieceStyle.standard,
        PieceStyle.standard,
        PieceStyle.standard
      ],
      List<Map<String, dynamic>> moves = const []})
      : pieceStyles = List.unmodifiable(pieceStyles),
        kinds = List.unmodifiable(kinds),
        owners = List.unmodifiable(owners),
        moves = List.unmodifiable(
            moves.map((move) => Map<String, dynamic>.unmodifiable({
                  ...move,
                  'drops': List<int>.unmodifiable(
                      (move['drops'] as List).cast<int>()),
                }))) {
    if ((rulesVersion != 1 && rulesVersion != 2) ||
        pieceStyles.length != 3 ||
        kinds.length != 3 ||
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
  final int rulesVersion;
  final List<HexSeatKind> kinds;
  final List<PieceStyle> pieceStyles;
  final List<String?> owners;
  final HexSeat starter;
  final BoardTheme boardTheme;
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
    return _replayFrom(
        HexGame.initial(
            radius: radius, starter: starter, rulesVersion: rulesVersion),
        0);
  }

  /// Check every immutable prefix record but only simulate newly appended
  /// moves. Metadata-only snapshots do not rebuild the complete board.
  HexGame replayAfter(HexRoom previous, HexGame game) {
    if (code != previous.code ||
        host != previous.host ||
        radius != previous.radius ||
        rulesVersion != previous.rulesVersion ||
        game.rulesVersion != rulesVersion ||
        starter != previous.starter ||
        boardTheme != previous.boardTheme ||
        !listEquals(kinds, previous.kinds) ||
        game.ply != previous.moves.length) {
      throw const FormatException('Hex room identity changed');
    }
    if (moves.length < previous.moves.length) return game;
    for (var i = 0; i < previous.moves.length; i++) {
      final old = previous.moves[i];
      final current = moves[i];
      if (!listEquals(old['drops'] as List, current['drops'] as List) ||
          !mapEquals(
              {...old}..remove('drops'), {...current}..remove('drops'))) {
        throw const FormatException('Hex move history changed');
      }
    }
    return _replayFrom(game, previous.moves.length);
  }

  HexGame _replayFrom(HexGame game, int start) {
    for (final record in moves.skip(start)) {
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

  HexRoom join(String uid, {PieceStyle pieceStyle = PieceStyle.standard}) {
    if (uid.isEmpty) throw ArgumentError('Sign in before joining');
    if (uid == host || owners.contains(uid)) return this;
    final seat = List.generate(3, (i) => i)
        .where((i) => kinds[i] == HexSeatKind.remoteHuman && owners[i] == null)
        .firstOrNull;
    if (seat == null || moves.isNotEmpty) throw StateError('This room is full');
    final joined = List<String?>.from(owners)..[seat] = uid;
    final styles = List<PieceStyle>.from(pieceStyles)..[seat] = pieceStyle;
    return HexRoom(
        code: code,
        host: host,
        radius: radius,
        rulesVersion: rulesVersion,
        kinds: kinds,
        owners: joined,
        pieceStyles: styles,
        starter: starter,
        boardTheme: boardTheme,
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
        rulesVersion: rulesVersion,
        kinds: kinds,
        owners: owners,
        pieceStyles: pieceStyles,
        starter: starter,
        boardTheme: boardTheme,
        moves: [...moves, move.toMap(game.current)]);
  }

  Map<String, dynamic> toMap() => {
        'version': rulesVersion,
        'code': code,
        'host': host,
        'radius': radius,
        'starter': starter.index,
        'boardTheme': boardTheme.name,
        'ply': moves.length,
        'kinds': {for (var i = 0; i < 3; i++) '$i': kinds[i].name},
        'owners': {for (var i = 0; i < 3; i++) '$i': owners[i]},
        'pieceStyles': {for (var i = 0; i < 3; i++) '$i': pieceStyles[i].name},
        'moves': {for (var i = 0; i < moves.length; i++) '$i': moves[i]},
      };

  factory HexRoom.fromMap(Map<String, dynamic> data) {
    if (data['version'] != 1 && data['version'] != 2) {
      throw const FormatException('Unsupported hex rules version');
    }
    final kinds = Map<String, dynamic>.from(data['kinds'] as Map);
    final owners = Map<String, dynamic>.from(data['owners'] as Map);
    final log = Map<String, dynamic>.from(data['moves'] as Map);
    final styles = data['pieceStyles'];
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
        rulesVersion: data['version'] as int,
        starter: HexSeat.values[data['starter'] as int],
        boardTheme: boardThemeFromWire(data['boardTheme']),
        kinds: List.generate(
            3, (i) => HexSeatKind.values.byName(kinds['$i'] as String)),
        owners: List.generate(3, (i) => owners['$i'] as String?),
        pieceStyles: List.generate(
            3, (i) => pieceStyleFromWire(styles is Map ? styles['$i'] : null)),
        moves: List.generate(
            count, (i) => Map<String, dynamic>.from(log['$i'] as Map)));
  }
}
