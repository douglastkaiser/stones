
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/play_games_service.dart';
import 'game_screen.dart';

class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  final TextEditingController _joinCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(onlineGameProvider.notifier).initialize();
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(onlineGameProvider);
    final playGames = ref.watch(playGamesServiceProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Play'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (online.session != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Leave room',
              onPressed: () => ref.read(onlineGameProvider.notifier).leaveRoom(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileCard(playGames),
            if (online.errorMessage != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: online.errorMessage!),
            ],
            const SizedBox(height: 12),
            _buildActions(context, settings.boardSize, online),
            const SizedBox(height: 12),
            _buildRoomStatus(context, online),
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
            ? 'Connected with Play Games'
            : 'Sign-in happens automatically when creating/joining'),
      ),
    );
  }

  Widget _buildActions(BuildContext context, int boardSize, OnlineGameState online) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Start a private match',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: online.creating
                  ? const Text('Creating room...')
                  : Text('Create game (Board $boardSize x $boardSize)'),
              onPressed: online.creating
                  ? null
                  : () => ref
                      .read(onlineGameProvider.notifier)
                      .createGame(boardSize: boardSize),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Join with room code'),
              onPressed: online.joining ? null : () => _showJoinDialog(context),
            ),
            if (online.session?.status == OnlineStatus.finished) ...[
              const Divider(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Offer rematch'),
                onPressed: () => ref.read(onlineGameProvider.notifier).requestRematch(),
              ),
            ],
            if (online.session?.status == OnlineStatus.playing && online.localColor != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.flag),
                label: const Text('Resign'),
                onPressed: () => ref.read(onlineGameProvider.notifier).resign(),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildRoomStatus(BuildContext context, OnlineGameState online) {
    if (online.session == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create or join a room to share a code with a friend. Games are saved in Firestore so both players stay in sync.',
              ),
            ],
          ),
        ),
      );
    }

    final session = online.session!;
    final subtitle = switch (session.status) {
      OnlineStatus.waiting => 'Share this code and wait for a friend to join.',
      OnlineStatus.playing => 'Game in progress. Make your move from the board.',
      OnlineStatus.finished => 'Game finished. Start a rematch to keep playing.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.videogame_asset, color: Colors.brown),
                const SizedBox(width: 8),
                Text('Room ${session.roomCode}',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (online.opponentInactive)
                  Chip(
                    label: const Text('Opponent left?'),
                    backgroundColor: Colors.orange.shade100,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 12),
            Row(
              children: [
                _PlayerPill(label: 'White', player: session.white),
                const SizedBox(width: 8),
                _PlayerPill(label: 'Black', player: session.black),
              ],
            ),
            const SizedBox(height: 12),
            _StatusBadge(status: session.status, winner: session.winner),
            const SizedBox(height: 12),
            if (session.status == OnlineStatus.waiting) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text('Waiting for opponent. Room code: ${session.roomCode}'),
            ],
            if (session.status == OnlineStatus.playing)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Open game board'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GameScreen()),
                ),
              ),
            if (session.status == OnlineStatus.finished)
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Request rematch'),
                onPressed: () => ref.read(onlineGameProvider.notifier).requestRematch(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showJoinDialog(BuildContext context) async {
    _joinCodeController.text = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join room'),
        content: TextField(
          controller: _joinCodeController,
          decoration: const InputDecoration(
            labelText: 'Room code',
            hintText: 'STONE-1234',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (result == true && _joinCodeController.text.isNotEmpty) {
      await ref.read(onlineGameProvider.notifier).joinGame(_joinCodeController.text);
    }
  }
}

class _PlayerPill extends StatelessWidget {
  final String label;
  final OnlineGamePlayer? player;

  const _PlayerPill({required this.label, required this.player});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(player?.displayName ?? 'Waiting...'),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OnlineStatus status;
  final OnlineWinner? winner;

  const _StatusBadge({required this.status, required this.winner});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    switch (status) {
      case OnlineStatus.waiting:
        color = Colors.amber.shade700;
        text = 'Waiting';
        break;
      case OnlineStatus.playing:
        color = Colors.green.shade700;
        text = 'Playing';
        break;
      case OnlineStatus.finished:
        color = Colors.indigo.shade700;
        text = winner == null
            ? 'Finished'
            : 'Winner: ${winner == OnlineWinner.white ? 'White' : winner == OnlineWinner.black ? 'Black' : 'Draw'}';
        break;
    }

    return Row(
      children: [
        Chip(
          backgroundColor: color.withValues(alpha: 0.1),
          label: Text(
            text,
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
