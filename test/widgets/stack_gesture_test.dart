import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/main.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/game_provider.dart';
import 'package:stones/providers/ui_state_provider.dart';

const _flat = Piece(type: PieceType.flat, color: PlayerColor.white);
const _cap = Piece(type: PieceType.capstone, color: PlayerColor.white);
const _wall = Piece(type: PieceType.standing, color: PlayerColor.black);

Future<ProviderContainer> _showBoard(WidgetTester tester, Board board) async {
  final container = ProviderContainer();
  container.read(gameStateProvider.notifier).loadState(
        GameState.initial(5).copyWith(board: board, phase: GamePhase.playing),
      );
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    container.dispose();
  });
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: GameScreen()),
  ));
  await tester.pump();
  return container;
}

// Board cells are built in row-major order; coordinates below target the
// rendered board rather than calling its private gesture handlers directly.
Finder _cell(int row, int col) => find
    .byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_BoardCell')
    .at(row * 5 + col);

void main() {
  testWidgets('swiping a capstone stack onto an adjacent wall is rejected',
      (tester) async {
    final board = Board.empty(5)
        .setStack(const Position(2, 0), const PieceStack([_flat, _cap]))
        .placePiece(const Position(2, 1), _wall);
    final container = await _showBoard(tester, board);

    await tester.fling(_cell(2, 0), const Offset(50, 0), 1000);
    await tester.pump();
    expect(container.read(uiStateProvider).mode, InteractionMode.idle);
    expect(container.read(gameStateProvider).board, board);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('swiping the hand square continues a legal capstone spread',
      (tester) async {
    final board = Board.empty(5)
        .setStack(const Position(2, 0), const PieceStack([_flat, _flat, _cap]))
        .placePiece(const Position(2, 2), _wall);
    final container = await _showBoard(tester, board);

    await tester.tap(_cell(2, 0));
    await tester.pump();
    await tester.tap(_cell(2, 1));
    await tester.pump();
    await tester.tap(_cell(2, 1));
    await tester.pump();
    expect(container.read(uiStateProvider).pendingDropCount, 2);

    await tester.fling(_cell(2, 1), const Offset(50, 0), 1000);
    await tester.pump();
    final preview = container.read(uiStateProvider);
    expect(preview.drops, [2]);
    expect(preview.piecesPickedUp, 1);
    expect(preview.getCurrentHandPosition(), const Position(2, 2));
    expect(container.read(gameStateProvider).board, board);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
    await tester.pump();
    final result = container.read(gameStateProvider);
    expect(result.board.stackAt(const Position(2, 0)).isEmpty, isTrue);
    expect(result.board.stackAt(const Position(2, 1)).pieces, [_flat, _flat]);
    expect(result.board.stackAt(const Position(2, 2)).pieces, [
      const Piece(type: PieceType.flat, color: PlayerColor.black),
      _cap,
    ]);
    expect(result.currentPlayer, PlayerColor.black);
    await tester.pumpWidget(const SizedBox());
  });
}
