import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/services/music_service.dart';
import 'package:stones/services/sound_manager.dart';
import 'package:stones/widgets/audio_controls.dart';

import 'helpers/music_voice.dart';

class _UnavailableEffects extends SoundManager {
  @override
  Future<void> initialize() async => throw StateError('effects unavailable');
}

void main() {
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
