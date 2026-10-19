import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_provider.dart';
import '../providers/player_profile_provider.dart';
import '../services/player_profile_repository.dart';

class PlayerNameEditor extends ConsumerStatefulWidget {
  const PlayerNameEditor(
      {super.key, required this.uid, required this.fallback});
  final String uid, fallback;
  @override
  ConsumerState<PlayerNameEditor> createState() => _PlayerNameEditorState();
}

class _PlayerNameEditorState extends ConsumerState<PlayerNameEditor> {
  bool _saving = false;
  Future<void> _edit() async {
    final saved = ref.read(playerNameProvider(widget.uid)).asData?.value;
    var name = saved ?? widget.fallback;
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Edit player name'),
                scrollable: true,
                content: Form(
                    key: form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'Your Stones name is public in games and leaderboards. It does not change your Google profile.'),
                          const SizedBox(height: 16),
                          TextFormField(
                              initialValue: name,
                              onChanged: (value) => name = value,
                              autofocus: true,
                              maxLength: 40,
                              decoration: const InputDecoration(
                                  labelText: 'Player name'),
                              validator: (value) {
                                try {
                                  validatePlayerName(value ?? '');
                                  return null;
                                } on FormatException catch (error) {
                                  return error.message;
                                }
                              }),
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        if (form.currentState!.validate()) {
                          Navigator.pop(context, name.trim());
                        }
                      },
                      child: const Text('Save name'))
                ]));
    if (!mounted ||
        value == null ||
        ref.read(accountProvider).identity?.uid != widget.uid) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(playerProfileRepositoryProvider).rename(widget.uid, value);
      if (mounted && ref.read(accountProvider).identity?.uid == widget.uid) {
        ref.invalidate(playerNameProvider(widget.uid));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Player name saved')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Name could not be confirmed. Check your connection and retry.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
      onPressed: _saving ? null : _edit,
      icon: const Icon(Icons.edit_outlined),
      label: Text(_saving ? 'Saving name…' : 'Edit player name'));
}
