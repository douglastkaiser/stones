import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_setup_form.dart';

void main() {
  for (final shape in BoardShape.values) {
    for (final width in [320.0, 1366.0]) {
      testWidgets(
          '${shape.name} shared setup at $width preserves seats and starts a mixed room',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        MatchConfig? started;
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: MediaQuery(
                    data: MediaQueryData(
                        size: Size(width, 900),
                        textScaler: const TextScaler.linear(1.5)),
                    child: SingleChildScrollView(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: MatchSetupForm(
                                initialConfig: MatchConfig.defaults(shape),
                                onStart: (config) async {
                                  started = config;
                                })))))));
        Future<void> reveal(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
        }

        Future<void> select(SeatId seat, SeatControl old, String label) async {
          final dropdown =
              find.byKey(ValueKey('control-${seat.name}-${old.name}'));
          await reveal(dropdown);
          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
        }

        while (find.text('Add player').evaluate().isNotEmpty) {
          await reveal(find.text('Add player'));
          await tester.tap(find.text('Add player'));
          await tester.pumpAndSettle();
        }
        expect(find.byKey(const ValueKey('seat-jade')), findsOneWidget);
        expect(find.text('Add player'), findsNothing);
        await select(SeatId.jade, SeatControl.localHuman, 'AI');
        await select(SeatId.charcoal, SeatControl.localHuman, 'Online human');
        final otherShape = shape == BoardShape.square ? 'Hex' : 'Square';
        await reveal(find.widgetWithText(ChoiceChip, otherShape));
        await tester.tap(find.widgetWithText(ChoiceChip, otherShape));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('control-jade-ai')), findsOneWidget);
        expect(find.byKey(const ValueKey('control-charcoal-onlineHuman')),
            findsOneWidget);
        await reveal(find.text('Create room'));
        await tester.tap(find.text('Create room'));
        await tester.pumpAndSettle();
        expect(started!.seats.length, 4);
        expect(started!.online, isTrue);
        expect(started!.seat(SeatId.jade).control, SeatControl.ai);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Hex removes to two, repairs starter and blocks duplicate launch',
      (tester) async {
    final pending = Completer<void>();
    var starts = 0;
    MatchConfig? started;
    final setup =
        MatchConfig.defaults(BoardShape.hex).copyWith(starter: SeatId.copper);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MatchSetupForm(
                    initialConfig: setup,
                    onStart: (config) async {
                      started = config;
                      starts++;
                      await pending.future;
                    })))));
    await tester.ensureVisible(find.byTooltip('Remove Copper'));
    await tester.tap(find.byTooltip('Remove Copper'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove Ivory'), findsNothing);
    await tester.ensureVisible(find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pump();
    expect(starts, 1);
    expect(started!.ids, [SeatId.ivory, SeatId.charcoal]);
    expect(started!.starter, SeatId.ivory);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
