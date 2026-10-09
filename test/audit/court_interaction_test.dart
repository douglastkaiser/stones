import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/main.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/providers.dart';

void recordPlacement(ProviderContainer container, Position position) {
  final notifier = container.read(gameStateProvider.notifier);
  expect(notifier.placePiece(position, PieceType.flat), isTrue);
  container
      .read(moveHistoryProvider.notifier)
      .addMove(notifier.lastMoveRecord!);
}

Future<void> showCourt(WidgetTester tester, ProviderContainer container,
    {Size size = const Size(390, 844), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: const GameScreen())));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Repeated Court takebacks restore the initial exchange and history',
      (tester) async {
    final container = ProviderContainer();
    container.read(gameSessionProvider.notifier).state =
        const GameSessionConfig(mode: GameMode.vsComputer, courtMode: true);
    recordPlacement(container, const Position(0, 0));
    recordPlacement(container, const Position(4, 4));
    recordPlacement(container, const Position(2, 2));
    recordPlacement(container, const Position(3, 3));
    await showCourt(tester, container);
    await tester.tap(find.byTooltip('Take back to your previous decision'));
    await tester.pump();
    expect(container.read(moveHistoryProvider).length, 2);
    expect(container.read(gameStateProvider).currentPlayer, PlayerColor.white);
    await tester.tap(find.byTooltip('Take back to your previous decision'));
    await tester.pump();
    expect(container.read(moveHistoryProvider), isEmpty);
    expect(container.read(gameStateProvider).board.occupiedPositions, isEmpty);
    expect(container.read(gameStateProvider).isOpeningPhase, isTrue);
    expect(container.read(aiThinkingProvider), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Take back a terminal AI reply together with the human move',
      (tester) async {
    final container = ProviderContainer();
    container.read(gameSessionProvider.notifier).state =
        const GameSessionConfig(mode: GameMode.vsComputer, courtMode: true);
    const stone = Piece(type: PieceType.flat, color: PlayerColor.black);
    final board = Board.empty(3)
        .setStack(const Position(0, 0), const PieceStack([stone]))
        .setStack(const Position(0, 1), const PieceStack([stone]));
    container.read(gameStateProvider.notifier).loadState(
        GameState.initial(3).copyWith(board: board, phase: GamePhase.playing));
    recordPlacement(container, const Position(2, 2));
    recordPlacement(container, const Position(0, 2));
    await showCourt(tester, container);
    await tester.tap(find.byTooltip('Take back to your previous decision'));
    await tester.pump();
    expect(container.read(gameStateProvider).board, same(board));
    expect(container.read(gameStateProvider).currentPlayer, PlayerColor.white);
    expect(container.read(gameStateProvider).isGameOver, isFalse);
    expect(container.read(moveHistoryProvider), isEmpty);
    expect(container.read(aiThinkingProvider), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Black cannot take back only the initial AI opening and strand its turn',
      (tester) async {
    final container = ProviderContainer();
    container.read(gameSessionProvider.notifier).state =
        const GameSessionConfig(
            mode: GameMode.vsComputer,
            courtMode: true,
            vsComputerPlayerColor: PlayerColor.black);
    recordPlacement(container, const Position(0, 0));
    await showCourt(tester, container);
    expect(container.read(gameStateProvider).currentPlayer, PlayerColor.black);
    final undo =
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));
    expect(undo.onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
        'Court is untimed with a stored clock preference and enlarged text at $size',
        (tester) async {
      final container = ProviderContainer();
      container.read(gameSessionProvider.notifier).state =
          const GameSessionConfig(mode: GameMode.vsComputer, courtMode: true);
      await container
          .read(appSettingsProvider.notifier)
          .setChessClockEnabled(true);
      await showCourt(tester, container, size: size, scale: 1.5);
      expect(container.read(chessClockProvider).isRunning, isFalse);
      expect(find.text('Ask coach'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Court win awards no achievements and can be replayed',
      (tester) async {
    final container = ProviderContainer();
    container.read(gameSessionProvider.notifier).state =
        const GameSessionConfig(mode: GameMode.vsComputer, courtMode: true);
    const stone = Piece(type: PieceType.flat, color: PlayerColor.white);
    final board = Board.empty(3)
        .setStack(const Position(0, 0), const PieceStack([stone]))
        .setStack(const Position(0, 1), const PieceStack([stone]));
    container.read(gameStateProvider.notifier).loadState(
        GameState.initial(3).copyWith(board: board, phase: GamePhase.playing));
    await showCourt(tester, container);
    recordPlacement(container, const Position(0, 2));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(container.read(gameStateProvider).isGameOver, isTrue);
    expect(container.read(achievementProvider).totalWins, 0);
    await tester.tap(find.byTooltip('Take back to your previous decision'));
    await tester.pump();
    recordPlacement(container, const Position(0, 2));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(container.read(achievementProvider).totalWins, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
