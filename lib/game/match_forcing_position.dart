import '../puzzles/forcing_search.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

/// Exhaustive proof adapter for the shared engine; gameplay AI is not a proof.
class MatchForcingPosition extends ForcingPosition<MatchState, MatchMove> {
  @override
  int player(MatchState state) => state.current.index;
  @override
  bool finished(MatchState state) => state.finished;
  @override
  int? winner(MatchState state) => state.result?.winner?.index;
  @override
  Iterable<MatchMove> moves(MatchState state) => MatchRules.legalMoves(state);
  @override
  MatchState play(MatchState state, MatchMove move) =>
      MatchRules.play(state, move) ?? (throw StateError('Illegal proof move'));
  @override
  MatchState learnerTurn(MatchState state, int learner) {
    final index = state.config.ids.indexOf(SeatId.values[learner]);
    final count = state.config.seats.length;
    return MatchState(
        config: state.config.copyWith(
            starter:
                state.config.ids[(index - state.ply % count + count) % count]),
        board: state.board,
        reserves: state.reserves,
        ply: state.ply,
        result: state.result);
  }

  @override
  String moveKey(MatchMove move) =>
      '${move.from.x},${move.from.y}:${move.type?.name}:${move.direction?.name}:${move.drops.join(',')}';
  @override
  String key(MatchState state) =>
      '${state.current.name}:${state.opening}:${state.config.profile.name}:'
      '${state.config.ids.map((id) => '${id.name},${state.reserves[id]!.stones},${state.reserves[id]!.caps}').join(';')}:'
      '${state.geometry.cells.map((cell) => state.stackAt(cell).map((p) => '${p.seat.index}${p.type.index}').join('.')).join('/')}';
}
