import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_match_provider.dart';
import 'package:stones/hex/hex_room.dart';
import 'package:stones/models/models.dart';
import 'package:stones/models/online_clock.dart';
import 'package:stones/providers/online_game_provider.dart';
import 'package:stones/providers/game_provider.dart';
import 'package:stones/providers/game_session_provider.dart';
import 'package:stones/providers/scenario_provider.dart';
import 'package:stones/providers/saved_rooms_provider.dart';
import 'package:stones/widgets/saved_online_games.dart';

import '../hex/hex_match_test.dart' show MemoryRooms, client, flush;

const host = OnlineGamePlayer(
    id: 'host', displayName: 'Host', pieceStyle: PieceStyle.morocco);
const guest = OnlineGamePlayer(id: 'guest', displayName: 'Guest');
const opening = [
  OnlineGameMove(notation: 'a1', player: PlayerColor.white),
  OnlineGameMove(notation: 'b1', player: PlayerColor.black)
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('online recovery clears an old lesson and its interaction restrictions',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(scenarioStateProvider.notifier)
        .startScenario(tutorialAndPuzzleLibrary.first);
    container.read(onlineGameProvider.notifier).rebuildFromSession(
        const OnlineGameSession(
            roomCode: 'ABCDEF',
            white: host,
            black: guest,
            status: OnlineStatus.playing,
            moves: opening),
        PlayerColor.white);
    expect(container.read(scenarioStateProvider).activeScenario, isNull);
    expect(container.read(gameSessionProvider).scenario, isNull);
  });

  test('Hex metadata updates keep input locked during host AI search',
      () async {
    final rooms = MemoryRooms();
    addTearDown(rooms.updates.close);
    final controller = HexMatchController(
        authenticate: () async => 'host',
        store: () => rooms,
        botDelay: Duration.zero);
    addTearDown(controller.dispose);
    await controller.create(
        2,
        [HexSeatKind.ai, HexSeatKind.localHuman, HexSeatKind.localHuman],
        HexSeat.ivory);
    await flush();
    expect(controller.state.busy, isTrue);
    rooms.publish();
    expect(controller.state.busy, isTrue);
    expect(controller.state.canPlay, isFalse);
    for (var i = 0; i < 100 && controller.state.game!.ply < 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(controller.state.game!.ply, 1);
    expect(controller.state.busy, isFalse);
  });

  test('starting offline play detaches a recovered square room', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(onlineGameProvider.notifier).rebuildFromSession(
        const OnlineGameSession(
            roomCode: 'ABCDEF',
            white: host,
            black: guest,
            status: OnlineStatus.playing,
            moves: opening),
        PlayerColor.white);
    container.read(gameSessionProvider.notifier).state =
        const GameSessionConfig();
    container.read(gameStateProvider.notifier).newGame(3);
    expect(container.read(onlineGameProvider).session, isNull);
    expect(container.read(gameStateProvider).boardSize, 3);
    expect(container.read(gameStateProvider).board.occupiedPositions, isEmpty);
  });

  test(
      'room pointers survive a new controller, bounded, deduplicated and removable',
      () async {
    final first = SavedRoomsController();
    addTearDown(first.dispose);
    for (var i = 0; i < 12; i++) {
      await first.remember(SavedRoom(
          code: 'AAAAA${String.fromCharCode(65 + i)}',
          uid: 'host',
          hex: false));
    }
    const hex = SavedRoom(code: 'HABCDEF', uid: 'host', hex: true);
    await first.remember(hex);
    await first.remember(hex);
    final reloaded = SavedRoomsController();
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.state.length, 10);
    expect(reloaded.state.first.code, hex.code);
    expect(reloaded.state.first.uid, 'host');
    expect(reloaded.state.first.hex, isTrue);
    await reloaded.forget(hex);
    final again = SavedRoomsController();
    addTearDown(again.dispose);
    await again.load();
    expect(again.state.any((room) => room.hex), isFalse);
  });

  test('bad saved data does not prevent launch or future saves', () async {
    SharedPreferences.setMockInitialValues(
        {SavedRoomsController.storageKey: '{bad json'});
    final saved = SavedRoomsController();
    addTearDown(saved.dispose);
    await saved.load();
    expect(saved.state, isEmpty);
    await saved
        .remember(const SavedRoom(code: 'ABCDEF', uid: 'host', hex: false));
    expect(saved.state.single.code, 'ABCDEF');
  });

  test(
      'fresh square controllers restore complete board, reserves and turn for either color',
      () {
    for (final color in PlayerColor.values) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const session = OnlineGameSession(
          roomCode: 'ABCDEF',
          white: host,
          black: guest,
          moves: opening,
          boardTheme: BoardTheme.morocco,
          status: OnlineStatus.playing);
      container
          .read(onlineGameProvider.notifier)
          .rebuildFromSession(session, color);
      final state = container.read(gameStateProvider);
      expect(state.board.stackAt(const Position(4, 0)).topPiece!.color,
          PlayerColor.black);
      expect(state.board.stackAt(const Position(4, 1)).topPiece!.color,
          PlayerColor.white);
      expect(state.currentPlayer, PlayerColor.white);
      expect(state.whitePieces.flatStones, 20);
      expect(state.blackPieces.flatStones, 20);
      expect(container.read(moveHistoryProvider).length, 2);
      expect(container.read(onlineGameProvider).appliedMoveCount, 2);
      expect(container.read(onlineGameProvider).session!.boardTheme,
          BoardTheme.morocco);
    }
  });

  test('square corrupt replay stops at the last valid prefix and locks play',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const session = OnlineGameSession(
        roomCode: 'ABCDEF',
        white: host,
        black: guest,
        status: OnlineStatus.playing,
        moves: [
          OnlineGameMove(notation: 'a1', player: PlayerColor.white),
          OnlineGameMove(notation: 'b1', player: PlayerColor.white),
          OnlineGameMove(notation: 'b1', player: PlayerColor.black),
        ]);
    container
        .read(onlineGameProvider.notifier)
        .rebuildFromSession(session, PlayerColor.white);
    expect(container.read(onlineGameProvider).appliedMoveCount, 1);
    expect(container.read(onlineGameProvider).errorMessage, contains('move 2'));
    expect(container.read(onlineGameProvider).isLocalTurn, isFalse);
    expect(container.read(moveHistoryProvider).length, 1);
  });

  test(
      'finished square rooms restore resignation result without a terminal move',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const session = OnlineGameSession(
        roomCode: 'ABCDEF',
        white: host,
        black: guest,
        moves: opening,
        status: OnlineStatus.finished,
        winner: OnlineWinner.black);
    container
        .read(onlineGameProvider.notifier)
        .rebuildFromSession(session, PlayerColor.white);
    expect(container.read(gameStateProvider).result, GameResult.blackWins);
    expect(container.read(gameStateProvider).isGameOver, isTrue);
    expect(container.read(onlineGameProvider).isLocalTurn, isFalse);
  });

  test(
      'waiting Charcoal host restores with an empty board and keeps input locked',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(onlineGameProvider.notifier).rebuildFromSession(
        const OnlineGameSession(
            roomCode: 'ABCDEF', black: host, creatorColor: PlayerColor.black),
        PlayerColor.black);
    expect(container.read(gameStateProvider).board.occupiedPositions, isEmpty);
    expect(container.read(onlineGameProvider).waitingForOpponent, isTrue);
    expect(container.read(onlineGameProvider).isLocalTurn, isFalse);
  });

  test('closing a timed room consumes elapsed time instead of refilling clocks',
      () {
    final last = DateTime.utc(2026, 10, 9, 12);
    final session = OnlineGameSession(
        roomCode: 'ABCDEF',
        white: host,
        black: guest,
        chessClockEnabled: true,
        chessClockSeconds: 300,
        status: OnlineStatus.playing,
        currentTurn: PlayerColor.black,
        lastMoveAt: last,
        moves: [
          const OnlineGameMove(
              notation: 'a1',
              player: PlayerColor.white,
              whiteSeconds: 245,
              blackSeconds: 280)
        ]);
    final restored =
        OnlineClockBalance.at(session, last.add(const Duration(seconds: 90)));
    expect(restored.white, 245);
    expect(restored.black, 190);
    expect(
        OnlineClockBalance.at(session, last.add(const Duration(hours: 1)))
            .black,
        0);
  });

  test(
      'fresh Hex host and guest return to existing seats and identical saved state',
      () async {
    final rooms = MemoryRooms();
    addTearDown(rooms.updates.close);
    final initialHost = client(rooms, 'host');
    final initialGuest = client(rooms, 'guest');
    await initialHost.create(
        2,
        [HexSeatKind.localHuman, HexSeatKind.remoteHuman, HexSeatKind.ai],
        HexSeat.ivory);
    await initialGuest.join('HABCDEF');
    await flush();
    await initialHost.play(HexMove.place(const HexCell(0, 0), PieceType.flat));
    await initialGuest.play(HexMove.place(const HexCell(1, 0), PieceType.flat));
    initialHost.dispose();
    initialGuest.dispose();
    final restoredGuest = client(rooms, 'guest');
    addTearDown(restoredGuest.dispose);
    await restoredGuest.join('HABCDEF', expectedUid: 'guest');
    expect(restoredGuest.state.controls, {HexSeat.charcoal});
    expect(restoredGuest.state.game!.ply, 2);
    final restoredHost = HexMatchController(
        authenticate: () async => 'host',
        store: () => rooms,
        botDelay: Duration.zero);
    addTearDown(restoredHost.dispose);
    await restoredHost.join('HABCDEF', expectedUid: 'host');
    for (var i = 0; i < 100 && restoredHost.state.game!.ply < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(restoredHost.state.game!.ply, 3,
        reason: 'Returning host must restart AI authority');
    expect(restoredGuest.state.game!.ply, 3);
    expect(rooms.room!.owners, ['host', 'guest', null]);
  });

  test('wrong identity cannot consume a vacant Hex seat through resume',
      () async {
    final rooms = MemoryRooms();
    addTearDown(rooms.updates.close);
    final owner = client(rooms, 'host');
    addTearDown(owner.dispose);
    await owner.create(
        2,
        [HexSeatKind.localHuman, HexSeatKind.remoteHuman, HexSeatKind.ai],
        HexSeat.ivory);
    final wrong = client(rooms, 'different');
    addTearDown(wrong.dispose);
    await wrong.join('HABCDEF', expectedUid: 'host');
    expect(wrong.state.game, isNull);
    expect(wrong.state.error, contains('original'));
    expect(rooms.room!.owners[1], isNull);
  });

  for (final width in [360.0, 1440.0]) {
    testWidgets('saved room discovery and shortcut removal at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = SavedRoomsController();
      await saved
          .remember(const SavedRoom(code: 'ABCDEF', uid: 'host', hex: false));
      await tester.pumpWidget(ProviderScope(
          overrides: [savedRoomsProvider.overrideWith((ref) => saved)],
          child: const MaterialApp(
              home: Scaffold(
                  body: SingleChildScrollView(child: SavedOnlineGames())))));
      await tester.pumpAndSettle();
      expect(find.text('Resume online game'), findsOneWidget);
      expect(find.text('Square · ABCDEF'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Remove ABCDEF shortcut'));
      await tester.pumpAndSettle();
      expect(find.text('Square · ABCDEF'), findsNothing);
    });
  }
}
