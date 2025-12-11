import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'providers/providers.dart';
import 'models/models.dart';
import 'services/services.dart';
import 'theme/theme.dart';
import 'version.dart';
import 'screens/main_menu_screen.dart';
import 'firebase_options.dart';

void _debugLog(String message) {
  developer.log('[GAME] $message', name: 'game');
  // ignore: avoid_print
  print('[GAME] $message');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: StonesApp()));
}

class StonesApp extends ConsumerStatefulWidget {
  const StonesApp({super.key});

  @override
  ConsumerState<StonesApp> createState() => _StonesAppState();
}

class _StonesAppState extends ConsumerState<StonesApp> {
  @override
  void initState() {
    super.initState();
    // Load settings on app start
    ref.read(appSettingsProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      title: 'Stones',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: GameColors.themeSeed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: GameColors.themeSeed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: settings.themeMode,
      home: const MainMenuScreen(),
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
        onPressed: () => _startNewGame(context, ref),
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

  void _startNewGame(BuildContext context, WidgetRef ref) {
    final gameState = ref.read(gameStateProvider);
    final isGameInProgress = !gameState.isGameOver &&
        (gameState.turnNumber > 1 || gameState.board.occupiedPositions.isNotEmpty);

    if (isGameInProgress) {
      // Show confirmation dialog
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Start New Game?'),
          content: const Text(
            'You have a game in progress. Starting a new game will discard your current game.\n\nAre you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _doStartNewGame(context, ref);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start New Game'),
            ),
          ],
        ),
      );
    } else {
      _doStartNewGame(context, ref);
    }
  }

  void _doStartNewGame(BuildContext context, WidgetRef ref) {
    ref.read(gameStateProvider.notifier).newGame(size);
    ref.read(uiStateProvider.notifier).reset();
    ref.read(animationStateProvider.notifier).reset();
    ref.read(moveHistoryProvider.notifier).clear();
    ref.read(lastMoveProvider.notifier).state = null;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }
}

