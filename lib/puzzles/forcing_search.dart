/// Exhaustive finite-horizon proof, separate from the playing AIs' heuristic
/// search. Every defender reply is included; either opponent may refute Hex.
abstract class ForcingPosition<S, M> {
  int player(S state);
  bool finished(S state);
  int? winner(S state);
  Iterable<M> moves(S state);
  S play(S state, M move);
  String key(S state);
  String moveKey(M move);
  S learnerTurn(S state, int learner);
}

class ForcingSearch<S, M> {
  ForcingSearch(this.rules, this.learner, {this.nodeLimit = 3000000});
  final ForcingPosition<S, M> rules;
  final int learner;
  final int nodeLimit;
  int nodes = 0;
  final Map<String, bool> _memo = {};

  bool wins(S state, int remaining) {
    if (++nodes > nodeLimit) {
      throw StateError('Proof limit exceeded; result is unknown, not a win.');
    }
    if (rules.finished(state)) return rules.winner(state) == learner;
    if (remaining <= 0) return false;
    final key = '${rules.key(state)}:$remaining';
    final cached = _memo[key];
    if (cached != null) return cached;
    final attacking = rules.player(state) == learner;
    var any = false;
    for (final move in rules.moves(state)) {
      any = true;
      final won =
          wins(rules.play(state, move), remaining - (attacking ? 1 : 0));
      if (won == attacking) {
        _remember(key, attacking);
        return attacking;
      }
    }
    final result = any && !attacking;
    _remember(key, result);
    return result;
  }

  void _remember(String key, bool value) {
    if (_memo.length >= 30000) _memo.clear();
    _memo[key] = value;
  }

  List<M> winningMoves(S state, int remaining) => [
        for (final move in rules.moves(state))
          if (wins(rules.play(state, move), remaining - 1)) move,
      ];

  /// A defender's actual refutation of the finite-move objective.
  M? refutation(S state, int remaining) {
    for (final move in rules.moves(state)) {
      if (!wins(rules.play(state, move), remaining)) return move;
    }
    return null;
  }
}
