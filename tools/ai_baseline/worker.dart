import 'engine.dart';
import '../ai_worker_protocol.dart';

Future<void> main() => serve((game, level, history, request) async {
      BaselineSearchStats? stats;
      final move = await BaselineMatchAI(level,
          yieldDuringSearch: false,
          onSearchComplete: (value) => stats = value).choose(game);
      return {
        'move': move?.toMap(game.current),
        'elapsedMs': stats?.elapsedMs,
        'depth': stats?.completedDepth,
        'rounds': stats?.completedRounds,
        'timedOut': stats?.timedOut,
        'stage': stats?.stage
      };
    });
