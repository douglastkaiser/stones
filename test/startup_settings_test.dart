import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stones/providers/settings_provider.dart';
import 'package:stones/main.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/screens/main_menu_screen.dart';
import 'package:stones/services/sound_manager.dart';

import 'support/fake_account_service.dart';

class _BlockingSound extends SoundManager {
  final ready = Completer<void>();

  @override
  Future<void> initialize() => ready.future;
}

class _DelayedStore extends InMemorySharedPreferencesStore {
  _DelayedStore() : super.withData({'flutter.theme_mode': 2});
  final ready = Completer<void>();
  int reads = 0;

  @override
  Future<Map<String, Object>> getAll() async {
    reads++;
    await ready.future;
    return super.getAll();
  }
}

class _UnavailableStore extends InMemorySharedPreferencesStore {
  _UnavailableStore() : super.empty();

  @override
  Future<Map<String, Object>> getAll() async =>
      throw StateError('Storage unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final value in <Object?>[null, 0, 1, 2, -1, 3, 999, '2', true]) {
    test('startup validates saved appearance $value', () async {
      SharedPreferences.setMockInitialValues({
        if (value != null) SettingsKeys.themeMode: value,
      });
      final settings = AppSettingsNotifier();
      addTearDown(settings.dispose);
      await settings.load();
      final expected = value is int && value >= 0 && value < 3
          ? ThemeMode.values[value]
          : ThemeMode.system;
      expect(settings.state.themeMode, expected);
    });
  }

  test('concurrent and later startup callers share one delayed read', () async {
    SharedPreferences.setMockInitialValues({});
    final store = _DelayedStore();
    SharedPreferencesStorePlatform.instance = store;
    final settings = AppSettingsNotifier();
    addTearDown(settings.dispose);
    final first = settings.load();
    final second = settings.load();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(store.reads, 1);
    store.ready.complete();
    await first;
    expect(settings.state.themeMode, ThemeMode.dark);
    await settings.load();
    expect(store.reads, 1);
  });

  test('unavailable storage completes startup in system appearance', () async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = _UnavailableStore();
    final settings = AppSettingsNotifier();
    addTearDown(settings.dispose);
    await settings.load();
    expect(settings.state.themeMode, ThemeMode.system);
    expect(settings.state.boardSize, 5);
  });

  testWidgets('menu first builds with saved settings; audio does not gate play',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = _DelayedStore();
    SharedPreferencesStorePlatform.instance = store;
    final sound = _BlockingSound();
    final providers = ProviderContainer(overrides: [
      accountServiceProvider.overrideWithValue(FakeAccount()),
      soundManagerProvider.overrideWithValue(sound),
    ]);
    final startup = launchStones(container: providers);
    await tester.pump();
    expect(find.byType(MaterialApp), findsNothing);
    store.ready.complete();
    await tester.pump();
    await startup;
    await tester.pump();
    expect(find.byType(MainMenuScreen), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark);
    expect(sound.ready.isCompleted, isFalse);
    expect(store.reads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    providers.dispose();
  });
}
