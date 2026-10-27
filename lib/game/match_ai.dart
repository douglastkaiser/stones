import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'match_config.dart';
import 'match_state.dart';
import 'match_ai_engine.dart';
import 'legacy_match_ai_engine.dart';
export 'match_ai_engine.dart';

Future<MatchMove?> selectMatchMove(MatchState game, BotLevel level,
        {bool Function()? cancelled,
        int? decisionSeed,
        AiMoveVariation variation = AiMoveVariation.deterministic,
        List<String> recentPositionKeys = const []}) =>
    kIsWeb
        ? game.config.aiEngine == 'shared-search-v1'
            ? LegacyMatchAI(level).choose(game, cancelled: cancelled)
            : MatchAI(level, variation: variation).choose(game,
                cancelled: cancelled,
                decisionSeed: decisionSeed,
                recentPositionKeys: recentPositionKeys)
        : compute(_selectMove,
            (game, level, recentPositionKeys, decisionSeed, variation));

Future<MatchMove?> _selectMove(
        (MatchState, BotLevel, List<String>, int?, AiMoveVariation) request) =>
    request.$1.config.aiEngine == 'shared-search-v1'
        ? LegacyMatchAI(request.$2, yieldDuringSearch: false).choose(request.$1)
        : MatchAI(request.$2, yieldDuringSearch: false, variation: request.$5)
            .choose(request.$1,
                recentPositionKeys: request.$3, decisionSeed: request.$4);
