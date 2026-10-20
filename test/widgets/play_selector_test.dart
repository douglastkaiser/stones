import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:stones/theme/tavern_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/screens/main_menu_screen.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_setup_screen.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/services/sound_manager.dart';
import 'package:stones/providers/account_provider.dart';
import '../support/fake_account_service.dart';
import '../game/match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

class _SilentSound extends SoundManager {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> setMuted(bool muted) async {}
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('STONES_CAPTURE_PREVIEW')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/finishing/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final font in [('StonesLora', 'Lora'), ('StonesSans', 'Roboto')]) {
      await (FontLoader(font.$1)
            ..addFont(rootBundle.load('assets/fonts/${font.$2}-Regular.ttf')))
          .load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(320, 568), const Size(1366, 768)]) {
    testWidgets('Square and Hex use one setup and playable match at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryMatchStorage();
      final store = MemoryMatchRoomStore();
      final controller = MatchController(
          storage: storage,
          authenticate: () async => 'host',
          store: () => store);
      final capture = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: capture,
          child: ProviderScope(
              overrides: [
                soundManagerProvider.overrideWithValue(_SilentSound()),
                accountServiceProvider.overrideWithValue(FakeAccount()),
                localMatchStorageProvider.overrideWithValue(storage),
                matchProvider.overrideWith((ref) => controller),
              ],
              child: MaterialApp(
                  theme: TavernTheme.build(Brightness.dark),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: const TextScaler.linear(1.5)),
                      child: child!),
                  home: const MainMenuScreen()))));
      await tester.pumpAndSettle();
      await _capture(
          tester, capture, 'app-home-${size.width.toInt()}-dark-large-text');
      expect(find.text('Vs Computer'), findsNothing);
      for (final shape in BoardShape.values) {
        final target = find.text(shape == BoardShape.square ? 'Square' : 'Hex');
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<MatchSetupScreen>(find.byType(MatchSetupScreen))
                .shape,
            shape);
        await _capture(tester, capture,
            'app-setup-${shape.name}-${size.width.toInt()}-dark-large-text');
        await tester.ensureVisible(find.text('Customize'));
        await tester.tap(find.text('Customize'));
        await tester.pumpAndSettle();
        final count = shape == BoardShape.square ? 2 : 3;
        expect(
            find.byWidgetPredicate(
                (w) => w is DropdownButtonFormField<SeatControl>),
            findsNWidgets(count));
        for (final id in SeatId.values.take(count)) {
          expect(find.text('${id.label} control'), findsOneWidget);
        }
        await tester.scrollUntilVisible(find.text('Start game'), 160,
            scrollable: find.byType(Scrollable).last);
        await tester.tap(find.text('Start game'));
        await tester.pumpAndSettle();
        expect(find.byType(MatchScreen), findsOneWidget);
        expect(controller.state.game!.config.shape, shape);
        expect(controller.state.game!.config.seats.length, count);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await store.updates.close();
    });
  }
}
