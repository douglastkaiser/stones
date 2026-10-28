import 'board_geometry.dart';
import 'match_config.dart';
import 'match_state.dart';

/// Search-local immutable position. The canonical rules still transform every
/// move; unchanged immutable stacks need neither copying nor revalidation.
/// Normal application positions and saved engines retain MatchState.copyWith.
class AiDuelPosition implements MatchState {
  AiDuelPosition._(
      MatchState source, this._board, this._reserves, this._ply, this._result)
      : config = source.config,
        geometry = source.geometry;

  @override
  final MatchConfig config;
  @override
  final BoardGeometry geometry;
  @override
  SeatId get current => config.turnAt(ply);
  @override
  bool get opening => ply < config.seats.length;
  @override
  bool get finished => result != null;
  @override
  List<Stone> stackAt(Cell cell) => board[cell] ?? const [];
  @override
  Stone? topAt(Cell cell) => board[cell]?.last;

  factory AiDuelPosition.from(MatchState source) => source is AiDuelPosition
      ? source
      : AiDuelPosition._(
          source, source.board, source.reserves, source.ply, source.result);

  @override
  Map<Cell, List<Stone>> get board => _board;
  final Map<Cell, List<Stone>> _board;
  @override
  Map<SeatId, Reserve> get reserves => _reserves;
  final Map<SeatId, Reserve> _reserves;
  @override
  int get ply => _ply;
  final int _ply;
  @override
  MatchResult? get result => _result;
  final MatchResult? _result;

  @override
  AiDuelPosition copyWith({
    Map<Cell, List<Stone>>? board,
    Map<SeatId, Reserve>? reserves,
    int? ply,
    MatchResult? result,
  }) {
    final nextPly = ply ?? this.ply;
    final nextResult = result ?? this.result;
    final nextReserves = reserves ?? this.reserves;
    if (nextPly < 0 ||
        (reserves != null &&
            (reserves.length != config.seats.length ||
                config.ids.any((id) => !reserves.containsKey(id)) ||
                reserves.values.any((r) => r.stones < 0 || r.caps < 0))) ||
        (nextResult?.winner != null &&
            !nextReserves.containsKey(nextResult!.winner))) {
      throw ArgumentError('Invalid match position');
    }
    final nextBoard = board == null
        ? this.board
        : Map<Cell, List<Stone>>.unmodifiable(board.map((cell, stack) {
            if (identical(stack, this.board[cell])) {
              return MapEntry(cell, stack);
            }
            if (!geometry.contains(cell) ||
                stack.isEmpty ||
                stack.any((s) => !nextReserves.containsKey(s.seat))) {
              throw ArgumentError('Invalid match position');
            }
            return MapEntry(cell, List<Stone>.unmodifiable(stack));
          }));
    return AiDuelPosition._(
        this,
        nextBoard,
        reserves == null ? this.reserves : Map.unmodifiable(reserves),
        nextPly,
        nextResult);
  }
}
