import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'match_config.dart';
import 'match_provider.dart';
import 'match_screen.dart';
import 'match_setup_form.dart';
import 'room_navigation.dart';
import '../theme/tavern_theme.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key, required this.shape});
  final BoardShape shape;
  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
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
      body: TavernBackdrop(child: SafeArea(
          child: SingleChildScrollView(padding: const EdgeInsets.all(20),
              child: Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: TavernPanel(child: MatchSetupForm(
                      initialConfig: _initialConfig,
                      onStart: (config) async {
                        if (!await _allowNewLocal(config)) return;
                        await leaveLegacyRooms(ref);
                        await ref.read(matchProvider.notifier).start(config);
                        if (!context.mounted) return;
                        await Navigator.push<void>(context,
                            MaterialPageRoute(builder: (_) => const MatchScreen()));
                      }))))))));
}