/// Main game screen
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _showHistory = false;

  // Long press stack view state
  Position? _longPressedPosition;
  PieceStack? _longPressedStack;

  void _startStackView(Position pos, PieceStack stack) {
    setState(() {
      _longPressedPosition = pos;
      _longPressedStack = stack;
    });
  }

  void _endStackView() {
    setState(() {
      _longPressedPosition = null;
      _longPressedStack = null;
    });
  }

  @override
  void initState() {
    super.initState();
    // Set up road win callback
    ref.read(gameStateProvider.notifier).onRoadWin = (roadPositions, winner) {
      ref.read(animationStateProvider.notifier).roadWin(roadPositions, winner);
    };

    ref.listen<GameState>(gameStateProvider, (previous, next) {
      unawaited(_maybeTriggerAiTurn(next));
      final moveCount = ref.read(moveHistoryProvider).length;
      unawaited(
        ref.read(playGamesServiceProvider.notifier).onGameStateChanged(
              next,
              previous: previous,
              moveCount: moveCount,
            ),
      );
    });

    // Listen for online game events (opponent moves/joins)
    ref.listen<OnlineGameState>(onlineGameProvider, (previous, next) {
      final soundManager = ref.read(soundManagerProvider);
      if (next.opponentJustJoined) {
        soundManager.playPiecePlace();
      }
      if (next.opponentJustMoved) {
        soundManager.playStackMove();
      }
    });
  }

  @override
  void dispose() {
    ref.read(gameStateProvider.notifier).onRoadWin = null;
    super.dispose();
  }

  void _undo() {
    if (ref.read(aiThinkingProvider)) return;
    final session = ref.read(gameSessionProvider);
    final gameState = ref.read(gameStateProvider);
    if (session.mode == GameMode.online) {
      return;
    }
    if (session.mode == GameMode.vsComputer && gameState.currentPlayer == PlayerColor.black) {
      return;
    }

    final gameNotifier = ref.read(gameStateProvider.notifier);
    if (gameNotifier.canUndo) {
      // Remove from move history
      ref.read(moveHistoryProvider.notifier).removeLast();
      // Undo game state
      gameNotifier.undo();
      // Reset UI state
      ref.read(uiStateProvider.notifier).reset();
      // Update last move highlight
      final history = ref.read(moveHistoryProvider);
      if (history.isNotEmpty) {
        ref.read(lastMoveProvider.notifier).state = history.last.affectedPositions;
      } else {
        ref.read(lastMoveProvider.notifier).state = null;
      }
      // Reset animation state
      ref.read(animationStateProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final uiState = ref.watch(uiStateProvider);
    final isGameOver = ref.watch(isGameOverProvider);
    final animationState = ref.watch(animationStateProvider);
    final isMuted = ref.watch(isMutedProvider);
    final moveHistory = ref.watch(moveHistoryProvider);
    final lastMovePositions = ref.watch(lastMoveProvider);
    final session = ref.watch(gameSessionProvider);
    final isAiThinking = ref.watch(aiThinkingProvider);
    final isAiTurn =
        session.mode == GameMode.vsComputer && gameState.currentPlayer == PlayerColor.black;
    final onlineState = ref.watch(onlineGameProvider);
    final isOnline = session.mode == GameMode.online;
    // FIX: Use LOCAL game state for turn enforcement instead of Firestore session
    // This prevents race condition where creator can play multiple moves before
    // Firestore listener updates session.currentTurn
    final isMyTurnLocally = isOnline && onlineState.localColor != null &&
        gameState.currentPlayer == onlineState.localColor;
    final isRemoteTurn = isOnline && !isMyTurnLocally;
    final waitingForOpponent = isOnline && onlineState.waitingForOpponent;
    final canUndo = !isOnline && ref.read(gameStateProvider.notifier).canUndo;
    final inputLocked = isAiTurn || isAiThinking || isRemoteTurn || waitingForOpponent;

    // Debug logging for turn enforcement
    if (isOnline) {
      _debugLog('>>> GAME SCREEN BUILD (ONLINE MODE) <<<');
      _debugLog('localColor=${onlineState.localColor}, roomCode=${onlineState.roomCode}');
      _debugLog('session.currentTurn=${onlineState.session?.currentTurn}, session.moves=${onlineState.session?.moves.length ?? 0}');
      _debugLog('LOCAL gameState: currentPlayer=${gameState.currentPlayer}, turnNumber=${gameState.turnNumber}');
      _debugLog('LOCAL board: occupiedCells=${gameState.board.occupiedPositions.length}');
      _debugLog('appliedMoveCount=${onlineState.appliedMoveCount}');
      _debugLog('isMyTurnLocally=$isMyTurnLocally, isRemoteTurn=$isRemoteTurn');
      _debugLog('waitingForOpponent=$waitingForOpponent, inputLocked=$inputLocked');
      _debugLog('>>> END GAME SCREEN BUILD <<<');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stones'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Undo button
          IconButton(
            icon: Icon(
              Icons.undo,
              color: canUndo ? null : Colors.grey.shade400,
            ),
            tooltip: canUndo ? 'Undo last move' : 'No moves to undo',
            onPressed: canUndo ? _undo : null,
          ),
          // History toggle button
          IconButton(
            icon: Icon(_showHistory ? Icons.history_toggle_off : Icons.history),
            tooltip: _showHistory ? 'Hide move history' : 'Show move history',
            onPressed: () => setState(() => _showHistory = !_showHistory),
          ),
          if (session.mode == GameMode.online)
            IconButton(
              icon: const Icon(Icons.flag),
              tooltip: 'Resign',
              onPressed: () => _confirmResign(context),
            ),
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
            onPressed: session.mode == GameMode.online
                ? null
                : () => _showNewGameDialog(context, ref),
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              // Main game area
              Expanded(
                child: Column(
                  children: [
                    // Game info bar
                    _GameInfoBar(
                      gameState: gameState,
                      isAiTurn: isAiTurn,
                      isThinking: isAiThinking,
                      aiDifficulty:
                          session.mode == GameMode.vsComputer ? session.aiDifficulty : null,
                      onlineState: isOnline ? onlineState : null,
                    ),

                    // Chess clock (only for local games when enabled)
                    if (session.mode == GameMode.local)
                      Consumer(
                        builder: (context, ref, _) {
                          final settings = ref.watch(appSettingsProvider);
                          if (!settings.chessClockEnabled) return const SizedBox.shrink();
                          return _ChessClockDisplay(
                            currentPlayer: gameState.currentPlayer,
                            isGameOver: gameState.isGameOver,
                          );
                        },
                      ),

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
                            child: IgnorePointer(
                              ignoring: inputLocked,
                              child: _GameBoard(
                                gameState: gameState,
                                uiState: uiState,
                                animationState: animationState,
                                lastMovePositions: lastMovePositions,
                                onCellTap: (pos) => _handleCellTap(context, ref, pos),
                                onLongPressStart: _startStackView,
                                onLongPressEnd: _endStackView,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom controls
                    IgnorePointer(
                      ignoring: inputLocked,
                      child: _BottomControls(
                        gameState: gameState,
                        uiState: uiState,
                        onPieceTypeChanged: (type) =>
                            ref.read(uiStateProvider.notifier).setGhostPieceType(type),
                        onConfirmMove: () => _confirmMove(ref),
                        onCancel: () => ref.read(uiStateProvider.notifier).reset(),
                      ),
                    ),

                    // Piece counts
                    _PieceCountsBar(gameState: gameState),

                    // Version footer
                    const VersionFooter(),
                  ],
                ),
              ),

              // Move history panel (collapsible sidebar)
              if (_showHistory)
                _MoveHistoryPanel(
                  moveHistory: moveHistory,
                  boardSize: gameState.boardSize,
                  onClose: () => setState(() => _showHistory = false),
                ),
            ],
          ),

          // Stack exploded view overlay (press and hold)
          if (_longPressedPosition != null && _longPressedStack != null)
            _StackExplodedOverlay(
              position: _longPressedPosition!,
              stack: _longPressedStack!,
              boardSize: gameState.boardSize,
            ),

          // Win overlay removed - now using _WinBanner in _GameInfoBar instead
          if (session.mode == GameMode.online && waitingForOpponent)
            _OnlineStatusBanner(
              message:
                  'Waiting for opponent... Room code: ${onlineState.roomCode ?? '---'}',
              icon: Icons.hourglass_empty,
            ),
          if (session.mode == GameMode.online &&
              onlineState.opponentDisconnected &&
              !onlineState.opponentInactive)
            const _OnlineStatusBanner(
              message: 'Opponent may have disconnected (no activity for 60s)',
              icon: Icons.wifi_off,
              color: Colors.orange,
            ),
          if (session.mode == GameMode.online && onlineState.opponentInactive)
            const _OnlineStatusBanner(
              message: 'Opponent disconnected (no activity for 2+ minutes)',
              icon: Icons.error_outline,
              color: Colors.red,
            ),
        ],
      ),
    );
  }

  void _handleCellTap(BuildContext context, WidgetRef ref, Position pos) {
    _debugLog('_handleCellTap: pos=$pos');
    final gameState = ref.read(gameStateProvider);
    final uiState = ref.read(uiStateProvider);
    final uiNotifier = ref.read(uiStateProvider.notifier);
    final session = ref.read(gameSessionProvider);

    // Online turn check
    if (session.mode == GameMode.online) {
      final onlineState = ref.read(onlineGameProvider);
      final isMyTurnLocally = onlineState.localColor != null &&
          gameState.currentPlayer == onlineState.localColor;
      _debugLog('_handleCellTap: ONLINE check - localColor=${onlineState.localColor}, '
          'localGameTurn=${gameState.currentPlayer}, '
          'isMyTurnLocally=$isMyTurnLocally, '
          'waitingForOpponent=${onlineState.waitingForOpponent}');
      if (!isMyTurnLocally || onlineState.waitingForOpponent) {
        _debugLog('_handleCellTap: BLOCKED - not local turn or waiting for opponent');
        uiNotifier.reset();
        return;
      }
      _debugLog('_handleCellTap: ALLOWED - is local turn');
    }

    // AI turn check
    final isAiTurn =
        session.mode == GameMode.vsComputer && gameState.currentPlayer == PlayerColor.black;
    if (gameState.isGameOver || isAiTurn || ref.read(aiThinkingProvider)) {
      uiNotifier.reset();
      return;
    }

    final stack = gameState.board.stackAt(pos);

    // Handle based on current interaction mode
    switch (uiState.mode) {
      case InteractionMode.idle:
        _handleIdleTap(ref, pos, stack, gameState);

      case InteractionMode.placingPiece:
        _handlePlacingPieceTap(ref, pos, stack, gameState, uiState);

      case InteractionMode.movingStack:
        _handleMovingStackTap(ref, pos, stack, gameState, uiState);

      case InteractionMode.droppingPieces:
        _handleDroppingPiecesTap(ref, pos, stack, gameState, uiState);
    }
  }

  /// Handle tap when in idle mode
  void _handleIdleTap(WidgetRef ref, Position pos, PieceStack stack, GameState gameState) {
    final uiNotifier = ref.read(uiStateProvider.notifier);

    if (stack.isEmpty) {
      // Tap empty cell: show ghost piece for placement
      uiNotifier.selectCellForPlacement(pos);
      return;
    }

    // Tap own stack: select for movement
    if (!gameState.isOpeningPhase && stack.controller == gameState.currentPlayer) {
      final maxPieces = stack.height > gameState.boardSize
          ? gameState.boardSize
          : stack.height;
      uiNotifier.selectStack(pos, maxPieces);
      return;
    }

    // Tap opponent's stack: do nothing
  }

  /// Handle tap when placing a piece (ghost piece showing)
  void _handlePlacingPieceTap(WidgetRef ref, Position pos, PieceStack stack,
      GameState gameState, UIState uiState) {
    final uiNotifier = ref.read(uiStateProvider.notifier);

    if (uiState.selectedPosition == pos) {
      // Tap same cell: place the piece
      final type = uiState.ghostPieceType;
      _performPlacementMove(pos, type, ref);
      uiNotifier.reset();
      return;
    }

    if (stack.isEmpty) {
      // Tap different empty cell: move ghost there
      uiNotifier.moveGhostPiece(pos);
      return;
    }

    // Tap on a stack: cancel placement and handle like idle
    uiNotifier.reset();
    _handleIdleTap(ref, pos, stack, gameState);
  }

  /// Handle tap when moving a stack (stack selected, waiting for direction)
  void _handleMovingStackTap(WidgetRef ref, Position pos, PieceStack stack,
      GameState gameState, UIState uiState) {
    final uiNotifier = ref.read(uiStateProvider.notifier);
    final selectedPos = uiState.selectedPosition!;

    if (pos == selectedPos) {
      // Tap same stack: cycle piece count
      final stackHeight = gameState.board.stackAt(pos).height;
      final maxPieces = stackHeight > gameState.boardSize
          ? gameState.boardSize
          : stackHeight;
      uiNotifier.cyclePiecesPickedUp(maxPieces);
      return;
    }

    // Check if tapped position is a valid destination (adjacent cell in any valid direction)
    final validDestinations = uiState.getValidMoveDestinations(gameState);
    if (validDestinations.contains(pos)) {
      // Determine direction from selected position to tapped position
      final dir = _getDirectionBetween(selectedPos, pos);
      if (dir != null) {
        // Start movement in this direction - enters dropping mode at first cell
        // No drops committed yet, user will choose how many to drop
        uiNotifier.startMoving(dir);
        return;
      }
    }

    // Tap on different own stack: switch selection
    if (!gameState.isOpeningPhase && stack.controller == gameState.currentPlayer && stack.isNotEmpty) {
      final maxPieces = stack.height > gameState.boardSize
          ? gameState.boardSize
          : stack.height;
      uiNotifier.selectStack(pos, maxPieces);
      return;
    }

    // Tap on empty cell that's not a valid destination: cancel and handle as new placement
    if (stack.isEmpty) {
      uiNotifier.selectCellForPlacement(pos);
      return;
    }

    // Otherwise cancel
    uiNotifier.reset();
  }

  /// Handle tap when dropping pieces (movement in progress)
  void _handleDroppingPiecesTap(WidgetRef ref, Position pos, PieceStack stack,
      GameState gameState, UIState uiState) {
    final uiNotifier = ref.read(uiStateProvider.notifier);
    final handPos = uiState.getCurrentHandPosition();
    final dir = uiState.selectedDirection!;

    if (handPos == null) {
      // No more pieces to drop, this shouldn't happen
      uiNotifier.reset();
      return;
    }

    // Get info about what we're moving
    final originalStack = gameState.board.stackAt(uiState.selectedPosition!);
    final movingPiece = originalStack.topPiece;
    if (movingPiece == null) {
      uiNotifier.reset();
      return;
    }

    // Check if we can continue to the next cell after current hand position
    final nextPos = dir.apply(handPos);
    final canContinue = gameState.board.isValidPosition(nextPos) && (() {
      final targetStack = gameState.board.stackAt(nextPos);
      return targetStack.canMoveOnto(movingPiece) ||
          (targetStack.topPiece?.type == PieceType.standing && movingPiece.canFlattenWalls);
    })();

    if (pos == handPos) {
      // Tap current hand position
      final piecesInHand = uiState.piecesPickedUp;
      final pendingDrop = uiState.pendingDropCount;

      if (pendingDrop == piecesInHand) {
        // All pieces selected to drop here
        if (!canContinue) {
          // Can't continue, so commit all pieces here and finish the move
          uiNotifier.addDrop(pendingDrop);
          _confirmMove(ref);
          return;
        } else {
          // Can continue, so cycle back to 1
          uiNotifier.cyclePendingDropCount(piecesInHand);
          return;
        }
      } else {
        // Not all pieces selected, cycle up
        uiNotifier.cyclePendingDropCount(piecesInHand);
        return;
      }
    }

    // Check if tapping the next cell in the movement direction
    if (pos == nextPos && canContinue) {
      // Drop current pending at hand position and move to next
      final dropCount = uiState.pendingDropCount;
      uiNotifier.addDrop(dropCount);

      // Check if all pieces are dropped
      if (ref.read(uiStateProvider).piecesPickedUp == 0) {
        // Auto-confirm the move
        _confirmMove(ref);
      }
      return;
    }

    // Tapping on already-dropped path or origin: do nothing
    final dropPath = uiState.getDropPath();
    if (dropPath.contains(pos) || pos == uiState.selectedPosition) {
      return;
    }

    // Otherwise cancel the move
    uiNotifier.reset();
  }

  /// Get the direction from one position to an adjacent position
  Direction? _getDirectionBetween(Position from, Position to) {
    final rowDiff = to.row - from.row;
    final colDiff = to.col - from.col;

    // Must be in a straight line
    if (rowDiff != 0 && colDiff != 0) return null;
    if (rowDiff == 0 && colDiff == 0) return null;

    if (rowDiff < 0 && colDiff == 0) return Direction.up;
    if (rowDiff > 0 && colDiff == 0) return Direction.down;
    if (rowDiff == 0 && colDiff < 0) return Direction.left;
    if (rowDiff == 0 && colDiff > 0) return Direction.right;

    return null;
  }

  void _confirmMove(WidgetRef ref) {
    final uiState = ref.read(uiStateProvider);
    final pos = uiState.selectedPosition;
    final dir = uiState.selectedDirection;
    final drops = uiState.drops;

    if (pos == null || dir == null || drops.isEmpty) return;
    _performStackMove(pos, dir, drops, ref);
    ref.read(uiStateProvider.notifier).reset();
  }

  bool _performPlacementMove(Position pos, PieceType type, WidgetRef ref) {
    final gameState = ref.read(gameStateProvider);
    final color = gameState.isOpeningPhase ? gameState.opponent : gameState.currentPlayer;
    final soundManager = ref.read(soundManagerProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    _debugLog('_performPlacementMove: pos=$pos, type=$type, currentPlayer=${gameState.currentPlayer}, turn=${gameState.turnNumber}');
    final success = gameNotifier.placePiece(pos, type);
    _debugLog('_performPlacementMove: placePiece result=$success');
    if (success) {
      final moveRecord = gameNotifier.lastMoveRecord;
      if (moveRecord != null) {
        ref.read(moveHistoryProvider.notifier).addMove(moveRecord);
        ref.read(lastMoveProvider.notifier).state = moveRecord.affectedPositions;
        _syncOnlineMove(moveRecord);
      }

      ref.read(animationStateProvider.notifier).piecePlaced(pos, type, color);
      soundManager.playPiecePlace();

      // Switch chess clock to next player (for local games)
      _switchChessClock(ref);

      if (ref.read(isGameOverProvider)) {
        soundManager.playWin();
        // Stop the clock when game is over
        ref.read(chessClockProvider.notifier).stop();
      }

      unawaited(_maybeTriggerAiTurn(ref.read(gameStateProvider)));
    } else {
      soundManager.playIllegalMove();
    }

    return success;
  }

  bool _performStackMove(
    Position from,
    Direction dir,
    List<int> drops,
    WidgetRef ref,
  ) {
    final dropPositions = _calculateDropPositions(from, dir, drops.length);

    final gameState = ref.read(gameStateProvider);
    final stack = gameState.board.stackAt(from);
    final topPiece = stack.topPiece;
    Position? flattenedWallPos;
    if (topPiece != null && topPiece.canFlattenWalls && dropPositions.isNotEmpty) {
      final targetStack = gameState.board.stackAt(dropPositions.last);
      if (targetStack.topPiece?.type == PieceType.standing) {
        flattenedWallPos = dropPositions.last;
      }
    }

    final soundManager = ref.read(soundManagerProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    final success = gameNotifier.moveStack(from, dir, drops);
    if (success) {
      final moveRecord = gameNotifier.lastMoveRecord;
      if (moveRecord != null) {
        ref.read(moveHistoryProvider.notifier).addMove(moveRecord);
        ref.read(lastMoveProvider.notifier).state = moveRecord.affectedPositions;
        _syncOnlineMove(moveRecord);
      }

      ref.read(animationStateProvider.notifier).stackMoved(from, dir, drops, dropPositions);
      if (flattenedWallPos != null) {
        ref.read(animationStateProvider.notifier).wallFlattened(flattenedWallPos);
        soundManager.playWallFlatten();
      } else {
        soundManager.playStackMove();
      }

      // Switch chess clock to next player (for local games)
      _switchChessClock(ref);

      if (ref.read(isGameOverProvider)) {
        soundManager.playWin();
        // Stop the clock when game is over
        ref.read(chessClockProvider.notifier).stop();
      }

      unawaited(_maybeTriggerAiTurn(ref.read(gameStateProvider)));
    } else {
      soundManager.playIllegalMove();
    }

    return success;
  }

  void _switchChessClock(WidgetRef ref) {
    final session = ref.read(gameSessionProvider);
    // Only switch clock for local games with clock enabled
    if (session.mode != GameMode.local) return;

    final settings = ref.read(appSettingsProvider);
    if (!settings.chessClockEnabled) return;

    final gameState = ref.read(gameStateProvider);
    // The game state has already switched to the next player, so start their clock
    ref.read(chessClockProvider.notifier).start(gameState.currentPlayer);
  }

  List<Position> _calculateDropPositions(Position start, Direction dir, int steps) {
    final dropPositions = <Position>[];
    var currentPos = start;
    for (var i = 0; i < steps; i++) {
      currentPos = dir.apply(currentPos);
      dropPositions.add(currentPos);
    }
    return dropPositions;
  }

  Future<void> _maybeTriggerAiTurn(GameState state) async {
    final session = ref.read(gameSessionProvider);
    if (session.mode != GameMode.vsComputer || state.isGameOver) return;
    if (state.currentPlayer != PlayerColor.black) return;
    if (ref.read(aiThinkingProvider)) return;

    ref.read(uiStateProvider.notifier).reset();
    ref.read(aiThinkingProvider.notifier).state = true;

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final latestState = ref.read(gameStateProvider);
      final latestSession = ref.read(gameSessionProvider);
      if (latestSession.mode != GameMode.vsComputer ||
          latestState.isGameOver ||
          latestState.currentPlayer != PlayerColor.black) {
        return;
      }

      final ai = StonesAI.forDifficulty(latestSession.aiDifficulty);
      final move = await ai.selectMove(latestState);

      if (move is AIPlacementMove) {
        _performPlacementMove(move.position, move.pieceType, ref);
      } else if (move is AIStackMove) {
        _performStackMove(move.from, move.direction, move.drops, ref);
      }

      ref.read(uiStateProvider.notifier).reset();
    } finally {
      ref.read(aiThinkingProvider.notifier).state = false;
    }
  }

  void _syncOnlineMove(MoveRecord? moveRecord) {
    if (moveRecord == null) return;
    final session = ref.read(gameSessionProvider);
    if (session.mode != GameMode.online) return;
    final latestState = ref.read(gameStateProvider);
    _debugLog('_syncOnlineMove: Recording move ${moveRecord.notation} to Firestore, '
        'nextTurn=${latestState.currentPlayer}');
    unawaited(
      ref.read(onlineGameProvider.notifier).recordLocalMove(moveRecord, latestState),
    );
  }

  Future<void> _confirmResign(BuildContext context) async {
    final session = ref.read(gameSessionProvider);
    if (session.mode != GameMode.online) return;
    final shouldResign = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Resign game?'),
            content: const Text(
              'Are you sure you want to resign this online match? Your opponent will be marked as the winner.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Resign'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldResign) {
      await ref.read(onlineGameProvider.notifier).resign();
    }
  }

  void _showNewGameDialog(BuildContext context, WidgetRef ref) {
    final gameState = ref.read(gameStateProvider);
    final isGameInProgress = !gameState.isGameOver &&
        (gameState.turnNumber > 1 || gameState.board.occupiedPositions.isNotEmpty);

    if (isGameInProgress) {
      // Show confirmation dialog first
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start New Game?'),
          content: const Text(
            'You have a game in progress. Starting a new game will discard your current game.\n\nAre you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showBoardSizeDialog(context, ref);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start New Game'),
            ),
          ],
        ),
      );
    } else {
      _showBoardSizeDialog(context, ref);
    }
  }

  void _showBoardSizeDialog(BuildContext context, WidgetRef ref) {
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
                      ref.read(moveHistoryProvider.notifier).clear();
                      ref.read(lastMoveProvider.notifier).state = null;
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

/// Chess clock display widget for local games
class _ChessClockDisplay extends ConsumerWidget {
  final PlayerColor currentPlayer;
  final bool isGameOver;

  const _ChessClockDisplay({
    required this.currentPlayer,
    required this.isGameOver,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clockState = ref.watch(chessClockProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ClockSide(
            label: 'Light',
            time: clockState.whiteTimeFormatted,
            isActive: currentPlayer == PlayerColor.white && !isGameOver && clockState.isRunning,
            isLow: clockState.whiteTimeRemaining < 30,
            isExpired: clockState.isExpired && clockState.expiredPlayer == PlayerColor.white,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: clockState.isRunning
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              clockState.isRunning ? Icons.timer : Icons.timer_off,
              size: 16,
              color: clockState.isRunning ? Colors.green : Colors.grey,
            ),
          ),
          _ClockSide(
            label: 'Dark',
            time: clockState.blackTimeFormatted,
            isActive: currentPlayer == PlayerColor.black && !isGameOver && clockState.isRunning,
            isLow: clockState.blackTimeRemaining < 30,
            isExpired: clockState.isExpired && clockState.expiredPlayer == PlayerColor.black,
          ),
        ],
      ),
    );
  }
}

