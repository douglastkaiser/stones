import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_ai_engine.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/models/piece.dart';
import '../../tools/ai_balance_proof.dart';

bool reference(MatchState game, SeatId attacker, int plies) {
  if (game.finished) return game.result!.winner == attacker;
  if (plies == 0) return false;
  final results = MatchRules.legalMoves(game)
      .map((m) => reference(MatchRules.play(game, m)!, attacker, plies - 1))
      .toList();
  if (results.isEmpty) return false;
  return game.current == attacker
      ? results.any((r) => r)
      : results.every((r) => r);
}

void main() {
  final cfg = MatchConfig(
      shape: BoardShape.square,
      size: 3,
      seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
  var start = MatchState.initial(cfg);
  for (final cell in [const Cell(0, 0), const Cell(0, 1), const Cell(1, 0)]) {
    start = MatchRules.play(start, MatchMove.place(cell, PieceType.flat))!;
  }
  final fork = MatchRules.play(
      MatchRules.play(
          start, MatchMove.place(const Cell(2, 2), PieceType.flat))!,
      MatchMove.place(const Cell(1, 1), PieceType.flat))!;
  test('bounded proofs match exhaustive legal search with both attackers', () {
    for (final game in [MatchState.initial(cfg), start, fork]) {
      for (final attacker in cfg.ids) {
        for (var plies = 0; plies <= 3; plies++) {
          final expected = reference(game, attacker, plies);
          expect(BoundedDuelProof().solve(game, attacker, plies),
              expected ? DuelProof.proven : DuelProof.refuted);
        }
      }
    }
  });
  test('node exhaustion is unknown and cannot establish balance', () {
    expect(BoundedDuelProof(maxNodes: 1).solve(fork, SeatId.ivory, 2),
        DuelProof.unknown);
    expect(BoundedDuelProof().solve(fork, SeatId.ivory, 2), DuelProof.proven);
  });

  test('recorded Hex race has a quiet flat defense before the double threat',
      () {
    var game = MatchState.initial(MatchConfig(
        shape: BoardShape.hex,
        size: 2,
        seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]));
    for (final (cell, type) in [
      (const Cell(-1, -1), PieceType.flat),
      (const Cell(-1, 2), PieceType.flat),
      (const Cell(0, 1), PieceType.capstone),
      (const Cell(-1, 0), PieceType.flat),
      (const Cell(-2, 2), PieceType.flat),
    ]) {
      game = MatchRules.play(game, MatchMove.place(cell, type))!;
    }
    final greedy = MatchRules.play(
        game, MatchMove.place(const Cell(0, 0), PieceType.flat))!;
    final defensive = MatchRules.play(
        game, MatchMove.place(const Cell(1, 0), PieceType.flat))!;
    expect(BoundedDuelProof().solve(greedy, SeatId.ivory, 3), DuelProof.proven);
    expect(BoundedDuelProof().solve(defensive, SeatId.ivory, 3),
        DuelProof.refuted);
  });

  test(
      'duel rules and evaluation are symmetric when colors and starter reverse',
      () {
    SeatId swap(SeatId id) =>
        id == SeatId.ivory ? SeatId.charcoal : SeatId.ivory;
    for (final shape in BoardShape.values) {
      final cfg = MatchConfig(
          shape: shape,
          size: shape == BoardShape.square ? 5 : 2,
          seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
      var game = MatchState.initial(cfg);
      for (var ply = 0; ply < 6 && !game.finished; ply++) {
        final mirror = MatchState(
            config: cfg.copyWith(starter: SeatId.charcoal),
            ply: game.ply,
            board: game.board.map((cell, stack) => MapEntry(
                cell, stack.map((s) => Stone(swap(s.seat), s.type)).toList())),
            reserves: game.reserves
                .map((id, reserve) => MapEntry(swap(id), reserve)));
        for (final id in cfg.ids) {
          expect(
              MatchAI.evaluate(game)[id], MatchAI.evaluate(mirror)[swap(id)]);
        }
        final legal = MatchRules.legalMoves(game).toList();
        for (final move in legal) {
          final next = MatchRules.play(game, move)!;
          final other = MatchRules.play(mirror, move);
          expect(other, isNotNull);
          expect(other!.current, swap(next.current));
          expect(other.result?.winner,
              next.result?.winner == null ? null : swap(next.result!.winner!));
          expect(other.result?.reason, next.result?.reason);
          expect(
              other.board,
              next.board.map((cell, stack) => MapEntry(cell,
                  stack.map((s) => Stone(swap(s.seat), s.type)).toList())));
        }
        game = MatchRules.play(game, legal[ply % legal.length])!;
      }
    }
  });
}
