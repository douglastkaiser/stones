import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/services/game_wake_lock.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_screen.dart';
import 'game/match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

void main() {
  for (final shape in BoardShape.values) {
    for (final aiSeats in [0, 1, 2]) {
      testWidgets('$shape with $aiSeats AI seats stays awake without input',
          (tester) async {
        final calls = <bool>[];
        final lock =
            GameWakeLock(toggle: (enabled) async => calls.add(enabled));
        final controller = MatchController(
          storage: MemoryMatchStorage(),
          authenticate: () async => 'host',
          store: () => MemoryMatchRoomStore(),
          botDelay: const Duration(days: 1),
        );
        await controller.start(MatchConfig.defaults(shape).copyWith(seats: [
          SeatConfig(SeatId.ivory,
              control: aiSeats == 2 ? SeatControl.ai : SeatControl.localHuman),
          SeatConfig(SeatId.charcoal,
              control: aiSeats > 0 ? SeatControl.ai : SeatControl.localHuman),
        ]));
        await tester.pumpWidget(ProviderScope(
          overrides: [
            matchProvider.overrideWith((ref) => controller),
            gameWakeLockProvider.overrideWithValue(lock),
          ],
          child: MaterialApp(
            navigatorObservers: [gameWakeLockRoutes],
            home: const MatchScreen(),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(minutes: 5));
        expect(calls, [true]);
        controller.pause(true);
        await tester.pumpAndSettle();
        expect(calls.last, false);
        controller.pause(false);
        await tester.pumpAndSettle();
        expect(calls.last, true);
        if (aiSeats < 2) {
          await controller.resign(SeatId.ivory);
          await tester.pumpAndSettle();
          expect(controller.state.game!.finished, isTrue);
          expect(calls.last, false);
        }
        await controller.start(MatchConfig.defaults(shape));
        await tester.pumpAndSettle();
        expect(calls.last, true);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(calls.last, false);
      });
    }
  }

  test('orders a late acquisition before releasing on departure', () async {
    final acquired = Completer<void>();
    final calls = <bool>[];
    final lock = GameWakeLock(toggle: (enabled) async {
      calls.add(enabled);
      if (enabled) await acquired.future;
    });
    final owner = Object();
    final enable = lock.update(owner, true);
    await Future<void>.delayed(Duration.zero);
    final disable = lock.update(owner, false);
    acquired.complete();
    await Future.wait([enable, disable]);
    expect(calls, [true, false]);
  });

  test('one departing game cannot release another game’s lock', () async {
    final calls = <bool>[];
    final lock = GameWakeLock(toggle: (enabled) async => calls.add(enabled));
    final first = Object(), second = Object();
    await lock.update(first, true);
    await lock.update(second, true);
    await lock.update(first, false);
    expect(calls, [true]);
    await lock.update(second, false);
    expect(calls, [true, false]);
  });

  testWidgets('pause, completion and rematch update the screen lock',
      (tester) async {
    final calls = <bool>[];
    final lock = GameWakeLock(toggle: (enabled) async => calls.add(enabled));
    final active = ValueNotifier(true);
    await tester.pumpWidget(ProviderScope(
      overrides: [gameWakeLockProvider.overrideWithValue(lock)],
      child: MaterialApp(
        navigatorObservers: [gameWakeLockRoutes],
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (_, value, __) => GameKeepAwake(
            active: value,
            child: const Scaffold(body: Text('Game')),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(calls, [true]);
    active.value = false;
    await tester.pumpAndSettle();
    expect(calls.last, false);
    active.value = true;
    await tester.pumpAndSettle();
    expect(calls.last, true);
    active.value = false;
    await tester.pumpAndSettle();
    active.value = true;
    await tester.pumpAndSettle();
    expect(calls, [true, false, true, false, true]);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(calls.last, false);
    active.dispose();
  });

  testWidgets('dialogs retain the lock; pages and background release it',
      (tester) async {
    final calls = <bool>[];
    final lock = GameWakeLock(toggle: (enabled) async => calls.add(enabled));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [gameWakeLockProvider.overrideWithValue(lock)],
      child: MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [gameWakeLockRoutes],
        home: const GameKeepAwake(
          active: true,
          child: Scaffold(body: Text('Game')),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    unawaited(showDialog<void>(
      context: tester.element(find.text('Game')),
      builder: (_) => const AlertDialog(content: Text('Help')),
    ));
    await tester.pumpAndSettle();
    expect(calls, [true]);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    unawaited(navigator.currentState!.push<void>(MaterialPageRoute(
      builder: (_) => const Scaffold(body: Text('Other page')),
    )));
    await tester.pumpAndSettle();
    expect(calls, [true, false]);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(calls, [true, false, true]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(calls.last, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls.last, true);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(calls.last, false);
  });

  testWidgets('denied requests retry on interaction without a rebuild loop',
      (tester) async {
    var attempts = 0;
    final lock = GameWakeLock(toggle: (enabled) async {
      if (enabled && ++attempts == 1) throw UnsupportedError('Denied');
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [gameWakeLockProvider.overrideWithValue(lock)],
      child: const MaterialApp(
        home: GameKeepAwake(
          active: true,
          child: Scaffold(body: Center(child: Text('Game'))),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    await tester.tap(find.text('Game'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    await tester.tap(find.text('Game'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
