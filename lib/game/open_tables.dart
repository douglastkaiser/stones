import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'match_room.dart';
import 'match_config.dart';
import 'match_room_store.dart';

class OpenTable {
  const OpenTable(
      {required this.host,
      required this.code,
      required this.shape,
      required this.size,
      required this.players,
      required this.seenAt});
  final String host, code, shape;
  final int size, players;
  final DateTime seenAt;
  static const lifetime = Duration(minutes: 3);
  bool fresh(DateTime now) => now.difference(seenAt) < lifetime;
}

abstract class OpenTablesRepository {
  Future<List<OpenTable>> list();
  Future<bool> isPublished(String host, String code);
  Future<void> publish(String host, String code, {bool refresh = false});
  Future<void> withdraw(String host, String code);
}

class FirestoreOpenTablesRepository implements OpenTablesRepository {
  FirestoreOpenTablesRepository(this.firestore);
  final FirebaseFirestore firestore;
  @override
  Future<List<OpenTable>> list() async {
    final result = await firestore
        .collection('openTables')
        .where('seenAt',
            isGreaterThan:
                Timestamp.fromDate(DateTime.now().subtract(OpenTable.lifetime)))
        .orderBy('seenAt', descending: true)
        .limit(25)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    return [
      for (final doc in result.docs)
        OpenTable(
            host: doc.id,
            code: doc['code'] as String,
            shape: doc['shape'] as String,
            size: doc['size'] as int,
            players: doc['players'] as int,
            seenAt: (doc['seenAt'] as Timestamp).toDate())
    ];
  }

  @override
  Future<bool> isPublished(String host, String code) async {
    final snapshot = await firestore
        .collection('openTables')
        .doc(host)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    final data = snapshot.data();
    return data != null &&
        data['code'] == code &&
        data['seenAt'] is Timestamp &&
        DateTime.now().difference((data['seenAt'] as Timestamp).toDate()) <
            OpenTable.lifetime;
  }

  @override
  Future<void> publish(String host, String code, {bool refresh = false}) =>
      firestore.runTransaction((tx) async {
        if (refresh) {
          final listing =
              await tx.get(firestore.collection('openTables').doc(host));
          if (!listing.exists || listing.data()?['code'] != code) {
            throw const OpenTableReplaced();
          }
        }
        final snapshot =
            await tx.get(firestore.collection('matches').doc(code));
        if (!snapshot.exists) throw StateError('This room no longer exists.');
        final room = FirestoreMatchRoomStore.decodeRoom(snapshot.data()!);
        if (!canPublishTable(room, host)) {
          throw StateError(
              'Only the host can open a waiting table with available seats.');
        }
        tx.set(firestore.collection('openTables').doc(host), {
          'code': code,
          'shape': room.config.shape.name,
          'size': room.config.size,
          'players': room.config.seats.length,
          'seenAt': FieldValue.serverTimestamp(),
        });
      }).timeout(const Duration(seconds: 12));
  @override
  Future<void> withdraw(String host, String code) =>
      firestore.runTransaction((tx) async {
        final ref = firestore.collection('openTables').doc(host);
        final snapshot = await tx.get(ref);
        if (snapshot.exists && snapshot.data()?['code'] == code) tx.delete(ref);
      }).timeout(const Duration(seconds: 12));
}

bool canPublishTable(MatchRoom room, String uid) =>
    room.host == uid &&
    room.moves.isEmpty &&
    room.resigned == null &&
    room.timedOut == null &&
    room.config.seats.any((seat) =>
        seat.control == SeatControl.onlineHuman &&
        room.owners[seat.id] == null);
final openTablesRepositoryProvider = Provider<OpenTablesRepository>(
    (ref) => FirestoreOpenTablesRepository(FirebaseFirestore.instance));

class OpenTableReplaced implements Exception {
  const OpenTableReplaced();
}
