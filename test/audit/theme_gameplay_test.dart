import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/main.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/cosmetics_provider.dart';
import 'package:stones/providers/game_provider.dart';

void main() {
  for (final theme in BoardTheme.values) {
    testWidgets(
        '${theme.name} renders mixed stacks and a capstone crush on a narrow 8x8 board',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const flat = Piece(type: PieceType.flat, color: PlayerColor.white);
      const dark = Piece(type: PieceType.flat, color: PlayerColor.black);
      const cap = Piece(type: PieceType.capstone, color: PlayerColor.white);
      final board = Board.empty(8)
          .setStack(const Position(3, 3), const PieceStack([flat, dark, cap]))
          .placePiece(const Position(3, 4),
              const Piece(type: PieceType.standing, color: PlayerColor.black));
      container.read(gameStateProvider.notifier).loadState(GameState.initial(8)
          .copyWith(board: board, phase: GamePhase.playing));
      await container.read(cosmeticsProvider.notifier).setTheme(theme);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!),
              home: const GameScreen())));
      Finder cell(int row, int col) => find
          .byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_BoardCell')
          .at(row * 8 + col);
      Future<void> press(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      await press(cell(3, 3));
      await press(find.byTooltip('Decrease Carry'));
      await press(find.byTooltip('Decrease Carry'));
      await press(cell(3, 4));
      expect(container.read(gameStateProvider).board, board);
      await press(find.widgetWithText(ElevatedButton, 'Confirm'));
      expect(
          container
              .read(gameStateProvider)
              .board
              .stackAt(const Position(3, 3))
              .pieces,
          [flat, dark]);
      expect(
          container
              .read(gameStateProvider)
              .board
              .stackAt(const Position(3, 4))
              .pieces,
          [dark, cap]);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
