import 'dart:math' as math;
import '../models/piece.dart';
import 'match_config.dart';
import 'match_rules.dart';
import 'match_state.dart';

class AiMaterialWeights {
  const AiMaterialWeights(
      {this.mobility = 0, this.crush = 4, this.exposure = 4, this.access = 4});
  final double mobility, crush, exposure, access;
  static const zero = AiMaterialWeights(crush: 0, exposure: 0, access: 0);
  String get key => '$mobility/$crush/$exposure/$access';
}

/// Local legal probes, never an alternative movement/flattening implementation.
double aiMaterialScore(
    MatchState game, SeatId seat, AiMaterialWeights weights) {
  if (weights.mobility == 0 &&
      weights.crush == 0 &&
      weights.exposure == 0 &&
      weights.access == 0) {
    return 0;
  }
  var mobile = 0.0, crush = 0.0, exposed = 0.0, accessible = 0.0;
  var stacks = 0;
  var ply = game.ply;
  while (game.config.turnAt(ply) != seat) {
    ply++;
  }
  final turn = game.copyWith(ply: ply);
  for (final entry in game.board.entries) {
    final stack = entry.value;
    if (stack.last.seat != seat) continue;
    stacks++;
    final top = stack.last;
    if (top.type != PieceType.capstone && stack.length == 1) continue;
    // A lone cap has no exposed/buried material. With mobility disabled,
    // legal probes matter only when an adjacent enemy wall can be crushed.
    if (stack.length == 1 &&
        top.type == PieceType.capstone &&
        weights.mobility == 0 &&
        (weights.crush == 0 ||
            !game.geometry.directions.any((direction) {
              final target = game.topAt(entry.key.step(direction));
              return target?.type == PieceType.standing && target!.seat != seat;
            }))) {
      continue;
    }
    var destinations = 0;
    var crushes = 0;
    for (final direction in game.geometry.directions) {
      final move = MatchMove.spread(entry.key, direction, const [1]);
      final next = MatchRules.apply(turn, move);
      if (next == null) continue;
      destinations++;
      final target = game.topAt(entry.key.step(direction));
      if (target?.type == PieceType.standing && target!.seat != seat) crushes++;
      // Moving a top stone may expose a friendly road or an enemy road.
      if (stack.length > 1) {
        final underneath = stack[stack.length - 2];
        if (underneath.type != PieceType.standing) {
          exposed += underneath.seat == seat ? 1 : -1;
        }
      }
    }
    if (top.type == PieceType.capstone) {
      mobile += destinations / game.geometry.directions.length;
      crush += math.min(1, crushes);
    }
    final buried =
        stack.take(stack.length - 1).where((s) => s.seat == seat).length;
    if (buried > 0) {
      accessible += destinations > 0 ? math.min(1, buried / 3) : -1;
    }
  }
  if (stacks == 0) return 0;
  final score = weights.mobility * (mobile / stacks) +
      weights.crush * (crush / stacks) +
      weights.exposure *
          (exposed / (stacks * game.geometry.directions.length)) +
      weights.access * (accessible / stacks);
  return score.clamp(-40.0, 40.0);
}
