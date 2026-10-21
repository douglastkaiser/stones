import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai/search_budget.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// A legal win on an unchanged position; this does not claim a forced win.
Future<Set<SeatId>> findMatchThreats(MatchState game,
    {bool Function()? cancelled, bool yieldDuringSearch = true}) async {
  if (!game.config.court || game.finished || game.opening) return {};
  final budget = SearchBudget(enabled: yieldDuringSearch, cancelled: cancelled);
  final threats = <SeatId>{};
  for (final seat in game.config.ids) {
    var delta = 0;
    while (game.config.turnAt(game.ply + delta) != seat) {
      delta++;
    }
    final position = game.copyWith(ply: game.ply + delta);
    for (final move in MatchRules.legalMoves(position)) {
      final pause = budget.pauseIfNeeded();
      if (pause != null) await pause;
      if (MatchRules.play(position, move)?.result?.winner == seat) {
        threats.add(seat);
        break;
      }
    }
  }
  return threats;
}

Future<Set<SeatId>> _nativeThreats(MatchState game) =>
    findMatchThreats(game, yieldDuringSearch: false);
final courtThreatsProvider = FutureProvider.autoDispose
    .family<Set<SeatId>, MatchState>((ref, game) async {
  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  return kIsWeb
      ? findMatchThreats(game, cancelled: () => cancelled)
      : compute(_nativeThreats, game);
});
