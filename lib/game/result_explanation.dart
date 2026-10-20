import 'match_rules.dart';
import 'match_state.dart';

/// Explain the adjudicated result, without treating flat counts as road scores.
String explainResult(MatchState game, {String? winnerName}) {
  final result = game.result;
  if (result == null) return '';
  final winner = winnerName ?? result.winner?.label;
  return switch (result.reason) {
    ResultReason.road => winner == null
        ? 'Draw: this move completed roads for multiple opponents.'
        : '$winner won by connecting opposite edges with exposed flats and capstones. '
            'The highlighted road wins before flat stones are counted.',
    ResultReason.flats =>
      '${game.board.length == game.geometry.cells.length ? 'The board is full' : 'A player has used all their pieces'}. '
          '${winner == null ? 'The highest exposed-flat count is tied, so the game is a draw.' : '$winner won with ${MatchRules.flatCounts(game)[result.winner]} exposed flats.'} '
          'Only top flat stones count; walls, capstones and buried stones do not.',
    ResultReason.resignation => winner == null
        ? 'The game ended after a resignation, without a winner.'
        : '$winner won because the other player resigned.',
    ResultReason.time => winner == null
        ? 'The game ended when a player ran out of time, without a winner.'
        : '$winner won because the other player ran out of time.',
    ResultReason.abandoned =>
      'The game was ended without a winner. This is not a competitive draw.',
  };
}
