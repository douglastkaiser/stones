import 'package:flutter_test/flutter_test.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_room.dart';
import 'package:stones/models/piece.dart' show PieceType;

HexRoom room(List<HexSeatKind> kinds) => HexRoom(
    code: 'HABCDEF',
    host: 'host',
    radius: 2,
    kinds: kinds,
    owners: kinds
        .map((kind) => kind == HexSeatKind.localHuman ? 'host' : null)
        .toList());

void main() {
  test('all 27 local/remote/AI seat compositions fill exactly three seats', () {
    for (final first in HexSeatKind.values) {
      for (final second in HexSeatKind.values) {
        for (final third in HexSeatKind.values) {
          final kinds = [first, second, third];
          var match = room(kinds);
          expect(match.ready, !kinds.contains(HexSeatKind.remoteHuman));
          for (var n = 0;
              n < kinds.where((kind) => kind == HexSeatKind.remoteHuman).length;
              n++) {
            match = match.join('remote$n');
          }
          expect(match.ready, isTrue);
          expect(match.kinds, kinds);
          for (var ply = 0; ply < 3; ply++) {
            final game = match.replay();
            final uid = kinds[game.current.index] == HexSeatKind.ai
                ? 'host'
                : match.owners[game.current.index]!;
            match = match.append(
                uid, ply, HexMove.place(HexCell(ply - 1, 0), PieceType.flat));
          }
          expect(match.replay().ply, 3);
          expect(match.replay().opening, isFalse);
        }
      }
    }
  });

  test('second and third humans join different seats; rejoin is idempotent',
      () {
    var match = room([
      HexSeatKind.localHuman,
      HexSeatKind.remoteHuman,
      HexSeatKind.remoteHuman
    ]);
    match = match.join('guest');
    expect(match.ready, isFalse);
    expect(identical(match.join('guest'), match), isTrue);
    match = match.join('third');
    expect(match.ready, isTrue);
    expect(match.controlledBy('guest'), {HexSeat.charcoal});
    expect(match.controlledBy('third'), {HexSeat.copper});
    expect(() => match.join('fourth'), throwsStateError);
    expect(match.owners, ['host', 'guest', 'third']);
  });

  test('two humans and one AI rejects outsider, wrong turn and stale move', () {
    var match =
        room([HexSeatKind.localHuman, HexSeatKind.remoteHuman, HexSeatKind.ai]);
    final move = HexMove.place(const HexCell(0, 0), PieceType.flat);
    expect(() => match.append('host', 0, move), throwsStateError);
    match = match.join('guest');
    expect(() => match.append('guest', 0, move), throwsStateError);
    match = match.append('host', 0, move);
    expect(() => match.append('host', 0, move), throwsStateError);
    expect(() => match.append('host', 1, move), throwsStateError);
    match = match.append(
        'guest', 1, HexMove.place(const HexCell(1, 0), PieceType.flat));
    expect(() => match.append('guest', 2, move), throwsStateError);
    expect(() => match.append('stranger', 2, move), throwsStateError);
    match = match.append(
        'host', 2, HexMove.place(const HexCell(-1, 0), PieceType.flat));
    expect(match.replay().current, HexSeat.ivory);
  });

  test('versioned serialization replays identically and rejects corrupt logs',
      () {
    final match = room([
      HexSeatKind.localHuman,
      HexSeatKind.localHuman,
      HexSeatKind.localHuman
    ]).append('host', 0, HexMove.place(const HexCell(0, 0), PieceType.flat));
    final decoded = HexRoom.fromMap(match.toMap());
    expect(decoded.replay().topAt(const HexCell(0, 0))!.seat, HexSeat.charcoal);
    expect(decoded.replay().ply, 1);
    expect(() => HexRoom.fromMap({...match.toMap(), 'version': 2}),
        throwsFormatException);
    expect(() => HexRoom.fromMap({...match.toMap(), 'ply': 2}),
        throwsFormatException);
    final badSeat = {
      ...match.toMap(),
      'moves': {
        '0': {...match.moves.first, 'seat': 1}
      }
    };
    expect(() => HexRoom.fromMap(badSeat).replay(), throwsFormatException);
    final badCell = {
      ...match.toMap(),
      'moves': {
        '0': {...match.moves.first, 'q': 99}
      }
    };
    expect(() => HexRoom.fromMap(badCell).replay(), throwsFormatException);
    final badOpening = {
      ...match.toMap(),
      'moves': {
        '0': {...match.moves.first, 'type': 2}
      }
    };
    expect(() => HexRoom.fromMap(badOpening).replay(), throwsFormatException);
  });
}
