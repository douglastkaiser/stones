import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'providers/providers.dart';
import 'models/models.dart';
import 'services/services.dart';
import 'theme/theme.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: GameColors.themeSeed),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Home screen with settings and start game
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize sound manager
    _initializeSounds();
  }

  Future<void> _initializeSounds() async {
    final soundManager = ref.read(soundManagerProvider);
    await soundManager.initialize();
    // Sync mute state with provider
    ref.read(isMutedProvider.notifier).state = soundManager.isMuted;
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = ref.watch(isMutedProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Sound toggle in top right
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    color: GameColors.subtitleColor,
                  ),
                  tooltip: isMuted ? 'Unmute sounds' : 'Mute sounds',
                  onPressed: () async {
                    final soundManager = ref.read(soundManagerProvider);
                    await soundManager.toggleMute();
                    ref.read(isMutedProvider.notifier).state = soundManager.isMuted;
                  },
                ),
              ),
            ),
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
                              color: GameColors.titleColor,
                              letterSpacing: 8,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A game of roads and flats',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: GameColors.subtitleColor,
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
              style: const TextStyle(
                fontSize: 12,
                color: GameColors.subtitleColor,
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
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    // Set up road win callback
    ref.read(gameStateProvider.notifier).onRoadWin = (roadPositions, winner) {
      ref.read(animationStateProvider.notifier).roadWin(roadPositions, winner);
    };
  }

  @override
  void dispose() {
    ref.read(gameStateProvider.notifier).onRoadWin = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final uiState = ref.watch(uiStateProvider);
    final isGameOver = ref.watch(isGameOverProvider);
    final animationState = ref.watch(animationStateProvider);
    final isMuted = ref.watch(isMutedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stones'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
            tooltip: isMuted ? 'Unmute sounds' : 'Mute sounds',
            onPressed: () async {
              final soundManager = ref.read(soundManagerProvider);
              await soundManager.toggleMute();
              ref.read(isMutedProvider.notifier).state = soundManager.isMuted;
            },
          ),
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
                        // Wooden frame gradient
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            GameColors.boardFrameInner,
                            GameColors.boardFrameOuter,
                            GameColors.boardFrameInner,
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: GameColors.boardFrameOuter,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(2, 4),
                          ),
                          BoxShadow(
                            color: GameColors.boardFrameInner.withValues(alpha: 0.5),
                            blurRadius: 2,
                            offset: const Offset(-1, -1),
                          ),
                        ],
                      ),
                      child: _GameBoard(
                        gameState: gameState,
                        uiState: uiState,
                        animationState: animationState,
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

    final gameState = ref.read(gameStateProvider);
    final color = gameState.isOpeningPhase ? gameState.opponent : gameState.currentPlayer;
    final soundManager = ref.read(soundManagerProvider);

    final success = ref.read(gameStateProvider.notifier).placePiece(pos, type);
    if (success) {
      ref.read(animationStateProvider.notifier).piecePlaced(pos, type, color);
      soundManager.playPiecePlace();
      // Check if this move caused a win
      if (ref.read(isGameOverProvider)) {
        soundManager.playWin();
      }
    } else {
      soundManager.playIllegalMove();
    }
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

    // Calculate drop positions for animation
    final dropPositions = <Position>[];
    var currentPos = pos;
    for (var i = 0; i < drops.length; i++) {
      currentPos = dir.apply(currentPos);
      dropPositions.add(currentPos);
    }

    // Check for wall flattening before the move
    final gameState = ref.read(gameStateProvider);
    final stack = gameState.board.stackAt(pos);
    final topPiece = stack.topPiece;
    Position? flattenedWallPos;
    if (topPiece != null && topPiece.canFlattenWalls && dropPositions.isNotEmpty) {
      final targetStack = gameState.board.stackAt(dropPositions.last);
      if (targetStack.topPiece?.type == PieceType.standing) {
        flattenedWallPos = dropPositions.last;
      }
    }

    final soundManager = ref.read(soundManagerProvider);
    final success = ref.read(gameStateProvider.notifier).moveStack(pos, dir, drops);
    if (success) {
      ref.read(animationStateProvider.notifier).stackMoved(pos, dir, drops, dropPositions);
      if (flattenedWallPos != null) {
        ref.read(animationStateProvider.notifier).wallFlattened(flattenedWallPos);
        soundManager.playWallFlatten();
      } else {
        soundManager.playStackMove();
      }
      // Check if this move caused a win
      if (ref.read(isGameOverProvider)) {
        soundManager.playWin();
      }
    } else {
      soundManager.playIllegalMove();
    }
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
                      ref.read(animationStateProvider.notifier).reset();
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
    final bgColor = isWhite ? GameColors.turnIndicatorLight : GameColors.turnIndicatorDark;
    final textColor = isWhite ? Colors.black : Colors.white;
    final secondaryColor = isWhite ? Colors.black54 : Colors.white70;
    final pieceColors = GameColors.forPlayer(isWhite);

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
              color: pieceColors.primary,
              border: Border.all(
                color: pieceColors.border,
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

/// The game board grid with wooden inset styling
class _GameBoard extends StatelessWidget {
  final GameState gameState;
  final UIState uiState;
  final AnimationState animationState;
  final Function(Position) onCellTap;

  const _GameBoard({
    required this.gameState,
    required this.uiState,
    required this.animationState,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final dropPath = uiState.getDropPath();
    final nextDropPos = uiState.getCurrentHandPosition();
    final boardSize = gameState.boardSize;

    // Calculate responsive spacing based on board size
    // Larger boards get smaller spacing to fit well
    final spacing = boardSize <= 4 ? 6.0 : (boardSize <= 6 ? 5.0 : 4.0);
    final padding = boardSize <= 4 ? 10.0 : (boardSize <= 6 ? 8.0 : 6.0);

    return Container(
      // Inner board area with inset shadow effect
      margin: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: GameColors.gridLine,
        borderRadius: BorderRadius.circular(6),
        // Inset shadow effect for the grid area
        boxShadow: [
          // Inner shadow (dark)
          BoxShadow(
            color: GameColors.gridLineShadow.withValues(alpha: 0.6),
            blurRadius: 4,
            spreadRadius: 1,
            offset: const Offset(2, 2),
          ),
          // Highlight edge
          BoxShadow(
            color: GameColors.gridLineHighlight.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(spacing),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: boardSize,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: boardSize * boardSize,
          itemBuilder: (context, index) {
            final row = index ~/ boardSize;
            final col = index % boardSize;
            final pos = Position(row, col);
            final stack = gameState.board.stackAt(pos);
            final isSelected = uiState.selectedPosition == pos;
            final isInDropPath = dropPath.contains(pos);
            final isNextDrop = nextDropPos == pos;

            // Check for animation events on this position
            final lastEvent = animationState.lastEvent;
            final isNewlyPlaced = lastEvent is PiecePlacedEvent && lastEvent.position == pos;
            final isInWinningRoad = animationState.winningRoad?.contains(pos) ?? false;

            // Check if this cell received pieces from a stack move
            bool isStackDropTarget = false;
            if (lastEvent is StackMovedEvent) {
              isStackDropTarget = lastEvent.dropPositions.contains(pos);
            }

            // Check for wall flattening
            bool wasWallFlattened = false;
            if (lastEvent is WallFlattenedEvent && lastEvent.position == pos) {
              wasWallFlattened = true;
            }

            return GestureDetector(
              onTap: () => onCellTap(pos),
              child: _BoardCell(
                key: ValueKey('cell_${pos.row}_${pos.col}_${stack.height}_${lastEvent?.timestamp.millisecondsSinceEpoch ?? 0}'),
                stack: stack,
                isSelected: isSelected,
                isInDropPath: isInDropPath,
                isNextDrop: isNextDrop,
                canSelect: !gameState.isGameOver,
                boardSize: boardSize,
                isNewlyPlaced: isNewlyPlaced,
                isInWinningRoad: isInWinningRoad,
                isStackDropTarget: isStackDropTarget,
                wasWallFlattened: wasWallFlattened,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A single cell on the board with wooden style and glow effects
class _BoardCell extends StatefulWidget {
  final PieceStack stack;
  final bool isSelected;
  final bool isInDropPath;
  final bool isNextDrop;
  final bool canSelect;
  final int boardSize;
  final bool isNewlyPlaced;
  final bool isInWinningRoad;
  final bool isStackDropTarget;
  final bool wasWallFlattened;

  const _BoardCell({
    super.key,
    required this.stack,
    required this.isSelected,
    this.isInDropPath = false,
    this.isNextDrop = false,
    required this.canSelect,
    required this.boardSize,
    this.isNewlyPlaced = false,
    this.isInWinningRoad = false,
    this.isStackDropTarget = false,
    this.wasWallFlattened = false,
  });

  @override
  State<_BoardCell> createState() => _BoardCellState();
}

class _BoardCellState extends State<_BoardCell> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _placementController;
  late AnimationController _slideController;
  late AnimationController _flattenController;
  late AnimationController _winPulseController;

  // Animations
  late Animation<double> _placementScale;
  late Animation<double> _slideScale;
  late Animation<double> _flattenScale;
  late Animation<double> _winPulse;

  @override
  void initState() {
    super.initState();

    // Placement animation: scale with bounce (200ms)
    _placementController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _placementScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _placementController,
        curve: Curves.elasticOut,
      ),
    );

    // Slide animation: scale in from direction (150ms)
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _slideScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      ),
    );

    // Flatten animation: quick squash (150ms)
    _flattenController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _flattenScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _flattenController,
      curve: Curves.easeInOut,
    ));

    // Win pulse animation: continuous glow (800ms loop)
    _winPulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _winPulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _winPulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations based on initial state
    if (widget.isNewlyPlaced) {
      _placementController.forward();
    }
    if (widget.isStackDropTarget) {
      _slideController.forward();
    }
    if (widget.wasWallFlattened) {
      _flattenController.forward();
    }
    if (widget.isInWinningRoad) {
      _winPulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_BoardCell oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger placement animation
    if (widget.isNewlyPlaced && !oldWidget.isNewlyPlaced) {
      _placementController.forward(from: 0);
    }

    // Trigger slide animation
    if (widget.isStackDropTarget && !oldWidget.isStackDropTarget) {
      _slideController.forward(from: 0);
    }

    // Trigger flatten animation
    if (widget.wasWallFlattened && !oldWidget.wasWallFlattened) {
      _flattenController.forward(from: 0);
    }

    // Start/stop win pulse
    if (widget.isInWinningRoad && !oldWidget.isInWinningRoad) {
      _winPulseController.repeat(reverse: true);
    } else if (!widget.isInWinningRoad && oldWidget.isInWinningRoad) {
      _winPulseController.stop();
      _winPulseController.reset();
    }
  }

  @override
  void dispose() {
    _placementController.dispose();
    _slideController.dispose();
    _flattenController.dispose();
    _winPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate responsive border radius based on board size
    final borderRadius = widget.boardSize <= 4 ? 6.0 : (widget.boardSize <= 6 ? 5.0 : 4.0);
    final borderWidth = widget.boardSize <= 4 ? 2.5 : (widget.boardSize <= 6 ? 2.0 : 1.5);

    // Build decoration based on state
    BoxDecoration decoration;

    if (widget.isSelected) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GameColors.cellSelected,
            GameColors.cellSelectedGlow,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: GameColors.cellSelectedBorder, width: borderWidth),
        boxShadow: [
          // Glow effect
          BoxShadow(
            color: GameColors.cellSelectedGlow.withValues(alpha: 0.6),
            blurRadius: 8,
            spreadRadius: 1,
          ),
          // Inner highlight
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(-1, -1),
          ),
        ],
      );
    } else if (widget.isNextDrop) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GameColors.cellNextDrop,
            GameColors.cellNextDropGlow,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: GameColors.cellNextDropBorder, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: GameColors.cellNextDropGlow.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      );
    } else if (widget.isInDropPath) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GameColors.cellDropPath,
            GameColors.cellDropPathGlow,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: GameColors.cellDropPathBorder, width: borderWidth * 0.8),
        boxShadow: [
          BoxShadow(
            color: GameColors.cellDropPathGlow.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      );
    } else {
      // Default wood-grain cell look
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GameColors.cellBackgroundLight,
            GameColors.cellBackground,
            GameColors.cellBackgroundDark,
          ],
          stops: [0.0, 0.4, 1.0],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        // Subtle inset effect
        boxShadow: [
          BoxShadow(
            color: GameColors.gridLineShadow.withValues(alpha: 0.3),
            blurRadius: 1,
            offset: const Offset(1, 1),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.5),
            blurRadius: 1,
            offset: const Offset(-0.5, -0.5),
          ),
        ],
      );
    }

    // Add winning road glow effect
    Widget cellContent = Container(
      decoration: decoration,
      child: Center(
        child: _buildStackDisplay(widget.stack),
      ),
    );

    // Wrap with win pulse animation if part of winning road
    if (widget.isInWinningRoad) {
      cellContent = AnimatedBuilder(
        animation: _winPulse,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: _winPulse.value * 0.8),
                  blurRadius: 12 * _winPulse.value,
                  spreadRadius: 2 * _winPulse.value,
                ),
              ],
            ),
            child: child,
          );
        },
        child: cellContent,
      );
    }

    return cellContent;
  }

  Widget _buildStackDisplay(PieceStack stack) {
    if (stack.isEmpty) return const SizedBox();

    final top = stack.topPiece!;
    final isLightPlayer = top.color == PlayerColor.white;
    final pieceColors = GameColors.forPlayer(isLightPlayer);
    final height = stack.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth;
        final pieceSize = cellSize * 0.7;

        Widget content;
        // For stacks, show depth visualization
        if (height > 1) {
          content = _buildStackWithDepth(stack, cellSize, pieceSize, pieceColors, isLightPlayer);
        } else {
          // Single piece - just show it centered
          content = _buildPiece(top.type, pieceSize, pieceColors, isLightPlayer);
        }

        // Apply placement animation (scale with bounce)
        if (widget.isNewlyPlaced) {
          content = ScaleTransition(
            scale: _placementScale,
            child: content,
          );
        }

        // Apply slide animation for stack drops
        if (widget.isStackDropTarget) {
          content = ScaleTransition(
            scale: _slideScale,
            child: content,
          );
        }

        // Apply flatten animation
        if (widget.wasWallFlattened) {
          content = AnimatedBuilder(
            animation: _flattenScale,
            builder: (context, child) {
              return Transform.scale(
                scaleY: _flattenScale.value,
                child: child,
              );
            },
            child: content,
          );
        }

        return content;
      },
    );
  }

  /// Build a stack visualization showing actual pieces stacked with depth
  Widget _buildStackWithDepth(
    PieceStack stack,
    double cellSize,
    double pieceSize,
    PieceColors topColors,
    bool isLightPlayer,
  ) {
    final height = stack.height;

    // Calculate responsive values based on board size
    // Vertical offset between pieces to show stacking
    final verticalOffset = widget.boardSize <= 4 ? 4.0 : (widget.boardSize <= 6 ? 3.5 : 3.0);
    final badgeFontSize = widget.boardSize <= 4 ? 10.0 : (widget.boardSize <= 6 ? 9.0 : 8.0);
    final badgePadding = widget.boardSize <= 4 ? 4.0 : (widget.boardSize <= 6 ? 3.0 : 2.5);

    // Show up to 3 pieces visually, use badge for taller stacks
    const maxVisiblePieces = 3;
    final visibleCount = height > maxVisiblePieces ? maxVisiblePieces : height;

    // Get the pieces to display (top N pieces of the stack)
    // pieces[0] is bottom, pieces[height-1] is top
    final startIndex = height - visibleCount;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Render pieces from bottom to top
        // Bottom pieces are rendered first (lower in visual stack)
        for (int i = 0; i < visibleCount; i++)
          Transform.translate(
            // Each piece moves up as we go higher in the stack
            // i=0 is the lowest visible piece, i=visibleCount-1 is the top
            offset: Offset(0, (visibleCount - 1 - i) * verticalOffset),
            child: _buildStackPiece(
              stack.pieces[startIndex + i],
              pieceSize,
              // Fade lower pieces slightly
              i < visibleCount - 1 ? 0.7 + (0.1 * i) : 1.0,
            ),
          ),

        // Stack height badge (always show for stacks > 1)
        Positioned(
          bottom: 1,
          right: 1,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: badgePadding,
              vertical: badgePadding * 0.5,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6D4C41),
                  GameColors.stackBadge,
                ],
              ),
              borderRadius: BorderRadius.circular(badgePadding),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(0.5, 0.5),
                ),
              ],
            ),
            child: Text(
              '$height',
              style: TextStyle(
                color: GameColors.stackBadgeText,
                fontSize: badgeFontSize,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 1,
                    offset: const Offset(0.5, 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build a single piece in a stack with optional opacity
  Widget _buildStackPiece(Piece piece, double pieceSize, double opacity) {
    final isLightPlayer = piece.color == PlayerColor.white;
    final pieceColors = GameColors.forPlayer(isLightPlayer);

    return Opacity(
      opacity: opacity,
      child: _buildPiece(piece.type, pieceSize, pieceColors, isLightPlayer),
    );
  }

  /// Build a piece widget based on type
  Widget _buildPiece(PieceType type, double size, PieceColors colors, bool isLightPlayer) {
    switch (type) {
      case PieceType.flat:
        return _buildFlatStone(size, colors, isLightPlayer);
      case PieceType.standing:
        return _buildStandingStone(size, colors);
      case PieceType.capstone:
        return _buildCapstone(size, colors);
    }
  }

  /// Flat stone: trapezoid for light, semi-circle for dark
  Widget _buildFlatStone(double size, PieceColors colors, bool isLightPlayer) {
    return CustomPaint(
      size: Size(size, size * 0.5),
      painter: isLightPlayer
          ? _TrapezoidPainter(colors: colors)
          : _SemiCirclePainter(colors: colors),
    );
  }

  /// Standing stone (wall): diagonal bar across the cell
  Widget _buildStandingStone(double size, PieceColors colors) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DiagonalWallPainter(colors: colors),
    );
  }

  /// Capstone: hexagon shape, slightly larger
  Widget _buildCapstone(double size, PieceColors colors) {
    final capSize = size * 0.85;
    return CustomPaint(
      size: Size(capSize, capSize),
      painter: _HexagonPainter(colors: colors),
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
      decoration: const BoxDecoration(
        color: GameColors.controlPanelBg,
        border: Border(
          top: BorderSide(color: GameColors.controlPanelBorder),
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
        style: const TextStyle(
          color: GameColors.subtitleColor,
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
            const Text('Pick up', style: TextStyle(fontSize: 12, color: GameColors.subtitleColor)),
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
                  color: !canContinue && remaining > 0 ? Colors.red.shade600 : GameColors.subtitleColor,
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
            border: Border.all(color: GameColors.controlPanelBorder),
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
                style: const TextStyle(fontSize: 10, color: GameColors.subtitleColor),
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
          height: size * 0.5,
          decoration: BoxDecoration(
            color: GameColors.pieceIconFill,
            border: Border.all(color: GameColors.pieceIconBorder),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: GameColors.flatStoneShadow,
                offset: const Offset(1, 1),
                blurRadius: 1,
              ),
            ],
          ),
        );
      case PieceType.standing:
        return Container(
          width: size * 0.4,
          height: size,
          decoration: BoxDecoration(
            color: GameColors.pieceIconFill,
            border: Border.all(color: GameColors.pieceIconBorder),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: GameColors.standingStoneShadow,
                offset: const Offset(2, 2),
                blurRadius: 2,
              ),
            ],
          ),
        );
      case PieceType.capstone:
        return CustomPaint(
          size: Size(size, size),
          painter: _HexagonIconPainter(),
        );
    }
  }
}

