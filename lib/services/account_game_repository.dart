import 'package:cloud_firestore/cloud_firestore.dart';
import '../game/match_room_store.dart';
import '../hex/hex_room.dart';
import '../models/online_game.dart';
import '../providers/saved_rooms_provider.dart';

/// Navigation data only. A reference never grants a seat or validates a board.
class AccountGame {
  const AccountGame(this.room, {this.archived = false, this.muted = false});
  final SavedRoom room;
  final bool archived;
  final bool muted;

  factory AccountGame.fromMap(Map<String, dynamic> data, String uid) =>
      AccountGame(
        SavedRoom.parse({...data, 'uid': uid}) ??
            (throw const FormatException('Invalid account game reference')),
        archived: data['archived'] == true,
        muted: data['muted'] == true,
      );
}

class AccountGamePage {
  const AccountGamePage(this.games, {this.cursor, this.hasMore = false});
  final List<AccountGame> games;
  final Object? cursor;
  final bool hasMore;
}

class AccountRoomStatus {
  const AccountRoomStatus(this.label, {this.confirmed = true});
  final String label;
  final bool confirmed;
}

abstract class AccountGameRepository {
  Future<AccountGamePage> page(String uid,
      {required bool archived, Object? after});
  Stream<AccountRoomStatus> watch(AccountGame game);
  Future<void> importRoom(SavedRoom room);
  Future<void> update(String uid, String code, {bool? archived, bool? muted});
}

DocumentReference<Map<String, dynamic>> accountGameRef(
        FirebaseFirestore db, String uid, String code) =>
    db.collection('playerGames').doc(uid).collection('rooms').doc(code);

Map<String, dynamic> accountGameData(SavedRoom room) => {
      ...(room.toMap()..remove('uid')),
      'addedAt': FieldValue.serverTimestamp(),
      'archived': false,
      'muted': false,
    };

/// Read before the caller writes: Firestore transactions require all reads first.
Future<void> indexJoinedRoom(
    Transaction tx, FirebaseFirestore db, SavedRoom room) async {
  final ref = accountGameRef(db, room.uid, room.code);
  if (!(await tx.get(ref)).exists) tx.set(ref, accountGameData(room));
}

String roomCollection(SavedRoom room) => room.unified
    ? 'matches'
    : room.hex
        ? 'hexGames'
        : 'games';

AccountRoomStatus describeAccountRoom(
    SavedRoom ref, Map<String, dynamic> data) {
  if (ref.unified) {
    final room = FirestoreMatchRoomStore.decodeRoom(data);
    if (room.host != ref.uid && !room.owners.values.contains(ref.uid)) {
      throw StateError('This account no longer owns a seat.');
    }
    final game = room.replay();
    if (game.finished) return const AccountRoomStatus('Completed');
    if (!room.ready) return const AccountRoomStatus('Inviting');
    if (room.takeback != null) {
      return const AccountRoomStatus('Waiting for takeback decision');
    }
    if (room.config.seat(game.current).control.name == 'ai') {
      return const AccountRoomStatus('Waiting for computer');
    }
    return AccountRoomStatus(
        room.owners[game.current] == ref.uid ? 'Your turn' : 'Waiting');
  }
  if (ref.hex) {
    final room = HexRoom.fromMap(data);
    if (room.host != ref.uid && !room.owners.contains(ref.uid)) {
      throw StateError('This account no longer owns a seat.');
    }
    final game = room.replay();
    if (game.finished) return const AccountRoomStatus('Completed');
    if (!room.ready) return const AccountRoomStatus('Inviting');
    if (room.kinds[game.current.index] == HexSeatKind.ai) {
      return const AccountRoomStatus('Waiting for computer');
    }
    return AccountRoomStatus(
        room.owners[game.current.index] == ref.uid ? 'Your turn' : 'Waiting');
  }
  final room = OnlineGameSession.fromSnapshot(ref.code, data);
  if (room.white?.id != ref.uid && room.black?.id != ref.uid) {
    throw StateError('This account no longer owns a seat.');
  }
  if (room.status == OnlineStatus.finished) {
    return const AccountRoomStatus('Completed');
  }
  if (room.status == OnlineStatus.waiting) {
    return const AccountRoomStatus('Inviting');
  }
  final owner = room.currentTurn.name == 'white' ? room.white : room.black;
  return AccountRoomStatus(owner?.id == ref.uid ? 'Your turn' : 'Waiting');
}

class FirestoreAccountGameRepository implements AccountGameRepository {
  FirestoreAccountGameRepository(this.db);
  final FirebaseFirestore db;
  @override
  Future<AccountGamePage> page(String uid,
      {required bool archived, Object? after}) async {
    Query<Map<String, dynamic>> query = db
        .collection('playerGames')
        .doc(uid)
        .collection('rooms')
        .where('archived', isEqualTo: archived)
        .orderBy('addedAt', descending: true)
        .orderBy(FieldPath.documentId)
        .limit(11);
    if (after != null) {
      query = query
          .startAfterDocument(after as DocumentSnapshot<Map<String, dynamic>>);
    }
    final snapshot = await query.get(const GetOptions(source: Source.server));
    final docs = snapshot.docs.take(10).toList();
    return AccountGamePage(
        docs.map((doc) => AccountGame.fromMap(doc.data(), uid)).toList(),
        cursor: docs.isEmpty ? null : docs.last,
        hasMore: snapshot.docs.length > 10);
  }

  @override
  Stream<AccountRoomStatus> watch(AccountGame game) => db
          .collection(roomCollection(game.room))
          .doc(game.room.code)
          .snapshots(includeMetadataChanges: true)
          .map((snapshot) {
        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return const AccountRoomStatus('Offline · reconnect to refresh',
              confirmed: false);
        }
        if (!snapshot.exists) throw StateError('Room no longer exists.');
        return describeAccountRoom(game.room, snapshot.data()!);
      });

  @override
  Future<void> importRoom(SavedRoom room) => db.runTransaction((tx) async {
        final snapshot =
            await tx.get(db.collection(roomCollection(room)).doc(room.code));
        if (!snapshot.exists) throw StateError('Room no longer exists.');
        describeAccountRoom(room, snapshot.data()!);
        await indexJoinedRoom(tx, db, room);
      });

  @override
  Future<void> update(String uid, String code, {bool? archived, bool? muted}) =>
      accountGameRef(db, uid, code).update({
        if (archived != null) 'archived': archived,
        if (muted != null) 'muted': muted,
      });
}
