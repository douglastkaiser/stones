import 'dart:async';
import '../models/cosmetics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Only server reads can grant the temporary cosmetic. No entitlement is cached.
final eliteThemeEligibilityProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, uid) {
  final controller = StreamController<bool>();
  var disposed = false, busy = false;
  Future<void> refresh() async {
    if (disposed || busy) return;
    busy = true;
    try {
      final players = FirebaseFirestore.instance
          .collection('skillPools')
          .doc('overall')
          .collection('players');
      final own = (await players
              .doc(uid)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 8)))
          .data();
      if (own == null || own['established'] != true || own['isAi'] != false) {
        if (!disposed) controller.add(false);
        return;
      }
      final humans = players
          .where('isAi', isEqualTo: false)
          .where('established', isEqualTo: true);
      // Firestore breaks equal ratings by document ID, selecting one winner.
      final leader = await humans
          .orderBy('rating', descending: true)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      if (!disposed) {
        controller.add(leader.docs.firstOrNull?.id == uid);
      }
    } catch (_) {
      if (!disposed) controller.add(false);
    } finally {
      busy = false;
    }
  }

  final timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    unawaited(controller.close());
  });
  unawaited(refresh());
  return controller.stream;
});

/// Shared policy for the live board and exported result images.
final effectiveBoardThemeProvider = Provider.autoDispose
    .family<BoardTheme, (BoardTheme, String?)>((ref, selection) {
  if (selection.$1 != BoardTheme.celestial) return selection.$1;
  final uid = selection.$2;
  return uid != null &&
          ref.watch(eliteThemeEligibilityProvider(uid)).valueOrNull == true
      ? BoardTheme.celestial
      : BoardTheme.classicWood;
});
