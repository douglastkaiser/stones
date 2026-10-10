import '../models/piece.dart';
import '../puzzles/study.dart';
import 'hex_game.dart';

const _i = HexStone(HexSeat.ivory, PieceType.flat);
const _ch = HexStone(HexSeat.charcoal, PieceType.flat);
const _cu = HexStone(HexSeat.copper, PieceType.flat);
const _cw = HexStone(HexSeat.charcoal, PieceType.standing);
const _uw = HexStone(HexSeat.copper, PieceType.standing);
const _iw = HexStone(HexSeat.ivory, PieceType.standing);
const _ic = HexStone(HexSeat.ivory, PieceType.capstone);
const _cc = HexStone(HexSeat.charcoal, PieceType.capstone);
const _uc = HexStone(HexSeat.copper, PieceType.capstone);

HexGame hexStudyPosition(Map<HexCell, List<HexStone>> board,
    {int radius = 2, HexSeat learner = HexSeat.ivory}) {
  final initial = HexGame.initial(radius: radius, starter: learner);
  final reserves = initial.reserves.toList();
  for (final entry in board.entries) {
    if (!entry.key.inside(radius)) {
      throw ArgumentError('Study cell outside Hex board');
    }
    for (final stone in entry.value) {
      final reserve = reserves[stone.seat.index];
      if (!reserve.has(stone.type)) {
        throw ArgumentError('Study exceeds Hex supply');
      }
      reserves[stone.seat.index] = reserve.use(stone.type);
    }
  }
  return initial.copyWith(board: board, reserves: reserves, ply: 3);
}

Study<HexGame> _study(
    int number,
    String title,
    Map<HexCell, List<HexStone>> board,
    String phase,
    String difficulty,
    int moves,
    List<String> hints,
    String explanation,
    {int radius = 2,
    HexSeat learner = HexSeat.ivory,
    int rotations = 0}) {
  for (var n = 0; n < rotations; n++) {
    board = {
      for (final entry in board.entries)
        HexCell(entry.key.s, entry.key.q): [
          for (final stone in entry.value) HexStone(stone.seat.next, stone.type)
        ]
    };
    learner = learner.next;
  }
  return Study(
      'hex_study_${number.toString().padLeft(2, '0')}',
      title,
      phase,
      difficulty,
      moves,
      hexStudyPosition(board, radius: radius, learner: learner),
      hints,
      explanation);
}

final hexStudies = <Study<HexGame>>[
  _study(
      1,
      'A winding route',
      {
        const HexCell(-2, 1): [_i],
        const HexCell(-1, 1): [_i],
        const HexCell(-1, 0): [_i, _i],
        const HexCell(0, 0): [_cu],
        const HexCell(1, -1): [_i],
        const HexCell(2, -1): [_i],
        const HexCell(0, -1): [_uw],
      },
      'Early play',
      'Easy',
      1,
      [
        'Trace Ivory’s q edges and look for captures that join the groups.',
        'One solution carries one east from (-1, 0) onto (0, 0).'
      ],
      'Capturing the center completes a bending road. Several legal spreads work; each is accepted.'),
  _study(
      2,
      'A guarded passage',
      {
        for (final r in [-2, -1, 1, 2]) HexCell(0, r): [_ch],
        const HexCell(0, 0): [_iw],
        const HexCell(1, -1): [_cc],
        const HexCell(1, 0): [_uw],
      },
      'Middle game',
      'Medium',
      1,
      [
        'Charcoal’s r edges are interrupted by a wall.',
        'Move the capstone southwest from (1, -1) onto (0, 0).'
      ],
      'The lone capstone crushes the central wall and joins Charcoal’s r-axis road.',
      learner: HexSeat.charcoal),
  _study(
      3,
      'Layers of copper',
      {
        for (final r in [-3, -2, 2, 3]) HexCell(0, r): [_cu],
        const HexCell(0, -1): [_i, _cu, _i, _cu, _uc],
        const HexCell(0, 0): [_ch],
        const HexCell(0, 1): [_iw],
      },
      'Middle game',
      'Hard',
      1,
      [
        'Copper connects s edges. Inspect the source after pickup.',
        'Carry three southeast from (0, -1), dropping 2 then 1.'
      ],
      'Copper remains at the source, covers the first cell and crushes the second with the final lone capstone.',
      radius: 3,
      learner: HexSeat.copper),
  _study(
      4,
      'Across the court',
      {
        for (final q in [-4, -3, 2, 3, 4]) HexCell(q, 0): [_i],
        const HexCell(-2, 0): [_ch, _i, _i, _cu, _i, _ic],
        const HexCell(-1, 0): [_cu],
        const HexCell(0, 0): [_ch],
        const HexCell(1, 0): [_uw],
      },
      'Middle game',
      'Hard',
      1,
      [
        'Every exposed top must remain Ivory, including the source.',
        'Carry four east from (-2, 0), dropping 1, 2, 1.'
      ],
      'Mixed layers force a precise distribution over three cells. Extra pickup exposes an enemy or abandons the endpoint.',
      radius: 4),
  _study(
      5,
      'After both opponents',
      {
        const HexCell(-2, 1): [_i],
        const HexCell(-1, 1): [_i],
        const HexCell(0, -1): [_i],
        for (final r in [-2, -1, 0]) HexCell(2, r): [_i],
        const HexCell(0, 2): [_cw],
        const HexCell(1, 1): [_uw],
      },
      'Early play',
      'Expert',
      2,
      [
        'Two opponents get a turn. Two threats may be insufficient.',
        'Connect the left group to the side arm; look for three finishing cells.'
      ],
      'The connecting move creates three independent finishes. Both opponents may defend, but a third finish survives.',
      rotations: 1),
  _study(
      6,
      'Three ways through',
      {
        for (final q in [-3, -2]) HexCell(q, 1): [_i],
        const HexCell(-1, 1): [_i, _ic],
        const HexCell(0, -1): [_i],
        const HexCell(0, 0): [_uw],
        for (final q in [2, 3])
          for (final r in [-2, -1, 0]) HexCell(q, r): [_i],
        const HexCell(0, 2): [_cw],
        const HexCell(1, 1): [_uw],
      },
      'Middle game',
      'Expert',
      2,
      [
        'Retain the left connection while opening three routes.',
        'Move only the capstone to the blocked central junction.'
      ],
      'Crushing the junction without emptying the source leaves three threats; every pair of opponent replies is included in the proof.',
      radius: 3,
      rotations: 2),
  _study(
      7,
      'One last distribution',
      {
        for (final cell in HexGame.initial(radius: 4).cells)
          if (!(cell.r == 0 && cell.q <= -1))
            cell: [
              cell.r == -cell.q && cell.q >= 2
                  ? _ch
                  : cell.r == 0 && cell.q >= 2
                      ? _cu
                      : HexStone(HexSeat.values[(cell.q - cell.r).abs() % 3],
                          PieceType.standing)
            ],
        const HexCell(-4, 0): [_ch, _i, _i, _i, _i],
      },
      'Endgame',
      'Expert',
      1,
      [
        'No road is needed if you fill the board with a winning flat count.',
        'Carry three east from (-4, 0), dropping 1, 1, 1.'
      ],
      'Ivory retains its source and finishes with four exposed flats against three each. Carrying four exposes Charcoal and loses.',
      radius: 4),
];
