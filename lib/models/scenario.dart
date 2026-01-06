import 'board.dart';
import 'game_state.dart';
import 'piece.dart';
import 'player.dart';
import '../services/ai/ai.dart';

/// Type of structured experience shown in the tutorial hub.
enum ScenarioType { tutorial, puzzle }

/// Difficulty level for puzzles.
enum PuzzleDifficulty { easy, medium, hard, expert }

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
  final PuzzleDifficulty? puzzleDifficulty;
  final String? hintText;
  final Duration? hintDelay;

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
    this.puzzleDifficulty,
    this.hintText,
    this.hintDelay,
  });
}

/// Type of action the user is being guided toward.
enum GuidedMoveType {
  placement,
  stackMove,
  anyPlacement,
  anyStackMove,
}

/// Structured hint for the exact move we expect during a scenario.
class GuidedMove {
  final GuidedMoveType type;

  /// For placement moves, the required destination (null for anyPlacement).
  final Position? target;

  /// For placement moves, the expected piece type (optional).
  final PieceType? pieceType;

  /// For stack moves, the origin position.
  final Position? from;

  /// For stack moves, the direction of travel (null for anyStackMove).
  final Direction? direction;

  /// For stack moves, the planned drop pattern.
  final List<int>? drops;

  /// Multiple valid target positions (for flexible solutions).
  final Set<Position>? allowedTargets;

  const GuidedMove.placement({required this.target, this.pieceType})
      : type = GuidedMoveType.placement,
        from = null,
        direction = null,
        drops = null,
        allowedTargets = null;

  const GuidedMove.stackMove({
    required this.from,
    required this.direction,
    required this.drops,
  })  : type = GuidedMoveType.stackMove,
        target = from,
        pieceType = null,
        allowedTargets = null;

  /// Allows placing a piece anywhere on the board.
  const GuidedMove.anyPlacement({this.pieceType})
      : type = GuidedMoveType.anyPlacement,
        target = null,
        from = null,
        direction = null,
        drops = null,
        allowedTargets = null;

  /// Allows moving a stack from a specific position in any direction.
  const GuidedMove.anyStackMove({required this.from})
      : type = GuidedMoveType.anyStackMove,
        target = from,
        pieceType = null,
        direction = null,
        drops = null,
        allowedTargets = null;

  /// Allows placement on any of the specified positions.
  const GuidedMove.multipleTargets({
    required this.allowedTargets,
    this.pieceType,
  })  : type = GuidedMoveType.placement,
        target = null,
        from = null,
        direction = null,
        drops = null;

