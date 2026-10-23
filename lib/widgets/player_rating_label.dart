import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/elo_provider.dart';
import '../providers/player_profile_provider.dart';
import '../game/rating_pool.dart';

class PlayerRatingLabel extends ConsumerWidget {
  const PlayerRatingLabel(
      {super.key,
      required this.uid,
      required this.pool,
      required this.fallback});
  final String uid;
  final RatingPool pool;
  final String fallback;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(seatRatingProvider((pool.id, uid)));
    final rating = value.asData?.value;
    final name = ref.watch(playerNameProvider(uid)).asData?.value ??
        rating?.displayName ??
        fallback;
    final rank = rating == null || rating.isAi || rating.provisional
        ? null
        : ref.watch(playerRankProvider((pool.id, rating.rating))).asData?.value;
    return Text(
        value.when(
            data: (rating) => rating == null
                ? '$name · Unrated'
                : '$name · ${rating.ratingLabel}${rating.skill == null ? "" : " ±${(1.96 * rating.skill!.deviation).round()}"}${rank == null ? "" : " · #$rank"}',
            loading: () => '$name · Rating…',
            error: (_, __) => '$name · Rating unavailable'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall);
  }
}
