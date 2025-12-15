import 'board.dart';
import 'game_state.dart';
import 'piece.dart';
import 'player.dart';
import '../services/ai/ai.dart';

/// Type of structured experience shown in the tutorial hub.
enum ScenarioType { tutorial, puzzle }

/// Describes a prebuilt scenario for tutorials or puzzles.
class GameScenario {
  final String id;
  final String title;
  final ScenarioType type;
  final String summary;
  final String objective;
  final List<String> dialogue;
  final GuidedMove guidedMove;
  final GameState Function() buildInitialState;
  final List<AIMove> scriptedResponses;
  final String completionText;
  final AIDifficulty aiDifficulty;

  const GameScenario({
    required this.id,
    required this.title,
    required this.type,
    required this.summary,
    required this.objective,
    required this.dialogue,
    required this.guidedMove,
    required this.buildInitialState,
    required this.scriptedResponses,
    required this.completionText,
    this.aiDifficulty = AIDifficulty.easy,
  });
}

/// Type of action the user is being guided toward.
enum GuidedMoveType { placement, stackMove }

/// Structured hint for the exact move we expect during a scenario.
class GuidedMove {
  final GuidedMoveType type;

  /// For placement moves, the required destination.
  final Position? target;

  /// For placement moves, the expected piece type (optional).
  final PieceType? pieceType;

  /// For stack moves, the origin position.
  final Position? from;

  /// For stack moves, the direction of travel.
  final Direction? direction;

  /// For stack moves, the planned drop pattern.
  final List<int>? drops;

  const GuidedMove.placement({required this.target, this.pieceType})
      : type = GuidedMoveType.placement,
        from = null,
        direction = null,
        drops = null;

  const GuidedMove.stackMove({
    required this.from,
    required this.direction,
    required this.drops,
  })  : type = GuidedMoveType.stackMove,
        target = from,
        pieceType = null;

  /// Cells to highlight so the user knows where to interact.
  Set<Position> highlightedCells(int boardSize) {
    if (type == GuidedMoveType.placement) {
      return {target!};
    }

    final start = from!;
    final dir = direction!;
    final steps = drops?.length ?? 0;
    final highlights = <Position>{start};
    var current = start;
    for (var i = 0; i < steps; i++) {
      current = dir.apply(current);
      if (current.row < 0 ||
          current.col < 0 ||
          current.row >= boardSize ||
          current.col >= boardSize) {
        break;
      }
      highlights.add(current);
    }
    return highlights;
  }
}

/// Stack placed at a concrete position for a scenario setup.
class PositionedStack {
  final Position position;
  final PieceStack stack;

  const PositionedStack({required this.position, required this.stack});
}

GameState _buildScenarioState({
  required int boardSize,
  required List<PositionedStack> stacks,
  required PlayerColor currentPlayer,
  int turnNumber = 4,
  GamePhase phase = GamePhase.playing,
}) {
  var board = Board.empty(boardSize);
  var whitePieces = PlayerPieces.initial(PlayerColor.white, boardSize);
  var blackPieces = PlayerPieces.initial(PlayerColor.black, boardSize);

  for (final entry in stacks) {
    board = board.setStack(entry.position, entry.stack);
    for (final piece in entry.stack.pieces) {
      if (piece.color == PlayerColor.white) {
        whitePieces = _consumePiece(whitePieces, piece.type);
      } else {
        blackPieces = _consumePiece(blackPieces, piece.type);
      }
    }
  }

  return GameState(
    board: board,
    currentPlayer: currentPlayer,
    whitePieces: whitePieces,
    blackPieces: blackPieces,
    turnNumber: turnNumber,
    phase: phase,
    result: null,
    winReason: null,
  );
}

PlayerPieces _consumePiece(PlayerPieces pieces, PieceType type) {
  switch (type) {
    case PieceType.flat || PieceType.standing:
      return pieces.copyWith(flatStones: pieces.flatStones - 1);
    case PieceType.capstone:
      return pieces.copyWith(capstones: pieces.capstones - 1);
  }
}

