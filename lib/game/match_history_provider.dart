import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_provider.dart';
import 'completed_match.dart';

final completedMatchStorageProvider =
    Provider<CompletedMatchStorage>((ref) => CompletedMatchStorage());

final completedMatchesProvider =
    FutureProvider.autoDispose.family<CompletedMatchPage, int>((ref, limit) {
  final identity = ref.watch(accountProvider.select((state) => state.identity));
  // Local guest games are recorded without a rating identity.
  return ref.read(completedMatchStorageProvider).readPage(identity?.uid,
      includeGuest: identity == null || identity.guest, limit: limit);
});
