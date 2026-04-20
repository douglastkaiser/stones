part of '../scenario.dart';

/// Scenario module guide:
/// Add tactical/challenge puzzle scenarios here when adding solved positions
/// that test move calculation, pattern recognition, or multi-move lines.

final _puzzle6CaptureAndWin = GameScenario(
  id: 'puzzle_6',
  title: 'Capture and Win',
  type: ScenarioType.puzzle,

  chapter: ScenarioChapter.puzzleBasics,
  orderInChapter: 1,
  prerequisiteScenarioIds: ['tutorial_9'],
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

  chapter: ScenarioChapter.puzzleBasics,
  orderInChapter: 2,
  prerequisiteScenarioIds: ['puzzle_6'],
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

  chapter: ScenarioChapter.puzzleBasics,
  orderInChapter: 3,
  prerequisiteScenarioIds: ['puzzle_7'],
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

final _puzzle10TheFork = GameScenario(
  id: 'puzzle_10',
  title: 'The Fork',
  type: ScenarioType.puzzle,

  chapter: ScenarioChapter.puzzleAdvanced,
  orderInChapter: 1,
  prerequisiteScenarioIds: ['puzzle_9'],
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
// EXPERT PUZZLE: THE CRUCIBLE
// A complex 3-move puzzle with a deceptive trap and forced winning sequence
// Moving the capstone first is tempting but WRONG - setup is required!
// ============================================================================

final _puzzle11TheCrucible = GameScenario(
  id: 'puzzle_11',
  title: 'The Crucible',
  type: ScenarioType.puzzle,

  chapter: ScenarioChapter.puzzleAdvanced,
  orderInChapter: 2,
  prerequisiteScenarioIds: ['puzzle_10'],
  puzzleDifficulty: PuzzleDifficulty.expert,
  summary: 'A three-move forced win — if you find the right sequence!',
  objective: 'Win in 3 moves. Every move must be precise!',
  dialogue: const [
    'White to move.',
    'Your Capstone looks ready to strike, but patience is key.',
    'Set up your attack first — rushing the Capstone leads to defeat!',
  ],
  guidedMove: const GuidedMove.placement(
    target: Position(2, 3),
    pieceType: PieceType.flat,
  ),
  completionText:
      'Three precise moves! The setup placement was crucial — moving the Capstone first would have failed. Patience and planning win in Tak.',
  hintText: 'Don\'t move the Capstone yet. Create a threat on Column 3 first...',
  hintDelay: const Duration(seconds: 30),
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 37,
    stacks: const [
      // ================================================================
      // ROW 0: Corner walls and road stacks
      // ================================================================
      PositionedStack(
        position: Position(0, 0),
        stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
      ),
      // (0,1) White stack - Column 1 road
      PositionedStack(
        position: Position(0, 1),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      PositionedStack(
        position: Position(0, 2),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      // (0,3) White stack - Column 3 road
      PositionedStack(
        position: Position(0, 3),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      // Black capstone in corner
      PositionedStack(
        position: Position(0, 4),
        stack: PieceStack([Piece(type: PieceType.capstone, color: PlayerColor.black)]),
      ),

      // ================================================================
      // ROW 1: Mixed control stacks
      // ================================================================
      // Black-controlled stack (captured white piece)
      PositionedStack(
        position: Position(1, 0),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.black),
        ]),
      ),
      // Column 1 road
      PositionedStack(
        position: Position(1, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      // Critical wall blocking Column 2
      PositionedStack(
        position: Position(1, 2),
        stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
      ),
      // White-controlled stack - Column 3 road
      PositionedStack(
        position: Position(1, 3),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      // Black-controlled stack
      PositionedStack(
        position: Position(1, 4),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.black),
        ]),
      ),

      // ================================================================
      // ROW 2: THE CRITICAL ROW - Capstone and key wall
      // ================================================================
      // (2,0) White CAPSTONE - THE KEY PIECE (but don't move it first!)
      PositionedStack(
        position: Position(2, 0),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.capstone, color: PlayerColor.white),
        ]),
      ),
      // (2,1) THE WALL that will be flattened in Move 2
      PositionedStack(
        position: Position(2, 1),
        stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
      ),
      // (2,2) EMPTY - Will be blocked by Black in response to the fork
      // (2,3) EMPTY - Move 1 target! Creates Column 3 TAK
      // (2,4) Row 2 road piece
      PositionedStack(
        position: Position(2, 4),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),

      // ================================================================
      // ROW 3: More road pieces and blocking wall
      // ================================================================
      // Black-controlled stack
      PositionedStack(
        position: Position(3, 0),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.black),
        ]),
      ),
      // Column 1 road
      PositionedStack(
        position: Position(3, 1),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      // Wall blocking Column 2
      PositionedStack(
        position: Position(3, 2),
        stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
      ),
      // White-controlled stack - Column 3 road
      PositionedStack(
        position: Position(3, 3),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      PositionedStack(
        position: Position(3, 4),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),

      // ================================================================
      // ROW 4: Bottom row
      // ================================================================
      PositionedStack(
        position: Position(4, 0),
        stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
      ),
      // (4,1) EMPTY - Move 3 wins here by completing Column 1!
      PositionedStack(
        position: Position(4, 2),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      // (4,3) EMPTY - Black blocks here after Move 1
      PositionedStack(
        position: Position(4, 4),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
    ],
  ),
  // ============================================================
  // SOLUTION ANALYSIS - 3 MOVE FORCED WIN:
  //
  // WHY MOVING CAPSTONE FIRST FAILS:
  // - If White moves capstone from (2,0) to (2,1) first:
  //   - Creates Col 1 TAK (needs 4,1)
  //   - Black blocks (4,1) with wall
  //   - Now White can create Row 2 TAK by placing (2,2)
  //   - Black blocks (2,3) with wall
  //   - White has NO winning path! Col 3 is blocked!
  //
  // THE CORRECT SEQUENCE:
  //
  // Move 1 (guided): Place flat at (2,3)
  //   - Creates Col 3 TAK: W(0,3), W(1,3), W(2,3), W(3,3), empty(4,3)
  //   - Black MUST block or lose!
  //
  // Black response 1: Places wall at (4,3) to block Col 3
  //
  // Move 2: Capstone from (2,0) moves right to (2,1), flattening wall
  //   - (2,0) keeps [B, W] - White still controls
  //   - Creates FORK:
  //     - Row 2: W(2,0), C(2,1), empty(2,2), W(2,3), W(2,4) = TAK!
  //     - Col 1: W(0,1), W(1,1), C(2,1), W(3,1), empty(4,1) = TAK!
  //   - Black can only block ONE!
  //
  // Black response 2: Places wall at (2,2) to block Row 2
  //
  // Move 3: Place flat at (4,1)
  //   - Col 1: W, W, C, W, W = COMPLETE ROAD = WIN!
  // ============================================================
  scriptedResponses: const [
    AIPlacementMove(Position(4, 3), PieceType.standing),
    AIPlacementMove(Position(2, 2), PieceType.standing),
  ],
);

final _puzzle12IronCauseway = GameScenario(
  id: 'puzzle_12',
  title: 'Iron Causeway',
  type: ScenarioType.puzzle,

  chapter: ScenarioChapter.puzzleAdvanced,
  orderInChapter: 3,
  prerequisiteScenarioIds: ['puzzle_11'],
  puzzleDifficulty: PuzzleDifficulty.expert,
  summary: 'Break a fortified defense with a precise three-move sequence.',
  objective: 'Win in 3 moves. Every response is forced.',
  dialogue: const [
    'White to move.',
    'The center is locked down with walls, heavy stacks, and both Capstones in play.',
    'Build the threat, force two exact replies, then crack the final wall.',
  ],
  guidedMove: const GuidedMove.placement(
    target: Position(2, 3),
    pieceType: PieceType.flat,
  ),
  completionText:
      'Perfect execution. You forced both replies, then used the Capstone break to finish the only winning road.',
  hintText:
      'Start with the quiet placement at (2,3). The winning break comes only after Black\'s forced wall responses.',
  hintDelay: const Duration(seconds: 35),
  buildInitialState: () => _buildScenarioState(
    boardSize: 5,
    currentPlayer: PlayerColor.white,
    turnNumber: 43,
    stacks: const [
      // Row 0
      PositionedStack(
        position: Position(0, 0),
        stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(0, 1),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      PositionedStack(
        position: Position(0, 2),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(0, 3),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      PositionedStack(
        position: Position(0, 4),
        stack: PieceStack([Piece(type: PieceType.capstone, color: PlayerColor.black)]),
      ),

      // Row 1
      PositionedStack(
        position: Position(1, 0),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.black),
        ]),
      ),
      PositionedStack(
        position: Position(1, 1),
        stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(1, 2),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      PositionedStack(
        position: Position(1, 3),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      PositionedStack(
        position: Position(1, 4),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),

      // Row 2 - tactical core
      PositionedStack(
        position: Position(2, 0),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.capstone, color: PlayerColor.white),
        ]),
      ),
      // (2,1) intentionally empty for move 2
      // (2,2) intentionally empty, Black's forced second block
      // (2,3) intentionally empty for move 1
      PositionedStack(
        position: Position(2, 4),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),

      // Row 3
      PositionedStack(
        position: Position(3, 0),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(3, 1),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      PositionedStack(
        position: Position(3, 2),
        stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(3, 3),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
      ),
      PositionedStack(
        position: Position(3, 4),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),

      // Row 4
      PositionedStack(
        position: Position(4, 0),
        stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
      ),
      PositionedStack(
        position: Position(4, 1),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
        ]),
      ),
      PositionedStack(
        position: Position(4, 2),
        stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
      ),
      // (4,3) empty, Black's forced first block
      PositionedStack(
        position: Position(4, 4),
        stack: PieceStack([
          Piece(type: PieceType.flat, color: PlayerColor.black),
          Piece(type: PieceType.flat, color: PlayerColor.white),
          Piece(type: PieceType.flat, color: PlayerColor.black),
        ]),
      ),
    ],
  ),
  // Forced line:
  // 1. White: place flat at (2,3) -> threatens Column 3 road (only block: 4,3 wall)
  // ... Black: 4,3 standing
  // 2. White: place flat at (2,1) -> threatens Row 2 road (only block: 2,2 wall)
  // ... Black: 2,2 standing
  // 3. White: move stack from (2,0) right with drops [1,1];
  //    Capstone lands on (2,2), flattens wall, and completes Row 2.
  scriptedResponses: const [
    AIPlacementMove(Position(4, 3), PieceType.standing),
    AIPlacementMove(Position(2, 2), PieceType.standing),
  ],
);

