import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/elo_provider.dart';
import '../game/rating_pool.dart';

class PlayerRatingLabel extends ConsumerWidget {
  const PlayerRatingLabel({super.key, required this.uid, required this.pool, required this.fallback});
  final String uid;
  final RatingPool pool;
  final String fallback;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(seatRatingProvider((pool.id, uid)));
    return Text(value.when(data: (rating) => rating == null ? '$fallback · Unrated' :
      '${rating.displayName} · ${rating.ratingLabel}', loading: () => '$fallback · Rating…',
      error: (_, __) => '$fallback · Rating unavailable'),
      maxLines: 2, overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall);
  }
}
