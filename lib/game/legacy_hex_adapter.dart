import '../hex/hex_game.dart';
import 'board_geometry.dart';
import 'match_config.dart';
import 'match_state.dart';

/// Versioned compatibility; legacy colors and documents are never extended.
class LegacyHexAdapter {
  static MatchState read(HexGame game) => MatchState(
      config: MatchConfig(
          shape: BoardShape.hex,
          size: game.radius,
          seats: SeatId.values.take(3).map(SeatConfig.new).toList(),
          starter: SeatId.values[game.starter.index],
          profile: game.rulesVersion == 1
              ? RulesProfile.legacyHex
              : RulesProfile.sharedRoads),
      board: {
        for (final entry in game.board.entries)
          Cell(entry.key.q, entry.key.r): entry.value
              .map((p) => Stone(SeatId.values[p.seat.index], p.type))
              .toList()
      },
      reserves: {
        for (var i = 0; i < 3; i++)
          SeatId.values[i]:
              Reserve(game.reserves[i].stones, game.reserves[i].caps)
      },
      ply: game.ply,
      result: game.finished
          ? MatchResult(
              game.winner == null ? null : SeatId.values[game.winner!.index],
              game.reason?.toLowerCase().contains('road') == true
                  ? ResultReason.road
                  : ResultReason.flats)
          : null);

  static MatchMove move(HexMove move) => move.type != null
      ? MatchMove.place(Cell(move.from.q, move.from.r), move.type!)
      : MatchMove.spread(Cell(move.from.q, move.from.r),
          Step.values[move.direction!.index], move.drops);

  static HexMove writeMove(MatchMove move) => move.type != null
      ? HexMove.place(HexCell(move.from.x, move.from.y), move.type!)
      : HexMove.spread(HexCell(move.from.x, move.from.y),
          HexDirection.values[move.direction!.index], move.drops);

  static HexGame write(HexGame original, MatchState state) => HexGame(
      radius: original.radius,
      rulesVersion: original.rulesVersion,
      starter: original.starter,
      ply: state.ply,
      board: {
        for (final e in state.board.entries)
          HexCell(e.key.x, e.key.y): e.value
              .map((p) => HexStone(HexSeat.values[p.seat.index], p.type))
              .toList()
      },
      reserves: [
        for (final id in state.config.ids)
          state.reserves[id]!.stones == original.reserves[id.index].stones &&
                  state.reserves[id]!.caps == original.reserves[id.index].caps
              ? original.reserves[id.index]
              : HexReserve(state.reserves[id]!.stones, state.reserves[id]!.caps)
      ],
      finished: state.finished,
      winner: state.result?.winner == null
          ? null
          : HexSeat.values[state.result!.winner!.index],
      reason: state.result == null
          ? null
          : state.result!.reason == ResultReason.road
              ? state.result!.draw
                  ? 'Simultaneous opponent roads — draw'
                  : 'Road'
              : state.result!.draw
                  ? 'Tied flats — draw'
                  : 'Flats');
}
