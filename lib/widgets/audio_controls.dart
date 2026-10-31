import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/sound_manager.dart';
import '../services/music_service.dart';
import '../services/audio_gesture.dart';
import 'music_scene.dart';

/// One audio owner for the entire app, including learning and online play.
class AudioControls extends ConsumerStatefulWidget {
  const AudioControls(
      {super.key, required this.child, required this.navigator});

  static void unlock(BuildContext context) =>
      context.findAncestorStateOfType<_AudioControlsState>()?._unlockAudio();

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

  late final _music = ref.read(musicServiceProvider);
  late final _director = ref.read(musicDirectorProvider);
  bool _unlocked = false, _foreground = true;
  bool _effectsFailed = false;
  Future<void> _updates = Future.value();
  late final VoidCallback _stopGestures;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _director.cue.addListener(_musicCueChanged);
    _musicCueChanged();
    _stopGestures = listenForAudioGesture(_unlockAudio);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopGestures();
    _director.cue.removeListener(_musicCueChanged);
    _music.configure(enabled: false, volume: 0);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final settings = ref.read(appSettingsProvider);
    _music.configure(
        enabled: _unlocked && _foreground, volume: settings.musicVolume);
    if (!_unlocked) return;
    _updates = _updates.then((_) async {
      if (!mounted) return;
      final sounds = ref.read(soundManagerProvider);
      await sounds.initialize();
      if (!mounted) return;
      await sounds.setMuted(settings.isSoundMuted);
      if (!mounted) return;
      ref.read(isMutedProvider.notifier).state = settings.isSoundMuted;
      _effectsFailed = false;
    }).catchError((Object _) {
      _effectsFailed = true;
      /* An optional effect load must not prevent music or gameplay. */
    });
  }

  void _musicCueChanged() => _music.setCue(_director.cue.value);

  void _unlockAudio() {
    if (!mounted) return;
    _music.unlock();
    if (!_unlocked) {
      _unlocked = true;
      _sync();
    } else {
      _music.retry();
      if (_effectsFailed) _sync();
    }
  }

  void _settings() {
    _unlockAudio();
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
    return MusicScope(
        director: _director,
        child: Listener(
            onPointerDown: (_) => _unlockAudio(),
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
            ]))));
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
          onChanged: (value) {
            AudioControls.unlock(context);
            unawaited(
                ref.read(appSettingsProvider.notifier).setSoundMuted(!value));
          }),
      SwitchListTile(
          secondary: const Icon(Icons.music_note),
          title: const Text('Background music'),
          subtitle: const Text(
              'An acoustic theme with variations for play and learning'),
          value: settings.musicVolume > 0,
          onChanged: (value) {
            AudioControls.unlock(context);
            unawaited(ref
                .read(appSettingsProvider.notifier)
                .setMusicVolume(value ? .25 : 0));
          }),
    ]));
  }
}
