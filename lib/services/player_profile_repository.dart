import 'package:cloud_firestore/cloud_firestore.dart';

String validatePlayerName(String name) {
  final clean = name.trim();
  if (clean.isEmpty ||
      clean.length > 40 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(clean)) {
    throw const FormatException('Use 1–40 characters without line breaks.');
  }
  return clean;
}

abstract class PlayerProfileRepository {
  Stream<String?> watch(String uid);
  Future<void> rename(String uid, String name);
}

class FirestorePlayerProfileRepository implements PlayerProfileRepository {
  FirestorePlayerProfileRepository(this.firestore);
  final FirebaseFirestore firestore;
  @override
  Stream<String?> watch(String uid) => firestore
      .collection('playerProfiles')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) => !snapshot.metadata.hasPendingWrites)
      .map((snapshot) => snapshot.data()?['name'] as String?);
  @override
  Future<void> rename(String uid, String name) =>
      firestore.collection('playerProfiles').doc(uid).set({
        'name': validatePlayerName(name),
        'updatedAt': FieldValue.serverTimestamp()
      }).timeout(const Duration(seconds: 12));
}
