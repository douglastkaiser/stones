import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_match_provider.dart';
import 'package:stones/hex/hex_room.dart';
import 'package:stones/hex/hex_room_store.dart';
import 'package:stones/models/board.dart';
import 'package:stones/models/piece.dart' show PieceType;
import 'package:stones/providers/game_provider.dart';
import 'package:stones/providers/settings_provider.dart';

class MemoryRooms implements HexRoomStore {
  HexRoom? room;
  bool acknowledge = true;
  final updates = StreamController<HexRoom>.broadcast(sync: true);
  void publish() => updates.add(room!);
  @override
  Future<HexRoom> create(
      String uid, int radius, List<HexSeatKind> kinds, HexSeat starter) async {
    room = HexRoom(
        code: 'HABCDEF',
        host: uid,
        radius: radius,
        kinds: kinds,
        starter: starter,
        owners: kinds
            .map((kind) => kind == HexSeatKind.localHuman ? uid : null)
            .toList());
    return room!;
  }

  @override
  Future<HexRoom> join(String code, String uid) async {
    room = room!.join(uid);
    publish();
    return room!;
  }

  @override
  Future<HexRoom> read(String code) async => room!;
  @override
  Stream<HexRoom> watch(String code) => Stream.multi((controller) {
        controller.add(room!);
        final subscription = updates.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      });
  @override
  Future<void> submit(
      String code, String uid, int expectedPly, HexMove move) async {
    room = room!.append(uid, expectedPly, move);
    if (acknowledge) publish();
  }
}

