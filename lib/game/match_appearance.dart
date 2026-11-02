import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cosmetics.dart';
import '../providers/account_provider.dart';
import '../providers/cosmetics_provider.dart';
import '../providers/elite_theme_provider.dart';
import 'match_config.dart';
import 'match_controller.dart';

/// Presentation-only resolution. Stored room choices and moves stay immutable.
Map<SeatId, PieceStyle> resolveMatchPieceStyles(
    WidgetRef ref, MatchSession session,
    {Map<SeatId, PieceStyle>? requested}) {
  final localStyle = ref.watch(currentPieceStyleProvider).style;
  final localUid = ref.watch(accountProvider).identity?.uid;
  return {
    for (final id in session.game!.config.ids)
      id: ref.watch(effectivePieceStyleProvider((
        requested?[id] ?? session.room?.styles[id] ?? localStyle,
        session.room == null
            ? localUid
            : session.room!.owners[id] ?? session.room!.host,
      ))),
  };
}
