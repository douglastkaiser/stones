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
import '../game/match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

class _SilentSound extends SoundManager {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> setMuted(bool muted) async {}
}

void main() {
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
      await tester.pumpWidget(ProviderScope(
          overrides: [
            soundManagerProvider.overrideWithValue(_SilentSound()),
            localMatchStorageProvider.overrideWithValue(storage),
            matchProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!),
              home: const MainMenuScreen())));
      await tester.pumpAndSettle();
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
