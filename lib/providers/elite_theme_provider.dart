import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool topDecileEligible(
        {required bool established,
        required int population,
        required int rank}) =>
    established &&
    population > 0 &&
    rank > 0 &&
    rank <= (population / 10).ceil();

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
      final counts = await Future.wait([
        humans.count().get(),
        humans.where('rating', isGreaterThan: own['rating']).count().get(),
      ]).timeout(const Duration(seconds: 8));
      if (!disposed) {
        controller.add(topDecileEligible(
            established: true,
            population: counts[0].count ?? 0,
            rank: 1 + (counts[1].count ?? 0)));
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
