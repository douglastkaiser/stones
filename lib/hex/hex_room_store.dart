import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show listEquals;

import 'hex_game.dart';
import 'hex_room.dart';

abstract class HexRoomStore {
  Future<HexRoom> create(
      String uid, int radius, List<HexSeatKind> kinds, HexSeat starter);
  Future<HexRoom> join(String code, String uid);
  Stream<HexRoom> watch(String code);
  Future<void> submit(String code, String uid, int expectedPly, HexMove move);
}

class FirestoreHexRoomStore implements HexRoomStore {
  FirestoreHexRoomStore(this.firestore);
  final FirebaseFirestore firestore;
  DocumentReference<Map<String, dynamic>> _room(String code) =>
      firestore.collection('hexGames').doc(code);

  @override
  Future<HexRoom> create(
      String uid, int radius, List<HexSeatKind> kinds, HexSeat starter) async {
    final rng = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code =
          'H${List.generate(6, (_) => String.fromCharCode(65 + rng.nextInt(26))).join()}';
      final room = HexRoom(
          code: code,
          host: uid,
          radius: radius,
          kinds: kinds,
          starter: starter,
          owners: kinds
              .map((kind) => kind == HexSeatKind.localHuman ? uid : null)
              .toList());
      final created = await firestore.runTransaction<bool>((transaction) async {
        final doc = _room(code);
        if ((await transaction.get(doc)).exists) return false;
        transaction.set(doc, room.toMap());
        return true;
      });
      if (created) return room;
    }
    throw StateError('Could not allocate a room code. Try again.');
  }

  @override
  Future<HexRoom> join(String code, String uid) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      List<String?>? ownersBefore;
      try {
        return await firestore.runTransaction((transaction) async {
          final doc = _room(code);
          final snapshot = await transaction.get(doc);
          if (!snapshot.exists) throw StateError('Hex room not found');
          final room = HexRoom.fromMap(snapshot.data()!);
          ownersBefore = room.owners;
          room.replay();
          final joined = room.join(uid);
          if (!identical(joined, room)) {
            transaction.update(doc, {'owners': joined.toMap()['owners']});
          }
          return joined;
        });
      } on FirebaseException catch (error) {
        // A competing join may fill our chosen seat before authorization is
        // evaluated. Retry only when the server's ownership revision changed.
        if (error.code != 'permission-denied' ||
            attempt == 2 ||
            ownersBefore == null) {
          rethrow;
        }
        final latest =
            await _room(code).get(const GetOptions(source: Source.server));
        if (!latest.exists ||
            listEquals(HexRoom.fromMap(latest.data()!).owners, ownersBefore)) {
          rethrow;
        }
      }
    }
    throw StateError('Room changed while joining. Try again.');
  }

  @override
  Stream<HexRoom> watch(String code) => _room(code).snapshots().map((snapshot) {
        if (!snapshot.exists) throw StateError('Hex room no longer exists');
        return HexRoom.fromMap(snapshot.data()!);
      });

  @override
  Future<void> submit(String code, String uid, int expectedPly, HexMove move) =>
      firestore.runTransaction((transaction) async {
        final doc = _room(code);
        final snapshot = await transaction.get(doc);
        if (!snapshot.exists) throw StateError('Hex room no longer exists');
        final room = HexRoom.fromMap(snapshot.data()!);
        final updated = room.append(uid, expectedPly, move);
        transaction.update(doc, {
          'moves.$expectedPly': updated.moves.last,
          'ply': updated.moves.length,
        });
      });
}
