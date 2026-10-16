import '../models/game_state.dart';
import '../models/online_game.dart';
import '../models/piece.dart';
import '../providers/game_provider.dart';
import '../providers/game_session_provider.dart';
import 'board_geometry.dart';
import 'legacy_square_adapter.dart';
import 'match_completed.dart';
import 'match_config.dart';
import 'match_controller.dart';
import 'match_room.dart';
import 'match_state.dart';

/// Compatibility adapter only. Awards still use the shared replay verifier.
MatchCompleted? legacyAchievementResult({required GameState state,
    required GameSessionConfig session, required List<MoveRecord> history,
    required String matchId, OnlineGameSession? room, int clockSeconds = 0}) {
  if (session.scenario != null || session.isCourtMode || session.mode == GameMode.local) return null;
  final online = session.mode == GameMode.online;
  if (online && room == null) return null;
  final human = SeatId.values[session.vsComputerPlayerColor.index];
  final config = MatchConfig(shape: BoardShape.square, size: state.boardSize,
    clockSeconds: clockSeconds, seats: [for (final id in [SeatId.ivory, SeatId.charcoal])
      SeatConfig(id, control: online ? SeatControl.onlineHuman :
        id == human ? SeatControl.localHuman : SeatControl.ai,
        level: BotLevel.values[session.aiDifficulty.index])]);
  final moves = <Map<String,dynamic>>[];
  for (final record in history) {
    final text = record.notation;
    Cell cell(String column, String row) => Cell(column.codeUnitAt(0)-97, state.boardSize-int.parse(row));
    final placement = RegExp(r'^(S|C)?([a-z])(\d+)$').firstMatch(text);
    MatchMove move;
    if (placement != null) {
      move = MatchMove.place(cell(placement.group(2)!,placement.group(3)!),
        switch (placement.group(1)) {'S' => PieceType.standing, 'C' => PieceType.capstone, _ => PieceType.flat});
    } else {
      final spread = RegExp(r'^(\d+)?([a-z])(\d+)([<>+-])(\d+)?$').firstMatch(text);
      if (spread == null) return null;
      final picked = int.parse(spread.group(1) ?? '1');
      final drops = spread.group(5)?.split('').map(int.parse).toList() ?? [picked];
      if (drops.fold(0,(int sum,int drop) => sum+drop) != picked) return null;
      move = MatchMove.spread(cell(spread.group(2)!,spread.group(3)!),
        switch (spread.group(4)) {'+' => Step.northWest, '-' => Step.southEast, '<' => Step.west, _ => Step.east}, drops);
    }
    moves.add(move.toMap(SeatId.values[record.player.index]));
  }
  final old = LegacySquareAdapter.read(state);
  final game = MatchState(config: config, board: old.board,
      reserves: old.reserves, ply: moves.length, result: old.result);
  final owners = {SeatId.ivory: room?.white?.id, SeatId.charcoal: room?.black?.id};
  return MatchCompleted(MatchSession(id: online ? room!.roomCode : matchId,
    uid: online ? owners[human] : null, game: game,
    room: online ? MatchRoom(code: room!.roomCode, host: room.white?.id ?? '',
      config: config, owners: owners, moves: moves) : null), moves: moves);
}
