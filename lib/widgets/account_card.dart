import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_provider.dart';

class AccountCard extends ConsumerStatefulWidget {
  const AccountCard({super.key});
  @override
  ConsumerState<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<AccountCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(accountProvider.notifier).initialize());
    });
  }

  Future<void> _confirm({required bool switchAccount}) async {
    final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(
                    switchAccount ? 'Use your existing account?' : 'Sign out?'),
                content: Text(switchAccount
                    ? 'Guest rooms stay owned by your current guest identity. They cannot be transferred to an existing Google account automatically. Finish those games before switching.'
                    : 'Online rooms remain saved. Sign back into this Google account to resume your seats. Achievements and settings remain on this device.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child:
                          Text(switchAccount ? 'Switch account' : 'Sign out'))
                ]));
    if (approved != true || !mounted) return;
    final controller = ref.read(accountProvider.notifier);
    if (switchAccount) {
      await controller.signInGoogle(useExistingAccount: true);
    } else {
      await controller.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final controller = ref.read(accountProvider.notifier);
    final user = account.identity;
    final signedIn = user != null && !user.guest;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  signedIn
                      ? user.name ?? 'Google account'
                      : user?.guest == true
                          ? 'Playing as a guest'
                          : 'Your Stones account',
                  style: Theme.of(context).textTheme.titleMedium),
              if (signedIn && user.email != null) Text(user.email!),
              const SizedBox(height: 8),
              Text(signedIn
                  ? 'Use this account on another device to rejoin your online rooms by code. Achievements, unlocked themes and settings currently save on each device.'
                  : 'Play without an account. Link Google to keep your guest identity and resume online rooms on another device. Achievements and settings save on this device.'),
              if (account.error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                        liveRegion: true,
                        child: Text(account.error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)))),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (account.busy || (!account.ready && account.error == null))
                  const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        Text('Connecting…')
                      ])
                else if (!account.ready)
                  OutlinedButton(
                      onPressed: controller.retry,
                      child: const Text('Retry connection'))
                else if (signedIn)
                  OutlinedButton(
                      onPressed: () => _confirm(switchAccount: false),
                      child: const Text('Sign out'))
                else
                  FilledButton.icon(
                      onPressed: () => controller.signInGoogle(),
                      icon: const Icon(Icons.account_circle_outlined),
                      label: const Text('Sign in with Google')),
                if (account.conflict && !account.busy)
                  OutlinedButton(
                      onPressed: () => _confirm(switchAccount: true),
                      child: const Text('Use existing account')),
              ]),
            ])));
  }
}
