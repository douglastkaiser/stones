import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../hex/hex_match_provider.dart';
import '../hex/hex_screen.dart';
import '../providers/online_game_provider.dart';
import '../screens/game_screen.dart';
import '../screens/online_lobby_screen.dart';
import 'match_provider.dart';
import '../providers/account_provider.dart';
import 'room_invitation.dart';
import 'match_screen.dart';

Future<void> leaveLegacyRooms(WidgetRef ref) async {
  ref.read(hexMatchProvider.notifier).leave();
  await ref.read(onlineGameProvider.notifier).leaveRoom();
}

/// One invitation/recovery entry point. Legacy formats keep their wire codecs.
Future<Widget?> loadInvitedRoom(WidgetRef ref, String invitation,
    {String? expectedUid}) async {
  final code = roomCodeFromInvitation(invitation);
  if (expectedUid != null) {
    final identity = await ref.read(accountProvider.notifier).ensurePlayer();
    if (identity.uid != expectedUid) {
      throw StateError('Use the original account or browser profile to resume this game.');
    }
  }
  if (!ref.context.mounted) return null;
  final current = ref.read(matchProvider);
  if (current.room?.code == code && current.game != null) {
    return const MatchScreen();
  }
  final hasActiveGame = current.game != null || current.busy ||
      ref.read(hexMatchProvider).game != null ||
      ref.read(onlineGameProvider).session != null;
  if (hasActiveGame) {
    final confirmed = await showDialog<bool>(context: ref.context,
        builder: (context) => AlertDialog(
          title: const Text('Switch to another game?'),
          content: const Text('Your current game stays saved. Online clocks keep running while you play elsewhere.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep current game')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Join other game')),
          ]));
    if (confirmed != true || !ref.context.mounted) return null;
  }
  if (code.startsWith('U') && code.length == 7) {
    await ref.read(matchProvider.notifier).join(code, expectedUid: expectedUid);
    if (!ref.context.mounted) return null;
    if (ref.read(matchProvider).room?.code != code) {
      throw StateError('Another game was opened. Your invitation is still available.');
    }
    await leaveLegacyRooms(ref);
    return const MatchScreen();
  }
  ref.read(matchProvider.notifier).leave();
  await leaveLegacyRooms(ref);
  if (code.startsWith('H') && code.length == 7) {
    await ref
        .read(hexMatchProvider.notifier)
        .join(code, expectedUid: expectedUid);
    final match = ref.read(hexMatchProvider);
    if (match.error != null || match.game == null) {
      throw StateError(match.error ?? 'Could not load this room.');
    }
    return const HexGameScreen();
  }
  await ref
      .read(onlineGameProvider.notifier)
      .joinGame(code, expectedUid: expectedUid);
  final online = ref.read(onlineGameProvider);
  if (online.errorMessage != null || online.session == null) {
    throw StateError(online.errorMessage ?? 'Could not load this room.');
  }
  return online.waitingForOpponent
      ? const OnlineLobbyScreen()
      : const GameScreen();
}
