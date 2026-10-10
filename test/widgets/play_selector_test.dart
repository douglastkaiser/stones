import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/screens/main_menu_screen.dart';
import 'package:stones/hex/hex_screen.dart';
import 'package:stones/hex/hex_room.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/services/sound_manager.dart';

class _SilentSound extends SoundManager {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> setMuted(bool muted) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(320, 568), const Size(1366, 768)]) {
    testWidgets('one board choice controls all play paths at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [soundManagerProvider.overrideWithValue(_SilentSound())],
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!),
              home: const MainMenuScreen())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final hex = find.widgetWithText(ChoiceChip, 'Hex · 3 players');
      await tester.ensureVisible(hex);
      await tester.tap(hex);
      await tester.pumpAndSettle();
      expect(find.text('Vs Computer'), findsOneWidget);
      expect(find.text('Local Game'), findsOneWidget);
      expect(find.text('Online Game'), findsOneWidget);
      expect(find.text('Three-player Hex'), findsNothing);
      for (final entry in [
        ('Vs Computer', HexSetupMode.computer),
        ('Local Game', HexSetupMode.local),
        ('Online Game', HexSetupMode.online)
      ]) {
        final target = find.text(entry.$1);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        final setup =
            tester.widget<HexSetupScreen>(find.byType(HexSetupScreen));
        expect(setup.initialMode, entry.$2);
        for (final seat in HexSeat.values) {
          final field = find.byWidgetPredicate((widget) =>
              widget is DropdownButtonFormField<HexSeatKind> &&
              widget.decoration.labelText == seat.label);
          await tester.scrollUntilVisible(field, 160,
              scrollable: find.byType(Scrollable).first);
          final value = tester
              .widget<DropdownButtonFormField<HexSeatKind>>(field)
              .initialValue;
          expect(
              value,
              seat == HexSeat.ivory
                  ? HexSeatKind.localHuman
                  : switch (entry.$2) {
                      HexSetupMode.computer => HexSeatKind.ai,
                      HexSetupMode.local => HexSeatKind.localHuman,
                      HexSetupMode.online => HexSeatKind.remoteHuman,
                    });
        }
        if (entry.$2 == HexSetupMode.online) {
          await tester.scrollUntilVisible(find.text('Join room'), 160,
              scrollable: find.byType(Scrollable).first);
          expect(find.text('Join room'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