  /// Cells to highlight so the user knows where to interact.
  Set<Position> highlightedCells(int boardSize) {
    if (type == GuidedMoveType.anyPlacement) {
      // Highlight all empty cells (handled by UI)
      return {};
    }

    if (type == GuidedMoveType.anyStackMove) {
      return {from!};
    }

    if (allowedTargets != null) {
      return allowedTargets!;
    }

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
  int? whiteFlatStones,
  int? whiteCapstones,
  int? blackFlatStones,
  int? blackCapstones,
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

  // Override piece counts if specified
  if (whiteFlatStones != null || whiteCapstones != null) {
    whitePieces = PlayerPieces(
      color: PlayerColor.white,
      flatStones: whiteFlatStones ?? whitePieces.flatStones,
      capstones: whiteCapstones ?? whitePieces.capstones,
    );
  }
  if (blackFlatStones != null || blackCapstones != null) {
    blackPieces = PlayerPieces(
      color: PlayerColor.black,
      flatStones: blackFlatStones ?? blackPieces.flatStones,
      capstones: blackCapstones ?? blackPieces.capstones,
    );
  }

  return GameState(
    board: board,
    currentPlayer: currentPlayer,
    whitePieces: whitePieces,
    blackPieces: blackPieces,
    turnNumber: turnNumber,
    phase: phase,
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

// ============================================================================
// TUTORIALS (9 total)
// ============================================================================

final _tutorial1BuildingRoad = GameScenario(
  id: 'tutorial_1',
  title: 'Building a Road',
  type: ScenarioType.tutorial,
  summary: 'Complete a road from top to bottom.',
  objective: 'Place a stone to complete the road.',
  dialogue: const [
    'Welcome to Tak! The goal is simple: build a road — a connected path of your flat stones linking opposite edges of the board.',
    'You have three stones already forming most of a vertical road. Place one more flat stone to connect the top and bottom edges.',
  ],
  guidedMove: const GuidedMove.placement(
    target: Position(3, 1),
    pieceType: PieceType.flat,
  ),
  completionText:
      'You built a road! Your stones form an unbroken path from one edge to the opposite edge. That\'s how you win at Tak.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 7,
    stacks: const [
      // White stones at rows 0, 1, 2 at col 1 - need row 3 to complete
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
      // Some black pieces elsewhere
      PositionedStack(
        position: Position(1, 2),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(2, 3),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(0, 3),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
    ],
  ),
  scriptedResponses: const [],
);

final _tutorial2StandingStones = GameScenario(
  id: 'tutorial_2',
  title: 'Standing Stones (Walls)',
  type: ScenarioType.tutorial,
  summary: 'Use a wall to block an opponent\'s road.',
  objective: 'Select the wall piece type, then place it to block Black.',
  dialogue: const [
    'Black is about to complete a road along the bottom edge!',
    'A standing stone (or "wall") blocks roads and movement — but doesn\'t count as part of YOUR road either.',
    'Use the piece selector on the side of the screen to choose "Wall", then place it to block Black\'s winning move.',
  ],
  guidedMove: const GuidedMove.placement(
    target: Position(3, 2),
    pieceType: PieceType.standing,
  ),
  completionText:
      'Your wall blocks their road! Walls are powerful blockers, but remember they can\'t be part of your road. Use them strategically.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 7,
    stacks: const [
      // White has some pieces
      PositionedStack(
        position: Position(0, 3),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      PositionedStack(
        position: Position(1, 2),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      PositionedStack(
        position: Position(2, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      // Black has road threat along bottom (row 3)
      PositionedStack(
        position: Position(3, 0),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(3, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(3, 3),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
    ],
  ),
  // Scripted response so tutorial doesn't use AI
  scriptedResponses: const [
    AIPlacementMove(Position(0, 0), PieceType.flat),
  ],
);

final _tutorial3Capstone = GameScenario(
  id: 'tutorial_3',
  title: 'The Capstone',
  type: ScenarioType.tutorial,
  summary: 'Use the Capstone to flatten a wall.',
  objective: 'Move the Capstone onto the wall to flatten it.',
  dialogue: const [
    'You\'re building a road, but a wall blocks your path!',
    'Regular flat stones can\'t go on top of walls. Enter the Capstone — your most powerful piece.',
    'The Capstone counts as part of roads, can flatten walls by moving onto them, and cannot be covered.',
    'Move your Capstone onto the wall to flatten it and complete your road.',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(2, 1),
    direction: Direction.right,
    drops: [1],
  ),
  completionText:
      'The wall is now flat — and your road is complete! The Capstone is essential for breaking through defenses.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 11,
    stacks: const [
      // White vertical road at column 2, missing row 2 (blocked by wall)
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
      // Black wall blocking the road at row 2
      PositionedStack(
        position: Position(2, 2),
        stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
      ),
      // White capstone on the side of the road, ready to flatten
      PositionedStack(
        position: Position(2, 1),
        stack: PieceStack([Piece(type: PieceType.capstone, color: PlayerColor.white)]),
      ),
      // Additional black pieces for realism
      PositionedStack(
        position: Position(1, 0),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(3, 4),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(0, 4),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(4, 0),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
    ],
  ),
  scriptedResponses: const [],
);

final _tutorial4MovingSinglePiece = GameScenario(
  id: 'tutorial_4',
  title: 'Moving a Single Piece',
  type: ScenarioType.tutorial,
  summary: 'Learn to move pieces on the board.',
  objective: 'Move your stone onto the adjacent black piece.',
  dialogue: const [
    'Instead of placing a new stone, you can move a piece you already control.',
    'Pieces move in a straight line: up, down, left, or right (not diagonally).',
    'You can move onto empty cells or onto other flat stones — creating a stack! Try moving onto the adjacent black piece.',
  ],
  guidedMove: const GuidedMove.anyStackMove(from: Position(1, 1)),
  completionText:
      'Pieces can move onto empty cells or onto other pieces (creating stacks). Moving lets you reposition without using new pieces from your supply.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 5,
    stacks: const [
      PositionedStack(
        position: Position(1, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      // Adjacent black piece - player can move onto it
      PositionedStack(
        position: Position(1, 2),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      // Additional pieces for realism
      PositionedStack(
        position: Position(3, 0),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(0, 3),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
    ],
  ),
  // Scripted response so tutorial doesn't use AI
  scriptedResponses: const [
    AIPlacementMove(Position(2, 2), PieceType.flat),
  ],
);

final _tutorial5StacksAndControl = GameScenario(
  id: 'tutorial_5',
  title: 'Stacks and Control',
  type: ScenarioType.tutorial,
  summary: 'Understand stack control.',
  objective: 'Move the stack to demonstrate control.',
  dialogue: const [
    'When pieces occupy the same cell, they form a stack.',
    'Here\'s the key rule: whoever has the top piece controls the stack.',
    'You have White on top, so you control this stack — even though there\'s a Black piece underneath.',
    'Select the stack and move it in any direction.',
  ],
  guidedMove: const GuidedMove.anyStackMove(from: Position(1, 1)),
  completionText:
      'The whole stack moved together! Controlling your opponent\'s pieces in stacks is a powerful tactic. Only the top piece determines the stack\'s color for roads.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 7,
    stacks: const [
      // 2-piece stack with White on top of Black
      PositionedStack(
        position: Position(1, 1),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
    ],
  ),
  // Scripted response so tutorial doesn't use AI
  scriptedResponses: const [
    AIPlacementMove(Position(0, 0), PieceType.flat),
  ],
);

final _tutorial6StackMovement = GameScenario(
  id: 'tutorial_6',
  title: 'Stack Movement & Carry Limit',
  type: ScenarioType.tutorial,
  summary: 'Learn about carry limits and dropping pieces.',
  objective: 'Spread the stack across the board.',
  dialogue: const [
    'When moving a stack, you can only pick up pieces equal to the board size. On a 5×5 board, you can carry up to 5 pieces.',
    'This stack has 6 pieces — more than the carry limit! Tap the stack to select it, then tap again to cycle how many to pick up.',
    'As you move, you must drop at least one piece per cell. Spread your pieces to claim territory!',
  ],
  guidedMove: const GuidedMove.anyStackMove(from: Position(2, 0)),
  completionText:
      'Excellent! You can only carry up to the board size (5 on a 5×5 board), even from taller stacks. Use this to spread influence across the board!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 13,
    stacks: const [
      // 6-piece stack (exceeds carry limit of 5) in corner
      PositionedStack(
        position: Position(2, 0),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      // Additional black pieces around the board for realism
      PositionedStack(
        position: Position(0, 3),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(1, 4),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(3, 2),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(4, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(4, 4),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
    ],
  ),
  // Scripted response so tutorial doesn't use AI
  scriptedResponses: const [
    AIPlacementMove(Position(0, 0), PieceType.flat),
  ],
);

final _tutorial7OpeningRule = GameScenario(
  id: 'tutorial_7',
  title: 'The Opening Rule',
  type: ScenarioType.tutorial,
  summary: 'Learn the special first-turn rule.',
  objective: 'Place a Black flat stone (your opponent\'s color).',
  dialogue: const [
    'There\'s one special rule: on the very first turn, each player places a piece of their opponent\'s color.',
    'This prevents a first-player advantage and creates interesting opening positions.',
    'You\'re White, going first. Place a Black flat stone anywhere.',
  ],
  guidedMove: const GuidedMove.anyPlacement(pieceType: PieceType.flat),
  completionText:
      'The opening rule is easy to forget! Some players place the opponent\'s piece in a corner (giving them little value), others place it centrally (creating interesting positions).',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 1, // First turn triggers opening rule
    phase: GamePhase.opening,
    stacks: const [],
  ),
  // Scripted response: Black places White's piece (opening rule)
  scriptedResponses: const [
    AIPlacementMove(Position(2, 2), PieceType.flat),
  ],
);

final _tutorial8FlatCount = GameScenario(
  id: 'tutorial_8',
  title: 'Winning by Flat Count',
  type: ScenarioType.tutorial,
  summary: 'Learn the alternative win condition.',
  objective: 'Place your last stone to fill the board and win!',
  dialogue: const [
    'Not every game ends with a road. When the board fills up or a player runs out of pieces, the game ends.',
    'If there\'s no road, the winner is whoever has more flat stones visible on top.',
    'Walls and Capstones don\'t count for flat count — only flat stones.',
    'The board has one empty space. Place your stone to end the game!',
  ],
  guidedMove: const GuidedMove.placement(
    target: Position(3, 3),
    pieceType: PieceType.flat,
  ),
  completionText:
      'You won by flat count! You had more flat stones showing on top. Walls block roads but hurt your flat count — use them wisely.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 29,
    whiteFlatStones: 1,
    blackFlatStones: 0,
    stacks: const [
      // Board almost full, no roads possible, White wins by flat count
      // Row 0: W B W B
      PositionedStack(position: Position(0, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(0, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(0, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(0, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      // Row 1: B W stack(B-W) W - white controls stack at (1,2)
      PositionedStack(position: Position(1, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(1, 2), stack: PieceStack([
        Piece(type: PieceType.flat, color: PlayerColor.black),
        Piece(type: PieceType.flat, color: PlayerColor.white),
      ])),
      PositionedStack(position: Position(1, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Row 2: W stack(W-B-W) W B - white controls stack at (2,1)
      PositionedStack(position: Position(2, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 1), stack: PieceStack([
        Piece(type: PieceType.flat, color: PlayerColor.white),
        Piece(type: PieceType.flat, color: PlayerColor.black),
        Piece(type: PieceType.flat, color: PlayerColor.white),
      ])),
      PositionedStack(position: Position(2, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      // Row 3: B W B (empty at col 3)
      PositionedStack(position: Position(3, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(3, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  scriptedResponses: const [],
);

final _tutorial9PieceSupply = GameScenario(
  id: 'tutorial_9',
  title: 'Running Out of Pieces',
  type: ScenarioType.tutorial,
  summary: 'Manage your limited piece supply.',
  objective: 'Place your last piece to end the game.',
  dialogue: const [
    'Each player has a limited supply of pieces — the number depends on board size.',
    'The game ends immediately when either player places their last piece.',
    'You have only 1 piece left! Place it to end the game. If there\'s no road, highest flat count wins.',
  ],
  guidedMove: const GuidedMove.anyPlacement(pieceType: PieceType.flat),
  completionText:
      'When pieces run low, every placement matters. Sometimes it\'s better to move existing pieces rather than place new ones. Watch your supply — and your opponent\'s!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 27,
    // White has 1 piece left (placed 14 of 15)
    whiteFlatStones: 1,
    whiteCapstones: 0,
    // Black has 2 pieces left (placed 13 of 15)
    blackFlatStones: 2,
    blackCapstones: 0,
    stacks: const [
      // Scattered pieces arranged to prevent any road wins
      // Row 0: W stack(W) B empty - broken by black at (0,2)
      PositionedStack(position: Position(0, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Stack with white on top of black pieces at (0,1)
      PositionedStack(
        position: Position(0, 1),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      PositionedStack(position: Position(0, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      // (0,3) empty
      // Row 1: B W B W - alternating, no road
      PositionedStack(position: Position(1, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(1, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Row 2: W stack(B) W B - alternating, no road
      PositionedStack(position: Position(2, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Stack with black on top at (2,1)
      PositionedStack(
        position: Position(2, 1),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.black),
        ]),
      ),
      PositionedStack(position: Position(2, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      // Row 3: B W empty W - broken by black at (3,0)
      PositionedStack(position: Position(3, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // (3,2) empty
      PositionedStack(position: Position(3, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
    ],
  ),
  scriptedResponses: const [],
);

// ============================================================================
// PUZZLES (4 total)
// ============================================================================

final _puzzle6CaptureAndWin = GameScenario(
  id: 'puzzle_6',
  title: 'Capture and Win',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.hard,
  summary: 'Capture a stack to complete your road!',
  objective: 'Win in 1 move. Capture the enemy stack to complete your road!',
  dialogue: const [
    'White to move.',
    'Black controls a key stack blocking your road.',
    'Capture it to claim victory!',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(2, 0),
    direction: Direction.right,
    drops: [1],
  ),
  completionText:
      'Capturing stacks turns enemy pieces into your road. Control is everything in Tak!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 19,
    stacks: const [
      // White stack at (2,0) to capture with
      PositionedStack(
        position: Position(2, 0),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      // Black-controlled stack at (2,1) - capturing completes the road
      PositionedStack(
        position: Position(2, 1),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.black),
        ]),
      ),
      // Row 2: after capture will be complete!
      PositionedStack(position: Position(2, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Black pieces for realistic board state
      PositionedStack(position: Position(0, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(0, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(4, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(4, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  // Capture completes row 2: W(2,0) W(2,1) W(2,2) W(2,3) W(2,4) = WIN!
  scriptedResponses: const [],
);

final _puzzle7TheSpread = GameScenario(
  id: 'puzzle_7',
  title: 'The Spread',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.hard,
  summary: 'Spread your stack to complete your road!',
  objective: 'Win in 1 move. Spread over the enemy pieces to complete your road!',
  dialogue: const [
    'White to move.',
    'Black pieces block your path, but your tall stack can cover them.',
    'Spread to complete your road and claim victory!',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(2, 0),
    direction: Direction.right,
    drops: [1, 1, 1],
  ),
  completionText:
      'Spreading over enemy pieces converts them to your road. A powerful finishing move!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 21,
    stacks: const [
      // White tall stack at (2,0) - spread completes road
      PositionedStack(
        position: Position(2, 0),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      // Black pieces in the way - will be covered by spread
      PositionedStack(position: Position(2, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(2, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(2, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      // White piece at end - spread will complete the road!
      PositionedStack(position: Position(2, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Black pieces for realistic board state
      PositionedStack(position: Position(0, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(0, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(4, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(4, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  // Spread [1,1,1] covers (2,1), (2,2), (2,3) - all become white-controlled
  // Row 2: W(2,0) W(2,1) W(2,2) W(2,3) W(2,4) = WIN!
  scriptedResponses: const [],
);

final _puzzle9CapstoneTactics = GameScenario(
  id: 'puzzle_9',
  title: 'Capstone Tactics',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.hard,
  summary: 'Use your Capstone to flatten and win!',
  objective: 'Win in 1 move. Flatten the wall to complete your road!',
  dialogue: const [
    'White to move.',
    'A wall blocks your road, but your Capstone can flatten it.',
    'Use the Capstone\'s unique power to claim victory!',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(2, 0),
    direction: Direction.right,
    drops: [1],
  ),
  completionText:
      'The Capstone flattens walls that would stop any other piece. Master this technique!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 19,
    stacks: const [
      // White road at row 2 blocked by wall - capstone will flatten and complete
      PositionedStack(position: Position(2, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Black wall blocking the road
      PositionedStack(position: Position(2, 1), stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)])),
      // Capstone on flat - will flatten wall and complete road
      PositionedStack(
        position: Position(2, 0),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.capstone, color: PlayerColor.white),
        ]),
      ),
      // Black pieces for realistic board state
      PositionedStack(position: Position(0, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(0, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(4, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(4, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  // Capstone flattens wall at (2,1), leaves flat at (2,0)
  // Row 2: W(2,0) C+flattened(2,1) W(2,2) W(2,3) W(2,4) = WIN!
  scriptedResponses: const [],
);

final _puzzle10GrandCombination = GameScenario(
  id: 'puzzle_10',
  title: 'The Grand Combination',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.expert,
  summary: 'Create a fork Black cannot escape!',
  objective: 'Win in 2 moves. Create a double threat!',
  dialogue: const [
    'White to move.',
    'You have two partial roads. Find the move that threatens both!',
    'Black can only block one threat — then strike the other!',
  ],
  guidedMove: const GuidedMove.placement(
    target: Position(2, 2),
    pieceType: PieceType.flat,
  ),
  completionText:
      'The fork is the most powerful tactic — threaten two roads, win with one!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 21,
    stacks: const [
      // Row 2 partial: W _ W W W (needs 2,1 to complete)
      PositionedStack(position: Position(2, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Col 2 partial: W W _ W W (needs 2,2 AND 3,2 - after placing at 2,2, needs 3,2)
      PositionedStack(position: Position(0, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(1, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(4, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Black pieces for realistic board state
      PositionedStack(position: Position(0, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(0, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(4, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(4, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  // Move 1: White plays (2,2) - creates FORK:
  //   Row 2: W(2,0) _(2,1) W(2,2) W(2,3) W(2,4) - needs (2,1) = TAK!
  //   Col 2: W(0,2) W(1,2) W(2,2) _(3,2) W(4,2) - needs (3,2) = TAK!
  // Black blocks row 2 at (2,1) with wall
  // Move 2: White plays (3,2) - completes col 2 = WIN!
  scriptedResponses: const [
    AIPlacementMove(Position(2, 1), PieceType.standing),
  ],
);

// ============================================================================
// LIBRARY EXPORT
// ============================================================================

/// Library of scenarios shown in the tutorial/puzzle selector.
final List<GameScenario> tutorialAndPuzzleLibrary = [
  // Tutorials (9)
  _tutorial1BuildingRoad,
  _tutorial2StandingStones,
  _tutorial3Capstone,
  _tutorial4MovingSinglePiece,
  _tutorial5StacksAndControl,
  _tutorial6StackMovement,
  _tutorial7OpeningRule,
  _tutorial8FlatCount,
  _tutorial9PieceSupply,
  // Puzzles (4)
  _puzzle6CaptureAndWin,
  _puzzle7TheSpread,
  _puzzle9CapstoneTactics,
  _puzzle10GrandCombination,
];