HexMatchController client(MemoryRooms rooms, String uid) => HexMatchController(
    authenticate: () async => uid,
    store: () => rooms,
    botDelay: const Duration(days: 1));

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'settings default off, persist across reload, reset, and leave square state alone',
      () async {
    SharedPreferences.setMockInitialValues(
        {'board_size': 6, 'sound_muted': true});
    final settings = AppSettingsNotifier();
    addTearDown(settings.dispose);
    await settings.load();
    expect(settings.state.hexModeEnabled, isFalse);
    await settings.setHexModeEnabled(true);
    final loaded = AppSettingsNotifier();
    addTearDown(loaded.dispose);
    await loaded.load();
    expect(loaded.state.hexModeEnabled, isTrue);
    expect(loaded.state.boardSize, 6);
    expect(loaded.state.isSoundMuted, isTrue);
    await loaded.resetToDefaults();
    expect(loaded.state.hexModeEnabled, isFalse);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameStateProvider.notifier)
        .placePiece(const Position(0, 0), PieceType.flat);
    final square = container.read(gameStateProvider);
    container.read(hexMatchProvider.notifier).startLocal(
        2,
        [
          HexSeatKind.localHuman,
          HexSeatKind.localHuman,
          HexSeatKind.localHuman
        ],
        HexSeat.copper);
    expect(identical(container.read(gameStateProvider), square), isTrue);
    expect(container.read(gameStateProvider.notifier).canUndo, isTrue);
  });

  test(
      'two controllers and AI share the same replay and three-seat turn authority',
      () async {
    final rooms = MemoryRooms();
    addTearDown(rooms.updates.close);
    final host = client(rooms, 'host');
    final guest = client(rooms, 'guest');
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    await host.create(
        2,
        [HexSeatKind.localHuman, HexSeatKind.remoteHuman, HexSeatKind.ai],
        HexSeat.ivory);
    await flush();
    expect(host.state.ready, isFalse);
    expect(await host.play(HexMove.place(const HexCell(0, 0), PieceType.flat)),
        isFalse);
    await guest.join('habcdef');
    await flush();
    expect(host.state.ready, isTrue);
    expect(guest.state.ready, isTrue);
    expect(guest.state.controls, {HexSeat.charcoal});
    expect(await guest.play(HexMove.place(const HexCell(0, 0), PieceType.flat)),
        isFalse);
    expect(await host.play(HexMove.place(const HexCell(0, 0), PieceType.flat)),
        isTrue);
    await flush();
    expect(guest.state.game!.ply, 1);
    expect(await guest.play(HexMove.place(const HexCell(1, 0), PieceType.flat)),
        isTrue);
    await flush();
    expect(
        await guest.play(HexMove.place(const HexCell(-1, 0), PieceType.flat),
            bot: true),
        isFalse);
    expect(
        await host.play(HexMove.place(const HexCell(-1, 0), PieceType.flat),
            bot: true),
        isTrue);
    await flush();
    expect(host.state.game!.ply, 3);
    expect(guest.state.game!.ply, 3);
    expect(host.state.game!.current, HexSeat.ivory);
    expect(guest.state.game!.current, HexSeat.ivory);
    expect(guest.state.game!.topAt(const HexCell(-1, 0))!.seat, HexSeat.ivory);
  });

  test(
      'input stays locked until acknowledged snapshot; no optimistic duplicate',
      () async {
    final rooms = MemoryRooms()..acknowledge = false;
    addTearDown(rooms.updates.close);
    final host = client(rooms, 'host');
    addTearDown(host.dispose);
    await host.create(2, List.filled(3, HexSeatKind.localHuman), HexSeat.ivory);
    await flush();
    final move = HexMove.place(const HexCell(0, 0), PieceType.flat);
    expect(await host.play(move), isTrue);
    expect(host.state.game!.ply, 0);
    expect(host.state.busy, isTrue);
    expect(await host.play(move), isFalse);
    expect(rooms.room!.moves.length, 1);
    rooms.publish();
    await flush();
    expect(host.state.game!.ply, 1);
    expect(host.state.busy, isFalse);
  });

  test(
      'bad remote record locks input without skipping it or corrupting last good state',
      () async {
    final rooms = MemoryRooms();
    addTearDown(rooms.updates.close);
    final host = client(rooms, 'host');
    addTearDown(host.dispose);
    await host.create(2, List.filled(3, HexSeatKind.localHuman), HexSeat.ivory);
    await flush();
    rooms.room = HexRoom.fromMap({
      ...rooms.room!.toMap(),
      'ply': 1,
      'moves': {
        '0': HexMove.place(const HexCell(0, 0), PieceType.flat)
            .toMap(HexSeat.copper)
      }
    });
    rooms.publish();
    await flush();
    expect(host.state.connected, isFalse);
    expect(host.state.canPlay, isFalse);
    expect(host.state.game!.ply, 0);
    expect(host.state.error, contains('out of turn'));
  });

  test(
      'consecutive local AI seats run automatically, then return control to human',
      () async {
    final rooms = MemoryRooms();
    addTearDown(rooms.updates.close);
    final match = HexMatchController(
        authenticate: () async => 'host',
        store: () => rooms,
        botDelay: const Duration(milliseconds: 1));
    addTearDown(match.dispose);
    final done = Completer<void>();
    final removeListener = match.addListener((state) {
      if (state.game?.ply == 3 && !state.busy && !done.isCompleted) {
        done.complete();
      }
    });
    addTearDown(removeListener);
    match.startLocal(
        2,
        [HexSeatKind.localHuman, HexSeatKind.ai, HexSeatKind.ai],
        HexSeat.ivory);
    await match.play(HexMove.place(const HexCell(0, 0), PieceType.flat));
    await done.future.timeout(const Duration(seconds: 15));
    expect(match.state.game!.current, HexSeat.ivory);
    expect(match.state.canPlay, isTrue);
    expect(match.state.game!.board.length, 3);
  });

  test('terminal room replay is consistent and refuses further submissions',
      () {
    var match = HexRoom(
        code: 'HABCDEF',
        host: 'host',
        radius: 2,
        kinds: List.filled(3, HexSeatKind.localHuman),
        owners: List.filled(3, 'host'));
    final placements = [
      (const HexCell(-2, 2), PieceType.flat),
      (const HexCell(-2, 1), PieceType.flat),
      (const HexCell(-2, 0), PieceType.flat),
      (const HexCell(-1, 0), PieceType.flat),
      (const HexCell(0, 1), PieceType.standing),
      (const HexCell(0, -1), PieceType.standing),
      (const HexCell(0, 0), PieceType.flat),
      (const HexCell(1, 1), PieceType.standing),
      (const HexCell(-1, -1), PieceType.standing),
      (const HexCell(1, 0), PieceType.flat),
      (const HexCell(2, -1), PieceType.standing),
      (const HexCell(-1, 2), PieceType.standing),
      (const HexCell(2, 0), PieceType.flat),
    ];
    for (final (cell, type) in placements) {
      match =
          match.append('host', match.moves.length, HexMove.place(cell, type));
    }
    expect(match.replay().winner, HexSeat.ivory);
    expect(HexRoom.fromMap(match.toMap()).replay().winner, HexSeat.ivory);
    expect(
        () => match.append('host', match.moves.length,
            HexMove.place(const HexCell(0, 2), PieceType.flat)),
        throwsStateError);
  });
}
