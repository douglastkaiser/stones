import '../models/board.dart';
import '../models/game_state.dart';
import '../models/piece.dart';
import 'study.dart';

const _w = Piece(color: PlayerColor.white, type: PieceType.flat);
const _b = Piece(color: PlayerColor.black, type: PieceType.flat);
const _ww = Piece(color: PlayerColor.white, type: PieceType.standing);
const _bw = Piece(color: PlayerColor.black, type: PieceType.standing);
const _cap = Piece(color: PlayerColor.white, type: PieceType.capstone);

GameState squareStudyPosition(int size, Map<Position, List<Piece>> stacks,
    {PlayerColor learner = PlayerColor.white}) {
  var state = GameState.initial(size);
  for (final entry in stacks.entries) {
    if (!state.board.allPositions.contains(entry.key)) {
      throw ArgumentError('Study cell outside board');
    }
    state = state.copyWith(
        board: state.board.setStack(entry.key, PieceStack(entry.value)));
    for (final piece in entry.value) {
      final reserve = state.piecesFor(piece.color);
      state = state.updatePieces(
          piece.color,
          reserve.copyWith(
            flatStones:
                reserve.flatStones - (piece.type == PieceType.capstone ? 0 : 1),
            capstones:
                reserve.capstones - (piece.type == PieceType.capstone ? 1 : 0),
          ));
    }
  }
  for (final color in PlayerColor.values) {
    final reserve = state.piecesFor(color);
    if (reserve.flatStones < 0 || reserve.capstones < 0) {
      throw ArgumentError('Study exceeds supply');
    }
  }
  return state.copyWith(
      currentPlayer: learner, phase: GamePhase.playing, turnNumber: 8);
}

Study<GameState> _study(
        int number,
        String title,
        int size,
        Map<Position, List<Piece>> board,
        String phase,
        String difficulty,
        int moves,
        List<String> hints,
        String explanation,
        {PlayerColor learner = PlayerColor.white}) =>
    Study(
        'square_study_${number.toString().padLeft(2, '0')}',
        title,
        phase,
        difficulty,
        moves,
        squareStudyPosition(size, board, learner: learner),
        hints,
        explanation);

