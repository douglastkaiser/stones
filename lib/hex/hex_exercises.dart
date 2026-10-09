import '../models/piece.dart';
import 'hex_game.dart';

/// Learning positions are separate local sandboxes, never multiplayer rooms.
class HexExercise {
  const HexExercise(
      {required this.id,
      required this.title,
      required this.goal,
      required this.hint,
      required this.initial,
      required this.solution,
      this.puzzle = false});
  final String id;
  final String title;
  final String goal;
  final String hint;
  final HexGame initial;
  final List<HexMove> solution;
  final bool puzzle;
  bool accepts(HexGame game, HexMove move, int step) {
    if (puzzle) {
      return HexRules.play(game, move) != null;
    }
    if (id == 'exchange') {
      return move.type == PieceType.flat && HexRules.play(game, move) != null;
    }
    if (id == 'neighbors') {
      return move.type == null &&
          move.from == const HexCell(0, 0) &&
          move.drops.length == 1 &&
          move.drops.single == 1;
    }
    final expected = solution[step];
    return move.from == expected.from &&
        move.type == expected.type &&
        move.direction == expected.direction &&
        move.drops.length == expected.drops.length &&
        List.generate(
                move.drops.length, (i) => move.drops[i] == expected.drops[i])
            .every((same) => same);
  }

  bool completed(HexGame result, int steps) => puzzle
      ? result.finished && result.winner == initial.current
      : steps == solution.length;
}

HexGame _position(Map<HexCell, List<HexStone>> board,
        {HexSeat seat = HexSeat.ivory}) =>
    HexGame.initial(starter: seat).copyWith(board: board, ply: 3);
HexStone _flat(HexSeat seat) => HexStone(seat, PieceType.flat);
HexGame _ivoryRoad() => _position({
      for (final q in [-2, -1, 1, 2]) HexCell(q, 0): [_flat(HexSeat.ivory)],
      const HexCell(-1, 1): [_flat(HexSeat.charcoal)],
      const HexCell(0, 1): [_flat(HexSeat.copper)],
    });
HexGame _charcoalCrush() => _position({
      for (final r in [-2, -1, 1, 2]) HexCell(0, r): [_flat(HexSeat.charcoal)],
      const HexCell(0, 0): [const HexStone(HexSeat.ivory, PieceType.standing)],
      const HexCell(1, 0): [
        const HexStone(HexSeat.charcoal, PieceType.capstone)
      ],
    }, seat: HexSeat.charcoal);
HexGame _copperCarry() => _position({
      for (final cell in [
        const HexCell(-1, -1),
        const HexCell(-1, 0),
        const HexCell(0, 0)
      ])
        cell: [_flat(HexSeat.copper)],
      const HexCell(1, 1): [
        _flat(HexSeat.copper),
        const HexStone(HexSeat.copper, PieceType.capstone)
      ],
      const HexCell(0, 1): [const HexStone(HexSeat.ivory, PieceType.standing)],
    }, seat: HexSeat.copper);

final hexExercises = <HexExercise>[
  HexExercise(
      id: 'exchange',
      title: 'The three-turn exchange',
      goal:
          'Place the next seat’s flat on each of the first three turns. You control all seats in this lesson.',
      hint:
          'Ivory places Charcoal, Charcoal places Copper, then Copper places Ivory. Choose any empty cells.',
      initial: HexGame.initial(),
      solution: [
        HexMove.place(const HexCell(-1, 0), PieceType.flat),
        HexMove.place(const HexCell(0, 0), PieceType.flat),
        HexMove.place(const HexCell(1, 0), PieceType.flat),
      ]),
  HexExercise(
      id: 'neighbors',
      title: 'Six directions',
      goal:
          'Move the center Ivory stone to any neighboring hexagon. A spread follows one of six straight directions.',
      hint:
          'Select the center stone, then a highlighted neighbor and Confirm. Touching at a corner does not connect cells.',
      initial: _position({
        const HexCell(0, 0): [_flat(HexSeat.ivory)]
      }),
      solution: [
        HexMove.spread(const HexCell(0, 0), HexDirection.east, [1])
      ]),
  HexExercise(
      id: 'edges',
      title: 'Your own opposite edges',
      goal:
          'Finish Ivory’s road between its matching marked edges by placing a flat at the center.',
      hint: 'Ivory connects q = -2 to q = 2. Charcoal and Copper have different edge pairs. Walls do not join roads.',
      initial: _ivoryRoad(),
      solution: [HexMove.place(const HexCell(0, 0), PieceType.flat)]),
  HexExercise(
      id: 'spread',
      title: 'Spread and crush',
      goal:
          'Carry all three center pieces east. Drop two on the first cell, then the lone capstone onto the wall.',
      hint:
          'Select the center stack and the wall at (2, 0). Choose 2 → 1. Drops preserve bottom-first order; only a lone final capstone crushes.',
      initial: _position({
        const HexCell(0, 0): [
          _flat(HexSeat.copper),
          _flat(HexSeat.ivory),
          const HexStone(HexSeat.ivory, PieceType.capstone)
        ],
        const HexCell(2, 0): [
          const HexStone(HexSeat.charcoal, PieceType.standing)
        ],
      }),
      solution: [
        HexMove.spread(const HexCell(0, 0), HexDirection.east, [2, 1])
      ]),
  HexExercise(
      id: 'ivory-gap',
      title: 'Ivory’s missing link',
      puzzle: true,
      goal: 'Win for Ivory in one move.',
      hint: 'Join the matching Ivory edges with an exposed flat or capstone.',
      initial: _ivoryRoad(),
      solution: [HexMove.place(const HexCell(0, 0), PieceType.flat)]),
  HexExercise(
      id: 'charcoal-wall',
      title: 'Charcoal’s gateway',
      puzzle: true,
      goal: 'Win for Charcoal in one move.',
      hint:
          'The center wall breaks Charcoal’s road. A neighboring capstone can open it.',
      initial: _charcoalCrush(),
      solution: [
        HexMove.spread(const HexCell(1, 0), HexDirection.west, [1])
      ]),
  HexExercise(
      id: 'copper-cap',
      title: 'Copper’s careful carry',
      puzzle: true,
      goal: 'Win for Copper in one move.',
      hint:
          'Keep the flat on the boundary. Carry only the capstone to the missing cell (1, 0).',
      initial: _copperCarry(),
      solution: [
        HexMove.spread(const HexCell(1, 1), HexDirection.northWest, [1])
      ]),
];
