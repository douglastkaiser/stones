import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hex/hex_match_provider.dart';
import '../hex/hex_screen.dart';
import '../game/match_provider.dart';
import '../game/match_screen.dart';
import '../providers/online_game_provider.dart';
import '../providers/saved_rooms_provider.dart';
import '../screens/game_screen.dart';
import '../screens/online_lobby_screen.dart';

/// Visible recovery entry point, without initializing Firebase on menu startup.
class SavedOnlineGames extends ConsumerStatefulWidget {
  const SavedOnlineGames({super.key});
  @override
  ConsumerState<SavedOnlineGames> createState() => _SavedOnlineGamesState();
}

class _SavedOnlineGamesState extends ConsumerState<SavedOnlineGames> {
  String? _loading;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await ref.read(savedRoomsProvider.notifier).load();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Saved rooms could not be loaded. You can still rejoin using the room code.');
      }
    }
  }

  Future<void> _resume(SavedRoom room) async {
    setState(() {
      _loading = room.code;
      _error = null;
    });
    try {
      ref.read(hexMatchProvider.notifier).leave();
      ref.read(matchProvider.notifier).leave();
      await ref.read(onlineGameProvider.notifier).leaveRoom();
      if (!mounted) return;
      Widget screen;
      if (room.unified) {
        await ref
            .read(matchProvider.notifier)
            .join(room.code, expectedUid: room.uid);
        if (!mounted) return;
        screen = const MatchScreen();
      } else if (room.hex) {
        await ref
            .read(hexMatchProvider.notifier)
            .join(room.code, expectedUid: room.uid);
        if (!mounted) return;
        final match = ref.read(hexMatchProvider);
        if (match.error != null || match.game == null) {
          throw StateError(match.error ?? 'Could not load this room.');
        }
        screen = const HexGameScreen();
      } else {
        await ref
            .read(onlineGameProvider.notifier)
            .joinGame(room.code, expectedUid: room.uid);
        if (!mounted) return;
        final online = ref.read(onlineGameProvider);
        if (online.errorMessage != null || online.session == null) {
          throw StateError(online.errorMessage ?? 'Could not load this room.');
        }
        screen = online.waitingForOpponent
            ? const OnlineLobbyScreen()
            : const GameScreen();
      }
      if (!mounted) return;
      await Navigator.push<void>(
          context, MaterialPageRoute(builder: (_) => screen));
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError
            ? error.message.toString()
            : 'Could not resume. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(savedRoomsProvider);
    if (rooms.isEmpty && _error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
          child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Resume online game',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
              'Rooms stay saved when you close the app. Return with this browser profile or account.'),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          for (final room in rooms)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(room.hex ? Icons.hexagon_outlined : Icons.grid_view),
              title: Text('${room.hex ? 'Hex' : 'Square'} · ${room.code}'),
              subtitle: Text(_loading == room.code
                  ? 'Loading saved state…'
                  : 'Resume from the latest confirmed move'),
              onTap: _loading == null ? () => _resume(room) : null,
              trailing: _loading == room.code
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      tooltip: 'Remove ${room.code} shortcut',
                      icon: const Icon(Icons.close),
                      onPressed: _loading != null
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(savedRoomsProvider.notifier)
                                    .forget(room);
                              } catch (_) {
                                if (mounted) {
                                  setState(() => _error =
                                      'Could not remove this shortcut. Try again.');
                                }
                              }
                            }),
            ),
          const Text(
              'Removing a shortcut does not delete the room. Clearing browser data can remove your guest identity.',
              style: TextStyle(fontSize: 12)),
        ]),
      )),
    );
  }
}
