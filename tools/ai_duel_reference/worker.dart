import 'package:stones/game/ai_material.dart';
import 'engine.dart';
import 'package:stones/game/match_rules.dart';
import '../ai_worker_protocol.dart';

Future<void> main() => serve((game, level, history, request) async {
      MatchSearchStats? stats;
      final weights = request['weights'] as List?;
      final move = await MatchAI(level,
              yieldDuringSearch: false,
              useCaches: request['caches'] != false,
              variation: AiMoveVariation.values
                  .byName(request['policy'] as String? ?? 'deterministic'),
              materialWeights: weights == null
                  ? const AiMaterialWeights()
                  : AiMaterialWeights(
                      mobility: (weights[0] as num).toDouble(),
                      crush: (weights[1] as num).toDouble(),
                      exposure: (weights[2] as num).toDouble(),
                      access: (weights[3] as num).toDouble()),
              onSearchComplete: (value) => stats = value)
          .choose(game,
              recentPositionKeys: history,
              decisionSeed: request['decisionSeed'] as int?);
      return {
        'move': move?.toMap(game.current),
        'elapsedMs': stats?.elapsedMs,
        'depth': stats?.completedDepth,
        'rounds': stats?.completedRounds,
        'rootWidth': stats?.completedRootWidth,
        'timedOut': stats?.timedOut,
        'stage': stats?.stage,
        'timeoutStage': stats?.timeoutStage,
        'randomSeed': stats?.decisionSeed,
        'alternatives': stats?.alternatives,
        'evaluationBefore': MatchAI.evaluationTerms(game, game.current,
            endgame: level.index >= 2),
        if (move != null)
          'evaluationAfter': MatchAI.evaluationTerms(
              MatchRules.play(game, move)!, game.current,
              endgame: level.index >= 2),
        'cacheHits': stats?.cacheHits,
        'cacheEntries': stats?.cacheEntries,
        'cacheEvictions': stats?.cacheEvictions,
        'forksProven': stats?.forksProven
      };
    });
