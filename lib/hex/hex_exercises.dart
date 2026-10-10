import '../models/piece.dart';
import 'hex_game.dart';
import 'hex_studies.dart';
import 'hex_forcing_position.dart';
import '../puzzles/certificates.dart';

/// Learning positions are separate local sandboxes, never multiplayer rooms.
class HexExercise {
  const HexExercise(
      {required this.id,
      required this.title,
      required this.goal,
      required this.hint,
      required this.initial,
      required this.solution,
      this.puzzle = false,
      this.moveLimit = 1,
      this.hints = const [],
      this.explanation = '',
      this.metadata = ''});
  final String id;
  final String title;
  final String goal;
  final String hint;
  final HexGame initial;
  final List<HexMove> solution;
  final bool puzzle;
  final int moveLimit;
  final List<String> hints;
  final String explanation;
  final String metadata;
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
      ? result.finished &&
          result.winner == initial.current &&
          steps > 0 &&
          steps <= moveLimit
      : steps == solution.length;
}

HexGame _position(Map<HexCell, List<HexStone>> board,
        {HexSeat seat = HexSeat.ivory}) =>
    hexStudyPosition(board, learner: seat);
HexStone _flat(HexSeat seat) => HexStone(seat, PieceType.flat);
HexGame _ivoryRoad() => _position({
      for (final q in [-2, -1, 1, 2]) HexCell(q, 0): [_flat(HexSeat.ivory)],
      const HexCell(-1, 1): [_flat(HexSeat.charcoal)],
      const HexCell(0, 1): [_flat(HexSeat.copper)],
    });
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
  for (var i = 0; i < hexStudies.length; i++)
    HexExercise(
      id: hexStudies[i].id,
      title: '${i + 1}. ${hexStudies[i].title}',
      puzzle: true,
      initial: hexStudies[i].initial,
      goal:
          'Win as ${hexStudies[i].initial.current.label} within ${hexStudies[i].moves} of your moves. Both opponents defend between your turns.',
      hint: hexStudies[i].hints.first,
      hints: hexStudies[i].hints,
      moveLimit: hexStudies[i].moves,
      explanation: hexStudies[i].explanation,
      metadata:
          'Radius ${hexStudies[i].initial.radius} · ${hexStudies[i].phase} · ${hexStudies[i].difficulty}',
      solution: [
        for (final key
            in puzzleCertificates[hexStudies[i].id]!['sample'] as List<dynamic>)
          HexForcingPosition.decode(key as String)
      ],
    ),
];
