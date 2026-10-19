import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_profile_provider.dart';

class PlayerName extends ConsumerWidget {
  const PlayerName(
      {super.key,
      required this.uid,
      required this.fallback,
      this.style,
      this.suffix = '',
      this.maxLines = 1});
  final String uid, fallback, suffix;
  final TextStyle? style;
  final int maxLines;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
      '${ref.watch(playerNameProvider(uid)).asData?.value ?? fallback}$suffix',
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis);
}
