import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_provider.dart';
import '../services/turn_notification_service.dart';
import '../services/turn_push_types.dart';

final turnAlertEnabledProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, uid) =>
        turnAlertPreferences(FirebaseFirestore.instance, uid)
            .snapshots()
            .map((snapshot) => snapshot.data()?['enabled'] == true));

class TurnNotificationSettings extends ConsumerStatefulWidget {
  const TurnNotificationSettings({super.key});
  @override
  ConsumerState<TurnNotificationSettings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<TurnNotificationSettings> {
  bool _busy = false;
  String? _notice;
  TurnPushPermission? _permission;
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _notice = error is StateError
            ? error.message.toString()
            : 'Could not update notifications. Check your connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity =
        ref.watch(accountProvider.select((state) => state.identity));
    final uid = identity != null && !identity.guest ? identity.uid : null;
    final enabled = uid != null && turnAlertsReleased
        ? ref.watch(turnAlertEnabledProvider(uid))
        : const AsyncData(false);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
      if (!turnAlertsReleased)
        const Text('Turn notifications are not available in this build yet.'),
      if (uid == null)
        const Text(
            'Sign in to receive turn notifications across your devices.'),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Your turn notifications'),
          subtitle: const Text(
              'All online games, unless muted in My games. Permission is separate on each device.'),
          value: enabled.valueOrNull ?? false,
          onChanged: uid == null ||
                  !turnAlertsReleased ||
                  _busy ||
                  enabled.isLoading ||
                  enabled.hasError
              ? null
              : (value) => _run(() =>
                  turnAlertPreferences(FirebaseFirestore.instance, uid)
                      .set({'enabled': value}).timeout(
                          const Duration(seconds: 15)))),
      if (enabled.hasError)
        const Text(
            'Notification preferences could not be loaded. Reopen Settings to retry.'),
      Wrap(spacing: 8, children: [
        OutlinedButton(
            onPressed: uid == null || !turnAlertsReleased || _busy
                ? null
                : () => _run(() async {
                      await turnNotificationService.enableDevice(uid);
                      _permission = await turnNotificationService.permission();
                    }),
            child: const Text('Enable on this device')),
        TextButton(
            onPressed: uid == null || !turnAlertsReleased || _busy
                ? null
                : () => _run(() async {
                      await turnNotificationService.disableDevice(uid);
                      _permission = TurnPushPermission.available;
                    }),
            child: const Text('Disable on this device')),
      ]),
      if (_permission != null)
        Text(switch (_permission!) {
          TurnPushPermission.enabled =>
            'Notification permission is enabled on this device.',
          TurnPushPermission.denied =>
            'Notifications are blocked. Enable them in browser or system settings.',
          TurnPushPermission.installRequired =>
            'On iPhone or iPad, add Stones to the Home Screen, open it there, sign in, then enable notifications.',
          TurnPushPermission.unsupported =>
            'This browser or device does not support turn notifications.',
          TurnPushPermission.available =>
            'Notifications are off on this device.',
        }),
      const Text(
          'On iPhone or iPad, use Add to Home Screen (iOS 16.4 or later). Delivery depends on system permissions and background settings.'),
      if (_busy) const LinearProgressIndicator(),
      if (_notice != null) Text(_notice!),
    ]);
  }
}
