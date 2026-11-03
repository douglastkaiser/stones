import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/account_game_repository.dart';
import 'account_provider.dart';
import 'saved_rooms_provider.dart';

final accountGameRepositoryProvider = Provider<AccountGameRepository>(
    (ref) => FirestoreAccountGameRepository(FirebaseFirestore.instance));

/// Lazy and UID-scoped: a failed import never hides the remote list.
final importAccountRoomsProvider =
    FutureProvider.autoDispose.family<int, String>((ref, uid) async {
  final saved = ref.read(savedRoomsProvider.notifier);
  await saved.load();
  final repository = ref.read(accountGameRepositoryProvider);
  var failures = 0;
  for (final room
      in ref.read(savedRoomsProvider).where((room) => room.uid == uid)) {
    if (ref.read(accountProvider).identity?.uid != uid) break;
    try {
      await repository.importRoom(room).timeout(const Duration(seconds: 15));
    } catch (_) {
      failures++;
    }
  }
  return failures;
});
