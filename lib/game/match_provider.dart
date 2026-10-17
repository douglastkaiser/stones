import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_provider.dart';
import '../providers/achievements_provider.dart';
import '../providers/cosmetics_provider.dart';
import '../providers/elo_provider.dart';
import '../providers/saved_rooms_provider.dart';
import 'match_config.dart';
import 'match_completed.dart';
import 'match_controller.dart';
import 'match_room_store.dart';
import 'match_storage.dart';

final localMatchStorageProvider =
    Provider<LocalMatchStorage>((ref) => PreferencesMatchStorage());
final savedLocalMatchProvider = FutureProvider<Map<String, dynamic>?>((ref) {
  ref.watch(matchProvider.select((session) => session.id));
  return ref.read(localMatchStorageProvider).read();
});
final matchRoomStoreProvider = Provider<MatchRoomStore>((ref) =>
    FirestoreMatchRoomStore(FirebaseFirestore.instance,
        style: ref.watch(shareablePieceStyleProvider),
        theme: ref.watch(shareableBoardThemeProvider)));

final StateNotifierProvider<MatchController, MatchSession> matchProvider =
    StateNotifierProvider<MatchController, MatchSession>((ref) {
  var active = true;
  ref.onDispose(() => active = false);
  return MatchController(
    storage: ref.read(localMatchStorageProvider),
    authenticate: () async =>
        (await ref.read(accountProvider.notifier).ensurePlayer()).uid,
    store: () => ref.read(matchRoomStoreProvider),
    completed: (session) async {
      final event = MatchCompleted(session,
          moves: ref.read(matchProvider.notifier).confirmedMoves);
      final achievementWrite =
          ref.read(achievementProvider.notifier).recordMatch(event);
      final identity = ref.read(accountProvider).identity;
      if (identity != null && !identity.guest) {
        ref.read(ratingStatusProvider.notifier).state = (event.id, 'Checking game result…');
        unawaited(ref.read(ratingRepositoryProvider)
            .submitResult(session, event.moves).then((message) {
          if (active && ref.read(matchProvider).id == event.id) {
            ref.read(ratingStatusProvider.notifier).state = (event.id, message);
          }
        }).catchError((Object error) {
          if (active && ref.read(matchProvider).id == event.id) {
            ref.read(ratingStatusProvider.notifier).state =
                (event.id, 'Game saved Â· rating update could not finish. Retry when connected.');
          }
        }));
      }
      await achievementWrite;
    },
    remember: (room, uid) => ref.read(savedRoomsProvider.notifier).remember(
        SavedRoom(
            code: room.code,
            uid: uid,
            hex: room.config.shape == BoardShape.hex,
            unified: true)),
  );
});

final ratingStatusProvider =
    StateProvider<(String, String)?>((ref) => null);
