import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../hex/hex_match_provider.dart';
import '../hex/hex_screen.dart';
import '../providers/online_game_provider.dart';
import '../screens/game_screen.dart';
import '../screens/online_lobby_screen.dart';
import 'match_provider.dart';
import 'match_screen.dart';

Future<void> leaveLegacyRooms(WidgetRef ref) async {
  ref.read(hexMatchProvider.notifier).leave();
  await ref.read(onlineGameProvider.notifier).leaveRoom();
}

/// One invitation/recovery entry point. Legacy formats keep their wire codecs.
Future<Widget> loadInvitedRoom(WidgetRef ref, String invitation,
    {String? expectedUid}) async {
  final code = invitation.trim().toUpperCase();
  if (!RegExp(r'^([UH][A-Z]{6}|[A-Z0-9]{6})$').hasMatch(code)) {
    throw StateError('Enter the room code from your invitation.');
  }
  ref.read(matchProvider.notifier).leave();
  await leaveLegacyRooms(ref);
  if (code.startsWith('U') && code.length == 7) {
    await ref.read(matchProvider.notifier).join(code, expectedUid: expectedUid);
    return const MatchScreen();
  }
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
