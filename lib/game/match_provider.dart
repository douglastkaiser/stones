import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_provider.dart';
import '../providers/achievements_provider.dart';
import '../providers/cosmetics_provider.dart';
import '../providers/elo_provider.dart';
import '../providers/saved_rooms_provider.dart';
import 'match_config.dart';
import 'rating_submission.dart';
import 'rating_recovery.dart';
import 'match_completed.dart';
import 'match_controller.dart';
import 'match_room_store.dart';
import 'match_storage.dart';
import 'completed_match.dart';
import 'match_history_provider.dart';

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
  ref.listen(accountProvider.select((value) => value.identity?.uid),
      (previous, next) {
    if (previous != next) ref.read(ratingStatusProvider.notifier).state = null;
  });
  late final MatchController controller;
  return controller = MatchController(
    storage: ref.read(localMatchStorageProvider),
    ratingIdentity: () {
      final identity = ref.read(accountProvider).identity;
      return identity != null && !identity.guest ? identity.uid : null;
    },
    authenticate: () async =>
        (await ref.read(accountProvider.notifier).ensurePlayer()).uid,
    store: () => ref.read(matchRoomStoreProvider),
    completed: (session) async {
      final event = MatchCompleted(session, moves: controller.confirmedMoves);
      final identity = ref.read(accountProvider).identity;
      final achievements = ref.read(achievementProvider.notifier);
      final ratings = ref.read(ratingRepositoryProvider);
      await ref
          .read(completedMatchStorageProvider)
          .save(CompletedMatch.capture(session, event.moves));
      if (!active) return;
      ref.invalidate(completedMatchesProvider);
      final achievementWrite = achievements.recordMatch(event);
      if (identity != null &&
          !identity.guest &&
          identity.uid == session.uid &&
          ref.read(accountProvider).identity?.uid == identity.uid) {
        ref.read(ratingStatusProvider.notifier).state =
            (event.id, const RatingSubmission.pending());
        unawaited(recoverRating(
          submit: () => ratings.submitResult(session, event.moves),
          isCurrent: () =>
              active &&
              controller.currentMatchId == event.id &&
              ref.read(accountProvider).identity?.uid == identity.uid,
          onResult: (result) => ref.read(ratingStatusProvider.notifier).state =
              (event.id, result),
        ));
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
    StateProvider<(String, RatingSubmission)?>((ref) => null);
