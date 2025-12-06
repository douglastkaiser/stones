import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/providers.dart';
import 'models/models.dart';

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
      home: const GameScreen(),
    );
  }
}

/// Temporary game screen - placeholder for UI development
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final phase = ref.watch(gamePhaseProvider);
    final result = ref.watch(gameResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _showNewGameDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.all(16),
            color: currentPlayer == PlayerColor.white
                ? Colors.grey.shade200
                : Colors.grey.shade800,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  result != null
                      ? _resultText(result)
                      : phase == GamePhase.opening
                          ? 'Opening: Place opponent\'s flat'
                          : '${currentPlayer.name.toUpperCase()}\'s turn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: currentPlayer == PlayerColor.white
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
                Text(
                  'Turn ${gameState.turnNumber}',
                  style: TextStyle(
                    color: currentPlayer == PlayerColor.white
                        ? Colors.black54
                        : Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Board placeholder
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
                  child: GridView.builder(
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

                      return GestureDetector(
                        onTap: () => _handleCellTap(context, ref, pos),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.brown.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: _buildStackDisplay(stack),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Piece counts
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPieceCount('White', gameState.whitePieces, Colors.white),
                _buildPieceCount('Black', gameState.blackPieces, Colors.black),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackDisplay(PieceStack stack) {
    if (stack.isEmpty) return const SizedBox();

    final top = stack.topPiece!;
    final color = top.color == PlayerColor.white ? Colors.white : Colors.black;
    final borderColor =
        top.color == PlayerColor.white ? Colors.black : Colors.white;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Stack height indicator
        if (stack.height > 1)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
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
          width: 32,
          height: top.type == PieceType.standing ? 32 : 24,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: top.type == PieceType.capstone
                ? BorderRadius.circular(16)
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
        ),
      ],
    );
  }

  Widget _buildPieceCount(String label, PlayerPieces pieces, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color == Colors.white ? Colors.black : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 20,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(
                  color: color == Colors.white ? Colors.black : Colors.white,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text('${pieces.flatStones}'),
            const SizedBox(width: 12),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(
                  color: color == Colors.white ? Colors.black : Colors.white,
                ),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text('${pieces.capstones}'),
          ],
        ),
      ],
    );
  }

  String _resultText(GameResult result) {
    return switch (result) {
      GameResult.whiteWins => 'White Wins!',
      GameResult.blackWins => 'Black Wins!',
      GameResult.draw => 'Draw!',
    };
  }

  void _handleCellTap(BuildContext context, WidgetRef ref, Position pos) {
    final notifier = ref.read(gameStateProvider.notifier);
    final gameState = ref.read(gameStateProvider);

    if (gameState.isGameOver) return;

    final stack = gameState.board.stackAt(pos);

    if (stack.isEmpty) {
      // Place a piece - show dialog to choose type
      _showPlacePieceDialog(context, notifier, pos, gameState);
    }
    // TODO: Handle stack selection and movement
  }

  void _showPlacePieceDialog(
    BuildContext context,
    GameStateNotifier notifier,
    Position pos,
    GameState gameState,
  ) {
    if (gameState.isOpeningPhase) {
      // Only flat stones during opening
      notifier.placePiece(pos, PieceType.flat);
      return;
    }

    final pieces = gameState.currentPlayerPieces;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Place Piece'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pieces.flatStones > 0) ...[
              ListTile(
                leading: const Icon(Icons.crop_square),
                title: const Text('Flat Stone'),
                subtitle: Text('${pieces.flatStones} remaining'),
                onTap: () {
                  Navigator.pop(context);
                  notifier.placePiece(pos, PieceType.flat);
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_agenda),
                title: const Text('Standing Stone (Wall)'),
                subtitle: Text('${pieces.flatStones} remaining'),
                onTap: () {
                  Navigator.pop(context);
                  notifier.placePiece(pos, PieceType.standing);
                },
              ),
            ],
            if (pieces.capstones > 0)
              ListTile(
                leading: const Icon(Icons.circle),
                title: const Text('Capstone'),
                subtitle: Text('${pieces.capstones} remaining'),
                onTap: () {
                  Navigator.pop(context);
                  notifier.placePiece(pos, PieceType.capstone);
                },
              ),
          ],
        ),
      ),
    );
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
              children: [
                for (int size = 3; size <= 8; size++)
                  ElevatedButton(
                    onPressed: () {
                      ref.read(gameStateProvider.notifier).newGame(size);
                      Navigator.pop(context);
                    },
                    child: Text('${size}x$size'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
