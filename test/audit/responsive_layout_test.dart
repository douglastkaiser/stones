import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/main.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/game_provider.dart';
import 'package:stones/providers/game_session_provider.dart';
import 'package:stones/providers/scenario_provider.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_match_provider.dart';
import 'package:stones/hex/hex_room.dart';
import 'package:stones/hex/hex_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1024, 600),
    const Size(1366, 768)
  ]) {
    for (final scale in [1.0, 1.5]) {
      for (final mode in [
        'square',
        'square result',
        'tutorial',
        'hex',
        'hex setup'
      ]) {
        testWidgets('$mode fits $size with text scale $scale', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final container = ProviderContainer();
          addTearDown(container.dispose);
          Widget screen;
          if (mode.startsWith('square') || mode == 'tutorial') {
            var game = GameState.initial(8);
            if (mode == 'tutorial') {
              final scenario = tutorialAndPuzzleLibrary[8];
              game = scenario.buildInitialState();
              container.read(gameSessionProvider.notifier).state =
                  GameSessionConfig(scenario: scenario);
              container
                  .read(scenarioStateProvider.notifier)
                  .startScenario(scenario);
              container.read(scenarioStateProvider.notifier).markIntroShown();
            }
            if (mode == 'square result') {
              game = game.copyWith(
                  phase: GamePhase.finished,
                  result: GameResult.blackWins,
                  winReason: WinReason.road);
            }
            container.read(gameStateProvider.notifier).loadState(game);
            screen = const GameScreen();
          } else if (mode == 'hex') {
            container.read(hexMatchProvider.notifier).startLocal(
                4, List.filled(3, HexSeatKind.localHuman), HexSeat.ivory);
            screen = const HexGameScreen();
          } else {
            screen = const HexSetupScreen();
          }
          await tester.pumpWidget(UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: MediaQuery(
                    data: MediaQueryData(
                        size: size, textScaler: TextScaler.linear(scale)),
                    child: screen),
              )));
          await tester.pump();
          expect(tester.takeException(), isNull);
          if (mode == 'hex') {
            expect(tester.getSize(find.byType(HexBoard)).shortestSide,
                greaterThanOrEqualTo(180));
            await tester.ensureVisible(find.byType(HexBoard));
            final rect = tester.getRect(find.byType(HexBoard));
            final geometry = HexBoardGeometry(rect.size, 4);
            await tester
                .tapAt(rect.topLeft + geometry.center(const HexCell(0, 0)));
            await tester.pump();
            final confirm = find.widgetWithText(FilledButton, 'Confirm');
            await tester.ensureVisible(confirm);
            await tester.pump();
            expect(
                tester.getRect(confirm).bottom, lessThanOrEqualTo(size.height));
            expect(tester.takeException(), isNull);
          } else if (mode == 'square') {
            final cell = find
                .byWidgetPredicate(
                    (widget) => widget.runtimeType.toString() == '_BoardCell')
                .first;
            await tester.ensureVisible(cell);
            await tester.tap(cell);
            await tester.pump();
            final cancel = find.widgetWithText(TextButton, 'Cancel');
            await tester.ensureVisible(cancel);
            await tester.pump();
            expect(
                tester.getRect(cancel).bottom, lessThanOrEqualTo(size.height));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
