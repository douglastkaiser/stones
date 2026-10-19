import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/player_profile_repository.dart';
import 'account_provider.dart';

final playerProfileRepositoryProvider = Provider<PlayerProfileRepository>(
    (ref) => FirestorePlayerProfileRepository(FirebaseFirestore.instance));
final playerNameProvider =
    StreamProvider.autoDispose.family<String?, String>((ref, uid) {
  if (!ref.watch(accountProvider.select((state) => state.ready)) ||
      uid.startsWith('ai_')) {
    return Stream.value(null);
  }
  return ref.watch(playerProfileRepositoryProvider).watch(uid);
});
