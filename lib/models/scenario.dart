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
// TUTORIALS (11 total)
// ============================================================================

final _tutorial1PlacingStones = GameScenario(
  id: 'tutorial_1',
  title: 'Placing Stones',
  type: ScenarioType.tutorial,
  summary: 'Learn to place your first flat stone.',
  objective: 'Tap any empty cell to place a flat stone.',
  dialogue: const [
    'Welcome to Tak! The goal is simple: build a road — a connected path of your stones linking opposite edges of the board.',
    'Let\'s start by placing a stone. Tap any empty cell to place a flat stone.',
  ],
  guidedMove: const GuidedMove.anyPlacement(pieceType: PieceType.flat),
  completionText:
      'That\'s a flat stone. Flat stones are the building blocks of your road. They lie flat on the board and can be part of your winning path. In a real game, you and your opponent take turns placing or moving pieces.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 3,
    stacks: const [],
  ),
  scriptedResponses: const [],
);

final _tutorial2BuildingRoad = GameScenario(
  id: 'tutorial_2',
  title: 'Building a Road',
  type: ScenarioType.tutorial,
  summary: 'Complete a road from top to bottom.',
  objective: 'Place stones to complete a vertical road reaching both edges.',
  dialogue: const [
    'A road connects two opposite edges of the board — top to bottom, or left to right.',
    'You have two stones already. Complete the road by connecting to both the top and bottom edges.',
  ],
  hintText: 'Place stones above and below your existing pieces to reach both edges.',
  hintDelay: const Duration(seconds: 10),
  guidedMove: GuidedMove.multipleTargets(
    allowedTargets: {const Position(0, 1), const Position(3, 1)},
    pieceType: PieceType.flat,
  ),
  completionText:
      'You built a road! Your stones form an unbroken path from one edge to the opposite edge. That\'s how you win at Tak.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 5,
    stacks: const [
      // White stones at rows 1 and 2, col 1 (0-indexed: rows 1-2, col 1)
      PositionedStack(
        position: Position(1, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      PositionedStack(
        position: Position(2, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
    ],
  ),
  scriptedResponses: const [],
);

final _tutorial3TurnsTaking = GameScenario(
  id: 'tutorial_3',
  title: 'Your Turn, Their Turn',
  type: ScenarioType.tutorial,
  summary: 'Learn about alternating turns and blocking.',
  objective: 'Place a stone, then respond to Black\'s threat.',
  dialogue: const [
    'Tak is a two-player game. You and your opponent alternate turns.',
    'Your opponent (Black) is also trying to build a road. Sometimes you need to block their plans while building your own.',
    'It\'s your turn. Place a stone.',
  ],
  guidedMove: const GuidedMove.anyPlacement(pieceType: PieceType.flat),
  completionText:
      'Well played! Balancing offense and defense is key. Sometimes you block, sometimes you race to complete your own road first.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 3,
    stacks: const [
      PositionedStack(
        position: Position(1, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      PositionedStack(
        position: Position(2, 2),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
    ],
  ),
  scriptedResponses: const [
    // Black builds toward a road threat
    AIPlacementMove(Position(2, 1), PieceType.flat),
  ],
);

final _tutorial4StandingStones = GameScenario(
  id: 'tutorial_4',
  title: 'Standing Stones (Walls)',
  type: ScenarioType.tutorial,
  summary: 'Use a wall to block an opponent\'s road.',
  objective: 'Place a standing stone to block Black\'s winning move.',
  dialogue: const [
    'Black is about to complete a road along the bottom edge!',
    'A standing stone (or "wall") is placed upright. Walls block movement and placement — but they don\'t count as part of roads.',
    'Place a wall to block Black\'s winning move.',
  ],
  guidedMove: const GuidedMove.placement(
    target: Position(3, 2),
    pieceType: PieceType.standing,
  ),
  completionText:
      'Your wall blocks their road! Black\'s path is broken. Remember: walls are powerful blockers, but they can\'t be part of YOUR road either. Use them strategically.',
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
  scriptedResponses: const [],
);

final _tutorial5Capstone = GameScenario(
  id: 'tutorial_5',
  title: 'The Capstone',
  type: ScenarioType.tutorial,
  summary: 'Use the Capstone to flatten a wall.',
  objective: 'Move the Capstone onto the wall to flatten it and complete your road.',
  dialogue: const [
    'You\'re building a road downward, but a wall blocks your path!',
    'Regular flat stones can\'t go on top of walls. Enter the Capstone — your most powerful piece.',
    'The Capstone: counts as part of roads (like flat stones), can flatten walls by moving onto them, and cannot be covered by other pieces.',
    'Move your Capstone onto the wall to flatten it and complete your road.',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(3, 1),
    direction: Direction.up,
    drops: [1],
  ),
  completionText:
      'The wall is now flat — and your road is complete! The Capstone is essential for breaking through defenses.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 9,
    stacks: const [
      // White road with gap blocked by wall
      PositionedStack(
        position: Position(0, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      PositionedStack(
        position: Position(1, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      // Black wall blocking at row 2
      PositionedStack(
        position: Position(2, 1),
        stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
      ),
      // White capstone ready to flatten
      PositionedStack(
        position: Position(3, 1),
        stack: PieceStack([Piece(type: PieceType.capstone, color: PlayerColor.white)]),
      ),
    ],
  ),
  scriptedResponses: const [],
);

final _tutorial6MovingSinglePiece = GameScenario(
  id: 'tutorial_6',
  title: 'Moving a Single Piece',
  type: ScenarioType.tutorial,
  summary: 'Learn to move pieces on the board.',
  objective: 'Tap your stone, then tap an adjacent cell to move it.',
  dialogue: const [
    'Instead of placing a new stone, you can move a piece you already control.',
    'Pieces move in a straight line: up, down, left, or right (not diagonally).',
    'Tap your stone, then tap an adjacent cell to move it.',
  ],
  guidedMove: const GuidedMove.anyStackMove(from: Position(1, 1)),
  completionText:
      'Pieces can only move onto empty cells or onto other pieces (creating stacks). Moving lets you reposition without using new pieces from your supply.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 5,
    stacks: const [
      PositionedStack(
        position: Position(1, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
    ],
  ),
  scriptedResponses: const [],
);

final _tutorial7StacksAndControl = GameScenario(
  id: 'tutorial_7',
  title: 'Stacks and Control',
  type: ScenarioType.tutorial,
  summary: 'Understand stack control.',
  objective: 'Move the stack to demonstrate control.',
  dialogue: const [
    'When pieces occupy the same cell, they form a stack.',
    'Here\'s the key rule: whoever has the top piece controls the stack.',
    'You have White on top, so you control this stack — even though there\'s a Black piece underneath.',
    'Move the stack.',
  ],
  guidedMove: const GuidedMove.anyStackMove(from: Position(1, 1)),
  completionText:
      'The whole stack moved together! Controlling your opponent\'s pieces in stacks is a powerful tactic. Only the top piece determines the stack\'s color for roads. The Black piece underneath doesn\'t help Black at all right now.',
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
  scriptedResponses: const [],
);

final _tutorial8StackMovement = GameScenario(
  id: 'tutorial_8',
  title: 'Stack Movement & Carry Limit',
  type: ScenarioType.tutorial,
  summary: 'Learn about carry limits and dropping pieces.',
  objective: 'Pick up pieces from the stack and drop them across multiple cells.',
  dialogue: const [
    'When moving a stack, you choose how many pieces to pick up from the top — up to the carry limit.',
    'The carry limit equals the board size. On a 5×5 board, you can carry up to 5 pieces.',
    'This stack has 4 pieces. Pick up 3 and spread them as you move.',
    'As you move, you must drop at least one piece per cell. You\'ll keep moving until your hand is empty.',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(2, 1),
    direction: Direction.right,
    drops: [1, 1, 1],
  ),
  completionText:
      'Stack movement lets you spread influence, capture opponent stacks, or set up complex tactics. Remember: carry limit equals board size, drop at least 1 per cell, and move in a straight line only.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 11,
    stacks: const [
      // 4-piece stack White controls
      PositionedStack(
        position: Position(2, 1),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
    ],
  ),
  scriptedResponses: const [],
);

final _tutorial9OpeningRule = GameScenario(
  id: 'tutorial_9',
  title: 'The Opening Rule',
  type: ScenarioType.tutorial,
  summary: 'Learn the special first-turn rule.',
  objective: 'Place a Black flat stone (your opponent\'s color) to start the game.',
  dialogue: const [
    'There\'s one special rule: on the very first turn, each player places a piece of their opponent\'s color.',
    'This prevents a first-player advantage and creates interesting opening positions.',
    'You\'re White, going first. Place a Black flat stone.',
  ],
  guidedMove: const GuidedMove.anyPlacement(pieceType: PieceType.flat),
  completionText:
      'The opening rule is easy to forget! Some players place the opponent\'s piece in a corner (giving them little value), others place it centrally (creating interesting positions). Now the game continues normally — you place your own White pieces from here on.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 1, // First turn triggers opening rule
    phase: GamePhase.opening,
    stacks: const [],
  ),
  scriptedResponses: const [],
);

final _tutorial10FlatCount = GameScenario(
  id: 'tutorial_10',
  title: 'Winning by Flat Count',
  type: ScenarioType.tutorial,
  summary: 'Learn the alternative win condition.',
  objective: 'Place your remaining stones to maximize your flat count.',
  dialogue: const [
    'Not every game ends with a road. When the board fills up or a player runs out of pieces, the game ends.',
    'If there\'s no road, the winner is whoever has more flat stones visible on top.',
    'Walls and Capstones don\'t count for flat count — only flat stones.',
    'The board is almost full. Place your remaining stones to maximize your flat count.',
  ],
  guidedMove: const GuidedMove.anyPlacement(pieceType: PieceType.flat),
  completionText:
      'You won by flat count! You had more flat stones showing on top. This is why walls are a tradeoff — they block, but they hurt your flat count. Use them wisely.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 27,
    whiteFlatStones: 2,
    blackFlatStones: 1,
    stacks: const [
      // Row 0: W B W B
      PositionedStack(position: Position(0, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(0, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(0, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(0, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      // Row 1: B W B W
      PositionedStack(position: Position(1, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(1, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Row 2: W B W (empty at col 3)
      PositionedStack(position: Position(2, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(2, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Row 3: B W (empty at col 2, 3)
      PositionedStack(position: Position(3, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
    ],
  ),
  scriptedResponses: const [],
);

final _tutorial11PieceSupply = GameScenario(
  id: 'tutorial_11',
  title: 'Running Out of Pieces',
  type: ScenarioType.tutorial,
  summary: 'Manage your limited piece supply.',
  objective: 'Complete the game wisely with your limited pieces.',
  dialogue: const [
    'Each player has a limited supply of pieces — the number depends on board size.',
    'The game ends immediately when either player places their last piece.',
    'If there\'s no road, highest flat count wins.',
    'You only have 2 pieces left! Finish the game wisely.',
  ],
  guidedMove: const GuidedMove.anyPlacement(pieceType: PieceType.flat),
  completionText:
      'When pieces run low, every placement matters. Sometimes it\'s better to move existing pieces rather than place new ones. Watch your supply — and your opponent\'s!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 23,
    whiteFlatStones: 2,
    whiteCapstones: 0,
    blackFlatStones: 5,
    blackCapstones: 0,
    stacks: const [
      // Mid-game state with several pieces
      PositionedStack(position: Position(0, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(0, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(1, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(2, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  scriptedResponses: const [],
);

// ============================================================================
// PUZZLES (10 total)
// ============================================================================

final _puzzle1CompleteRoad = GameScenario(
  id: 'puzzle_1',
  title: 'Complete the Road',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.easy,
  summary: 'Win in 1 move — complete your road!',
  objective: 'Win in 1 move. Complete your road!',
  dialogue: const [
    'White to move.',
    'Your road is almost complete. Find the winning move!',
  ],
  guidedMove: const GuidedMove.placement(
    target: Position(3, 1),
    pieceType: PieceType.flat,
  ),
  completionText:
      'Roads connect opposite edges. Always look for one-move wins!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 9,
    stacks: const [
      // White vertical road at col 1, missing row 3
      PositionedStack(position: Position(0, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(1, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Some black pieces
      PositionedStack(position: Position(1, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  scriptedResponses: const [],
);

final _puzzle2BlockAndWin = GameScenario(
  id: 'puzzle_2',
  title: 'Block and Win',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.easy,
  summary: 'Win in 1 move before Black completes their road!',
  objective: 'Win in 1 move before Black completes their road!',
  dialogue: const [
    'White to move.',
    'Black threatens to complete a road next turn. Can you win first?',
  ],
  guidedMove: const GuidedMove.placement(
    target: Position(0, 3),
    pieceType: PieceType.flat,
  ),
  completionText:
      'Sometimes racing to win is better than blocking!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 11,
    stacks: const [
      // White horizontal road at row 0, missing col 3
      PositionedStack(position: Position(0, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(0, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(0, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Black horizontal road at row 3, missing col 3
      PositionedStack(position: Position(3, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  scriptedResponses: const [],
);

final _puzzle3CrucialBlock = GameScenario(
  id: 'puzzle_3',
  title: 'The Crucial Block',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.easy,
  summary: 'Block Black\'s winning road!',
  objective: 'Black wins next turn unless you stop them! Block their road.',
  dialogue: const [
    'White to move.',
    'Black is one move from winning. You must block!',
  ],
  guidedMove: const GuidedMove.placement(
    target: Position(1, 3),
    pieceType: PieceType.standing,
  ),
  completionText:
      'Walls don\'t help your road, but they can save the game!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 9,
    stacks: const [
      // Black horizontal road at row 1, missing col 3
      PositionedStack(position: Position(1, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      // Scattered white pieces
      PositionedStack(position: Position(0, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
    ],
  ),
  scriptedResponses: const [],
);

final _puzzle4FlattenToVictory = GameScenario(
  id: 'puzzle_4',
  title: 'Flatten to Victory',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.medium,
  summary: 'Use your Capstone to break through!',
  objective: 'Win in 1 move. The wall blocks your road — but you have a Capstone!',
  dialogue: const [
    'White to move.',
    'A wall blocks your road. Your Capstone can flatten it!',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(3, 1),
    direction: Direction.up,
    drops: [1],
  ),
  completionText:
      'The Capstone breaks through walls. Always look for flattening opportunities!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 4,
    currentPlayer: PlayerColor.white,
    turnNumber: 11,
    stacks: const [
      // White road blocked by wall
      PositionedStack(position: Position(0, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(1, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Black wall blocking
      PositionedStack(position: Position(2, 1), stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)])),
      // White capstone ready
      PositionedStack(position: Position(3, 1), stack: PieceStack([Piece(type: PieceType.capstone, color: PlayerColor.white)])),
    ],
  ),
  scriptedResponses: const [],
);

final _puzzle5StackEscape = GameScenario(
  id: 'puzzle_5',
  title: 'Stack Escape',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.medium,
  summary: 'Use stack movement to complete your road!',
  objective: 'Win in 1 move. Use stack movement to complete your road!',
  dialogue: const [
    'White to move.',
    'Your road is almost complete. Use your stack to place a piece in the right spot!',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(1, 0),
    direction: Direction.right,
    drops: [1],
  ),
  completionText:
      'Stack movement can place pieces exactly where you need them!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 15,
    stacks: const [
      // White road at row 1, missing col 1
      PositionedStack(position: Position(1, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(1, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(1, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // White stack that can complete the road
      PositionedStack(
        position: Position(1, 0),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      // Some black pieces
      PositionedStack(position: Position(2, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  scriptedResponses: const [],
);

final _puzzle6CaptureAndWin = GameScenario(
  id: 'puzzle_6',
  title: 'Capture and Win',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.medium,
  summary: 'Take control of a key stack!',
  objective: 'Win in 1 move. Take control of that stack!',
  dialogue: const [
    'White to move.',
    'Black controls a stack in your road. Capture it to win!',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(2, 0),
    direction: Direction.right,
    drops: [1],
  ),
  completionText:
      'Capturing the top of a stack gives you control. Turn their pieces into your road!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 17,
    stacks: const [
      // White road at row 2, but col 1 has Black-controlled stack
      PositionedStack(position: Position(2, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Black-controlled stack in the road
      PositionedStack(
        position: Position(2, 1),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.black),
        ]),
      ),
      // White stack to capture with
      PositionedStack(
        position: Position(2, 0),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
    ],
  ),
  scriptedResponses: const [],
);

final _puzzle7TheSpread = GameScenario(
  id: 'puzzle_7',
  title: 'The Spread',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.hard,
  summary: 'Spread your stack to build a road!',
  objective: 'Win in 1 move. Spread your stack to build a road!',
  dialogue: const [
    'White to move.',
    'Your tall stack holds the key to victory. Spread it wisely!',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(2, 0),
    direction: Direction.right,
    drops: [1, 1, 1, 1],
  ),
  completionText:
      'Tall stacks are potential roads waiting to be unrolled!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 21,
    stacks: const [
      // White tall stack at (2,0)
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
      // White piece at end of row
      PositionedStack(position: Position(2, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Some black pieces
      PositionedStack(position: Position(1, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  scriptedResponses: const [],
);

final _puzzle8DoubleThreat = GameScenario(
  id: 'puzzle_8',
  title: 'Double Threat',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.hard,
  summary: 'Create a threat Black cannot fully block!',
  objective: 'Create two road threats that Black cannot both block!',
  dialogue: const [
    'White to move.',
    'Set up a fork — two threats that Black cannot both stop!',
  ],
  guidedMove: const GuidedMove.placement(
    target: Position(2, 2),
    pieceType: PieceType.flat,
  ),
  completionText:
      'Creating multiple threats forces your opponent into impossible choices!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 17,
    stacks: const [
      // White pieces set up for fork
      // Horizontal threat at row 2
      PositionedStack(position: Position(2, 0), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Vertical threat at col 2
      PositionedStack(position: Position(0, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(1, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(3, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(4, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Black pieces
      PositionedStack(position: Position(1, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  scriptedResponses: const [],
);

final _puzzle9CapstoneTactics = GameScenario(
  id: 'puzzle_9',
  title: 'Capstone Tactics',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.hard,
  summary: 'Your Capstone is the key!',
  objective: 'Flatten the wall and complete your road!',
  dialogue: const [
    'White to move.',
    'A wall blocks your road. Use your Capstone to break through and win!',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(2, 0),
    direction: Direction.right,
    drops: [1],
  ),
  completionText:
      'The Capstone can reshape the entire board. Plan its path carefully!',
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 19,
    stacks: const [
      // White road at row 2 blocked by wall at col 1
      PositionedStack(position: Position(2, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Wall blocking
      PositionedStack(position: Position(2, 1), stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)])),
      // Capstone ready
      PositionedStack(position: Position(2, 0), stack: PieceStack([Piece(type: PieceType.capstone, color: PlayerColor.white)])),
      // Some black pieces
      PositionedStack(position: Position(1, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  scriptedResponses: const [],
);

final _puzzle10GrandCombination = GameScenario(
  id: 'puzzle_10',
  title: 'The Grand Combination',
  type: ScenarioType.puzzle,
  puzzleDifficulty: PuzzleDifficulty.expert,
  summary: 'Find the path to victory!',
  objective: 'Find the winning move in this complex position!',
  dialogue: const [
    'White to move.',
    'This is a complex position. Study the board carefully and find the winning combination!',
  ],
  guidedMove: const GuidedMove.stackMove(
    from: Position(2, 2),
    direction: Direction.left,
    drops: [1, 1],
  ),
  completionText:
      'Masterful! You\'ve learned to see the whole board and plan ahead.',
  buildInitialState: () => _buildScenarioState(
    boardSize: 6,
    currentPlayer: PlayerColor.white,
    turnNumber: 31,
    stacks: const [
      // Complex position requiring stack spread
      // White road at row 2, needs pieces at col 0 and 1
      PositionedStack(position: Position(2, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 4), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      PositionedStack(position: Position(2, 5), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)])),
      // Tall stack at (2,2) that can spread left
      PositionedStack(
        position: Position(2, 2),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      // Black pieces creating complexity
      PositionedStack(position: Position(1, 1), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(3, 2), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
      PositionedStack(position: Position(1, 4), stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)])),
      PositionedStack(position: Position(4, 3), stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)])),
    ],
  ),
  scriptedResponses: const [],
);

// ============================================================================
// LIBRARY EXPORT
// ============================================================================

/// Library of scenarios shown in the tutorial/puzzle selector.
final List<GameScenario> tutorialAndPuzzleLibrary = [
  // Tutorials (11)
  _tutorial1PlacingStones,
  _tutorial2BuildingRoad,
  _tutorial3TurnsTaking,
  _tutorial4StandingStones,
  _tutorial5Capstone,
  _tutorial6MovingSinglePiece,
  _tutorial7StacksAndControl,
  _tutorial8StackMovement,
  _tutorial9OpeningRule,
  _tutorial10FlatCount,
  _tutorial11PieceSupply,
  // Puzzles (10)
  _puzzle1CompleteRoad,
  _puzzle2BlockAndWin,
  _puzzle3CrucialBlock,
  _puzzle4FlattenToVictory,
  _puzzle5StackEscape,
  _puzzle6CaptureAndWin,
  _puzzle7TheSpread,
  _puzzle8DoubleThreat,
  _puzzle9CapstoneTactics,
  _puzzle10GrandCombination,
];
