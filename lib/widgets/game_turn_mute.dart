import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_provider.dart';
import '../services/account_game_repository.dart';

class GameTurnMute extends ConsumerWidget {
  const GameTurnMute({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(accountProvider.select((s) => s.identity));
    if (identity == null || identity.guest || Firebase.apps.isEmpty) {
      return const SizedBox.shrink();
    }
    final reference =
        accountGameRef(FirebaseFirestore.instance, identity.uid, code);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: reference.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final muted = data?['muted'] == true;
          return IconButton(
              tooltip: muted
                  ? 'Unmute turn notifications'
                  : 'Mute turn notifications',
              icon: Icon(muted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_outlined),
              onPressed: data == null
                  ? null
                  : () async {
                      try {
                        await reference.update({'muted': !muted}).timeout(
                            const Duration(seconds: 15));
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Could not save notification preference. Retry when connected.')));
                        }
                      }
                    });
        });
  }
}
