// Deterministic work counts, not a physical-device frame-rate benchmark.
// Baseline: --dart-define=STONES_PERF_ASSERT=false
// Evidence: --dart-define=STONES_PERF_OUTPUT=build/qa/performance/before
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/main.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/providers/settings_provider.dart';
import 'package:stones/screens/settings_screen.dart';
import 'package:stones/services/music_service.dart';
import 'package:stones/services/play_games_service.dart';
import 'package:stones/services/sound_manager.dart';
import 'package:stones/widgets/theme_gallery.dart';

import '../helpers/music_voice.dart';
import '../support/fake_account_service.dart';

const _assertPerformance =
    bool.fromEnvironment('STONES_PERF_ASSERT', defaultValue: true);
const _output = String.fromEnvironment('STONES_PERF_OUTPUT',
    defaultValue: 'build/qa/performance/current');

class _SilentSound extends SoundManager {
  @override
  Future<void> initialize() async {}
}

class _DelayedPlayGames extends PlayGamesService {
  _DelayedPlayGames(super.ref);
  final connected = Completer<void>();
  final restored = Completer<bool>();

  @override
  Future<void> manualSignIn() async {
    await connected.future;
    state = const PlayGamesState(errorMessage: 'Deferred connection failed');
  }

  @override
  Future<bool> restoreCloudGame() => restored.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(1366, 900),
  ]) {
    testWidgets('settings preview paints while scrolling at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = FakeAccount();
      addTearDown(account.events.close);
      final container = ProviderContainer(overrides: [
        accountServiceProvider.overrideWithValue(account),
      ]);
      addTearDown(container.dispose);
      var paints = 0;
      debugOnProfilePaint = (render) {
        if (render is RenderCustomPaint &&
            render.painter is ThemeSamplePainter) {
          paints++;
        }
      };
      addTearDown(() => debugOnProfilePaint = null);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen())));
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byType(ThemeGallery), 300,
          scrollable: scrollable);
      await tester.ensureVisible(find.byType(ThemeGallery));
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(scrollable).position;
      final start = position.pixels;
      // Warm the complete range before counting repaint work.
      for (var i = 0; i <= 12; i++) {
        position.jumpTo(math.min(position.maxScrollExtent, start + i * 20));
        await tester.pump();
      }
      paints = 0;
      for (var i = 0; i < 60; i++) {
        final step = i % 24;
        final offset = (step <= 12 ? step : 24 - step) * 20;
        position.jumpTo(math.min(position.maxScrollExtent, start + offset));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final galleryPaints = paints;
      await tester.ensureVisible(find.text('Preview Porto'));
      await tester.tap(find.text('Preview Porto'));
      await tester.pumpAndSettle();
      final previewPosition = tester
          .state<ScrollableState>(find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(Scrollable)))
          .position;
      // The dialog has no ListView-provided repaint boundary around its samples.
      for (var i = 0; i <= 12; i++) {
        previewPosition
            .jumpTo(math.min(previewPosition.maxScrollExtent, i * 10.0));
        await tester.pump();
      }
      paints = 0;
      for (var i = 0; i < 60; i++) {
        final step = i % 24;
        final offset = (step <= 12 ? step : 24 - step) * 10.0;
        previewPosition
            .jumpTo(math.min(previewPosition.maxScrollExtent, offset));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final previewPaints = paints;
      debugOnProfilePaint = null;
      final result = {
        'viewport': [size.width, size.height],
        'scrollFrames': 60,
        'gallerySamplePaints': galleryPaints,
        'dialogSamplePaints': previewPaints,
        'scope': 'Flutter test renderer; warmed scroll; not device FPS',
      };
      print('SETTINGS_PERF ${jsonEncode(result)}');
      await tester.runAsync(() async {
        final file = File('$_output/scroll-${size.width.toInt()}.json');
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode(result));
      });
      if (_assertPerformance) {
        expect(galleryPaints, 0,
            reason: 'Scrolling unchanged previews should reuse their layers');
        expect(previewPaints, 0,
            reason: 'Dialog scrolling should also reuse unchanged samples');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('unrelated settings do not rebuild the app or settings route',
      (tester) async {
    final account = FakeAccount();
    addTearDown(account.events.close);
    final music = MusicService(createVoice: FakeVoice.new);
    addTearDown(() => tester.runAsync(music.dispose));
    final container = ProviderContainer(overrides: [
      accountServiceProvider.overrideWithValue(account),
      musicServiceProvider.overrideWithValue(music),
      soundManagerProvider.overrideWithValue(_SilentSound()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const StonesApp()));
    await tester.pumpAndSettle();
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(navigator
        .push<void>(MaterialPageRoute(builder: (_) => const SettingsScreen())));
    await tester.pumpAndSettle();
    var appBuilds = 0;
    var settingsBuilds = 0;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is StonesApp) appBuilds++;
      if (element.widget is SettingsScreen) settingsBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    final settings = container.read(appSettingsProvider.notifier);
    await settings.setPlacementAnimationsEnabled(false);
    await tester.pumpAndSettle();
    await settings.setChessClockDefault(5, 420);
    await tester.pumpAndSettle();
    debugOnRebuildDirtyWidget = null;
    final result = {
      'unrelatedAppBuilds': appBuilds,
      'settingsRouteBuilds': settingsBuilds
    };
    print('SETTINGS_PERF ${jsonEncode(result)}');
    await tester.runAsync(() async {
      final file = File('$_output/rebuilds.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(result));
    });
    if (_assertPerformance) {
      expect(appBuilds, 0);
      expect(settingsBuilds, 0);
    }
    await settings.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark);
    expect(find.text('Settings'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('clock editing retains focus, validation and saved defaults',
      (tester) async {
    final account = FakeAccount();
    addTearDown(account.events.close);
    final container = ProviderContainer(overrides: [
      accountServiceProvider.overrideWithValue(account),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen())));
    final field = find.widgetWithText(TextField, '5×5 minutes');
    await tester.scrollUntilVisible(field, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(field, '0');
    await tester.pump();
    expect(find.text('Enter 1–999'), findsOneWidget);
    expect(
        container.read(appSettingsProvider).chessClockSecondsForSize(5), 300);
    final editor = tester.widget<TextField>(field);
    expect(editor.focusNode!.hasFocus, isTrue);
    await container
        .read(appSettingsProvider.notifier)
        .setPlacementAnimationsEnabled(false);
    await tester.pump();
    expect(editor.controller!.text, '0');
    expect(editor.focusNode!.hasFocus, isTrue);
    await tester.enterText(field, '7');
    await tester.pump();
    expect(
        container.read(appSettingsProvider).chessClockSecondsForSize(5), 420);
    final restored = AppSettingsNotifier();
    await restored.load();
    expect(restored.state.chessClockSecondsForSize(5), 420);
    expect(restored.state.placementAnimationsEnabled, isFalse);
    restored.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  for (final signIn in [true, false]) {
    testWidgets('pending Play Games feedback survives scrolling away: $signIn',
        (tester) async {
      final account = FakeAccount();
      addTearDown(account.events.close);
      late _DelayedPlayGames service;
      final container = ProviderContainer(overrides: [
        accountServiceProvider.overrideWithValue(account),
        playGamesServiceProvider.overrideWith((ref) {
          service = _DelayedPlayGames(ref);
          return service;
        }),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen())));
      final section = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_PlayGamesSection');
      await tester.scrollUntilVisible(section, 300,
          scrollable: find.byType(Scrollable).first);
      // The host does not enable the Android-only platform connection. Invoke
      // its real bound callback with an isolated service to exercise lifetime.
      final dynamic controls = tester.widget(section);
      final callback = (signIn ? controls.onManualSignIn : controls.onRestore)
          as Future<void> Function();
      final pending = callback();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(section, findsNothing);
      if (signIn) {
        service.connected.complete();
      } else {
        service.restored.complete(false);
      }
      await pending;
      await tester.pumpAndSettle();
      expect(
          find.text(signIn
              ? 'Deferred connection failed'
              : 'No compatible cloud save found.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('capture all 36 cosmetic combinations on both geometries',
      (tester) async {
    await tester.runAsync(() async {
      for (final shape in BoardShape.values) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xFFF7F1E4), BlendMode.src);
        for (final board in BoardTheme.values) {
          for (final pieces in PieceStyle.values) {
            canvas.save();
            canvas.translate(board.index * 160, pieces.index * 160);
            ThemeSamplePainter(board, style: pieces, shape: shape)
                .paint(canvas, const Size(160, 160));
            canvas.restore();
          }
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(960, 960);
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final file = File('$_output/mixed-${shape.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }
    });
  });
}
