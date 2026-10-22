import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/sound_manager.dart';

/// One audio owner for the entire app, including learning and online play.
class AudioControls extends ConsumerStatefulWidget {
  const AudioControls(
      {super.key, required this.child, required this.navigator});

  /// Gameplay supplies an inline audio command instead of an overlapping button.
  static VoidCallback hideFloatingButton(BuildContext context) {
    final owner = context.findAncestorStateOfType<_AudioControlsState>();
    if (owner == null) return () {};
    owner._inlineOwners++;
    owner._refreshButton();
    var released = false;
    return () {
      if (released) return;
      released = true;
      owner._inlineOwners--;
      owner._refreshButton();
    };
  }

  final Widget child;
  final GlobalKey<NavigatorState> navigator;
  @override
  ConsumerState<AudioControls> createState() => _AudioControlsState();
}

class _AudioControlsState extends ConsumerState<AudioControls>
    with WidgetsBindingObserver {
  int _inlineOwners = 0;
  void _refreshButton() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  final _music = AudioPlayer();
  bool _unlocked = false, _foreground = true;
  Future<void> _updates = Future.value();
  bool _started = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_music.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (!_unlocked) return;
    final settings = ref.read(appSettingsProvider);
    _updates = _updates.then((_) async {
      if (!mounted) return;
      final sounds = ref.read(soundManagerProvider);
      await sounds.initialize();
      if (!mounted) return;
      await sounds.setMuted(settings.isSoundMuted);
      if (!mounted) return;
      ref.read(isMutedProvider.notifier).state = settings.isSoundMuted;
      if (!_foreground || settings.musicVolume == 0) {
        await _music.pause();
        return;
      }
      await _music.setVolume(settings.musicVolume);
      if (!_started) {
        await _music.setReleaseMode(ReleaseMode.loop);
        await _music.play(AssetSource('sounds/background.wav'));
        _started = true;
      } else {
        await _music.resume();
      }
    }).catchError((Object _) {
      _unlocked = false;
      /* Browser audio may require another gesture. */
    });
  }

  void _settings() {
    final overlay = widget.navigator.currentState?.overlay;
    if (overlay == null) return;
    showModalBottomSheet<void>(
        context: overlay.context,
        showDragHandle: true,
        builder: (_) => const SafeArea(
            child: Padding(
                padding: EdgeInsets.all(20), child: AudioSettingsPanel())));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider, (_, next) => _sync());
    return Listener(
        onPointerDown: (_) {
          if (!_unlocked) {
            _unlocked = true;
            _sync();
          }
        },
        child: Overlay.wrap(
            child: Stack(children: [
          widget.child,
          if (_inlineOwners == 0)
            Positioned(
                right: 12,
                bottom: 12,
                child: SafeArea(
                    child: Material(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(24),
                        child: IconButton(
                            tooltip: 'Audio settings',
                            onPressed: _settings,
                            icon: const Icon(Icons.volume_up_outlined))))),
        ])));
  }
}

class AudioSettingsPanel extends ConsumerWidget {
  const AudioSettingsPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Audio settings', style: Theme.of(context).textTheme.titleLarge),
      SwitchListTile(
          title: const Text('Sound effects'),
          value: !settings.isSoundMuted,
          onChanged: (value) =>
              ref.read(appSettingsProvider.notifier).setSoundMuted(!value)),
      SwitchListTile(
          secondary: const Icon(Icons.music_note),
          title: const Text('Background music'),
          subtitle: const Text('A quiet instrumental loop'),
          value: settings.musicVolume > 0,
          onChanged: (value) => ref
              .read(appSettingsProvider.notifier)
              .setMusicVolume(value ? .25 : 0)),
    ]));
  }
}
