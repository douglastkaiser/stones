part of '../scenario.dart';

/// Scenario module guide:
/// Add guided onboarding/teaching scenarios here when introducing core rules
/// or fundamentals progression chapters.

final _tutorial1BuildingRoad = GameScenario(
  id: 'tutorial_1',
  title: 'Building a Road',
  type: ScenarioType.tutorial,

  chapter: ScenarioChapter.fundamentals,
  orderInChapter: 1,
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

  chapter: ScenarioChapter.fundamentals,
  orderInChapter: 2,
  prerequisiteScenarioIds: ['tutorial_1'],
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

  chapter: ScenarioChapter.fundamentals,
  orderInChapter: 3,
  prerequisiteScenarioIds: ['tutorial_2'],
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

  chapter: ScenarioChapter.fundamentals,
  orderInChapter: 4,
  prerequisiteScenarioIds: ['tutorial_3'],
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

  chapter: ScenarioChapter.fundamentals,
  orderInChapter: 5,
  prerequisiteScenarioIds: ['tutorial_4'],
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

  chapter: ScenarioChapter.fundamentals,
  orderInChapter: 6,
  prerequisiteScenarioIds: ['tutorial_5'],
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

  chapter: ScenarioChapter.fundamentals,
  orderInChapter: 7,
  prerequisiteScenarioIds: ['tutorial_6'],
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

  chapter: ScenarioChapter.fundamentals,
  orderInChapter: 8,
  prerequisiteScenarioIds: ['tutorial_7'],
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

  chapter: ScenarioChapter.fundamentals,
  orderInChapter: 9,
  prerequisiteScenarioIds: ['tutorial_8'],
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

