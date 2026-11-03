import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/services/music_service.dart';
import 'package:stones/services/sound_manager.dart';
import 'package:stones/providers/settings_provider.dart';
import 'package:stones/widgets/audio_controls.dart';

import 'helpers/music_voice.dart';

class _UnavailableEffects extends SoundManager {
  @override
  Future<void> initialize() async => throw StateError('effects unavailable');
}

class _CountingEffects extends SoundManager {
  int initializations = 0;
  int muteUpdates = 0;

  @override
  Future<void> initialize() async => initializations++;

  @override
  Future<void> setMuted(bool muted) async => muteUpdates++;
}

void main() {
  testWidgets('unrelated preferences do not reconfigure unlocked audio',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final effects = _CountingEffects();
    final music = MusicService(createVoice: FakeVoice.new, wait: (_) async {});
    final container = ProviderContainer(overrides: [
      musicServiceProvider.overrideWithValue(music),
      soundManagerProvider.overrideWithValue(effects),
    ]);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) =>
                AudioControls(navigator: navigator, child: child!),
            home: const Scaffold(body: AudioSettingsPanel()))));
    await tester.tap(find.text('Sound effects'));
    await tester.pumpAndSettle();
    final initializations = effects.initializations;
    final muteUpdates = effects.muteUpdates;
    expect(initializations, greaterThan(0));
    final settings = container.read(appSettingsProvider.notifier);
    await settings.setPlacementAnimationsEnabled(false);
    await settings.setChessClockDefault(5, 420);
    await settings.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(effects.initializations, initializations);
    expect(effects.muteUpdates, muteUpdates);
    await settings.setSoundMuted(false);
    await tester.pumpAndSettle();
    expect(effects.muteUpdates, greaterThan(muteUpdates));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(music.dispose);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'accessible music activation works without a pointer or working effects',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final voices = <FakeVoice>[];
    final music = MusicService(
        createVoice: () {
          final voice = FakeVoice();
          voices.add(voice);
          return voice;
        },
        wait: (_) async {});
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          musicServiceProvider.overrideWithValue(music),
          soundManagerProvider.overrideWithValue(_UnavailableEffects()),
        ],
        child: MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) =>
                AudioControls(navigator: navigator, child: child!),
            home: const Scaffold(body: AudioSettingsPanel()))));
    expect(voices.any((voice) => voice.playing), isFalse);
    // DOM semantics and assistive activation can invoke onChanged without sending
    // onPointerDown to the surrounding Flutter Listener.
    tester.widgetList<Switch>(find.byType(Switch)).last.onChanged!(true);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(voices.where((voice) => voice.playing), hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(voices.any((voice) => voice.playing), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(voices.where((voice) => voice.playing), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(music.dispose);
    expect(tester.takeException(), isNull);
  });
}
