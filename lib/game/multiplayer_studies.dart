import '../models/piece.dart';
import 'board_geometry.dart';
import 'match_config.dart';
import 'match_state.dart';
import 'match_study.dart';

/// These positions have exhaustive one-move certificates in the model tests.
/// Seat count and size are part of each study's stable identity.
final multiplayerStudies = <MatchStudy>[
  for (final shape in BoardShape.values)
    for (final count in [3, 4])
      for (final size in shape == BoardShape.square ? [5, 6] : [2, 3])
        _capDelivery(shape, count, size),
];

MatchStudy _capDelivery(BoardShape shape, int count, int size) {
  final config = MatchConfig(
      shape: shape,
      size: size,
      seats: SeatId.values.take(count).map(SeatConfig.new).toList());
  final initial = MatchState.initial(config);
  final y = shape == BoardShape.square ? 1 : 0;
  final gap = shape == BoardShape.square ? 1 : 0;
  final board = <Cell, List<Stone>>{
    for (var x = shape == BoardShape.square ? 0 : -size;
        x <= (shape == BoardShape.square ? size - 1 : size);
        x++)
      Cell(x, y): [
        Stone(x == gap ? SeatId.charcoal : SeatId.ivory,
            x == gap ? PieceType.standing : PieceType.flat)
      ],
    Cell(gap, y + 2): [
      Stone(SeatId.values[count - 1], PieceType.flat),
      const Stone(SeatId.ivory, PieceType.capstone),
    ],
  };
  final reserves = {
    for (final id in config.ids)
      id: Reserve(
          initial.reserves[id]!.stones -
              board.values
                  .expand((s) => s)
                  .where((p) => p.seat == id && p.type != PieceType.capstone)
                  .length,
          initial.reserves[id]!.caps -
              board.values
                  .expand((s) => s)
                  .where((p) => p.seat == id && p.type == PieceType.capstone)
                  .length),
  };
  final game = initial.copyWith(board: board, reserves: reserves, ply: count);
  return MatchStudy(
    id: 'unified_v1_${shape.name}_${count}_${size}_cap_delivery',
    title: '$count players: deliver the capstone',
    goal:
        'Ivory to play. Win in one move. The wall blocks the road and your capstone is two cells away.',
    initial: game,
    puzzle: true,
    moveLimit: 1,
    accepts: (move, step) => true,
    replies: (move) => const [],
    prerequisites: ['unified_v1_${shape.name}_exchange_$count'],
    hints: [
      'You cannot jump the empty cell between your stack and the wall.',
      'Carry both pieces. Drop the bottom piece on the empty cell; leave only the capstone for the wall.',
    ],
    explanation:
        'Spreading preserves bottom-to-top order. The buried rival stone goes first; the lone capstone flattens the wall on the final drop and joins Ivory’s road.',
  );
}
