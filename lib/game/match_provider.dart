import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_provider.dart';
import '../providers/achievements_provider.dart';
import '../providers/cosmetics_provider.dart';
import '../providers/saved_rooms_provider.dart';
import '../services/ai/ai.dart';
import 'match_config.dart';
import 'match_completed.dart';
import 'match_controller.dart';
import 'match_room_store.dart';
import 'match_storage.dart';
import 'match_state.dart';

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

final matchProvider = StateNotifierProvider<MatchController, MatchSession>(
    (ref) => MatchController(
          storage: ref.read(localMatchStorageProvider),
          authenticate: () async =>
              (await ref.read(accountProvider.notifier).ensurePlayer()).uid,
          store: () => ref.read(matchRoomStoreProvider),
          completed: (session) async {
            final event = MatchCompleted(session);
            if (!event.eligibleWin) return;
            await ref.read(achievementProvider.notifier).recordWin(
                matchId: event.id,
                isOnline: event.online,
                aiDifficulty: switch (event.defeatedAILevel) {
                  BotLevel.easy => AIDifficulty.easy,
                  BotLevel.medium => AIDifficulty.medium,
                  BotLevel.hard => AIDifficulty.hard,
                  BotLevel.expert => AIDifficulty.expert,
                  null => null,
                },
                byTime: event.game.result!.reason == ResultReason.time,
                byFlats: event.game.result!.reason == ResultReason.flats);
          },
          remember: (room, uid) => ref
              .read(savedRoomsProvider.notifier)
              .remember(SavedRoom(
                  code: room.code,
                  uid: uid,
                  hex: room.config.shape == BoardShape.hex,
                  unified: true)),
        ));
