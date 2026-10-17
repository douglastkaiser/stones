import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'match_config.dart';
import 'match_state.dart';
import 'match_ai_engine.dart';
export 'match_ai_engine.dart';

Future<MatchMove?> selectMatchMove(MatchState game, BotLevel level,
        {bool Function()? cancelled}) =>
    kIsWeb
        ? MatchAI(level).choose(game, cancelled: cancelled)
        : compute(_selectMove, (game, level));

Future<MatchMove?> _selectMove((MatchState, BotLevel) request) =>
    MatchAI(request.$2, yieldDuringSearch: false).choose(request.$1);

