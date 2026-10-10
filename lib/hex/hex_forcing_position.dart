import '../models/piece.dart';
import '../puzzles/forcing_search.dart';
import 'hex_game.dart';

class HexForcingPosition extends ForcingPosition<HexGame, HexMove> {
  @override
  HexGame learnerTurn(HexGame state, int learner) =>
      state.copyWith(ply: state.ply + (learner - state.current.index + 3) % 3);
  @override
  int player(HexGame state) => state.current.index;
  @override
  bool finished(HexGame state) => state.finished;
  @override
  int? winner(HexGame state) => state.winner?.index;
  @override
  Iterable<HexMove> moves(HexGame state) => HexRules.legalMoves(state);
  @override
  HexGame play(HexGame state, HexMove move) =>
      HexRules.play(state, move) ??
      (throw StateError('Illegal Hex puzzle move'));
  @override
  String moveKey(HexMove move) => move.type != null
      ? 'p:${move.from.key}:${move.type!.index}'
      : 's:${move.from.key}:${move.direction!.index}:${move.drops.join(',')}';
  static HexMove decode(String key) {
    final parts = key.split(':');
    final coordinate = parts[1].split(',').map(int.parse).toList();
    final cell = HexCell(coordinate[0], coordinate[1]);
    return parts[0] == 'p'
        ? HexMove.place(cell, PieceType.values[int.parse(parts[2])])
        : HexMove.spread(cell, HexDirection.values[int.parse(parts[2])],
            parts[3].split(',').map(int.parse).toList());
  }

  @override
  String key(HexGame state) {
    final buffer = StringBuffer(
        '${state.rulesVersion}/${state.radius}/${state.current.index}/${state.opening}/${state.finished}/');
    for (final reserve in state.reserves) {
      buffer.write('${reserve.stones},${reserve.caps}/');
    }
    for (final cell in state.cells) {
      for (final stone in state.stackAt(cell)) {
        buffer.write('${stone.seat.index}${stone.type.index}');
      }
      buffer.write('/');
    }
    return buffer.toString();
  }
}
