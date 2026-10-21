import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/providers/settings_provider.dart';
import 'package:stones/widgets/audio_controls.dart';

void main() {
  test('music and effects persist independently', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsNotifier();
    await settings.load();
    expect(settings.state.musicVolume, 0);
    expect(settings.state.isSoundMuted, false);
    await settings.setSoundMuted(true);
    await settings.setMusicVolume(.4);
    final restored = AppSettingsNotifier();
    await restored.load();
    expect(restored.state.musicVolume, .4);
    expect(restored.state.isSoundMuted, true);
    await restored.setMusicVolume(0);
    expect(restored.state.isSoundMuted, true);
    settings.dispose();
    restored.dispose();
  });
  testWidgets(
      'audio panel fits phone with enlarged text and exposes both controls',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(body: AudioSettingsPanel())))));
    expect(find.text('Sound effects'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(find.text('Background music'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