/// Simple hexagon painter for piece icons (neutral color)
class _HexagonIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final path = _createHexagonPath(center, radius * 0.85);

    // Fill
    final fillPaint = Paint()..color = GameColors.pieceIconFill;
    canvas.drawPath(path, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = GameColors.pieceIconBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, borderPaint);
  }

  Path _createHexagonPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
            backgroundColor: GameColors.pieceIconFill,
            foregroundColor: GameColors.pieceIconBorder,
            minimumSize: const Size(28, 28),
            padding: EdgeInsets.zero,
          ),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: GameColors.controlPanelBorder,
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
            backgroundColor: GameColors.pieceIconFill,
            foregroundColor: GameColors.pieceIconBorder,
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
            label: 'Light',
            pieces: gameState.whitePieces,
            isLightPlayer: true,
            isCurrentPlayer: gameState.currentPlayer == PlayerColor.white,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade300,
          ),
          _PlayerPieceCounts(
            label: 'Dark',
            pieces: gameState.blackPieces,
            isLightPlayer: false,
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
  final bool isLightPlayer;
  final bool isCurrentPlayer;

  const _PlayerPieceCounts({
    required this.label,
    required this.pieces,
    required this.isLightPlayer,
    required this.isCurrentPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final pieceColors = GameColors.forPlayer(isLightPlayer);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: isCurrentPlayer
          ? BoxDecoration(
              color: GameColors.currentPlayerHighlight,
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
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: pieceColors.gradientColors,
                  ),
                  border: Border.all(color: pieceColors.border, width: 1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${pieces.flatStones}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              // Capstone icon (small hexagon)
              CustomPaint(
                size: const Size(14, 14),
                painter: _SmallHexagonPainter(colors: pieceColors),
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

/// Small hexagon painter for piece count display
class _SmallHexagonPainter extends CustomPainter {
  final PieceColors colors;

  _SmallHexagonPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final path = _createHexagonPath(center, radius * 0.85);

    // Fill with gradient
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: colors.gradientColors,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, gradientPaint);

    // Border
    final borderPaint = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, borderPaint);
  }

  Path _createHexagonPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SmallHexagonPainter oldDelegate) {
    return oldDelegate.colors != colors;
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
    final (title, pieceColors) = switch (result) {
      GameResult.whiteWins => ('Light Wins!', GameColors.lightPlayerColors),
      GameResult.blackWins => ('Dark Wins!', GameColors.darkPlayerColors),
      GameResult.draw => ('Draw!', const PieceColors(
        primary: Colors.grey,
        secondary: Colors.grey,
        border: Color(0xFF757575),
      )),
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: pieceColors.gradientColors,
                    ),
                    border: Border.all(
                      color: pieceColors.border,
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

/// Trapezoid painter for light player flat stones
class _TrapezoidPainter extends CustomPainter {
  final PieceColors colors;

  _TrapezoidPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Trapezoid: wider at bottom, narrower at top
    final inset = w * 0.15;
    final path = Path()
      ..moveTo(inset, 0) // top left
      ..lineTo(w - inset, 0) // top right
      ..lineTo(w, h) // bottom right
      ..lineTo(0, h) // bottom left
      ..close();

    // Shadow
    final shadowPath = Path()
      ..moveTo(inset + 2, 2)
      ..lineTo(w - inset + 2, 2)
      ..lineTo(w + 2, h + 2)
      ..lineTo(2, h + 2)
      ..close();
    final shadowPaint = Paint()
      ..color = GameColors.flatStoneShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(shadowPath, shadowPaint);

    // Gradient fill
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors.gradientColors,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, gradientPaint);

    // Border
    final borderPaint = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TrapezoidPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

/// Semi-circle painter for dark player flat stones
/// The chord is slightly below the diameter (more than a half circle)
class _SemiCirclePainter extends CustomPainter {
  final PieceColors colors;

  _SemiCirclePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;

    // Semi-circle with chord below diameter (about 60% of circle showing)
    // The arc spans more than 180 degrees
    final radius = w * 0.5;
    final chordY = h * 0.1; // Where the chord (flat bottom) sits

    final path = Path();
    // Start from left side of chord
    path.moveTo(centerX - radius * 0.95, h - chordY);
    // Arc over the top
    path.arcToPoint(
      Offset(centerX + radius * 0.95, h - chordY),
      radius: Radius.circular(radius),
      largeArc: true,
    );
    // Close with the chord
    path.close();

    // Shadow
    canvas.save();
    canvas.translate(1, 2);
    final shadowPaint = Paint()
      ..color = GameColors.flatStoneShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Gradient fill
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors.gradientColors,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, gradientPaint);

    // Border
    final borderPaint = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SemiCirclePainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

/// Diagonal wall painter - a bar laying diagonally across the cell
class _DiagonalWallPainter extends CustomPainter {
  final PieceColors colors;

  _DiagonalWallPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Diagonal bar from bottom-left to top-right
    final barWidth = w * 0.25;
    final margin = w * 0.1;

    final path = Path()
      ..moveTo(margin, h - margin - barWidth) // bottom-left top corner
      ..lineTo(margin + barWidth, h - margin) // bottom-left bottom corner
      ..lineTo(w - margin, margin + barWidth) // top-right bottom corner
      ..lineTo(w - margin - barWidth, margin) // top-right top corner
      ..close();

    // Shadow (offset down-right)
    canvas.save();
    canvas.translate(2, 3);
    final shadowPaint = Paint()
      ..color = GameColors.standingStoneShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Gradient fill (along the diagonal)
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors.gradientColors,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, gradientPaint);

    // Border
    final borderPaint = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _DiagonalWallPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

/// Custom painter for hexagon-shaped capstone
class _HexagonPainter extends CustomPainter {
  final PieceColors colors;

  _HexagonPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Create hexagon path
    final path = _createHexagonPath(center, radius * 0.9);

    // Draw shadow
    final shadowPath = _createHexagonPath(
      Offset(center.dx + 2, center.dy + 2),
      radius * 0.9,
    );
    final shadowPaint = Paint()
      ..color = GameColors.capstoneShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(shadowPath, shadowPaint);

    // Draw gradient fill
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors.gradientColors,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, gradientPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);

    // Draw small inner circle for visual interest
    final innerCirclePaint = Paint()..color = colors.border.withValues(alpha: 0.3);
    canvas.drawCircle(center, radius * 0.25, innerCirclePaint);
  }

  Path _createHexagonPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      // Start from top point (rotate -90 degrees so flat side is at bottom)
      final angle = (i * 60 - 90) * math.pi / 180;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}
