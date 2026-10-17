import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_provider.dart';
import '../providers/achievements_provider.dart';
import '../providers/cosmetics_provider.dart';
import '../providers/elo_provider.dart';
import 'match_ai.dart';
import 'match_state.dart';
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
    StateNotifierProvider<MatchController, MatchSession>(
        (ref) {
          var active = true;
          ref.onDispose(() => active = false);
          return MatchController(
              storage: ref.read(localMatchStorageProvider),
              search: (game, level) async {
                final identity = ref.read(accountProvider).identity;
                final session = ref.read(matchProvider);
                final canCalibrate = identity != null && !identity.guest &&
                    !game.config.court && game.config.seats.length == 2 &&
                    game.config.seats.where((s) => s.control == SeatControl.ai).length == 1;
                if (canCalibrate && session.id != null &&
                    DateTime.now().isAfter(ref.read(calibrationRetryAfterProvider))) {
                  try {
                    final move = await ref.read(ratingRepositoryProvider).botMove(
                        session.id!, game.config,
                        ref.read(matchProvider.notifier).confirmedMoves);
                    if (!active || ref.read(matchProvider).id != session.id) return move;
                    ref.read(calibrationStatusProvider.notifier).state =
                        'AI calibration uses verified server moves; human rating is unchanged.';
                    return move;
                  } catch (_) {
                    if (!active) return null;
                    ref.read(calibrationRetryAfterProvider.notifier).state =
                        DateTime.now().add(const Duration(minutes: 2));
                    ref.read(calibrationStatusProvider.notifier).state =
                        'Practice · AI calibration service unavailable';
                  }
                }
                return selectMatchMove(game, level);
              },
              authenticate: () async =>
                  (await ref.read(accountProvider.notifier).ensurePlayer()).uid,
              store: () => ref.read(matchRoomStoreProvider),
              completed: (session) async {
                final event = MatchCompleted(session,
                    moves: ref.read(matchProvider.notifier).confirmedMoves);
                final achievementWrite = ref.read(achievementProvider.notifier).recordMatch(event);
                final identity = ref.read(accountProvider).identity;
                if (identity != null && !identity.guest && !event.game.config.court &&
                    event.game.config.seats.length == 2 &&
                    event.game.config.seats.where((s) => s.control == SeatControl.ai).length == 1 &&
                    [ResultReason.road, ResultReason.flats].contains(event.game.result?.reason)) {
                  unawaited(ref.read(ratingRepositoryProvider).completeCalibration(
                      event.id, event.game.config, event.moves).then((message) {
                    if (active && ref.read(matchProvider).id == event.id) { ref.read(calibrationStatusProvider.notifier).state = message; }
                  }).catchError((Object error) {
                    if (active && ref.read(matchProvider).id == event.id) { ref.read(calibrationStatusProvider.notifier).state =
                        'Practice · this result could not calibrate the AI'; }
                  }));
                }
                await achievementWrite;
              },
              remember: (room, uid) => ref
                  .read(savedRoomsProvider.notifier)
                  .remember(SavedRoom(
                      code: room.code,
                      uid: uid,
                      hex: room.config.shape == BoardShape.hex,
                      unified: true)),
            );
        });

final calibrationStatusProvider = StateProvider<String?>((ref) => null);
final calibrationRetryAfterProvider = StateProvider<DateTime>((ref) => DateTime.fromMillisecondsSinceEpoch(0));
