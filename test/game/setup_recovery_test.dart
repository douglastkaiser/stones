import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/match_setup_form.dart';
import 'package:stones/game/match_setup_screen.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/providers/settings_provider.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

Map<String, dynamic> snapshotFor(
    MatchConfig config, Iterable<MatchMove> moves) {
  var game = MatchState.initial(config);
  final records = <Map<String, dynamic>>[];
  for (final move in moves) {
    records.add(move.toMap(game.current));
    game = MatchRules.play(game, move)!;
  }
  expect(game.finished, isTrue);
  return {'id': 'finished-game', 'config': config.toMap(), 'moves': records};
}

Future<void> startAfterFinishedGame(
    WidgetTester tester, Map<String, dynamic> snapshot) async {
  final storage = MemoryMatchStorage()..snapshot = snapshot;
  final store = MemoryMatchRoomStore();
  // A fresh controller cannot rely on an in-memory result to identify completion.
  final controller = MatchController(
      storage: storage, authenticate: () async => 'host', store: () => store);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        matchProvider.overrideWith((ref) => controller),
        localMatchStorageProvider.overrideWithValue(storage),
      ],
      child:
          const MaterialApp(home: MatchSetupScreen(shape: BoardShape.square))));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Same-device game'));
  await tester.tap(find.text('Same-device game'));
  await tester.pumpAndSettle();
  expect(find.text('Replace your saved local game?'), findsNothing);
  expect(find.byType(MatchScreen), findsOneWidget);
  expect(controller.state.id, isNot(snapshot['id']));
  expect(controller.state.game!.ply, 0);
  expect(controller.state.game!.finished, isFalse);
  expect(storage.snapshot!['moves'], isEmpty);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await store.updates.close();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final shape in BoardShape.values) {
    testWidgets(
        '${shape.name} road result in a cold save skips replacement prompt',
        (tester) async {
      final config = MatchConfig.defaults(shape).copyWith(
          seats: const [SeatConfig(SeatId.ivory), SeatConfig(SeatId.charcoal)]);
      final cells = shape == BoardShape.square
          ? [
              (4, 0),
              (0, 0),
              (0, 1),
              (4, 1),
              (0, 2),
              (4, 2),
              (0, 3),
              (3, 1),
              (0, 4)
            ]
          : [
              (-2, 2),
              (-2, 0),
              (-1, 0),
              (0, 2),
              (0, 0),
              (1, 1),
              (1, 0),
              (2, -2),
              (2, 0)
            ];
      final snapshot = snapshotFor(config, [
        for (var i = 0; i < cells.length; i++)
          MatchMove.place(
              Cell(cells[i].$1, cells[i].$2),
              shape == BoardShape.hex && i > 1 && i.isOdd
                  ? PieceType.standing
                  : PieceType.flat),
      ]);
      expect(snapshot['result'], isNull);
      await startAfterFinishedGame(tester, snapshot);
    });
  }

  for (final draw in [false, true]) {
    testWidgets(
        'cold saved flat ${draw ? 'draw' : 'win'} skips replacement prompt',
        (tester) async {
      final config = MatchConfig.defaults(BoardShape.square).copyWith(size: 3);
      final cells = [
        (0, 0),
        (2, 2),
        (0, 2),
        (1, 0),
        (2, 0),
        (0, 1),
        (1, 1),
        (2, 1),
        (1, 2)
      ];
      final snapshot = snapshotFor(config, [
        for (var i = 0; i < cells.length; i++)
          MatchMove.place(Cell(cells[i].$1, cells[i].$2),
              i < 2 || (i == 2 && !draw) ? PieceType.flat : PieceType.standing),
      ]);
      expect(snapshot['result'], isNull);
      await startAfterFinishedGame(tester, snapshot);
    });
  }

  for (final reason in [
    ResultReason.resignation,
    ResultReason.time,
    ResultReason.abandoned
  ]) {
    testWidgets('cold saved ${reason.name} skips replacement prompt',
        (tester) async {
      final config = MatchConfig.defaults(BoardShape.square);
      await startAfterFinishedGame(tester, {
        'id': 'ended-game',
        'config': config.toMap(),
        'moves': [
          MatchMove.place(const Cell(0, 0), PieceType.flat).toMap(SeatId.ivory)
        ],
        'result': {
          'winner': reason == ResultReason.abandoned ? null : 'charcoal',
          'reason': reason.name
        },
      });
    });
  }

  testWidgets(
      'setup respects saved size/clocks and cancelling replacement preserves the game',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {SettingsKeys.boardSize: 6, SettingsKeys.chessClockEnabled: true});
    final storage = MemoryMatchStorage();
    final store = MemoryMatchRoomStore();
    final controller = MatchController(
        storage: storage, authenticate: () async => 'host', store: () => store);
    await controller.start(MatchConfig.defaults(BoardShape.square));
    await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    final id = controller.state.id;
    final container = ProviderContainer(overrides: [
      matchProvider.overrideWith((ref) => controller),
      localMatchStorageProvider.overrideWithValue(storage),
    ]);
    await container.read(appSettingsProvider.notifier).load();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: MatchSetupScreen(shape: BoardShape.square))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Customize'));
    await tester.tap(find.text('Customize'));
    await tester.pumpAndSettle();
    final config = tester
        .widget<MatchSetupForm>(find.byType(MatchSetupForm))
        .initialConfig;
    expect(config.size, 6);
    expect(config.clockSeconds, 600);
    await tester.ensureVisible(find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    expect(find.text('Replace your saved local game?'), findsOneWidget);
    await tester.tap(find.text('Keep saved game'));
    await tester.pumpAndSettle();
    expect(container.read(matchProvider).id, id);
    expect(storage.snapshot!['moves'], hasLength(1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await store.updates.close();
  });
}