/// Library of scenarios shown in the tutorial/puzzle selector.
final List<GameScenario> tutorialAndPuzzleLibrary = [
  GameScenario(
    id: 'tutorial_1',
    title: 'Tutorial 1',
    type: ScenarioType.tutorial,
    summary: 'Finish the open road with one flat.',
    objective: 'Tap the highlighted square to drop a flat and claim the row.',
    dialogue: const [
      'You are White. The center road is almost done.',
      'Place a single flat on the glowing cell to connect your line.',
    ],
    guidedMove: const GuidedMove.placement(
      target: Position(2, 2),
      pieceType: PieceType.flat,
    ),
    completionText:
        'That one flat closes the lane and instantly finishes the road. Look for short gaps like this.',
    buildInitialState: () => _buildScenarioState(
      boardSize: 5,
      currentPlayer: PlayerColor.white,
      turnNumber: 8,
      stacks: const [
        PositionedStack(
          position: Position(2, 0),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(2, 1),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(2, 3),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(2, 4),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(1, 1),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
      ],
    ),
    scriptedResponses: const [],
  ),
  GameScenario(
    id: 'tutorial_2',
    title: 'Tutorial 2',
    type: ScenarioType.tutorial,
    summary: 'Slide your capstone to crush a wall.',
    objective: 'Move from c3 to the glowing square to flatten the standing stone.',
    dialogue: const [
      'Capstones clear walls. Use yours to reopen the lane.',
      'Pick up the capstone and slide it onto the highlighted space.',
    ],
    guidedMove: const GuidedMove.stackMove(
      from: Position(2, 1),
      direction: Direction.right,
      drops: [1],
    ),
    completionText:
        'Crushing the wall reclaims the file and keeps your capstone on top to hold the road.',
    buildInitialState: () => _buildScenarioState(
      boardSize: 5,
      currentPlayer: PlayerColor.white,
      turnNumber: 10,
      stacks: const [
        PositionedStack(
          position: Position(2, 1),
          stack: PieceStack([Piece(type: PieceType.capstone, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(2, 2),
          stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(0, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(1, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(3, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(4, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(1, 3),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
      ],
    ),
    scriptedResponses: const [],
  ),
  GameScenario(
    id: 'tutorial_3',
    title: 'Tutorial 3',
    type: ScenarioType.tutorial,
    summary: 'Spread a tall stack cleanly.',
    objective: 'Drag the highlighted stack left, dropping as you go.',
    dialogue: const [
      'Tall stacks can cover multiple cells in one motion.',
      'Split this stack to hold the center and left lane at the same time.',
    ],
    guidedMove: const GuidedMove.stackMove(
      from: Position(2, 3),
      direction: Direction.left,
      drops: [1, 1],
    ),
    completionText:
        'Dropping pieces along the path leaves anchors behind and keeps pressure on two fronts.',
    buildInitialState: () => _buildScenarioState(
      boardSize: 5,
      currentPlayer: PlayerColor.white,
      turnNumber: 12,
      stacks: const [
        PositionedStack(
          position: Position(2, 3),
          stack: PieceStack([
            Piece(type: PieceType.flat, color: PlayerColor.white),
            Piece(type: PieceType.flat, color: PlayerColor.white),
          ]),
        ),
        PositionedStack(
          position: Position(2, 0),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(2, 4),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(1, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(3, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(1, 4),
          stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
        ),
      ],
    ),
    scriptedResponses: const [],
  ),
  GameScenario(
    id: 'puzzle_1',
    title: 'Puzzle 1',
    type: ScenarioType.puzzle,
    summary: 'White to move – finish the column.',
    objective: 'Place the flat on the glowing square to score Tak.',
    dialogue: const [
      'Your vertical road is one cell short.',
      'Fill the gap to connect top to bottom immediately.',
    ],
    guidedMove: const GuidedMove.placement(
      target: Position(3, 1),
      pieceType: PieceType.flat,
    ),
    completionText:
        'Dropping the flat closes the only gap and ends the game on the spot.',
    buildInitialState: () => _buildScenarioState(
      boardSize: 5,
      currentPlayer: PlayerColor.white,
      turnNumber: 12,
      stacks: const [
        PositionedStack(
          position: Position(0, 1),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(1, 1),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(2, 1),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(4, 1),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(2, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(1, 3),
          stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
        ),
      ],
    ),
    scriptedResponses: const [],
  ),
  GameScenario(
    id: 'puzzle_2',
    title: 'Puzzle 2',
    type: ScenarioType.puzzle,
    summary: 'Smash the block and keep moving.',
    objective: 'Slide the capstone down to break Black\'s wall.',
    dialogue: const [
      'Black dropped a wall in your road.',
      'Use the capstone above it to punch through.',
    ],
    guidedMove: const GuidedMove.stackMove(
      from: Position(2, 1),
      direction: Direction.down,
      drops: [1],
    ),
    completionText:
        'The wall is gone and the capstone now anchors the row for Tak.',
    buildInitialState: () => _buildScenarioState(
      boardSize: 5,
      currentPlayer: PlayerColor.white,
      turnNumber: 14,
      stacks: const [
        PositionedStack(
          position: Position(2, 1),
          stack: PieceStack([Piece(type: PieceType.capstone, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(3, 1),
          stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(3, 0),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(3, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(3, 3),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(3, 4),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(0, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
      ],
    ),
    scriptedResponses: const [],
  ),
  GameScenario(
    id: 'puzzle_3',
    title: 'Puzzle 3',
    type: ScenarioType.puzzle,
    summary: 'Split a tower to make dual threats.',
    objective: 'Drag the tall stack onto the glowing squares in one sweep.',
    dialogue: const [
      'White controls the center tower.',
      'Spread it left to cover two lanes at once.',
    ],
    guidedMove: const GuidedMove.stackMove(
      from: Position(1, 3),
      direction: Direction.left,
      drops: [1, 1, 1],
    ),
    completionText:
        'Leaving stones behind turns one tower into multiple anchors and forces tough answers.',
    buildInitialState: () => _buildScenarioState(
      boardSize: 5,
      currentPlayer: PlayerColor.white,
      turnNumber: 16,
      stacks: const [
        PositionedStack(
          position: Position(1, 3),
          stack: PieceStack([
            Piece(type: PieceType.flat, color: PlayerColor.white),
            Piece(type: PieceType.flat, color: PlayerColor.white),
            Piece(type: PieceType.flat, color: PlayerColor.white),
          ]),
        ),
        PositionedStack(
          position: Position(1, 0),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(1, 4),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(2, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(0, 3),
          stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(2, 3),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
      ],
    ),
    scriptedResponses: const [],
  ),
];