class _ClockSide extends StatelessWidget {
  final String label;
  final String time;
  final bool isActive;
  final bool isLow;
  final bool isExpired;

  const _ClockSide({
    required this.label,
    required this.time,
    required this.isActive,
    required this.isLow,
    required this.isExpired,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isExpired
        ? Colors.red
        : isLow
            ? Colors.orange
            : isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : isExpired
                    ? Colors.red.withValues(alpha: 0.1)
                    : null,
            borderRadius: BorderRadius.circular(4),
            border: isActive
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Text(
            time,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Win banner - shows game result prominently without blocking the board
class _WinBanner extends StatelessWidget {
  final GameResult result;
  final WinReason? winReason;

  const _WinBanner({
    required this.result,
    this.winReason,
  });

  @override
  Widget build(BuildContext context) {
    final (title, pieceColors, icon) = switch (result) {
      GameResult.whiteWins => (
          'Light Wins!',
          GameColors.lightPlayerColors,
          winReason == WinReason.road ? Icons.route : Icons.emoji_events,
        ),
      GameResult.blackWins => (
          'Dark Wins!',
          GameColors.darkPlayerColors,
          winReason == WinReason.road ? Icons.route : Icons.emoji_events,
        ),
      GameResult.draw => (
          'Draw!',
          const PieceColors(
            primary: Colors.grey,
            secondary: Colors.grey,
            border: Color(0xFF757575),
          ),
          Icons.handshake,
        ),
    };

    final reasonText = switch (winReason) {
      WinReason.road => 'by road',
      WinReason.flats => 'by flat count',
      null => '',
    };

    final textColor = result == GameResult.blackWins ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pieceColors.gradientColors,
        ),
        border: Border(
          bottom: BorderSide(
            color: pieceColors.border,
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: pieceColors.border.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: textColor,
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: 1,
                ),
              ),
              if (reasonText.isNotEmpty)
                Text(
                  reasonText,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Icon(
            icon,
            size: 32,
            color: textColor,
          ),
        ],
      ),
    );
  }
}

/// Game info bar showing current player and phase
class _GameInfoBar extends StatelessWidget {
  final GameState gameState;
  final bool isAiTurn;
  final bool isThinking;
  final AIDifficulty? aiDifficulty;
  final OnlineGameState? onlineState;

