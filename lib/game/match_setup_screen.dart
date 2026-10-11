import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'match_config.dart';
import 'match_provider.dart';
import 'match_screen.dart';
import 'match_setup_form.dart';
import 'room_navigation.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key, required this.shape});
  final BoardShape shape;
  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  final _code = TextEditingController();
  bool _joining = false;
  String? _error;
  late final MatchConfig _initialConfig;
  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    final defaults = MatchConfig.defaults(widget.shape);
    final size = widget.shape == BoardShape.square
        ? settings.boardSize.clamp(3, 8)
        : defaults.size;
    _initialConfig = defaults.copyWith(
        size: size,
        clockSeconds: settings.chessClockEnabled
            ? settings.chessClockSecondsForSize(
                widget.shape == BoardShape.square ? size : 2 * size + 1)
            : 0);
  }

  Future<bool> _allowNewLocal(MatchConfig config) async {
    if (config.online) return true;
    final saved = await ref.read(localMatchStorageProvider).read();
    if (saved == null ||
        (saved['moves'] as List).isEmpty ||
        saved['result'] != null) {
      return true;
    }
    final active = ref.read(matchProvider);
    if (active.id == saved['id'] && active.game?.finished == true) return true;
    if (!mounted) return false;
    return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Replace your saved local game?'),
                    content: const Text(
                        'Starting a new local game replaces the one saved on this device. Your online rooms remain available in Saved games.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Keep saved game')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Start new game')),
                    ])) ??
        false;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final screen = await loadInvitedRoom(ref, _code.text);
      if (!mounted) return;
      await Navigator.push<void>(
          context, MaterialPageRoute(builder: (context) => screen));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(
              '${widget.shape == BoardShape.square ? 'Square' : 'Hex'} · set up a game')),
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MatchSetupForm(
                                initialConfig: _initialConfig,
                                onStart: (config) async {
                                  if (!await _allowNewLocal(config)) return;
                                  await leaveLegacyRooms(ref);
                                  await ref
                                      .read(matchProvider.notifier)
                                      .start(config);
                                  if (!context.mounted) return;
                                  await Navigator.push<void>(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const MatchScreen()));
                                }),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 12),
                            Text('Have an invitation?',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            const Text(
                                'Joining uses the host’s board and seat setup.'),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _code,
                                enabled: !_joining,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp('[a-zA-Z0-9]')),
                                  LengthLimitingTextInputFormatter(7)
                                ],
                                decoration: const InputDecoration(
                                    labelText: 'Room code',
                                    hintText: 'UABCDEF'),
                                onSubmitted: (value) => _join()),
                            if (_error != null)
                              Text(_error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                                onPressed: _joining ? null : _join,
                                icon: const Icon(Icons.login),
                                label:
                                    Text(_joining ? 'Joining…' : 'Join room')),
                          ]))))));
}