final squareStudies = <Study<GameState>>[
  _study(
      1,
      'A short connection',
      3,
      {
        const Position(0, 0): [_w],
        const Position(1, 0): [_w],
        const Position(0, 1): [_b],
        const Position(2, 2): [_b],
      },
      'Early play',
      'Easy',
      1,
      [
        'Trace both pairs of opposite edges.',
        'A flat at a1 completes the left column.'
      ],
      'Two existing flats and a third on a1 make a road. Walls cannot complete it.'),
  _study(
      2,
      'Around the corner',
      4,
      {
        const Position(2, 0): [_w, _w],
        const Position(2, 1): [_b],
        for (final c in [1, 2, 3]) Position(1, c): [_w],
        const Position(1, 0): [_bw],
      },
      'Middle game',
      'Easy',
      1,
      [
        'A road can bend. Count what remains under a carried stone.',
        'Carry one from a2 to b2, leaving White on a2.'
      ],
      'Capturing b2 joins the left edge through b3 to the right edge. Carrying both empties the left endpoint.'),
  _study(
      3,
      'The buried connection',
      5,
      {
        const Position(2, 0): [_b, _w, _b, _w, _cap],
        const Position(2, 1): [_b],
        const Position(2, 2): [_bw],
        const Position(2, 3): [_w],
        const Position(2, 4): [_w],
      },
      'Middle game',
      'Medium',
      1,
      [
        'Check the exposed color after each possible pickup.',
        'Carry three east from a3, dropping 2 then 1.'
      ],
      'Leaving White at a3, covering b3 with White and crushing c3 completes the road. Bottom-first drops matter.'),
  _study(
      4,
      'A move before the win',
      3,
      {
        const Position(0, 0): [_w],
        const Position(1, 1): [_w],
        const Position(0, 2): [_b],
      },
      'Early play',
      'Medium',
      2,
      [
        'Create two independent finishing moves.',
        'A flat at a2 threatens a1 and c2.'
      ],
      'Black can stop one road, but cannot stop both a1 and c2 on the same turn.'),
  _study(
      5,
      'Four in hand',
      6,
      {
        const Position(3, 0): [_b, _w, _w, _b, _w, _cap],
        const Position(3, 1): [_b],
        const Position(3, 2): [_b],
        const Position(3, 3): [_bw],
        const Position(3, 4): [_w],
        const Position(3, 5): [_w],
      },
      'Middle game',
      'Hard',
      1,
      [
        'Keep control of the source and every traversed cell.',
        'Carry four east from a3; drop 1, 2, 1.'
      ],
      'The first friendly flat, then an enemy under a friendly flat, then the capstone preserve a continuous road.'),
  _study(
      6,
      'Two directions',
      4,
      {
        const Position(1, 0): [_w, _w],
        const Position(1, 1): [_b],
        const Position(1, 3): [_w],
        const Position(0, 1): [_w],
        const Position(2, 1): [_w],
        const Position(0, 3): [_bw],
      },
      'Middle game',
      'Hard',
      2,
      [
        'A capture can create both a horizontal and vertical threat.',
        'Move one from a3 onto b3.'
      ],
      'Preserving a3 while capturing b3 threatens c3 and b1. A wall can defend one axis, not both.'),
  _study(
      7,
      'Both roads',
      4,
      {
        const Position(3, 1): [_w, _w, _b],
        const Position(0, 1): [_w],
        for (final c in [0, 2, 3]) Position(0, c): [_b],
        for (final c in [0, 2, 3]) Position(1, c): [_w],
      },
      'Middle game',
      'Hard',
      1,
      [
        'You are Black. An opponent road need not invalidate your move.',
        'Carry all three from b1 north, dropping 1 on each cell.'
      ],
      'Both colors complete roads. Black made the move, so Black wins under the simultaneous-road rule.',
      learner: PlayerColor.black),
  _study(
      8,
      'Through resistance',
      5,
      {
        const Position(1, 0): [_w, _cap],
        const Position(1, 1): [_bw],
        for (final c in [3, 4]) Position(1, c): [_w],
        for (final r in [0, 2, 3]) Position(r, 1): [_w],
        const Position(0, 3): [_bw],
      },
      'Middle game',
      'Expert',
      2,
      [
        'Open the crossing without losing the left edge.',
        'Carry only the capstone from a4 to b4.'
      ],
      'Crushing the crossing preserves a4 and creates threats at c4 and b1. Covering an endpoint stops only one.'),
  _study(
      9,
      'A wider crossing',
      7,
      {
        const Position(3, 0): [_w, _cap],
        const Position(3, 1): [_bw],
        for (final c in [3, 4, 5, 6]) Position(3, c): [_w],
        for (final r in [0, 1, 2, 4, 5]) Position(r, 1): [_w],
        const Position(2, 4): [_bw],
      },
      'Middle game',
      'Expert',
      2,
      [
        'Extra capstones change the defenses; retain two threats.',
        'Move the capstone from a4 onto b4.'
      ],
      'The crossing threatens c4 and b1 even with two capstones per side. An endpoint capture cannot break both axes.'),
  _study(
      10,
      'The final count',
      8,
      {
        for (var r = 0; r < 8; r++)
          for (var c = 0; c < 8; c++)
            if (!(r == 0 && c < 4))
              Position(r, c): [
                r == 4 && [2, 4, 6].contains(c)
                    ? _b
                    : (r + c).isEven
                        ? _ww
                        : _bw
              ],
        const Position(0, 0): [_b, _w, _w, _w, _w],
      },
      'Endgame',
      'Expert',
      1,
      [
        'A full board ends the game. Count exposed flats, including the source.',
        'Carry three east from a8, dropping 1, 1, 1.'
      ],
      'White keeps a8 and fills three holes: four White flats against three Black. Carrying four exposes Black and loses.'),
];
