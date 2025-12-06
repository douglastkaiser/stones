import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'providers/providers.dart';
import 'models/models.dart';
import 'version.dart';

void main() {
  runApp(const ProviderScope(child: StonesApp()));
}

class StonesApp extends StatelessWidget {
  const StonesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stones',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Home screen with settings and start game
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        'STONES',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.brown.shade800,
                              letterSpacing: 8,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A game of roads and flats',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.brown.shade600,
                            ),
                      ),
                      const SizedBox(height: 64),

                      // Board size selector
                      Text(
                        'Select Board Size',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          for (int size = 3; size <= 8; size++)
                            _BoardSizeButton(size: size),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // Continue current game button
                      Consumer(
                        builder: (context, ref, _) {
                          final gameState = ref.watch(gameStateProvider);
                          if (gameState.turnNumber == 1 &&
                              gameState.board.occupiedPositions.isEmpty) {
                            return const SizedBox();
                          }
                          return TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GameScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Continue Game'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const VersionFooter(),
          ],
        ),
      ),
    );
  }
}

class _BoardSizeButton extends ConsumerWidget {
  final int size;

  const _BoardSizeButton({required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = PieceCounts.forBoardSize(size);
    return SizedBox(
      width: 100,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        ),
        onPressed: () {
          ref.read(gameStateProvider.notifier).newGame(size);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GameScreen()),
          );
        },
        child: Column(
          children: [
            Text(
              '${size}x$size',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${counts.flatStones}F ${counts.capstones}C',
              style: TextStyle(
                fontSize: 12,
                color: Colors.brown.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interaction mode for the game
enum InteractionMode {
  idle,
  selectingPieceType,
  selectingMoveDirection,
  selectingDrops,
}

/// Provider for UI state
class UIState {
  final Position? selectedPosition;
  final InteractionMode mode;
  final Direction? selectedDirection;
  final List<int> drops;
  final int piecesPickedUp;

  const UIState({
    this.selectedPosition,
    this.mode = InteractionMode.idle,
    this.selectedDirection,
    this.drops = const [],
    this.piecesPickedUp = 0,
  });

  /// Get the positions where pieces have been dropped so far
  List<Position> getDropPath() {
    if (selectedPosition == null || selectedDirection == null) return [];

    final path = <Position>[];
    var pos = selectedPosition!;
    for (var i = 0; i < drops.length; i++) {
      pos = selectedDirection!.apply(pos);
      path.add(pos);
    }
    return path;
  }

  /// Get the current "hand" position (where next drop would go)
  Position? getCurrentHandPosition() {
    if (selectedPosition == null || selectedDirection == null) return null;
    if (piecesPickedUp == 0) return null;

    var pos = selectedPosition!;
    for (var i = 0; i < drops.length; i++) {
      pos = selectedDirection!.apply(pos);
    }
    return selectedDirection!.apply(pos);
  }

  UIState copyWith({
    Position? selectedPosition,
    InteractionMode? mode,
    Direction? selectedDirection,
    List<int>? drops,
    int? piecesPickedUp,
    bool clearSelection = false,
  }) {
    return UIState(
      selectedPosition: clearSelection ? null : (selectedPosition ?? this.selectedPosition),
      mode: mode ?? this.mode,
      selectedDirection: clearSelection ? null : (selectedDirection ?? this.selectedDirection),
      drops: drops ?? this.drops,
      piecesPickedUp: piecesPickedUp ?? this.piecesPickedUp,
    );
  }

  static const initial = UIState();
}

class UIStateNotifier extends StateNotifier<UIState> {
  UIStateNotifier() : super(UIState.initial);

  void selectCell(Position pos) {
    state = UIState(selectedPosition: pos, mode: InteractionMode.selectingPieceType);
  }

  void selectStack(Position pos, int maxPieces) {
    state = UIState(
      selectedPosition: pos,
      mode: InteractionMode.selectingMoveDirection,
      piecesPickedUp: maxPieces,
    );
  }

  void selectDirection(Direction dir) {
    state = state.copyWith(
      selectedDirection: dir,
      mode: InteractionMode.selectingDrops,
      drops: [],
    );
  }

  void addDrop(int count) {
    state = state.copyWith(
      drops: [...state.drops, count],
      piecesPickedUp: state.piecesPickedUp - count,
    );
  }

  void setPiecesPickedUp(int count) {
    state = state.copyWith(piecesPickedUp: count);
  }

  void reset() {
    state = UIState.initial;
  }
}

final uiStateProvider = StateNotifierProvider<UIStateNotifier, UIState>((ref) {
  return UIStateNotifier();
});

/// Main game screen
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final uiState = ref.watch(uiStateProvider);
    final isGameOver = ref.watch(isGameOverProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stones'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Game',
            onPressed: () => _showNewGameDialog(context, ref),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Game info bar
              _GameInfoBar(gameState: gameState),

              // Board
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.brown.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _GameBoard(
                        gameState: gameState,
                        uiState: uiState,
                        onCellTap: (pos) => _handleCellTap(context, ref, pos),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom controls
              _BottomControls(
                gameState: gameState,
                uiState: uiState,
                onPieceSelected: (type) => _placePiece(ref, type),
                onDirectionSelected: (dir) => _selectDirection(ref, dir),
                onDropSelected: (count) => _addDrop(ref, count),
                onPieceCountChanged: (count) => ref.read(uiStateProvider.notifier).setPiecesPickedUp(count),
                onConfirmMove: () => _confirmMove(ref),
                onCancel: () => ref.read(uiStateProvider.notifier).reset(),
              ),

              // Piece counts
              _PieceCountsBar(gameState: gameState),

              // Version footer
              const VersionFooter(),
            ],
          ),

          // Win overlay
          if (isGameOver)
            _WinOverlay(
              result: gameState.result!,
              winReason: gameState.winReason,
              onNewGame: () => _showNewGameDialog(context, ref),
              onHome: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }

  void _handleCellTap(BuildContext context, WidgetRef ref, Position pos) {
    final gameState = ref.read(gameStateProvider);
    final uiState = ref.read(uiStateProvider);
    final uiNotifier = ref.read(uiStateProvider.notifier);

    if (gameState.isGameOver) return;

    final stack = gameState.board.stackAt(pos);

    // If already in piece selection mode and tapping same cell, cancel
    if (uiState.mode == InteractionMode.selectingPieceType &&
        uiState.selectedPosition == pos) {
      uiNotifier.reset();
      return;
    }

    // If tapping empty cell, go to piece selection
    if (stack.isEmpty) {
      uiNotifier.selectCell(pos);
      return;
    }

    // If tapping own stack in playing phase, select for movement
    if (!gameState.isOpeningPhase &&
        stack.controller == gameState.currentPlayer) {
      // If already selected this stack, deselect
      if (uiState.selectedPosition == pos &&
          uiState.mode == InteractionMode.selectingMoveDirection) {
        uiNotifier.reset();
        return;
      }
      // Max pieces to pick up is min(stack height, board size)
      final maxPieces = stack.height > gameState.boardSize
          ? gameState.boardSize
          : stack.height;
      uiNotifier.selectStack(pos, maxPieces);
      return;
    }
  }

  void _placePiece(WidgetRef ref, PieceType type) {
    final uiState = ref.read(uiStateProvider);
    final pos = uiState.selectedPosition;
    if (pos == null) return;

    ref.read(gameStateProvider.notifier).placePiece(pos, type);
    ref.read(uiStateProvider.notifier).reset();
  }

  void _selectDirection(WidgetRef ref, Direction dir) {
    ref.read(uiStateProvider.notifier).selectDirection(dir);
  }

  void _addDrop(WidgetRef ref, int count) {
    ref.read(uiStateProvider.notifier).addDrop(count);
  }

  void _confirmMove(WidgetRef ref) {
    final uiState = ref.read(uiStateProvider);
    final pos = uiState.selectedPosition;
    final dir = uiState.selectedDirection;
    final drops = uiState.drops;

    if (pos == null || dir == null || drops.isEmpty) return;

    ref.read(gameStateProvider.notifier).moveStack(pos, dir, drops);
    ref.read(uiStateProvider.notifier).reset();
  }

  void _showNewGameDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Game'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select board size:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int size = 3; size <= 8; size++)
                  ElevatedButton(
                    onPressed: () {
                      ref.read(gameStateProvider.notifier).newGame(size);
                      ref.read(uiStateProvider.notifier).reset();
                      Navigator.pop(context);
                    },
                    child: Text('${size}x$size'),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Game info bar showing current player and phase
class _GameInfoBar extends StatelessWidget {
  final GameState gameState;

  const _GameInfoBar({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final isWhite = gameState.currentPlayer == PlayerColor.white;
    final bgColor = isWhite ? Colors.grey.shade200 : Colors.grey.shade800;
    final textColor = isWhite ? Colors.black : Colors.white;
    final secondaryColor = isWhite ? Colors.black54 : Colors.white70;

    String statusText;
    if (gameState.isGameOver) {
      statusText = _resultText(gameState.result!);
    } else if (gameState.isOpeningPhase) {
      statusText = "Place opponent's flat stone";
    } else {
      statusText = 'Place or move';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bgColor,
      child: Row(
        children: [
          // Current player indicator
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isWhite ? Colors.white : Colors.black,
              border: Border.all(
                color: isWhite ? Colors.black : Colors.white,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${gameState.currentPlayer.name.toUpperCase()}\'S TURN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: secondaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Turn ${gameState.turnNumber}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _resultText(GameResult result) {
    return switch (result) {
      GameResult.whiteWins => 'White Wins!',
      GameResult.blackWins => 'Black Wins!',
      GameResult.draw => 'Draw!',
    };
  }
}

/// The game board grid
class _GameBoard extends StatelessWidget {
  final GameState gameState;
  final UIState uiState;
  final Function(Position) onCellTap;

  const _GameBoard({
    required this.gameState,
    required this.uiState,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final dropPath = uiState.getDropPath();
    final nextDropPos = uiState.getCurrentHandPosition();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gameState.boardSize,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: gameState.boardSize * gameState.boardSize,
      itemBuilder: (context, index) {
        final row = index ~/ gameState.boardSize;
        final col = index % gameState.boardSize;
        final pos = Position(row, col);
        final stack = gameState.board.stackAt(pos);
        final isSelected = uiState.selectedPosition == pos;
        final isInDropPath = dropPath.contains(pos);
        final isNextDrop = nextDropPos == pos;

        return GestureDetector(
          onTap: () => onCellTap(pos),
          child: _BoardCell(
            stack: stack,
            isSelected: isSelected,
            isInDropPath: isInDropPath,
            isNextDrop: isNextDrop,
            canSelect: !gameState.isGameOver,
          ),
        );
      },
    );
  }
}

/// A single cell on the board
class _BoardCell extends StatelessWidget {
  final PieceStack stack;
  final bool isSelected;
  final bool isInDropPath;
  final bool isNextDrop;
  final bool canSelect;

  const _BoardCell({
    required this.stack,
    required this.isSelected,
    this.isInDropPath = false,
    this.isNextDrop = false,
    required this.canSelect,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Border? border;

    if (isSelected) {
      bgColor = Colors.amber.shade200;
      border = Border.all(color: Colors.amber.shade700, width: 3);
    } else if (isNextDrop) {
      bgColor = Colors.green.shade200;
      border = Border.all(color: Colors.green.shade600, width: 2);
    } else if (isInDropPath) {
      bgColor = Colors.blue.shade100;
      border = Border.all(color: Colors.blue.shade400, width: 2);
    } else {
      bgColor = Colors.brown.shade100;
      border = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: border,
      ),
      child: Center(
        child: _buildStackDisplay(stack),
      ),
    );
  }

  Widget _buildStackDisplay(PieceStack stack) {
    if (stack.isEmpty) return const SizedBox();

    final top = stack.topPiece!;
    final color = top.color == PlayerColor.white ? Colors.white : Colors.black;
    final borderColor =
        top.color == PlayerColor.white ? Colors.black : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth;
        final pieceSize = cellSize * 0.7;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Stack height indicator
            if (stack.height > 1)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.brown.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${stack.height}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Piece display
            Container(
              width: pieceSize,
              height: top.type == PieceType.standing ? pieceSize : pieceSize * 0.6,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: borderColor, width: 2),
                borderRadius: top.type == PieceType.capstone
                    ? BorderRadius.circular(pieceSize / 2)
                    : BorderRadius.circular(4),
                boxShadow: top.type == PieceType.standing
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          offset: const Offset(2, 2),
                          blurRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: top.type == PieceType.capstone
                  ? Center(
                      child: Container(
                        width: pieceSize * 0.3,
                        height: pieceSize * 0.3,
                        decoration: BoxDecoration(
                          color: borderColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }
}

/// Bottom controls panel - changes based on interaction mode
class _BottomControls extends StatelessWidget {
  final GameState gameState;
  final UIState uiState;
  final Function(PieceType) onPieceSelected;
  final Function(Direction) onDirectionSelected;
  final Function(int) onDropSelected;
  final Function(int) onPieceCountChanged;
  final VoidCallback onConfirmMove;
  final VoidCallback onCancel;

  const _BottomControls({
    required this.gameState,
    required this.uiState,
    required this.onPieceSelected,
    required this.onDirectionSelected,
    required this.onDropSelected,
    required this.onPieceCountChanged,
    required this.onConfirmMove,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (gameState.isGameOver) {
      return const SizedBox(height: 80);
    }

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        border: Border(
          top: BorderSide(color: Colors.brown.shade200),
        ),
      ),
      child: _buildControls(context),
    );
  }

  Widget _buildControls(BuildContext context) {
    switch (uiState.mode) {
      case InteractionMode.idle:
        return _buildIdleHint();
      case InteractionMode.selectingPieceType:
        return _buildPieceSelector();
      case InteractionMode.selectingMoveDirection:
        return _buildDirectionSelector();
      case InteractionMode.selectingDrops:
        return _buildDropSelector();
    }
  }

  Widget _buildIdleHint() {
    final hint = gameState.isOpeningPhase
        ? 'Tap an empty cell to place opponent\'s flat stone'
        : 'Tap empty cell to place, or tap your stack to move';

    return Center(
      child: Text(
        hint,
        style: TextStyle(
          color: Colors.brown.shade600,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPieceSelector() {
    final pieces = gameState.currentPlayerPieces;
    final isOpening = gameState.isOpeningPhase;

    // During opening, only flat stones allowed
    if (isOpening) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PieceButton(
            type: PieceType.flat,
            count: pieces.flatStones,
            onTap: () => onPieceSelected(PieceType.flat),
            isEnabled: true,
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _PieceButton(
          type: PieceType.flat,
          count: pieces.flatStones,
          onTap: pieces.flatStones > 0 ? () => onPieceSelected(PieceType.flat) : null,
          isEnabled: pieces.flatStones > 0,
        ),
        _PieceButton(
          type: PieceType.standing,
          count: pieces.flatStones,
          label: 'Wall',
          onTap: pieces.flatStones > 0 ? () => onPieceSelected(PieceType.standing) : null,
          isEnabled: pieces.flatStones > 0,
        ),
        _PieceButton(
          type: PieceType.capstone,
          count: pieces.capstones,
          onTap: pieces.capstones > 0 ? () => onPieceSelected(PieceType.capstone) : null,
          isEnabled: pieces.capstones > 0,
        ),
        IconButton(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
        ),
      ],
    );
  }

  Widget _buildDirectionSelector() {
    final pos = uiState.selectedPosition!;
    final boardSize = gameState.boardSize;
    final stackHeight = gameState.board.stackAt(pos).height;
    final maxPickup = stackHeight > boardSize ? boardSize : stackHeight;

    // Check which directions are valid
    final canUp = pos.row > 0 && _canMoveInDirection(Direction.up);
    final canDown = pos.row < boardSize - 1 && _canMoveInDirection(Direction.down);
    final canLeft = pos.col > 0 && _canMoveInDirection(Direction.left);
    final canRight = pos.col < boardSize - 1 && _canMoveInDirection(Direction.right);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Piece count selector
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pick up', style: TextStyle(fontSize: 12, color: Colors.brown.shade600)),
            _PieceCountSelector(
              current: uiState.piecesPickedUp,
              max: maxPickup,
              onChanged: onPieceCountChanged,
            ),
          ],
        ),
        const SizedBox(width: 24),
        // Direction arrows
        SizedBox(
          width: 120,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: _DirectionButton(
                  direction: Direction.up,
                  icon: Icons.arrow_upward,
                  enabled: canUp,
                  onTap: canUp ? () => onDirectionSelected(Direction.up) : null,
                ),
              ),
              Positioned(
                bottom: 0,
                child: _DirectionButton(
                  direction: Direction.down,
                  icon: Icons.arrow_downward,
                  enabled: canDown,
                  onTap: canDown ? () => onDirectionSelected(Direction.down) : null,
                ),
              ),
              Positioned(
                left: 0,
                child: _DirectionButton(
                  direction: Direction.left,
                  icon: Icons.arrow_back,
                  enabled: canLeft,
                  onTap: canLeft ? () => onDirectionSelected(Direction.left) : null,
                ),
              ),
              Positioned(
                right: 0,
                child: _DirectionButton(
                  direction: Direction.right,
                  icon: Icons.arrow_forward,
                  enabled: canRight,
                  onTap: canRight ? () => onDirectionSelected(Direction.right) : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
        ),
      ],
    );
  }

  bool _canMoveInDirection(Direction dir) {
    final pos = uiState.selectedPosition!;
    final stack = gameState.board.stackAt(pos);
    if (stack.isEmpty) return false;

    final newPos = dir.apply(pos);
    if (!gameState.board.isValidPosition(newPos)) return false;

    final targetStack = gameState.board.stackAt(newPos);
    final topPiece = stack.topPiece!;

    return targetStack.canMoveOnto(topPiece);
  }

  Widget _buildDropSelector() {
    final remaining = uiState.piecesPickedUp;
    final drops = uiState.drops;
    final canConfirm = remaining == 0 && drops.isNotEmpty;

    // Check if we can continue moving after this drop
    final canContinue = _canContinueAfterDrop();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                drops.isEmpty ? 'Choose how many to drop' : 'Drops: ${drops.join(' → ')}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'Holding: $remaining piece${remaining == 1 ? '' : 's'}${!canContinue && remaining > 0 ? ' (must drop all)' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: !canContinue && remaining > 0 ? Colors.red.shade600 : Colors.brown.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Drop count buttons - limit shown buttons
        if (remaining > 0) ...[
          for (int i = 1; i <= remaining && i <= 3; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _DropButton(
                count: i,
                onTap: () => onDropSelected(i),
                enabled: canContinue || i == remaining,
              ),
            ),
          if (remaining > 3)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _DropButton(
                count: remaining,
                label: 'All ($remaining)',
                onTap: () => onDropSelected(remaining),
                enabled: true,
              ),
            ),
        ],
        const SizedBox(width: 8),
        if (canConfirm)
          ElevatedButton(
            onPressed: onConfirmMove,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          )
        else
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
          ),
      ],
    );
  }

  /// Check if we can continue moving after the current drops
  bool _canContinueAfterDrop() {
    final pos = uiState.selectedPosition;
    final dir = uiState.selectedDirection;
    if (pos == null || dir == null) return false;

    // Calculate current position after all drops so far
    var currentPos = pos;
    for (var i = 0; i < uiState.drops.length; i++) {
      currentPos = dir.apply(currentPos);
    }

    // Check if the next position is valid
    final nextPos = dir.apply(currentPos);
    if (!gameState.board.isValidPosition(nextPos)) return false;

    // Check if we can move onto the next cell
    final stack = gameState.board.stackAt(pos);
    if (stack.isEmpty) return false;

    final targetStack = gameState.board.stackAt(nextPos);
    final topPiece = stack.topPiece!;

    return targetStack.canMoveOnto(topPiece);
  }
}

class _PieceButton extends StatelessWidget {
  final PieceType type;
  final int count;
  final String? label;
  final VoidCallback? onTap;
  final bool isEnabled;

  const _PieceButton({
    required this.type,
    required this.count,
    this.label,
    required this.onTap,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? type.name[0].toUpperCase() + type.name.substring(1);

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.brown.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PieceIcon(type: type, size: 24),
              const SizedBox(height: 4),
              Text(
                displayLabel,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                '($count)',
                style: TextStyle(fontSize: 10, color: Colors.brown.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PieceIcon extends StatelessWidget {
  final PieceType type;
  final double size;

  const _PieceIcon({required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case PieceType.flat:
        return Container(
          width: size,
          height: size * 0.6,
          decoration: BoxDecoration(
            color: Colors.brown.shade200,
            border: Border.all(color: Colors.brown.shade600),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      case PieceType.standing:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.brown.shade200,
            border: Border.all(color: Colors.brown.shade600),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                offset: const Offset(2, 2),
              ),
            ],
          ),
        );
      case PieceType.capstone:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.brown.shade200,
            border: Border.all(color: Colors.brown.shade600),
            shape: BoxShape.circle,
          ),
        );
    }
  }
}

class _DirectionButton extends StatelessWidget {
  final Direction direction;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _DirectionButton({
    required this.direction,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.3,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: enabled ? Colors.blue.shade100 : Colors.grey.shade200,
          foregroundColor: enabled ? Colors.blue.shade800 : Colors.grey,
        ),
        iconSize: 20,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _DropButton extends StatelessWidget {
  final int count;
  final String? label;
  final VoidCallback onTap;
  final bool enabled;

  const _DropButton({
    required this.count,
    this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onTap : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(40, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(label ?? '$count'),
    );
  }
}

class _PieceCountSelector extends StatelessWidget {
  final int current;
  final int max;
  final Function(int) onChanged;

  const _PieceCountSelector({
    required this.current,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: current > 1 ? () => onChanged(current - 1) : null,
          icon: const Icon(Icons.remove, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: Colors.brown.shade200,
            foregroundColor: Colors.brown.shade800,
            minimumSize: const Size(28, 28),
            padding: EdgeInsets.zero,
          ),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.brown.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '$current',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        IconButton(
          onPressed: current < max ? () => onChanged(current + 1) : null,
          icon: const Icon(Icons.add, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: Colors.brown.shade200,
            foregroundColor: Colors.brown.shade800,
            minimumSize: const Size(28, 28),
            padding: EdgeInsets.zero,
          ),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }
}

/// Piece counts bar at bottom
class _PieceCountsBar extends StatelessWidget {
  final GameState gameState;

  const _PieceCountsBar({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _PlayerPieceCounts(
            label: 'White',
            pieces: gameState.whitePieces,
            color: Colors.white,
            isCurrentPlayer: gameState.currentPlayer == PlayerColor.white,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade300,
          ),
          _PlayerPieceCounts(
            label: 'Black',
            pieces: gameState.blackPieces,
            color: Colors.black,
            isCurrentPlayer: gameState.currentPlayer == PlayerColor.black,
          ),
        ],
      ),
    );
  }
}

class _PlayerPieceCounts extends StatelessWidget {
  final String label;
  final PlayerPieces pieces;
  final Color color;
  final bool isCurrentPlayer;

  const _PlayerPieceCounts({
    required this.label,
    required this.pieces,
    required this.color,
    required this.isCurrentPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = color == Colors.white ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: isCurrentPlayer
          ? BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flat stone icon
              Container(
                width: 18,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: borderColor, width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${pieces.flatStones}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              // Capstone icon
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: borderColor, width: 1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${pieces.capstones}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Win overlay shown when game ends
class _WinOverlay extends StatelessWidget {
  final GameResult result;
  final WinReason? winReason;
  final VoidCallback onNewGame;
  final VoidCallback onHome;

  const _WinOverlay({
    required this.result,
    required this.winReason,
    required this.onNewGame,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final (title, color) = switch (result) {
      GameResult.whiteWins => ('White Wins!', Colors.white),
      GameResult.blackWins => ('Black Wins!', Colors.black),
      GameResult.draw => ('Draw!', Colors.grey),
    };

    final reasonText = switch (winReason) {
      WinReason.road => 'by building a road',
      WinReason.flats => 'by flat count',
      null => '',
    };

    final textColor = result == GameResult.blackWins ? Colors.white : Colors.black;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(
                      color: result == GameResult.draw
                          ? Colors.grey.shade600
                          : (result == GameResult.whiteWins ? Colors.black : Colors.white),
                      width: 4,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    winReason == WinReason.road ? Icons.route : Icons.emoji_events,
                    size: 40,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (reasonText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    reasonText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onHome,
                      icon: const Icon(Icons.home),
                      label: const Text('Home'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: onNewGame,
                      icon: const Icon(Icons.refresh),
                      label: const Text('New Game'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Version footer shown at the bottom of all pages
class VersionFooter extends StatelessWidget {
  const VersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final commitUrl = AppVersion.commitUrl;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: commitUrl != null
            ? MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _launchUrl(commitUrl),
                  child: Text(
                    AppVersion.displayVersion,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.grey.shade400,
                    ),
                  ),
                ),
              )
            : Text(
                AppVersion.displayVersion,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
