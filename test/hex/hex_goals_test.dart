import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/hex/hex_match_provider.dart';
import 'package:stones/hex/hex_room.dart';
import 'package:stones/hex/hex_screen.dart';

import 'hex_victory_audit_test.dart' show reportedPosition;

HexGame beforeSharedWin() {
  final game = reportedPosition();
  return game.copyWith(
      ply: 39, board: {...game.board}..remove(const HexCell(0, -2)));
}

class AuditController extends HexMatchController {
  AuditController(HexGame game, {bool thinking = true})
      : super(
            authenticate: () async => 'audit',
            store: () => throw StateError('Offline audit'),
            botDelay: const Duration(milliseconds: 1)) {
    state = HexMatchState(
        game: game,
        controls: {HexSeat.ivory},
        kinds: const [HexSeatKind.localHuman, HexSeatKind.ai, HexSeatKind.ai],
        busy: thinking);
  }
}

void main() {
  testWidgets('legacy room shows its original goals and matching help',
      (tester) async {
    final controller = AuditController(reportedPosition(rulesVersion: 1));
    await tester.pumpWidget(ProviderScope(
        overrides: [hexMatchProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: HexGameScreen())));
    await tester.pump();
    expect(find.textContaining('Legacy room'), findsOneWidget);
    expect(find.text('I A'), findsOneWidget);
    expect(find.text('I B'), findsOneWidget);
    expect(find.textContaining('Any color'), findsNothing);
    await tester.tap(find.byTooltip('Hex rules'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Only your assigned pair wins.'), findsOneWidget);
    expect(
        find.textContaining('Every color can connect any pair'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (var radius = 2; radius <= 4; radius++) {
    test(
        'all six goal labels occupy their correct visual boundaries at R$radius',
        () {
      final game = HexGame.initial(radius: radius);
      final geometry = HexBoardGeometry(const Size(304, 360), radius);
      const center = Offset(152, 180);
      final ivoryA = geometry.goalAnchor(game, HexAxis.q, false);
      final ivoryB = geometry.goalAnchor(game, HexAxis.q, true);
      expect(ivoryA.dx, lessThan(center.dx));
      expect(ivoryA.dy, greaterThan(center.dy));
      expect(ivoryB.dx, greaterThan(center.dx));
      expect(ivoryB.dy, lessThan(center.dy));
      expect(
          geometry.goalAnchor(game, HexAxis.r, false).dy, lessThan(center.dy));
      expect(geometry.goalAnchor(game, HexAxis.r, true).dy,
          greaterThan(center.dy));
      final copperA = geometry.goalAnchor(game, HexAxis.s, false);
      expect(copperA.dx, greaterThan(center.dx));
      expect(copperA.dy, greaterThan(center.dy));
      for (final seat in HexAxis.values) {
        final a = geometry.goalAnchor(game, seat, false);
        final b = geometry.goalAnchor(game, seat, true);
        expect((a + b - center * 2).distance, lessThan(.0001));
        for (final anchor in [a, b]) {
          expect(anchor.dx, inInclusiveRange(16, 288));
          expect(anchor.dy, inInclusiveRange(9, 351));
        }
      }
    });
  }
  for (final size in [const Size(320, 568), const Size(1366, 768)]) {
    testWidgets('shared goals remain clear during Charcoal AI at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AuditController(beforeSharedWin().copyWith(ply: 40));
      await tester.pumpWidget(ProviderScope(
          overrides: [hexMatchProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: HexGameScreen())));
      await tester.pump();
      expect(find.text('Charcoal · AI thinking'), findsOneWidget);
      expect(find.textContaining('Any color · A to A, B to B, or C to C'),
          findsOneWidget);
      final board = tester.widget<HexBoard>(find.byType(HexBoard));
      expect(board.game.rulesVersion, 2);
      for (final marker in ['A', 'B', 'C']) {
        expect(find.text(marker), findsNWidgets(2));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  test('winning human move reaches controller terminal state before either bot',
      () async {
    final controller = AuditController(beforeSharedWin(), thinking: false);
    addTearDown(controller.dispose);
    final move = HexMove.place(const HexCell(0, -2), PieceType.flat);
    expect(await controller.play(move), isTrue);
    expect(controller.state.game!.winner, HexSeat.ivory);
    expect(controller.state.game!.finished, isTrue);
    expect(controller.state.busy, isFalse);
    expect(controller.state.canPlay, isFalse);
    final terminal = controller.state.game;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(identical(controller.state.game, terminal), isTrue);
    expect(await controller.play(move, bot: true), isFalse);
  });

  testWidgets('finished road shows Ivory victory instead of the next AI turn',
      (tester) async {
    final result = HexRules.play(beforeSharedWin(),
        HexMove.place(const HexCell(0, -2), PieceType.flat))!;
    final controller = AuditController(result, thinking: false);
    await tester.pumpWidget(ProviderScope(
        overrides: [hexMatchProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: HexGameScreen())));
    await tester.pump();
    expect(find.text('Ivory · Road'), findsOneWidget);
    final chips =
        tester.widgetList<ActionChip>(find.byType(ActionChip)).toList();
    final primary = Theme.of(tester.element(find.byType(HexGameScreen)))
        .colorScheme
        .primary;
    expect(chips[HexSeat.ivory.index].side!.color, primary);
    expect(chips[HexSeat.charcoal.index].side!.color, Colors.transparent);
    expect(chips[HexSeat.copper.index].side!.color, Colors.transparent);
    expect(find.text('Set up another match'), findsOneWidget);
    expect(find.textContaining('AI thinking'), findsNothing);
    expect(tester.widget<HexBoard>(find.byType(HexBoard)).road, isNotEmpty);
    expect(tester.widget<HexBoard>(find.byType(HexBoard)).onCell, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
