import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/main.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/game_provider.dart';
import 'package:stones/providers/game_session_provider.dart';
import 'package:stones/services/ai/ai.dart';
import 'package:stones/services/ai/court_coach.dart';

const white = Piece(type: PieceType.flat, color: PlayerColor.white);
const black = Piece(type: PieceType.flat, color: PlayerColor.black);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Court is opt-in and isolated from online, local and scenarios', () {
    expect(const GameSessionConfig().isCourtMode, isFalse);
    const court = GameSessionConfig(mode: GameMode.vsComputer, courtMode: true);
    expect(court.isCourtMode, isTrue);
    expect(court.copyWith(mode: GameMode.online).isCourtMode, isFalse);
    expect(court.copyWith(mode: GameMode.local).isCourtMode, isFalse);
    expect(court.copyWith(scenario: tutorialAndPuzzleLibrary.first).isCourtMode,
        isFalse);
    expect(court.copyWith(courtMode: false).isCourtMode, isFalse);
    expect(
        court.copyWith(aiDifficulty: AIDifficulty.expert).isCourtMode, isTrue);
  });

  test('Opening coaching explains the opposing reserve and coordinates', () {
    final state = GameState.initial(5);
    const move = AIPlacementMove(Position(4, 0), PieceType.flat);
    final text = CourtCoach.explain(state, move);
    expect(text, contains('a1'));
    expect(text, contains('opponent'));
    expect(text, contains('not part of your own road'));
    expect(
        CourtCoach.apply(state, move)!
            .board
            .stackAt(const Position(4, 0))
            .controller,
        PlayerColor.black);
  });

  test(
      'Cap spread commentary describes bottom-first drops and control left behind',
      () {
    final board = Board.empty(5)
        .setStack(
            const Position(2, 0),
            const PieceStack([
              black,
              white,
              Piece(type: PieceType.capstone, color: PlayerColor.white)
            ]))
        .setStack(
            const Position(2, 2),
            const PieceStack(
                [Piece(type: PieceType.standing, color: PlayerColor.black)]));
    final state =
        GameState.initial(5).copyWith(board: board, phase: GamePhase.playing);
    final text = CourtCoach.explain(
        state, AIStackMove(const Position(2, 0), Direction.right, [1, 1]));
    expect(text, contains('Carry 2 from a3'));
    expect(text, contains('drop 1 on b3, then drop 1 on c3'));
    expect(text, contains('flattening'));
    expect(text, contains('opponent’s control'));
    expect(
        CourtCoach.explain(
            state, AIStackMove(const Position(2, 0), Direction.right, [1, 2])),
        contains('no longer legal'));
  });

  test('Tak warnings include a movement-only winning road', () async {
    var board = Board.empty(3);
    board = board
        .setStack(const Position(0, 0), const PieceStack([white]))
        .setStack(const Position(0, 1), const PieceStack([white]))
        .setStack(const Position(1, 2), const PieceStack([white]))
        .setStack(const Position(0, 2), const PieceStack([black]));
    final state =
        GameState.initial(3).copyWith(board: board, phase: GamePhase.playing);
    expect(await CourtCoach.warnings(state), contains('Tak! White'));
    expect(await CourtCoach.warnings(GameState.initial(3)), isEmpty);
    expect(await CourtCoach.warnings(state.copyWith(phase: GamePhase.finished)),
        isEmpty);
  });

  for (final color in PlayerColor.values) {
    for (final size in [
      const Size(320, 568),
      const Size(844, 390),
      const Size(1366, 768)
    ]) {
      testWidgets('Court fits $size and takes back a finished move for $color',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(gameSessionProvider.notifier).state = GameSessionConfig(
            mode: GameMode.vsComputer,
            courtMode: true,
            vsComputerPlayerColor: color);
        final notifier = container.read(gameStateProvider.notifier);
        final stone = Piece(type: PieceType.flat, color: color);
        final board = Board.empty(3)
            .setStack(const Position(0, 0), PieceStack([stone]))
            .setStack(const Position(0, 1), PieceStack([stone]));
        notifier.loadState(GameState.initial(3).copyWith(
            board: board, phase: GamePhase.playing, currentPlayer: color));
        expect(
            notifier.placePiece(const Position(0, 2), PieceType.flat), isTrue);
        container
            .read(moveHistoryProvider.notifier)
            .addMove(notifier.lastMoveRecord!);
        expect(container.read(gameStateProvider).isGameOver, isTrue);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: GameScreen())));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Ask coach'), findsOneWidget);
        await tester.tap(find.byTooltip('Take back to your previous decision'));
        await tester.pump();
        expect(container.read(gameStateProvider).isGameOver, isFalse);
        expect(container.read(gameStateProvider).currentPlayer, color);
        expect(
            container
                .read(gameStateProvider)
                .board
                .stackAt(const Position(0, 2))
                .isEmpty,
            isTrue);
        expect(container.read(moveHistoryProvider), isEmpty);
        expect(container.read(aiThinkingProvider), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
