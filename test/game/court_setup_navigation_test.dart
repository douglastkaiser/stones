import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_setup_form.dart';
import 'package:stones/game/match_setup_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final shape in BoardShape.values) {
    for (final mouse in [false, true]) {
      testWidgets(
          '${shape.name}: ${mouse ? 'wheel' : 'touch'} reaches Court after expanding setup at large text',
          (tester) async {
        tester.view.physicalSize =
            mouse ? const Size(1280, 640) : const Size(390, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
                theme: ThemeData(
                    platform: mouse
                        ? TargetPlatform.windows
                        : TargetPlatform.android),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: child!),
                home: MatchSetupScreen(shape: shape))));
        await tester.pumpAndSettle();

        final scroll = find.byType(SingleChildScrollView).first;
        Future<void> scrollTo(Finder target) async {
          for (var attempt = 0;
              target.hitTestable().evaluate().isEmpty && attempt < 30;
              attempt++) {
            if (mouse) {
              final bounds = tester.getRect(scroll);
              await tester.sendEventToBinding(PointerScrollEvent(
                  position: Offset(bounds.right - 24, bounds.center.dy),
                  scrollDelta: const Offset(0, 260)));
            } else {
              await tester.drag(scroll, const Offset(0, -260));
            }
            await tester.pumpAndSettle();
          }
          expect(target.hitTestable(), findsOneWidget);
        }

        await scrollTo(find.text('Customize'));
        await tester.tap(find.text('Customize'));
        await tester.pumpAndSettle();
        await scrollTo(find.text('Game settings'));
        await tester.tap(find.text('Game settings'));
        await tester.pumpAndSettle();
        final court = find.widgetWithText(SwitchListTile, 'Court Mode');
        await scrollTo(court);
        expect(tester.widget<SwitchListTile>(court).onChanged, isNull);
        expect(find.textContaining('Choose AI for at least one player'),
            findsOneWidget);

        // Return to the seats using actual reverse input as well.
        final position = tester
            .state<ScrollableState>(find
                .descendant(of: scroll, matching: find.byType(Scrollable))
                .first)
            .position;
        for (var attempt = 0; position.pixels > 0 && attempt < 30; attempt++) {
          if (mouse) {
            await tester.sendEventToBinding(PointerScrollEvent(
                position: tester.getRect(scroll).center,
                scrollDelta: const Offset(0, -500)));
          } else {
            await tester.drag(scroll, const Offset(0, 500));
          }
          await tester.pumpAndSettle();
        }
        expect(position.pixels, 0);
        final seat = find.byKey(const ValueKey('control-charcoal-localHuman'));
        await scrollTo(seat);
        await tester.tap(seat);
        await tester.pumpAndSettle();
        await tester.tap(find.text('AI').last);
        await tester.pumpAndSettle();
        await scrollTo(court);
        expect(tester.widget<SwitchListTile>(court).onChanged, isNotNull);
        await tester.tap(court);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(court).value, isTrue);
        expect(find.text('Clock per player'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final controls in [
    [SeatControl.localHuman, SeatControl.onlineHuman],
    [SeatControl.ai, SeatControl.ai],
  ]) {
    testWidgets('Court stays visible and unavailable for $controls',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: MatchSetupForm(
                      initialConfig: MatchConfig(
                          shape: BoardShape.square,
                          size: 5,
                          seats: [
                            SeatConfig(SeatId.ivory, control: controls[0]),
                            SeatConfig(SeatId.charcoal, control: controls[1]),
                          ]),
                      onStart: (_) async {})))));
      await tester.ensureVisible(find.text('Game settings'));
      await tester.tap(find.text('Game settings'));
      await tester.pumpAndSettle();
      final court = find.widgetWithText(SwitchListTile, 'Court Mode');
      await tester.ensureVisible(court);
      expect(tester.widget<SwitchListTile>(court).onChanged, isNull);
      expect(tester.widget<SwitchListTile>(court).value, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
