import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/saved_rooms_provider.dart';

/// The sender derives recipients from the room, never from a client's payload.
/// Court revision plus ply is monotonic even when a takeback rewinds the log.
void enqueueTurn(Transaction tx, FirebaseFirestore db, SavedRoom room,
    {required int ply, int revision = 0}) {
  if (!const bool.fromEnvironment('STONES_TURN_ALERTS_ENABLED')) return;
  tx.set(
      db
          .collection('turnNotificationJobs')
          .doc('${room.code}_${revision}_$ply'),
      {
        'code': room.code,
        'format': roomCollectionName(room),
        'ply': ply,
        'revision': revision,
        'state': 'pending',
        'dueAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
}

String roomCollectionName(SavedRoom room) => room.unified
    ? 'matches'
    : room.hex
        ? 'hexGames'
        : 'games';