  const _GameInfoBar({
    required this.gameState,
    this.isAiTurn = false,
    this.isThinking = false,
    this.aiDifficulty,
    this.onlineState,
  });

  @override
  Widget build(BuildContext context) {
    // Show prominent win banner when game is over
    if (gameState.isGameOver && gameState.result != null) {
      return _WinBanner(result: gameState.result!, winReason: gameState.winReason);
    }

    final isWhite = gameState.currentPlayer == PlayerColor.white;
    final bgColor = isWhite ? GameColors.turnIndicatorLight : GameColors.turnIndicatorDark;
    final textColor = isWhite ? Colors.black : Colors.white;
    final secondaryColor = isWhite ? Colors.black54 : Colors.white70;
    final pieceColors = GameColors.forPlayer(isWhite);

    String statusText;
    if (gameState.isOpeningPhase) {
      statusText = "Place opponent's flat stone";
    } else {
      statusText = 'Place or move';
    }

    // Online game: show player names
    String? currentPlayerName;
    bool isLocalPlayerTurn = false;
    if (onlineState != null && onlineState!.session != null) {
      final session = onlineState!.session!;
      final currentColor = gameState.currentPlayer;
      currentPlayerName = currentColor == PlayerColor.white
          ? session.white.displayName
          : session.black?.displayName;
      // FIX: Use LOCAL game state for turn display instead of Firestore session
      isLocalPlayerTurn = onlineState!.localColor != null &&
          gameState.currentPlayer == onlineState!.localColor;
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
                if (onlineState != null && currentPlayerName != null)
                  Row(
                    children: [
                      Text(
                        isLocalPlayerTurn ? 'YOUR TURN' : "${currentPlayerName.toUpperCase()}'S TURN",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLocalPlayerTurn
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          gameState.currentPlayer.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  )
                else
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
          if (aiDifficulty != null && (isAiTurn || isThinking))
            Row(
              children: [
                if (isThinking)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Computer (${aiDifficulty!.name[0].toUpperCase()}${aiDifficulty!.name.substring(1)})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (isAiTurn)
                      Text(
                        isThinking ? 'Thinking...' : 'Planning move',
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
            ),
          // Show online game info
          if (onlineState != null && onlineState!.session != null)
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      onlineState!.localColor == PlayerColor.white ? 'You: White' : 'You: Black',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'vs ${onlineState!.localColor == PlayerColor.white ? (onlineState!.session!.black?.displayName ?? "...") : onlineState!.session!.white.displayName}',
                      style: TextStyle(
                        fontSize: 10,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
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
  final Set<Position>? lastMovePositions;
  final Function(Position) onCellTap;
  final Function(Position, PieceStack) onLongPressStart;
  final VoidCallback onLongPressEnd;

  const _GameBoard({
    required this.gameState,
    required this.uiState,
    required this.animationState,
    required this.onCellTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    this.lastMovePositions,
  });

  /// Get ghost piece info for a position (for placement mode)
  (PieceType?, PlayerColor?) _getGhostPieceInfo(Position pos) {
    if (uiState.mode != InteractionMode.placingPiece) return (null, null);
    if (uiState.selectedPosition != pos) return (null, null);

    // During opening phase, ghost is opponent's color
    final color = gameState.isOpeningPhase
        ? gameState.opponent
        : gameState.currentPlayer;

    return (uiState.ghostPieceType, color);
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging for board state
    final occupiedCount = gameState.board.occupiedPositions.length;
    _debugLog('BOARD BUILD: currentTurn=${gameState.currentPlayer}, '
        'turnNumber=${gameState.turnNumber}, '
        'phase=${gameState.phase}, '
        'occupiedCells=$occupiedCount, '
        'isGameOver=${gameState.isGameOver}');

    final dropPath = uiState.getDropPath();
    final nextDropPos = uiState.getCurrentHandPosition();
    final validMoveDestinations = uiState.getValidMoveDestinations(gameState);
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

            // Check if this is part of the last move
            final isLastMove = lastMovePositions?.contains(pos) ?? false;

            // Check if this is a valid move destination (legal move hint)
            final isLegalMoveHint = validMoveDestinations.contains(pos);

            // Ghost piece info for placement mode
            final (ghostPieceType, ghostPieceColor) = _getGhostPieceInfo(pos);

            // For stack movement mode, show pieces being picked up count
            final showPickupCount = uiState.mode == InteractionMode.movingStack &&
                uiState.selectedPosition == pos;

            // Show pending drop count when in droppingPieces mode at hand position
            final showPendingDrop = uiState.mode == InteractionMode.droppingPieces &&
                nextDropPos == pos;

            return GestureDetector(
              onTap: () => onCellTap(pos),
              onLongPressStart: stack.isNotEmpty ? (_) => onLongPressStart(pos, stack) : null,
              onLongPressEnd: stack.isNotEmpty ? (_) => onLongPressEnd() : null,
              onLongPressCancel: stack.isNotEmpty ? () => onLongPressEnd() : null,
              child: _BoardCell(
                key: ValueKey('cell_${pos.row}_${pos.col}_${stack.height}_${lastEvent?.timestamp.millisecondsSinceEpoch ?? 0}_${ghostPieceType?.name ?? ''}'),
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
                isLastMove: isLastMove,
                isLegalMoveHint: isLegalMoveHint,
                ghostPieceType: ghostPieceType,
                ghostPieceColor: ghostPieceColor,
                pickupCount: showPickupCount ? uiState.piecesPickedUp : null,
                pendingDropCount: showPendingDrop ? uiState.pendingDropCount : null,
                piecesInHand: showPendingDrop ? uiState.piecesPickedUp : null,
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
  final bool isLastMove;
  final bool isLegalMoveHint;

  /// Ghost piece to show (for placement preview)
  final PieceType? ghostPieceType;
  final PlayerColor? ghostPieceColor;

  /// Number of pieces being picked up (for stack movement)
  final int? pickupCount;

  /// Pending drop count at this position
  final int? pendingDropCount;

  /// Total pieces in hand (for drop preview)
  final int? piecesInHand;

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
    this.ghostPieceType,
    this.ghostPieceColor,
    this.pickupCount,
    this.pendingDropCount,
    this.piecesInHand,
    this.isStackDropTarget = false,
    this.wasWallFlattened = false,
    this.isLastMove = false,
    this.isLegalMoveHint = false,
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
    } else if (widget.isLegalMoveHint) {
      // Legal move destination hint (cyan/teal highlight)
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GameColors.cellLegalMove,
            GameColors.cellLegalMoveGlow,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: GameColors.cellLegalMoveBorder, width: borderWidth * 0.8),
        boxShadow: [
          BoxShadow(
            color: GameColors.cellLegalMoveGlow.withValues(alpha: 0.5),
            blurRadius: 6,
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
        child: _buildCellContent(),
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

    // Add last move highlighting (subtle outline)
    // Only show if not already highlighted by another state
    if (widget.isLastMove && !widget.isSelected && !widget.isInDropPath && !widget.isNextDrop && !widget.isInWinningRoad) {
      cellContent = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: GameColors.lastMoveBorder,
            width: borderWidth * 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: GameColors.lastMoveGlow.withValues(alpha: 0.3),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
        child: cellContent,
      );
    }

    return cellContent;
  }

  /// Build the cell content - handles ghost pieces, stacks, and overlay badges
  Widget _buildCellContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth;
        final pieceSize = cellSize * 0.7;
        final badgeFontSize = widget.boardSize <= 4 ? 10.0 : (widget.boardSize <= 6 ? 9.0 : 8.0);
        final badgePadding = widget.boardSize <= 4 ? 4.0 : (widget.boardSize <= 6 ? 3.0 : 2.5);

        // If showing ghost piece (empty cell with placement preview)
        if (widget.ghostPieceType != null && widget.ghostPieceColor != null && widget.stack.isEmpty) {
          final isLightPlayer = widget.ghostPieceColor == PlayerColor.white;
          final pieceColors = GameColors.forPlayer(isLightPlayer);

          return Opacity(
            opacity: 0.5,
            child: _buildPiece(widget.ghostPieceType!, pieceSize, pieceColors, isLightPlayer),
          );
        }

        // If empty cell and no ghost, show nothing
        if (widget.stack.isEmpty) {
          // But if this is the next drop position, show pending drop indicator
          if (widget.pendingDropCount != null && widget.piecesInHand != null) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Show pending drop count badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: badgePadding * 1.5,
                    vertical: badgePadding,
                  ),
                  decoration: BoxDecoration(
                    color: GameColors.cellNextDropBorder.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(badgePadding * 2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${widget.pendingDropCount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: badgeFontSize * 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          }
          return const SizedBox();
        }

        // Build normal stack display
        Widget content = _buildStackDisplay(widget.stack);

        // Add pickup count overlay for stack movement
        if (widget.pickupCount != null) {
          content = Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              content,
              // Pickup count badge at top
              Positioned(
                top: -2,
                right: -2,
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
                        Color(0xFF1565C0),
                        Color(0xFF0D47A1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(badgePadding),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1,
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
                    '${widget.pickupCount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Add pending drop count overlay for dropping mode
        if (widget.pendingDropCount != null && widget.piecesInHand != null) {
          content = Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              content,
              // Pending drop badge
              Positioned(
                top: -2,
                left: -2,
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
                        Color(0xFFE65100),
                        Color(0xFFBF360C),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(badgePadding),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1,
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
                    '+${widget.pendingDropCount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return content;
      },
    );
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

/// Random tips about Tak rules and strategy
const List<String> _takTips = [
  'Win by building a road connecting opposite edges of the board.',
  'Flats count toward road building; walls and capstones do not.',
  'Walls block roads but can be flattened by a capstone.',
  'Capstones can flatten walls but cannot be stacked upon.',
  'Diagonals do not count when building a road.',
  'If neither player can win by road, the game ends when the board fills or someone runs out of pieces.',
  'In a flat count win, only flat stones on top of stacks count.',
  'You can move a stack up to its height in spaces.',
  'The carry limit is equal to the board size.',
  'Long press on any stack to see all pieces in it.',
  'Standing stones (walls) cannot have pieces placed on them.',
  'During the opening, you place your opponent\'s flat stone.',
  'Control a stack by having your piece on top.',
  'A capstone is your most powerful piece - use it wisely!',
  'Walls are great for blocking your opponent\'s roads.',
];

/// Bottom controls panel - simplified for on-board interaction
class _BottomControls extends StatelessWidget {
  final GameState gameState;
  final UIState uiState;
  final Function(PieceType) onPieceTypeChanged;
  final VoidCallback onConfirmMove;
  final VoidCallback onCancel;

  const _BottomControls({
    required this.gameState,
    required this.uiState,
    required this.onPieceTypeChanged,
    required this.onConfirmMove,
    required this.onCancel,
  });

  // Get a deterministic "random" tip based on turn number
  String _getTip() {
    final index = (gameState.turnNumber * 7) % _takTips.length;
    return _takTips[index];
  }

  @override
  Widget build(BuildContext context) {
    if (gameState.isGameOver) {
      return const SizedBox(height: 100);
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : GameColors.controlPanelBg,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.outline
                : GameColors.controlPanelBorder,
          ),
        ),
      ),
      child: _buildControls(context),
    );
  }

  Widget _buildControls(BuildContext context) {
    switch (uiState.mode) {
      case InteractionMode.idle:
        return _buildIdleHint(context);
      case InteractionMode.placingPiece:
        return _buildPlacingPieceControls(context);
      case InteractionMode.movingStack:
        return _buildMovingStackHint(context);
      case InteractionMode.droppingPieces:
        return _buildDroppingPiecesControls(context);
    }
  }

  Widget _buildIdleHint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : GameColors.subtitleColor;
    final tipColor = isDark ? Colors.white54 : Colors.grey.shade600;

    final String instruction;
    if (gameState.isOpeningPhase) {
      final playerName = gameState.currentPlayer == PlayerColor.white ? 'Light' : 'Dark';
      instruction = '$playerName\'s turn: Tap any empty cell to place your opponent\'s flat stone.';
    } else {
      final playerName = gameState.currentPlayer == PlayerColor.white ? 'Light' : 'Dark';
      instruction = '$playerName\'s turn: Tap an empty cell to place a piece, or tap your own stack to move it.';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          instruction,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 14, color: tipColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _getTip(),
                style: TextStyle(
                  color: tipColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlacingPieceControls(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : GameColors.subtitleColor;
    final pieces = gameState.currentPlayerPieces;
    final isOpening = gameState.isOpeningPhase;
    final currentType = uiState.ghostPieceType;

    // During opening, only flat stones allowed - just show hint
    if (isOpening) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cell selected! Tap this cell again to confirm placement.',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Or tap a different cell to change your selection.',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                color: textColor,
              ),
            ],
          ),
        ],
      );
    }

    final typeName = switch (currentType) {
      PieceType.flat => 'Flat Stone',
      PieceType.standing => 'Wall',
      PieceType.capstone => 'Capstone',
      _ => 'piece',
    };

    // Show piece type selector with current selection highlighted
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Placing: $typeName. Tap cell to place, or select a different piece type below.',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PieceTypeToggle(
              type: PieceType.flat,
              isSelected: currentType == PieceType.flat,
              isEnabled: pieces.flatStones > 0,
              onTap: pieces.flatStones > 0 ? () => onPieceTypeChanged(PieceType.flat) : null,
            ),
            const SizedBox(width: 8),
            _PieceTypeToggle(
              type: PieceType.standing,
              label: 'Wall',
              isSelected: currentType == PieceType.standing,
              isEnabled: pieces.flatStones > 0,
              onTap: pieces.flatStones > 0 ? () => onPieceTypeChanged(PieceType.standing) : null,
            ),
            const SizedBox(width: 8),
            _PieceTypeToggle(
              type: PieceType.capstone,
              isSelected: currentType == PieceType.capstone,
              isEnabled: pieces.capstones > 0,
              onTap: pieces.capstones > 0 ? () => onPieceTypeChanged(PieceType.capstone) : null,
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              color: textColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMovingStackHint(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : GameColors.subtitleColor;
    final piecesPickedUp = uiState.piecesPickedUp;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Picking up $piecesPickedUp piece${piecesPickedUp == 1 ? '' : 's'} from this stack.',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : null,
                ),
              ),
              Text(
                'Tap the stack again to change how many pieces to pick up. Tap an adjacent cell to start moving.',
                style: TextStyle(
                  color: textColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          color: textColor,
        ),
      ],
    );
  }

  Widget _buildDroppingPiecesControls(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : GameColors.subtitleColor;
    final remaining = uiState.piecesPickedUp;
    final drops = uiState.drops;
    final pendingDrop = uiState.pendingDropCount;
    final canConfirm = remaining == 0 && drops.isNotEmpty;

    if (canConfirm) {
      // All pieces dropped, show confirm hint
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Move complete! Dropped ${drops.join(' → ')} pieces.',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : null,
                  ),
                ),
                const Text(
                  'Press Confirm to finalize, or Cancel to undo.',
                  style: TextStyle(
                    color: Colors.green,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onConfirmMove,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            color: textColor,
          ),
        ],
      );
    }

    // Still dropping - show hint
    final dropsText = drops.isEmpty ? '' : 'Already dropped: ${drops.join(' → ')}. ';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Dropping $pendingDrop piece${pendingDrop == 1 ? '' : 's'} here. $remaining remaining in hand.',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : null,
                ),
              ),
              Text(
                '${dropsText}Tap this cell to change drop count, or tap an adjacent cell to continue.',
                style: TextStyle(
                  color: textColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          color: textColor,
        ),
      ],
    );
  }
}

