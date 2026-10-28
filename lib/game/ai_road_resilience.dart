import '../models/piece.dart';
import 'ai_tactics.dart';
import 'ai_road_connections.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Bounded vulnerability of minimum one-/two-placement completion sets.
/// A structural estimate, never a forced-win or engine-policy certificate.
class AiRoadResilience {
  const AiRoadResilience(this.cost, this.maximumIncrease, this.probes);
  final int cost, maximumIncrease, probes;
  double score(double weight) => -(weight * maximumIncrease).clamp(0.0, 40.0);

  static AiRoadResilience measure(MatchState game, SeatId seat) {
    if (game.finished || game.opening) return const AiRoadResilience(0, 0, 0);
    final roadStones = game.board.values
        .where((s) => s.last.seat == seat && s.last.type != PieceType.standing)
        .length;
    // Each placement adds one exposed road stone; every opposing-edge road
    // needs at least the geometry's span. No two-placement route exists yet.
    if (roadStones + 2 < game.geometry.carryLimit) {
      return const AiRoadResilience(3, 0, 0);
    }
    final base = AiRoadConnections(game, seat).continuations;
    // Only one-/two-placement continuations contribute this secondary term.
    // Exact spread/flat tactics remain the search's responsibility.
    if (base.gaps == 0 || base.gaps >= 3) {
      return AiRoadResilience(base.gaps, 0, 0);
    }
    if (base.criticalCells.isNotEmpty &&
        game.config.ids
            .any((id) => id != seat && game.reserves[id]!.total > 0)) {
      return AiRoadResilience(base.gaps, 1, 1);
    }
    var probes = 0;
    for (final rival in game.config.ids.where((id) => id != seat)) {
      final turn = aiTurnFor(game, rival);
      for (final entry in game.board.entries) {
        if (entry.value.last.seat != rival) continue;
        for (final direction in game.geometry.directions) {
          final cell = entry.key.step(direction);
          final top = game.topAt(cell);
          if (top?.seat != seat || top?.type != PieceType.flat) continue;
          final next = MatchRules.apply(
              turn, MatchMove.spread(entry.key, direction, const [1]));
          if (next == null) continue;
          probes++;
          if (AiRoadConnections(next, seat).continuations.gaps > base.gaps) {
            return AiRoadResilience(base.gaps, 1, probes);
          }
        }
      }
    }
    return AiRoadResilience(base.gaps, 0, probes);
  }
}
