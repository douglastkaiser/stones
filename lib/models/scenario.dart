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
    required this.buildInitialState,
    required this.scriptedResponses,
    required this.completionText,
    this.aiDifficulty = AIDifficulty.easy,
  });
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
    summary: 'Practice simple flat placements and extending a road.',
    objective: 'Use your white flats to connect the open lane across the center.',
    dialogue: [
      'You are playing as White. A road is nearly complete through the middle of the board.',
      'Try placing a flat stone to stitch the two halves together while keeping an eye on Black\'s blocks.',
    ],
    completionText:
        'Notice how a single flat placement can complete a continuous white path. Small gaps are often the fastest wins.',
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
          position: Position(1, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(3, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(1, 3),
          stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
        ),
      ],
    ),
    scriptedResponses: [
      AIPlacementMove(Position(0, 4), PieceType.flat),
    ],
  ),
  GameScenario(
    id: 'tutorial_2',
    title: 'Tutorial 2',
    type: ScenarioType.tutorial,
    summary: 'Learn to move stacks and flatten a wall with a capstone.',
    objective: 'Slide your capstone onto the wall to clear a path for your road.',
    dialogue: [
      'Capstones can flatten standing stones, letting your road continue.',
      'Pick up the capstone on d3 and move it right to crush the wall.',
    ],
    completionText:
        'Flattening walls with a capstone both removes the block and keeps your stone on top to control the square.',
    buildInitialState: () => _buildScenarioState(
      boardSize: 5,
      currentPlayer: PlayerColor.white,
      turnNumber: 10,
      stacks: const [
        PositionedStack(
          position: Position(2, 2),
          stack: PieceStack([Piece(type: PieceType.capstone, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(2, 3),
          stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(2, 1),
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
          position: Position(1, 3),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
      ],
    ),
    scriptedResponses: [
      AIPlacementMove(Position(0, 0), PieceType.flat),
    ],
  ),
  GameScenario(
    id: 'puzzle_1',
    title: 'Puzzle 1',
    type: ScenarioType.puzzle,
    summary: 'You are White to move – find Tak in 2.',
    objective: 'Flatten the wall in the center column and finish a vertical road.',
    dialogue: [
      'White controls most of the center file, but a black wall is stopping the road.',
      'Use your capstone on d3 to smash through and set up a finish on your next turn.',
    ],
    completionText:
        'The capstone opens the column while your follow-up placement completes the connection for Tak.',
    buildInitialState: () => _buildScenarioState(
      boardSize: 5,
      currentPlayer: PlayerColor.white,
      turnNumber: 12,
      stacks: const [
        PositionedStack(
          position: Position(0, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(1, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(2, 2),
          stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(3, 2),
          stack: PieceStack([Piece(type: PieceType.capstone, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(4, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
        PositionedStack(
          position: Position(2, 3),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
      ],
    ),
    scriptedResponses: [
      AIPlacementMove(Position(0, 4), PieceType.flat),
    ],
  ),
  GameScenario(
    id: 'puzzle_2',
    title: 'Puzzle 2',
    type: ScenarioType.puzzle,
    summary: 'Break the fork and keep the road threat alive.',
    objective: 'Advance your stack to spread pieces while Black reacts predictably.',
    dialogue: [
      'White has a strong stack on c3 ready to spread along the third row.',
      'Try moving the stack to the right, dropping stones to maintain multiple threats.',
    ],
    completionText:
        'Spreading a tall stack lets you keep tempo while forcing your opponent to defend in multiple places.',
    buildInitialState: () => _buildScenarioState(
      boardSize: 5,
      currentPlayer: PlayerColor.white,
      turnNumber: 14,
      stacks: const [
        PositionedStack(
          position: Position(2, 2),
          stack: PieceStack([
            Piece(type: PieceType.flat, color: PlayerColor.white),
            Piece(type: PieceType.flat, color: PlayerColor.white),
            Piece(type: PieceType.flat, color: PlayerColor.white),
          ]),
        ),
        PositionedStack(
          position: Position(2, 3),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(1, 3),
          stack: PieceStack([Piece(type: PieceType.standing, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(3, 1),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.black)]),
        ),
        PositionedStack(
          position: Position(4, 2),
          stack: PieceStack([Piece(type: PieceType.flat, color: PlayerColor.white)]),
        ),
      ],
    ),
    scriptedResponses: [
      AIPlacementMove(Position(0, 0), PieceType.flat),
      AIPlacementMove(Position(4, 4), PieceType.flat),
    ],
    aiDifficulty: AIDifficulty.medium,
  ),
];
