import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cosmetics.dart';
import 'match_config.dart';
import 'match_clock.dart';
import 'match_room.dart';
import 'match_state.dart';

/// Cached and pending snapshots report connectivity without advancing play.
class MatchRoomUpdate {
  const MatchRoomUpdate(this.room,
      {this.confirmed = true, this.connected = true});
  final MatchRoom? room;
  final bool confirmed;
  final bool connected;
}

abstract class MatchRoomStore {
  Future<MatchRoom> create(String uid, MatchConfig config);
  Future<MatchRoom> join(String code, String uid);
  Future<MatchRoom> read(String code);
  Stream<MatchRoomUpdate> watch(String code);
  Future<void> submit(String code, String uid, int expectedPly, MatchMove move);
  Future<void> resign(String code, String uid, SeatId seat);
  Future<MatchRoom> claimRunner(String code, String uid);
  Future<void> expire(String code, String uid);
}

class FirestoreMatchRoomStore implements MatchRoomStore {
  FirestoreMatchRoomStore(this.firestore,
      {this.style = PieceStyle.standard, this.theme = BoardTheme.classicWood});
  final FirebaseFirestore firestore;
  final PieceStyle style;
  final BoardTheme theme;
  DocumentReference<Map<String, dynamic>> _room(String code) =>
      firestore.collection('matches').doc(code);
  MatchRoom _decode(Map<String, dynamic> data) => MatchRoom.fromMap({
        ...data,
        'aiLeaseAt': (data['aiLeaseAt'] as Timestamp?)
            ?.toDate()
            .toUtc()
            .toIso8601String(),
        if (data['clock'] != null)
          'clock': {
            ...Map<String, dynamic>.from(data['clock']),
            for (final field in ['started', 'stopped'])
              field: Map<String, dynamic>.from(data['clock'][field]).map(
                  (key, value) => MapEntry(
                      key,
                      (value as Timestamp?)
                          ?.toDate()
                          .toUtc()
                          .toIso8601String())),
          },
      });
  Map<String, dynamic> _encodeClock(MatchClock clock) => {
        'bank': {for (final e in clock.bank.entries) e.key.name: e.value},
        'started': {
          for (final e in clock.started.entries)
            e.key.name: e.value == null ? null : Timestamp.fromDate(e.value!)
        },
        'stopped': {
          for (final e in clock.stopped.entries)
            e.key.name: e.value == null ? null : Timestamp.fromDate(e.value!)
        },
      };
  @override
  Future<MatchRoom> create(String uid, MatchConfig config) async {
    final random = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code =
          'U${List.generate(6, (_) => String.fromCharCode(65 + random.nextInt(26))).join()}';
      final room = MatchRoom(
          code: code,
          host: uid,
          config: config,
          owners: {
            for (final seat in config.seats)
              seat.id: seat.control == SeatControl.localHuman ? uid : null
          },
          styles: {
            for (final seat in config.seats)
              seat.id: seat.control == SeatControl.onlineHuman
                  ? PieceStyle.standard
                  : style
          },
          boardTheme: theme);
      final created = await firestore.runTransaction<bool>((tx) async {
        final ref = _room(code);
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, room.toMap());
        return true;
      });
      if (created) return room;
    }
    throw StateError('Could not allocate a room code. Try again.');
  }

  @override
  Future<MatchRoom> join(String code, String uid) =>
      firestore.runTransaction((tx) async {
        final ref = _room(code);
        final snapshot = await tx.get(ref);
        if (!snapshot.exists) throw StateError('Room not found');
        final room = _decode(snapshot.data()!);
        room.replay();
        final joined = room.join(uid, style);
        if (!identical(joined, room)) {
          tx.update(ref, {
            'owners': joined.toMap()['owners'],
            'styles': joined.toMap()['styles']
          });
        }
        return joined;
      });
  @override
  Future<MatchRoom> read(String code) async {
    final snapshot =
        await _room(code).get(const GetOptions(source: Source.server));
    if (!snapshot.exists) throw StateError('Room not found');
    return _decode(snapshot.data()!);
  }

  @override
  Stream<MatchRoomUpdate> watch(String code) =>
      _room(code).snapshots(includeMetadataChanges: true).map((snapshot) {
        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return MatchRoomUpdate(null,
              confirmed: false, connected: !snapshot.metadata.isFromCache);
        }
        if (!snapshot.exists) throw StateError('Room no longer exists');
        return MatchRoomUpdate(_decode(snapshot.data()!));
      });
  @override
  Future<void> submit(
          String code, String uid, int expectedPly, MatchMove move) =>
      firestore.runTransaction((tx) async {
        final ref = _room(code);
        final snapshot = await tx.get(ref);
        if (!snapshot.exists) throw StateError('Room no longer exists');
        final previous = _decode(snapshot.data()!);
        final game = previous.replay();
        final updated = previous.append(uid, expectedPly, move);
        final clock =
            updated.clock == null ? null : _encodeClock(updated.clock!);
        if (clock != null) {
          clock['stopped'][game.current.name] = FieldValue.serverTimestamp();
          clock['started'][game.config.next(game.current).name] =
              FieldValue.serverTimestamp();
        }
        tx.update(
            ref, {'moves': updated.moves, if (clock != null) 'clock': clock});
      });
  @override
  Future<void> resign(String code, String uid, SeatId seat) =>
      firestore.runTransaction((tx) async {
        final ref = _room(code);
        final snapshot = await tx.get(ref);
        if (!snapshot.exists) throw StateError('Room no longer exists');
        final updated = _decode(snapshot.data()!).resign(uid, seat);
        tx.update(ref, {'resigned': updated.resigned!.name});
      });
  @override
  Future<MatchRoom> claimRunner(String code, String uid) async {
    await firestore.runTransaction((tx) async {
      final ref = _room(code);
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) throw StateError('Room no longer exists');
      final room = _decode(snapshot.data()!);
      room.claimRunner(uid, DateTime.now());
      tx.update(
          ref, {'aiRunner': uid, 'aiLeaseAt': FieldValue.serverTimestamp()});
    });
    return read(code);
  }

  @override
  Future<void> expire(String code, String uid) =>
      firestore.runTransaction((tx) async {
        final ref = _room(code);
        final snapshot = await tx.get(ref);
        if (!snapshot.exists) throw StateError('Room no longer exists');
        final expired = _decode(snapshot.data()!).expire(uid, DateTime.now());
        tx.update(ref, {'timedOut': expired.timedOut!.name});
      });
}