/// Toggle button for piece type selection
class _PieceTypeToggle extends StatelessWidget {
  final PieceType type;
  final String? label;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _PieceTypeToggle({
    required this.type,
    this.label,
    required this.isSelected,
    required this.isEnabled,
    this.onTap,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? GameColors.cellSelectedGlow.withValues(alpha: 0.3)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? GameColors.cellSelectedBorder
                  : GameColors.controlPanelBorder,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PieceIcon(type: type, size: 20),
              const SizedBox(height: 2),
              Text(
                displayLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? GameColors.cellSelectedBorder : null,
                ),
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

/// Piece counts bar at bottom
class _PieceCountsBar extends StatelessWidget {
  final GameState gameState;

  const _PieceCountsBar({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.grey.shade100;
    final borderColor = isDark
        ? Theme.of(context).colorScheme.outline
        : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor),
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
            color: borderColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pieceColors = GameColors.forPlayer(isLightPlayer);
    final textColor = isDark ? Colors.white : Colors.black87;
    final countColor = isDark ? Colors.white : Colors.black87;
    final highlightColor = isDark
        ? Theme.of(context).colorScheme.primaryContainer
        : GameColors.currentPlayerHighlight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: isCurrentPlayer
          ? BoxDecoration(
              color: highlightColor,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
              color: textColor,
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
                style: TextStyle(fontWeight: FontWeight.w500, color: countColor),
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
                style: TextStyle(fontWeight: FontWeight.w500, color: countColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Move history panel - collapsible sidebar showing moves in algebraic notation
class _MoveHistoryPanel extends StatelessWidget {
  final List<MoveRecord> moveHistory;
  final int boardSize;
  final VoidCallback onClose;

  const _MoveHistoryPanel({
    required this.moveHistory,
    required this.boardSize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: GameColors.controlPanelBg,
        border: const Border(
          left: BorderSide(color: GameColors.controlPanelBorder, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: GameColors.boardFrameInner,
              border: Border(
                bottom: BorderSide(color: GameColors.controlPanelBorder),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Move History',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),

          // Move list
          Expanded(
            child: moveHistory.isEmpty
                ? const Center(
                    child: Text(
                      'No moves yet',
                      style: TextStyle(
                        color: GameColors.subtitleColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: (moveHistory.length + 1) ~/ 2, // Number of turn pairs
                    itemBuilder: (context, turnIndex) {
                      return _buildTurnRow(turnIndex);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnRow(int turnIndex) {
    // Each turn has white's move and potentially black's move
    final whiteIndex = turnIndex * 2;
    final blackIndex = whiteIndex + 1;

    final hasWhiteMove = whiteIndex < moveHistory.length;
    final hasBlackMove = blackIndex < moveHistory.length;

    final turnNumber = turnIndex + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          // Turn number
          SizedBox(
            width: 28,
            child: Text(
              '$turnNumber.',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: GameColors.subtitleColor,
                fontSize: 12,
              ),
            ),
          ),
          // White's move
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: hasWhiteMove ? GameColors.lightPiece.withValues(alpha: 0.5) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: hasWhiteMove
                    ? Border.all(color: GameColors.lightPieceBorder.withValues(alpha: 0.3))
                    : null,
              ),
              child: Text(
                hasWhiteMove ? moveHistory[whiteIndex].notation : '',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasWhiteMove ? Colors.black87 : Colors.transparent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Black's move
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: hasBlackMove ? GameColors.darkPiece.withValues(alpha: 0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: hasBlackMove
                    ? Border.all(color: GameColors.darkPieceBorder.withValues(alpha: 0.3))
                    : null,
              ),
              child: Text(
                hasBlackMove ? moveHistory[blackIndex].notation : '',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasBlackMove ? Colors.white : Colors.transparent,
                ),
              ),
            ),
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

/// Stack viewer dialog - shows full stack contents from bottom to top
class _StackViewerDialog extends StatelessWidget {
  final Position position;
  final PieceStack stack;
  final int boardSize;

  const _StackViewerDialog({
    required this.position,
    required this.stack,
    required this.boardSize,
  });

  @override
  Widget build(BuildContext context) {
    final posNotation = _positionToNotation(position);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.layers, size: 24),
          const SizedBox(width: 8),
          Text('Stack at $posNotation'),
        ],
      ),
      content: SizedBox(
        width: 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${stack.height} piece${stack.height == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'TOP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: GameColors.subtitleColor,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Show pieces from top to bottom
                    for (int i = stack.height - 1; i >= 0; i--)
                      _StackPieceRow(
                        piece: stack.pieces[i],
                        index: i,
                        isTop: i == stack.height - 1,
                        isBottom: i == 0,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'BOTTOM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: GameColors.subtitleColor,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _positionToNotation(Position pos) {
    final col = String.fromCharCode('a'.codeUnitAt(0) + pos.col);
    final row = (boardSize - pos.row).toString();
    return '$col$row';
  }
}

/// A single piece row in the stack viewer
class _StackPieceRow extends StatelessWidget {
  final Piece piece;
  final int index;
  final bool isTop;
  final bool isBottom;

  const _StackPieceRow({
    required this.piece,
    required this.index,
    required this.isTop,
    required this.isBottom,
  });

  @override
  Widget build(BuildContext context) {
    final isLightPlayer = piece.color == PlayerColor.white;
    final pieceColors = GameColors.forPlayer(isLightPlayer);
    final playerName = isLightPlayer ? 'Light' : 'Dark';
    final typeName = piece.type.name[0].toUpperCase() + piece.type.name.substring(1);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            pieceColors.primary.withValues(alpha: 0.3),
            pieceColors.secondary.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: pieceColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Piece icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: pieceColors.gradientColors),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: pieceColors.border, width: 1.5),
            ),
            child: Center(
              child: _getPieceIcon(piece.type),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  playerName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (isTop)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Text(
                'CTRL',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getPieceIcon(PieceType type) {
    switch (type) {
      case PieceType.flat:
        return Container(
          width: 16,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      case PieceType.standing:
        return Container(
          width: 6,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      case PieceType.capstone:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        );
    }
  }
}

/// Stack exploded view overlay - shows stack contents on long press
class _StackExplodedOverlay extends StatelessWidget {
  final Position position;
  final PieceStack stack;
  final int boardSize;

  const _StackExplodedOverlay({
    required this.position,
    required this.stack,
    required this.boardSize,
  });

  String _positionToNotation(Position pos) {
    final col = String.fromCharCode('a'.codeUnitAt(0) + pos.col);
    final row = (boardSize - pos.row).toString();
    return '$col$row';
  }

  @override
  Widget build(BuildContext context) {
    final posNotation = _positionToNotation(position);

    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.layers,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stack at $posNotation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${stack.height} piece${stack.height == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Exploded stack view
              Container(
                constraints: const BoxConstraints(maxHeight: 400, maxWidth: 280),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // TOP label
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TOP (Controls)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Stack pieces from top to bottom (exploded view)
                      for (int i = stack.height - 1; i >= 0; i--) ...[
                        _ExplodedPieceCard(
                          piece: stack.pieces[i],
                          index: i,
                          isTop: i == stack.height - 1,
                          totalPieces: stack.height,
                        ),
                        if (i > 0)
                          Container(
                            height: 16,
                            width: 2,
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                          ),
                      ],

                      const SizedBox(height: 8),
                      // BOTTOM label
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'BOTTOM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Release to close',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Exploded piece card for the stack overlay
class _ExplodedPieceCard extends StatelessWidget {
  final Piece piece;
  final int index;
  final bool isTop;
  final int totalPieces;

  const _ExplodedPieceCard({
    required this.piece,
    required this.index,
    required this.isTop,
    required this.totalPieces,
  });

  @override
  Widget build(BuildContext context) {
    final isLightPlayer = piece.color == PlayerColor.white;
    final pieceColors = GameColors.forPlayer(isLightPlayer);
    final playerName = isLightPlayer ? 'Light' : 'Dark';
    final typeName = piece.type.name[0].toUpperCase() + piece.type.name.substring(1);

    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pieceColors.gradientColors,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pieceColors.border,
          width: isTop ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: pieceColors.border.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Piece visual
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Center(child: _getPieceVisual(piece.type)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: pieceColors.border.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
                Text(
                  playerName,
                  style: TextStyle(
                    fontSize: 12,
                    color: (pieceColors.border.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white)
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (isTop)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'CTRL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getPieceVisual(PieceType type) {
    switch (type) {
      case PieceType.flat:
        return Container(
          width: 24,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      case PieceType.standing:
        return Container(
          width: 8,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      case PieceType.capstone:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        );
    }
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

class _OnlineStatusBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;

  const _OnlineStatusBanner({
    required this.message,
    this.icon = Icons.wifi_tethering,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bannerColor = color ?? GameColors.boardFrameInner;
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.white.withValues(alpha: 0.95),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: bannerColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color != null ? bannerColor : null,
                  ),
                ),
              ),
            ],
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
