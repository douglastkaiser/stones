import 'package:stones/game/ai_material.dart';
import 'package:stones/game/ai_road_resilience.dart';
import 'package:stones/game/match_ai_engine.dart';
import 'package:stones/game/match_rules.dart';
import 'ai_worker_protocol.dart';

// Compile distinct immutable ablation binaries; defaults remain production.
const _fullWidth = bool.fromEnvironment('STONES_FULL_WIDTH');
const _resilience =
    String.fromEnvironment('STONES_RESILIENCE_WEIGHT', defaultValue: '0');
const _tacticalSafety =
    bool.fromEnvironment('STONES_TACTICAL_SAFETY', defaultValue: true);
const _duelLimits = String.fromEnvironment('STONES_DUEL_BUDGETS');

Future<void> main() => serve((game, level, history, request) async {
      MatchSearchStats? stats;
      final weights = request['weights'] as List?;
      final resilienceWeight =
          (request['roadResilienceWeight'] as num?)?.toDouble() ??
              double.parse(_resilience);
      final limits = _duelLimits.isEmpty
          ? null
          : _duelLimits.split(':').map(int.parse).toList();
      if (limits != null && (limits.length != 4 || limits.any((n) => n < 0))) {
        throw ArgumentError('Four nonnegative duel budgets required');
      }
      final move = await MatchAI(level,
          yieldDuringSearch: false,
          useCaches: request['caches'] != false,
          fullWidthDuels: request['fullWidthDuels'] as bool? ?? _fullWidth,
          roadResilienceWeight: resilienceWeight,
          tacticalSafety: request['tacticalSafety'] as bool? ?? _tacticalSafety,
          duelThinkingLimit: limits == null
              ? null
              : Duration(milliseconds: limits[level.index]),
          variation: AiMoveVariation.values
              .byName(request['policy'] as String? ?? 'deterministic'),
          materialWeights: weights == null
              ? const AiMaterialWeights()
              : AiMaterialWeights(
                  mobility: (weights[0] as num).toDouble(),
                  crush: (weights[1] as num).toDouble(),
                  exposure: (weights[2] as num).toDouble(),
                  access: (weights[3] as num).toDouble()),
          onSearchComplete: (value) =>
              stats = value).choose(game,
          recentPositionKeys: history,
          decisionSeed: request['decisionSeed'] as int?);
      return {
        'move': move?.toMap(game.current),
        'elapsedMs': stats?.elapsedMs,
        'depth': stats?.completedDepth,
        'rounds': stats?.completedRounds,
        'rootWidth': stats?.completedRootWidth,
        'strategicLimitMs': stats?.strategicLimitMs,
        'totalLimitMs': stats?.totalLimitMs,
        'completedIterations': stats?.completedIterations,
        'timedOut': stats?.timedOut,
        'stage': stats?.stage,
        'timeoutStage': stats?.timeoutStage,
        'randomSeed': stats?.decisionSeed,
        'alternatives': stats?.alternatives,
        'evaluationBefore': MatchAI.evaluationTerms(game, game.current,
            endgame: level.index >= 2, roadResilienceWeight: resilienceWeight),
        if (move != null)
          'evaluationAfter': MatchAI.evaluationTerms(
              MatchRules.play(game, move)!, game.current,
              endgame: level.index >= 2,
              roadResilienceWeight: resilienceWeight),
        'cacheHits': stats?.cacheHits,
        'cacheEntries': stats?.cacheEntries,
        'cacheEvictions': stats?.cacheEvictions,
        'forksProven': stats?.forksProven,
        'searchModel': stats?.searchModel,
        'exhaustiveDepth': stats?.exhaustiveDepth,
        'completedTacticalDepth': stats?.completedTacticalDepth,
        'safetyPlies': stats?.safetyPlies,
        'safetyProbes': stats?.safetyProbes,
        'safetyNodes': stats?.safetyNodes,
        'safetyVetoes': stats?.safetyVetoes,
        'safetyUnknown': stats?.safetyUnknown,
        'safetyReplacedMove': stats?.safetyReplacedMove,
        'nodes': stats?.nodes,
        'generatedMoves': stats?.generatedMoves,
        'evaluations': stats?.evaluations,
        'cutoffs': stats?.cutoffs,
        'extensionNodes': stats?.extensionNodes,
        'tacticalChecks': stats?.tacticalChecks,
        'orderingMicros': stats?.orderingMicros,
        'evaluationMicros': stats?.evaluationMicros,
        'tacticalMicros': stats?.tacticalMicros,
        'emergencyFallback': stats?.emergencyFallback,
        'experiment': {
          'fullWidthDuels': request['fullWidthDuels'] as bool? ?? _fullWidth,
          'roadResilienceWeight': resilienceWeight,
          if (limits != null) 'duelBudgetsMs': limits,
          if (request['tacticalSafety'] as bool? ?? _tacticalSafety)
            'tacticalSafety': true,
        },
        if (resilienceWeight != 0 &&
            game.config.aiEngine == 'shared-search-v3' &&
            game.config.seats.length == 2)
          'roadResilienceBefore': {
            for (final seat in game.config.ids)
              seat.name: {
                'cost': AiRoadResilience.measure(game, seat).cost,
                'maximumIncrease':
                    AiRoadResilience.measure(game, seat).maximumIncrease,
              }
          },
      };
    });
