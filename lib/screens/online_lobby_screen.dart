
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../theme/theme.dart';
import 'game_screen.dart';

class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  final TextEditingController _joinCodeController = TextEditingController();
  int _selectedBoardSize = 5;
  bool _hasNavigatedToGame = false;

  @override
  void initState() {
    super.initState();
    ref.read(onlineGameProvider.notifier).initialize();
    // Load saved board size preference
    final settings = ref.read(appSettingsProvider);
    _selectedBoardSize = settings.boardSize;
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  void _playSound(GameSound sound) {
    final soundManager = ref.read(soundManagerProvider);
    soundManager.play(sound);
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(onlineGameProvider);
    final playGames = ref.watch(playGamesServiceProvider);

    // Listen for opponent join or move to play sounds
    ref.listen<OnlineGameState>(onlineGameProvider, (previous, next) {
      if (next.opponentJustJoined) {
        _playSound(GameSound.piecePlace);
      }
      if (next.opponentJustMoved) {
        _playSound(GameSound.stackMove);
      }
      // Auto-navigate to game when opponent joins and game starts
      if (!_hasNavigatedToGame &&
          next.session?.status == OnlineStatus.playing &&
          previous?.session?.status == OnlineStatus.waiting) {
        _hasNavigatedToGame = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Play'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(onlineGameProvider.notifier).leaveRoom();
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile card
            _buildProfileCard(playGames),

            // Error banner
            if (online.errorMessage != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: online.errorMessage!),
            ],

            const SizedBox(height: 16),

            // Main content based on state
            if (online.session == null)
              _buildLobbyActions(context, online)
            else if (online.session!.status == OnlineStatus.waiting)
              _buildWaitingScreen(context, online)
            else if (online.session!.status == OnlineStatus.playing)
              _buildPlayingStatus(context, online)
            else if (online.session!.status == OnlineStatus.finished)
              _buildFinishedStatus(context, online),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(PlayGamesState playGames) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(playGames.player?.displayName ?? 'Guest'),
        subtitle: Text(playGames.isSignedIn
            ? 'Signed in with Play Games'
            : 'Will sign in when creating or joining a game'),
      ),
    );
  }

  Widget _buildLobbyActions(BuildContext context, OnlineGameState online) {
    return Column(
      children: [
        // Create Game section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline, color: GameColors.boardFrameInner),
                    const SizedBox(width: 8),
                    Text(
                      'Create Game',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Select board size:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                _BoardSizeSelector(
                  selectedSize: _selectedBoardSize,
                  onSizeSelected: (size) {
                    setState(() => _selectedBoardSize = size);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: online.creating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(online.creating ? 'Creating...' : 'Create Game'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameColors.boardFrameInner,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: online.creating
                        ? null
                        : () => ref
                            .read(onlineGameProvider.notifier)
                            .createGame(boardSize: _selectedBoardSize),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Join Game section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.login, color: GameColors.boardFrameOuter),
                    const SizedBox(width: 8),
                    Text(
                      'Join Game',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _joinCodeController,
                  decoration: InputDecoration(
                    labelText: 'Room Code',
                    hintText: 'e.g., ABCXYZ',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.tag),
                    suffixIcon: _joinCodeController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _joinCodeController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    helperText: _joinCodeController.text.isEmpty
                        ? 'Enter 6-letter room code'
                        : _joinCodeController.text.length < 6
                            ? '${6 - _joinCodeController.text.length} more letter${6 - _joinCodeController.text.length == 1 ? '' : 's'} needed'
                            : null,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                    LengthLimitingTextInputFormatter(6),
                    _UpperCaseTextFormatter(),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: _JoinGameButton(
                    isJoining: online.joining,
                    codeLength: _joinCodeController.text.length,
                    onJoin: () => ref
                        .read(onlineGameProvider.notifier)
                        .joinGame(_joinCodeController.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingScreen(BuildContext context, OnlineGameState online) {
    final session = online.session!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.hourglass_empty,
              size: 48,
              color: GameColors.boardFrameInner,
            ),
            const SizedBox(height: 16),
            Text(
              'Waiting for opponent...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  'Share this code with a friend:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Colors.grey.shade600,
                      ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Big room code display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: GameColors.boardFrameInner.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GameColors.boardFrameInner.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Text(
                session.roomCode,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: GameColors.boardFrameInner,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            // Copy button
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy Code'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: session.roomCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Room code copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const LinearProgressIndicator(),
            const SizedBox(height: 24),
            // Player info
            _PlayerInfoCard(
              label: 'You (White)',
              player: session.white,
              isLocal: true,
            ),
            const SizedBox(height: 8),
            const _PlayerInfoCard(
              label: 'Opponent (Black)',
              player: null,
              isLocal: false,
              waiting: true,
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  'Board size: ${session.boardSize}×${session.boardSize}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Colors.grey.shade600,
                      ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Leave game button
            TextButton.icon(
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Leave Game'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
              onPressed: () {
                ref.read(onlineGameProvider.notifier).leaveRoom();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayingStatus(BuildContext context, OnlineGameState online) {
    final session = online.session!;
    final isYourTurn = online.isLocalTurn;
    final yourColor = online.localColor == PlayerColor.white ? 'White' : 'Black';
    final opponentColor = online.localColor == PlayerColor.white ? 'Black' : 'White';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.sports_esports,
                  color: isYourTurn ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  isYourTurn ? 'Your turn!' : "Opponent's turn",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isYourTurn ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PlayerInfoCard(
              label: 'You ($yourColor)',
              player: online.localColor == PlayerColor.white ? session.white : session.black,
              isLocal: true,
              isActive: isYourTurn,
            ),
            const SizedBox(height: 8),
            _PlayerInfoCard(
              label: 'Opponent ($opponentColor)',
              player: online.localColor == PlayerColor.white ? session.black : session.white,
              isLocal: false,
              isActive: !isYourTurn,
            ),
            if (online.opponentDisconnected && !online.opponentInactive) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.orange.shade900 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off,
                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Opponent may have disconnected (no activity for 60s)',
                            style: TextStyle(
                              color: isDark ? Colors.orange.shade200 : Colors.orange.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            if (online.opponentInactive) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red.shade900 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Opponent disconnected (no activity for 2+ minutes)',
                            style: TextStyle(
                              color: isDark ? Colors.red.shade200 : Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Open Game Board'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameColors.boardFrameInner,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const GameScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.flag),
                    label: const Text('Resign'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    onPressed: () => _confirmResign(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Leave'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                    onPressed: () {
                      ref.read(onlineGameProvider.notifier).leaveRoom();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedStatus(BuildContext context, OnlineGameState online) {
    final session = online.session!;
    final winner = session.winner;
    final yourColor = online.localColor == PlayerColor.white ? 'White' : 'Black';
    final opponentColor = online.localColor == PlayerColor.white ? 'Black' : 'White';

    String resultText;
    Color resultColor;
    if (winner == OnlineWinner.draw) {
      resultText = 'Game ended in a draw!';
      resultColor = Colors.orange.shade700;
    } else if ((winner == OnlineWinner.white && online.localColor == PlayerColor.white) ||
        (winner == OnlineWinner.black && online.localColor == PlayerColor.black)) {
      resultText = 'You won!';
      resultColor = Colors.green.shade700;
    } else {
      resultText = 'You lost!';
      resultColor = Colors.red.shade700;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              winner == OnlineWinner.draw
                  ? Icons.handshake
                  : resultColor == Colors.green.shade700
                      ? Icons.emoji_events
                      : Icons.sentiment_dissatisfied,
              size: 48,
              color: resultColor,
            ),
            const SizedBox(height: 8),
            Text(
              resultText,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: resultColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _PlayerInfoCard(
              label: 'You ($yourColor)',
              player: online.localColor == PlayerColor.white ? session.white : session.black,
              isLocal: true,
            ),
            const SizedBox(height: 8),
            _PlayerInfoCard(
              label: 'Opponent ($opponentColor)',
              player: online.localColor == PlayerColor.white ? session.black : session.white,
              isLocal: false,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Rematch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameColors.boardFrameInner,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  ref.read(onlineGameProvider.notifier).requestRematch();
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Leave Game'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
              onPressed: () {
                ref.read(onlineGameProvider.notifier).leaveRoom();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResign(BuildContext context) async {
    final shouldResign = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Resign game?'),
            content: const Text(
              'Are you sure you want to resign? Your opponent will be declared the winner.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
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
}

class _BoardSizeSelector extends StatelessWidget {
  final int selectedSize;
  final ValueChanged<int> onSizeSelected;

  const _BoardSizeSelector({
    required this.selectedSize,
    required this.onSizeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int size = 3; size <= 8; size++)
          ChoiceChip(
            label: Text('$size×$size'),
            selected: selectedSize == size,
            onSelected: (_) => onSizeSelected(size),
            selectedColor: GameColors.boardFrameInner.withValues(alpha: 0.2),
            checkmarkColor: GameColors.boardFrameInner,
          ),
      ],
    );
  }
}

class _PlayerInfoCard extends StatelessWidget {
  final String label;
  final OnlineGamePlayer? player;
  final bool isLocal;
  final bool isActive;
  final bool waiting;

  const _PlayerInfoCard({
    required this.label,
    required this.player,
    required this.isLocal,
    this.isActive = false,
    this.waiting = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Background colors
    final bgColor = isActive
        ? (isDark ? Colors.green.shade900 : Colors.green.shade50)
        : isLocal
            ? (isDark ? Colors.blue.shade900 : Colors.blue.shade50)
            : (isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100);

    // Border colors
    final borderColor = isActive
        ? (isDark ? Colors.green.shade700 : Colors.green.shade300)
        : isLocal
            ? (isDark ? Colors.blue.shade700 : Colors.blue.shade200)
            : (isDark ? colorScheme.outline : Colors.grey.shade300);

    // Icon/text colors
    final iconColor = isActive
        ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
        : isLocal
            ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700)
            : (isDark ? colorScheme.onSurfaceVariant : Colors.grey.shade600);

    final labelColor = isActive
        ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
        : isLocal
            ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700)
            : (isDark ? Colors.white : Colors.grey.shade700);

    final nameColor = waiting
        ? (isDark ? colorScheme.onSurfaceVariant : Colors.grey.shade500)
        : (isDark ? colorScheme.onSurface : Colors.grey.shade700);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isLocal ? Icons.person : Icons.person_outline,
            color: iconColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                  ),
                ),
                Text(
                  waiting ? 'Waiting...' : (player?.displayName ?? 'Unknown'),
                  style: TextStyle(
                    color: nameColor,
                    fontStyle: waiting ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'TURN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? Colors.red.shade900 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: isDark ? Colors.red.shade300 : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isDark ? Colors.red.shade100 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Join Game button with visual feedback when disabled
class _JoinGameButton extends StatefulWidget {
  final bool isJoining;
  final int codeLength;
  final VoidCallback onJoin;

  const _JoinGameButton({
    required this.isJoining,
    required this.codeLength,
    required this.onJoin,
  });

  @override
  State<_JoinGameButton> createState() => _JoinGameButtonState();
}

class _JoinGameButtonState extends State<_JoinGameButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  bool get _isEnabled => !widget.isJoining && widget.codeLength == 6;

  void _handleTap() {
    if (_isEnabled) {
      widget.onJoin();
    } else {
      // Trigger shake animation for visual feedback
      _shakeController.forward().then((_) => _shakeController.reset());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final shakeOffset = _shakeAnimation.value * 8 *
            ((_shakeController.value * 8).floor().isEven ? 1 : -1);
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: child,
        );
      },
      child: OutlinedButton.icon(
        icon: widget.isJoining
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.login,
                color: _isEnabled
                    ? GameColors.boardFrameOuter
                    : isDark
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
              ),
        label: Text(
          widget.isJoining ? 'Joining...' : 'Join Game',
          style: TextStyle(
            color: _isEnabled
                ? GameColors.boardFrameOuter
                : isDark
                    ? Colors.grey.shade600
                    : Colors.grey.shade400,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _isEnabled
              ? GameColors.boardFrameOuter
              : isDark
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
          side: BorderSide(
            color: _isEnabled
                ? GameColors.boardFrameOuter
                : isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade300,
            width: 2,
          ),
          disabledForegroundColor: isDark
              ? Colors.grey.shade600
              : Colors.grey.shade400,
        ),
        onPressed: _isEnabled ? _handleTap : _handleTap,
      ),
    );
  }
}
