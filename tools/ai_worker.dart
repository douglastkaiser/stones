import 'package:stones/game/ai_material.dart';
import 'package:stones/game/match_ai_engine.dart';
import 'ai_worker_protocol.dart';

Future<void> main() => serve((game, level, history, request) async {
      MatchSearchStats? stats;
      final weights = request['weights'] as List?;
      final move = await MatchAI(level,
              yieldDuringSearch: false,
              useCaches: request['caches'] != false,
              materialWeights: weights == null
                  ? const AiMaterialWeights()
                  : AiMaterialWeights(
                      mobility: (weights[0] as num).toDouble(),
                      crush: (weights[1] as num).toDouble(),
                      exposure: (weights[2] as num).toDouble(),
                      access: (weights[3] as num).toDouble()),
              onSearchComplete: (value) => stats = value)
          .choose(game, recentPositionKeys: history);
      return {
        'move': move?.toMap(game.current),
        'elapsedMs': stats?.elapsedMs,
        'depth': stats?.completedDepth,
        'rounds': stats?.completedRounds,
        'timedOut': stats?.timedOut,
        'stage': stats?.stage,
        'cacheHits': stats?.cacheHits,
        'cacheEntries': stats?.cacheEntries,
        'cacheEvictions': stats?.cacheEvictions,
        'forksProven': stats?.forksProven
      };
    });
