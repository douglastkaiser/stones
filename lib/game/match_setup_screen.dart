import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'match_config.dart';
import 'match_provider.dart';
import 'match_screen.dart';
import 'match_setup_form.dart';
import 'match_preset.dart';
import 'match_preset_dialog.dart';
import 'match_storage.dart';
import 'room_navigation.dart';
import '../theme/tavern_theme.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key, required this.shape, this.preset});
  final BoardShape shape;
  final MatchPreset? preset;
  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  late final MatchConfig _initialConfig;
  bool _busy = false;
  String? _error;
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

  Future<void> _startPreset(MatchPreset preset) async {
    if (_busy) return;
    final config = preset == MatchPreset.sameDevice
        ? preset.configuration(widget.shape)
        : await showDialog<MatchConfig>(
            context: context,
            builder: (_) =>
                MatchPresetDialog(preset: preset, shape: widget.shape));
    if (config != null && mounted) await _start(config);
  }

  Future<void> _start(MatchConfig config) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _allowNewLocal(config)) return;
      await leaveLegacyRooms(ref);
      await ref.read(matchProvider.notifier).start(config);
      if (!mounted) return;
      await Navigator.push<void>(
          context, MaterialPageRoute(builder: (_) => const MatchScreen()));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not start the game. Your saved game is kept. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _allowNewLocal(MatchConfig config) async {
    if (config.online) return true;
    final saved = await ref.read(localMatchStorageProvider).read();
    if (saved == null) return true;
    final game = replayLocalMatch(saved);
    if (game.finished || game.ply == 0) return true;
    if (!mounted) return false;
    return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Replace your saved local game?'),
                    content: const Text(
                        'Starting a new local game replaces the one saved on this device. Your online rooms remain available in My games.'),
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
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('New game')),
      body: TavernBackdrop(
          child: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: TavernPanel(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                Text(
                                    widget.shape == BoardShape.square
                                        ? 'Play Square'
                                        : 'Play Hex',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                const SizedBox(height: 8),
                                Text(widget.shape == BoardShape.square
                                    ? '5 × 5 · two players · untimed'
                                    : 'Radius 2 · three players · untimed · Stones variant'),
                                const SizedBox(height: 16),
                                for (final preset in MatchPreset.values)
                                  Card(
                                      child: ListTile(
                                          enabled: !_busy,
                                          leading: Icon(switch (preset) {
                                            MatchPreset.learn =>
                                              Icons.school_outlined,
                                            MatchPreset.computer =>
                                              Icons.smart_toy_outlined,
                                            MatchPreset.sameDevice =>
                                              Icons.people_outline,
                                            MatchPreset.online => Icons.link,
                                          }),
                                          title: Text(preset.label),
                                          subtitle: Text(preset.description),
                                          trailing: widget.preset == preset
                                              ? const Icon(Icons.star_outline)
                                              : const Icon(Icons.chevron_right),
                                          onTap: _busy
                                              ? null
                                              : () => _startPreset(preset))),
                                if (_busy) const Text('Starting…'),
                                if (_error != null)
                                  Text(_error!, semanticsLabel: _error),
                                const SizedBox(height: 8),
                                ExpansionTile(
                                    key: const ValueKey('customize-game'),
                                    maintainState: true,
                                    tilePadding: EdgeInsets.zero,
                                    title: const Text('Customize'),
                                    subtitle: const Text(
                                        'Board size, players, difficulty and clock'),
                                    children: [
                                      AbsorbPointer(
                                          absorbing: _busy,
                                          child: MatchSetupForm(
                                              initialConfig: widget.preset
                                                      ?.configuration(
                                                          widget.shape) ??
                                                  _initialConfig,
                                              onStart: _start)),
                                    ]),
                              ]))))))));
}
