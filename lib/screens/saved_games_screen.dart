import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../game/match_provider.dart';
import '../game/match_screen.dart';
import '../game/join_room_screen.dart';
import '../widgets/saved_online_games.dart';
import '../widgets/play_mode_card.dart';
import 'game_screen.dart';

/// Device shortcuts today; the account-backed index is a separate finishing packet.
class SavedGamesScreen extends ConsumerStatefulWidget {
  const SavedGamesScreen({super.key});
  @override
  ConsumerState<SavedGamesScreen> createState() => _SavedGamesScreenState();
}
class _SavedGamesScreenState extends ConsumerState<SavedGamesScreen> {
  bool _resuming = false;
  Future<void> _resume() async {
    if (_resuming) return;
    setState(() => _resuming = true);
    try {
      final controller = ref.read(matchProvider.notifier);
      final session = ref.read(matchProvider);
      if (session.game == null || session.room != null) {
        if (!await controller.resumeLocal()) return;
      }
      controller.pause(false);
      if (!mounted) return;
      await Navigator.push<void>(context,
          MaterialPageRoute(builder: (_) => const MatchScreen()));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not resume. Your saved game is kept; try again.')));
      }
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final legacy = ref.watch(gameSessionProvider.select((s) => s.mode != GameMode.online)) &&
        ref.watch(gameStateProvider.select((s) => !s.isGameOver &&
            (s.turnNumber > 1 || s.board.occupiedPositions.isNotEmpty)));
    final saved = ref.watch(savedLocalMatchProvider);
    final local = ref.watch(matchProvider.select((s) => s.game != null && s.room == null));
    return Scaffold(appBar: AppBar(title: const Text('My games')),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Games saved on this device. Use the original account or browser profile to resume online rooms.'),
            const SizedBox(height: 16),
            if (saved.isLoading) const LinearProgressIndicator(),
            if (saved.hasError) const Text('The local save could not be read. Try reopening My games.'),
            if (saved.valueOrNull != null || local) ...[
              PlayModeCard(title: 'Continue saved game',
                  description: _resuming ? 'Loading saved state...' : 'Resume your local board and players.',
                  icon: Icons.play_arrow, featured: true, onTap: _resuming ? () {} : _resume),
              const SizedBox(height: 16),
            ],
            if (legacy) ...[
              PlayModeCard(title: 'Continue previous game', description: 'Resume your earlier game.',
                  icon: Icons.play_arrow, onTap: () => Navigator.push<void>(context,
                      MaterialPageRoute(builder: (_) => const GameScreen()))),
              const SizedBox(height: 16),
            ],
            const SavedOnlineGames(),
            const Text('Have another game? Open its invitation link or enter its room code.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => Navigator.push<void>(context,
                MaterialPageRoute(builder: (_) => const JoinRoomScreen())),
                icon: const Icon(Icons.link), label: const Text('Join a friend')),
          ]))))));
  }
}
