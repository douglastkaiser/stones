import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_provider.dart';
import '../providers/cosmetics_provider.dart';
import '../providers/saved_rooms_provider.dart';
import 'match_config.dart';
import 'match_controller.dart';
import 'match_room_store.dart';
import 'match_storage.dart';

final localMatchStorageProvider =
    Provider<LocalMatchStorage>((ref) => PreferencesMatchStorage());
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
          remember: (room, uid) => ref
              .read(savedRoomsProvider.notifier)
              .remember(SavedRoom(
                  code: room.code,
                  uid: uid,
                  hex: room.config.shape == BoardShape.hex,
                  unified: true)),
        ));
