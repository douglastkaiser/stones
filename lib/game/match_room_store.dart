import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cosmetics.dart';
import 'match_config.dart';
import 'match_room.dart';
import 'match_state.dart';

abstract class MatchRoomStore {
  Future<MatchRoom> create(String uid, MatchConfig config);
  Future<MatchRoom> join(String code, String uid);
  Future<MatchRoom> read(String code);
  Stream<MatchRoom> watch(String code);
  Future<void> submit(String code, String uid, int expectedPly, MatchMove move);
  Future<void> resign(String code, String uid, SeatId seat);
}

class FirestoreMatchRoomStore implements MatchRoomStore {
  FirestoreMatchRoomStore(this.firestore,
      {this.style = PieceStyle.standard, this.theme = BoardTheme.classicWood});
  final FirebaseFirestore firestore;
  final PieceStyle style;
  final BoardTheme theme;
  DocumentReference<Map<String, dynamic>> _room(String code) =>
      firestore.collection('matches').doc(code);
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
        final room = MatchRoom.fromMap(snapshot.data()!);
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
    return MatchRoom.fromMap(snapshot.data()!);
  }

  @override
  Stream<MatchRoom> watch(String code) => _room(code)
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) =>
              !snapshot.metadata.isFromCache &&
              !snapshot.metadata.hasPendingWrites)
          .map((snapshot) {
        if (!snapshot.exists) throw StateError('Room no longer exists');
        return MatchRoom.fromMap(snapshot.data()!);
      });
  @override
  Future<void> submit(
          String code, String uid, int expectedPly, MatchMove move) =>
      firestore.runTransaction((tx) async {
        final ref = _room(code);
        final snapshot = await tx.get(ref);
        if (!snapshot.exists) throw StateError('Room no longer exists');
        final updated =
            MatchRoom.fromMap(snapshot.data()!).append(uid, expectedPly, move);
        tx.update(ref, {'moves': updated.moves});
      });
  @override
  Future<void> resign(String code, String uid, SeatId seat) =>
      firestore.runTransaction((tx) async {
        final ref = _room(code);
        final snapshot = await tx.get(ref);
        if (!snapshot.exists) throw StateError('Room no longer exists');
        final updated = MatchRoom.fromMap(snapshot.data()!).resign(uid, seat);
        tx.update(ref, {'resigned': updated.resigned!.name});
      });
}
