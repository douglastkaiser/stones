import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../game/match_provider.dart';
import '../game/match_screen.dart';
import '../game/join_room_screen.dart';
import '../game/match_history_provider.dart';
import '../game/match_review_screen.dart';
import '../game/result_explanation.dart';
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
  int _historyLimit = 10;
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
      await Navigator.push<void>(
          context, MaterialPageRoute(builder: (_) => const MatchScreen()));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not resume. Your saved game is kept; try again.')));
      }
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final legacy = ref.watch(
            gameSessionProvider.select((s) => s.mode != GameMode.online)) &&
        ref.watch(gameStateProvider.select((s) =>
            !s.isGameOver &&
            (s.turnNumber > 1 || s.board.occupiedPositions.isNotEmpty)));
    final saved = ref.watch(savedLocalMatchProvider);
    final history = ref.watch(completedMatchesProvider(_historyLimit));
    final local = ref
        .watch(matchProvider.select((s) => s.game != null && s.room == null));
    return Scaffold(
        appBar: AppBar(title: const Text('My games')),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                  'Games saved on this device. Use the original account or browser profile to resume online rooms.'),
                              const SizedBox(height: 16),
                              if (saved.isLoading)
                                const LinearProgressIndicator(),
                              if (saved.hasError)
                                const Text(
                                    'The local save could not be read. Try reopening My games.'),
                              if (saved.valueOrNull != null || local) ...[
                                PlayModeCard(
                                    title: 'Continue saved game',
                                    description: _resuming
                                        ? 'Loading saved state...'
                                        : 'Resume your local board and players.',
                                    icon: Icons.play_arrow,
                                    featured: true,
                                    onTap: _resuming ? () {} : _resume),
                                const SizedBox(height: 16),
                              ],
                              if (legacy) ...[
                                PlayModeCard(
                                    title: 'Continue previous game',
                                    description: 'Resume your earlier game.',
                                    icon: Icons.play_arrow,
                                    onTap: () => Navigator.push<void>(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const GameScreen()))),
                                const SizedBox(height: 16),
                              ],
                              const SavedOnlineGames(),
                              if (history.hasError) ...[
                                const Text(
                                    'Completed games could not be read. Saved records have been kept.'),
                                TextButton(
                                    onPressed: () => ref
                                        .invalidate(completedMatchesProvider),
                                    child: const Text('Retry game history')),
                              ],
                              if (history.valueOrNull?.unreadableCount
                                  case final int count when count > 0)
                                const Text(
                                    'Some completed games could not be read. Other games are available; saved records have been kept.'),
                              if (history.valueOrNull?.matches.isNotEmpty ==
                                  true) ...[
                                Text('Completed games on this device',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                for (final match in history.value!.matches)
                                  ListTile(
                                      title: Text(
                                          '${match.config.shape.name} · ${match.config.seats.length} players · ${match.moves.length} moves'),
                                      subtitle: Text(
                                          explainResult(match.finalPosition)),
                                      trailing: const Icon(Icons.history),
                                      onTap: () => Navigator.push<void>(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => MatchReviewScreen(
                                                  match: match)))),
                              ],
                              if (history.valueOrNull?.hasMore == true)
                                TextButton(
                                    onPressed: () =>
                                        setState(() => _historyLimit += 10),
                                    child: const Text(
                                        'Show more completed games')),
                              const Text(
                                  'Have another game? Open its invitation link or enter its room code.'),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                  onPressed: () => Navigator.push<void>(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const JoinRoomScreen())),
                                  icon: const Icon(Icons.link),
                                  label: const Text('Join a friend')),
                            ]))))));
  }
}
