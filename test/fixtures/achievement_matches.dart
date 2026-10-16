import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_completed.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';

/// Real, legal histories from an empty board; no invented terminal flags.
MatchCompleted roadMatch(
    {String id = 'test-match',
    BoardShape shape = BoardShape.square,
    int? size,
    int count = 2,
    BotLevel level = BotLevel.hard,
    SeatId human = SeatId.ivory,
    bool online = false,
    bool court = false,
    bool capstone = false,
    bool crush = false,
    bool longSpread = false,
    int clockSeconds = 0,
    String opponent = 'opponent',
    List<BotLevel>? levels}) {
  final config = MatchConfig(
      shape: shape,
      size: size ?? (shape == BoardShape.square ? 5 : 2),
      court: court,
      clockSeconds: clockSeconds,
      seats: [
        for (var i = 0; i < count; i++)
          SeatConfig(SeatId.values[i],
              control: online
                  ? i == 0
                      ? SeatControl.localHuman
                      : SeatControl.onlineHuman
                  : SeatId.values[i] == human
                      ? SeatControl.localHuman
                      : SeatControl.ai,
              level: levels?[i] ?? level)
      ]);
  var game = MatchState.initial(config);
  final records = <Map<String, dynamic>>[];
  void play(MatchMove move) {
    records.add(move.toMap(game.current));
    final next = MatchRules.play(game, move);
    if (next == null) {
      throw StateError('Invalid achievement test move at ${game.ply}: $move');
    }
    game = next;
  }

  if (longSpread) {
    play(MatchMove.place(const Cell(4, 4), PieceType.flat));
    play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    final moves = [
      MatchMove.place(const Cell(1, 0), PieceType.flat),
      MatchMove.place(const Cell(3, 0), PieceType.flat),
      MatchMove.place(const Cell(4, 0), PieceType.flat),
      MatchMove.place(const Cell(2, 3), PieceType.flat),
      MatchMove.place(const Cell(2, 4), PieceType.flat),
      MatchMove.spread(const Cell(2, 4), Step.northWest, [1]),
      MatchMove.place(const Cell(1, 3), PieceType.capstone),
      MatchMove.spread(const Cell(1, 3), Step.east, [1]),
      MatchMove.spread(const Cell(2, 3), Step.northWest, [1, 1, 1]),
    ];
    final targets = [
      const Cell(0, 1),
      const Cell(1, 1),
      const Cell(3, 1),
      const Cell(4, 1),
      const Cell(0, 2),
      const Cell(1, 2),
      const Cell(3, 2),
      const Cell(4, 2)
    ];
    for (var i = 0; i < moves.length; i++) {
      play(moves[i]);
      if (!game.finished) {
        play(MatchMove.place(targets[i], PieceType.standing));
      }
    }
  } else if (crush) {
    if (shape != BoardShape.square || count != 2 || config.size != 5) {
      throw ArgumentError('Crush fixture');
    }
    for (final move in [
      MatchMove.place(const Cell(4, 4), PieceType.flat),
      MatchMove.place(const Cell(0, 0), PieceType.flat),
      MatchMove.place(const Cell(1, 0), PieceType.flat),
      MatchMove.place(const Cell(4, 0), PieceType.standing),
      MatchMove.place(const Cell(2, 0), PieceType.flat),
      MatchMove.place(const Cell(0, 3), PieceType.standing),
      MatchMove.place(const Cell(3, 0), PieceType.flat),
      MatchMove.place(const Cell(1, 3), PieceType.standing),
      MatchMove.place(const Cell(4, 1), PieceType.capstone),
      MatchMove.place(const Cell(2, 3), PieceType.standing),
      MatchMove.spread(const Cell(4, 1), Step.northWest, [1])
    ]) {
      play(move);
    }
  } else {
    final road = <Cell>[
      for (var x = shape == BoardShape.square ? 0 : -config.size;
          x <= (shape == BoardShape.square ? config.size - 1 : config.size);
          x++)
        Cell(x, 0)
    ];
    while (!game.finished && game.ply < 200) {
      MatchMove? move;
      if (game.opening && config.next(game.current) == SeatId.ivory) {
        move = MatchMove.place(road.first, PieceType.flat);
      } else if (!game.opening && game.current == SeatId.ivory) {
        final target = road.firstWhere((cell) => game.stackAt(cell).isEmpty);
        move = MatchMove.place(
            target,
            capstone && target == road[road.length ~/ 2]
                ? PieceType.capstone
                : PieceType.flat);
      } else {
        for (final cell in game.geometry.cells.where(
            (cell) => !road.contains(cell) && game.stackAt(cell).isEmpty)) {
          final candidate = MatchMove.place(cell, PieceType.flat);
          final after = MatchRules.play(game, candidate);
          if (after != null && !after.finished) {
            move = candidate;
            break;
          }
        }
        move ??= MatchRules.legalMoves(game)
            .where((m) =>
                m.type == null &&
                !road.contains(m.from) &&
                !road.contains(m.end) &&
                MatchRules.play(game, m)?.finished == false)
            .firstOrNull;
      }
      if (move == null) throw StateError('Could not build test road');
      play(move);
    }
  }
  if (game.result?.winner != SeatId.ivory ||
      game.result?.reason != ResultReason.road) {
    throw StateError('Test history did not end in Ivory road');
  }
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) % 308915776;
  }
  var encoded = hash;
  final code = 'U${List.generate(6, (_) {
    final letter = String.fromCharCode(65 + encoded % 26);
    encoded ~/= 26;
    return letter;
  }).join()}';
  final owners = {
    for (var i = 0; i < count; i++)
      SeatId.values[i]: i == 0 ? 'player' : '$opponent-$i'
  };
  return MatchCompleted(
      MatchSession(
          id: online ? code : id,
          game: game,
          uid: online ? 'player' : null,
          room: online
              ? MatchRoom(
                  code: code,
                  host: 'player',
                  config: config,
                  owners: owners,
                  moves: records)
              : null),
      moves: records);
}

MatchCompleted drawnHardDuel({String id = 'drawn-duel', bool flatWin = false}) {
  final config = MatchConfig(shape: BoardShape.square, size: 5, seats: const [
    SeatConfig(SeatId.ivory),
    SeatConfig(SeatId.charcoal, control: SeatControl.ai, level: BotLevel.hard)
  ]);
  var game = MatchState.initial(config);
  final moves = <Map<String, dynamic>>[];
  while (!game.finished) {
    final color = game.opening ? config.next(game.current) : game.current;
    final cell = game.geometry.cells.firstWhere(
        (c) => game.stackAt(c).isEmpty && (c.x + c.y) % 2 == color.index);
    final move = MatchMove.place(
        cell,
        (cell == const Cell(2, 2) || (flatWin && cell == const Cell(1, 2)))
            ? PieceType.standing
            : PieceType.flat);
    moves.add(move.toMap(game.current));
    final next = MatchRules.play(game, move);
    if (next == null) {
      throw StateError('Invalid draw fixture');
    }
    game = next;
  }
  if (flatWin
      ? game.result?.winner != SeatId.ivory
      : game.result?.draw != true) {
    throw StateError('Flat fixture has wrong result');
  }
  return MatchCompleted(MatchSession(id: id, game: game), moves: moves);
}
