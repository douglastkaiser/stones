import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/court_takeback.dart';
import 'package:stones/game/match_completed.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/rating_evidence.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/models/piece.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

MatchRoom onlineCourt(BoardShape shape, int count, {bool shared = false}) {
  final config = MatchConfig(
      shape: shape,
      size: shape == BoardShape.square ? 5 : 2,
      court: true,
      seats: List.generate(
          count,
          (i) => SeatConfig(SeatId.values[i],
              control: i == 0 || (shared && i == 1)
                  ? SeatControl.localHuman
                  : SeatControl.onlineHuman)));
  var room = MatchRoom(code: 'UABCDEF', host: 'host', config: config, owners: {
    for (final seat in config.seats)
      seat.id: seat.control == SeatControl.localHuman ? 'host' : null,
  });
  for (final seat
      in config.seats.where((s) => s.control == SeatControl.onlineHuman)) {
    room = room.join('guest-${seat.id.name}', PieceStyle.standard);
  }
  return room;
}

MatchRoom opening(MatchRoom room) {
  for (var i = 0; i < room.config.seats.length; i++) {
    room = room.append(room.owners[room.replay().current]!, i,
        MatchMove.place(room.replay().geometry.cells[i], PieceType.flat),
        expectedRevision: room.revision);
  }
  return room;
}

class FailingCourtStore extends MemoryMatchRoomStore {
  bool failDecisions = false;
  @override
  Future<void> takeback(String code, String uid, int expectedRevision,
      CourtTakebackAction action) async {
    if (failDecisions) throw StateError('Offline');
    await super.takeback(code, uid, expectedRevision, action);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final shape in BoardShape.values) {
    for (final count in [2, 3, 4]) {
      test('$shape $count human Court serializes and rewinds only unanimously',
          () {
        final initial = opening(onlineCourt(shape, count));
        var room = initial.updateTakeback(
            'host', initial.revision, CourtTakebackAction.request);
        expect(room.takeback!.removed.length, count);
        expect(room.canMove(room.owners[room.replay().current]!, room.replay()),
            isFalse);
        expect(
            () => room.append('host', room.moves.length,
                MatchMove.place(const Cell(0, 0), PieceType.flat),
                expectedRevision: room.revision),
            throwsStateError);
        expect(
            () => room.updateTakeback(
                'stranger', room.revision, CourtTakebackAction.approve),
            throwsStateError);
        expect(
            () => room.updateTakeback(
                'host', initial.revision, CourtTakebackAction.cancel),
            throwsStateError);
        expect(MatchRoom.fromMap(room.toMap()).toMap(), room.toMap());
        final declined = room.updateTakeback(
            'guest-charcoal', room.revision, CourtTakebackAction.decline);
        expect(declined.moves, initial.moves);
        expect(declined.takeback, isNull);
        final cancelled = room.updateTakeback(
            'host', room.revision, CourtTakebackAction.cancel);
        expect(cancelled.moves, initial.moves);
        expect(cancelled.takeback, isNull);
        for (final uid in initial.humanOwners.where((uid) => uid != 'host')) {
          final previous = room;
          room = room.updateTakeback(
              uid, room.revision, CourtTakebackAction.approve);
          if (room.takeback != null) {
            expect(room.moves, initial.moves);
          } else {
            expect(room.replayAfter(previous, previous.replay()).ply, 0);
          }
        }
        expect(room.moves, isEmpty);
        expect(room.takeback, isNull);
        expect(room.revision, greaterThan(initial.revision));
        expect(
            () => room.append(
                'host',
                0,
                MatchMove.place(
                    room.replay().geometry.cells.first, PieceType.flat)),
            throwsStateError);
      });

      test(
          '$shape $count same-device Court hints, saves and takes back without awards',
          () async {
        final storage = MemoryMatchStorage();
        final host = MatchController(
            storage: storage,
            authenticate: () async => 'host',
            store: () => MemoryMatchRoomStore(),
            search: (game, _) async => MatchRules.legalMoves(game).first);
        addTearDown(host.dispose);
        final config = MatchConfig(
            shape: shape,
            size: shape == BoardShape.square ? 5 : 2,
            seats: SeatId.values.take(count).map(SeatConfig.new).toList(),
            court: true);
        await host.start(config);
        expect(await host.hint(), isNotNull);
        expect(host.state.game!.ply, 0);
        await host.play(MatchRules.legalMoves(host.state.game!).first);
        await host.play(MatchRules.legalMoves(host.state.game!).first);
        expect(await host.takeBack(), isTrue);
        expect(host.state.game!.ply, 1);
        expect(storage.snapshot!['moves'], hasLength(1));
        await host.resign(host.state.game!.current);
        expect(MatchCompleted(host.state).participant, isNull);
        expect(RatingEvidence.verify(host.state, host.confirmedMoves, 'host'),
            isNull);
        expect(await host.takeBack(), isTrue);
        expect(host.state.game!.finished, isFalse);
      });
    }
  }

  for (final shape in BoardShape.values) {
    for (final size in [const Size(390, 600), const Size(844, 390)]) {
      testWidgets(
          '$shape $size offers online agreement and decline at large text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var room = opening(onlineCourt(shape, size.width > 700 ? 4 : 2));
        room = room.updateTakeback(
            'host', room.revision, CourtTakebackAction.request);
        for (final uid in room.humanOwners
            .where((uid) => uid != 'host' && uid != 'guest-charcoal')) {
          room = room.updateTakeback(
              uid, room.revision, CourtTakebackAction.approve);
        }
        final store = MemoryMatchRoomStore()..room = room;
        final guest = MatchController(
            storage: MemoryMatchStorage(),
            authenticate: () async => 'guest-charcoal',
            store: () => store);
        await guest.join('UABCDEF');
        await tester.pumpWidget(ProviderScope(
            overrides: [
              matchProvider.overrideWith((ref) => guest),
            ],
            child: MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: child!),
                home: const MatchScreen())));
        await tester.pumpAndSettle();
        expect(guest.state.canPlay, isFalse);
        final agree = find.widgetWithText(FilledButton, 'Agree');
        final decline = find.widgetWithText(TextButton, 'Decline');
        await tester.ensureVisible(decline);
        expect(decline.hitTestable(), findsOneWidget);
        await tester.ensureVisible(agree);
        expect(agree.hitTestable(), findsOneWidget);
        await tester.tap(agree);
        await tester.pumpAndSettle();
        expect(store.room!.moves, isEmpty);
        expect(guest.state.room!.takeback, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await store.updates.close();
      });
    }
  }

  test('failed shared requests and approvals preserve the position for retry',
      () async {
    final store = FailingCourtStore()
      ..room = opening(onlineCourt(BoardShape.square, 2));
    final host = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => store);
    final guest = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'guest-charcoal',
        store: () => store);
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    await host.join('UABCDEF');
    await guest.join('UABCDEF');
    store.failDecisions = true;
    expect(await host.takeBack(), isFalse);
    expect(host.state.game!.ply, 2);
    expect(host.state.canPlay, isTrue);
    store.failDecisions = false;
    expect(await host.takeBack(), isTrue);
    store.failDecisions = true;
    expect(await guest.courtTakeback(CourtTakebackAction.approve), isFalse);
    expect(store.room!.moves, hasLength(2));
    expect(store.room!.takeback, isNotNull);
    store.failDecisions = false;
    expect(await guest.courtTakeback(CourtTakebackAction.approve), isTrue);
    expect(host.state.game!.ply, 0);
    await store.updates.close();
  });

  test('shared local seats need one account vote and target its latest move',
      () {
    final initial = opening(onlineCourt(BoardShape.hex, 4, shared: true));
    var room = initial.updateTakeback(
        'host', initial.revision, CourtTakebackAction.request);
    expect(room.takeback!.retained.length, 1);
    expect(room.humanOwners, hasLength(3));
    for (final uid in room.humanOwners.where((uid) => uid != 'host')) {
      room =
          room.updateTakeback(uid, room.revision, CourtTakebackAction.approve);
    }
    expect(room.moves, hasLength(1));
  });

  test('finished online Court reopens only after agreement', () {
    var room = opening(onlineCourt(BoardShape.square, 2));
    room = room.resign('guest-charcoal', SeatId.charcoal);
    final ended = room;
    room =
        room.updateTakeback('host', room.revision, CourtTakebackAction.request);
    expect(room.replay().finished, isTrue);
    room = room.updateTakeback(
        'guest-charcoal', room.revision, CourtTakebackAction.approve);
    expect(room.replayAfter(ended, ended.replay()).finished, isFalse);
    expect(room.resigned, isNull);
    expect(room.finishedAt, isNull);
  });

  test(
      'controller reconciles votes, stale hints, reconnect and same-ply revisions',
      () async {
    final store = MemoryMatchRoomStore()
      ..room = opening(onlineCourt(BoardShape.square, 2));
    final hint = Completer<MatchMove?>();
    var suggestions = 0;
    final host = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => store,
        search: (game, _) async => ++suggestions == 1
            ? MatchRules.legalMoves(game).first
            : await hint.future);
    final guest = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'guest-charcoal',
        store: () => store);
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    await host.join('UABCDEF');
    await guest.join('UABCDEF');
    final old = store.room!;
    expect(await host.hint(), isNotNull);
    expect(host.state.explanation, isNotNull);
    final suggestion = host.hint();
    expect(await guest.takeBack(), isTrue);
    expect(host.state.canPlay, isFalse);
    expect(host.state.explanation, isNull);
    hint.complete(MatchRules.legalMoves(old.replay()).first);
    expect(await suggestion, isNull);
    expect(await host.courtTakeback(CourtTakebackAction.approve), isTrue);
    expect(host.state.game!.ply, 1);
    expect(guest.state.game!.ply, 1);
    await host.reconnect();
    expect(host.state.game!.ply, 1);
    store.updates.add(old);
    expect(host.state.game!.ply, 1);
    expect(await guest.play(MatchRules.legalMoves(guest.state.game!).first),
        isTrue);
    expect(host.state.game!.ply, old.moves.length);
    expect(host.state.room!.revision, greaterThan(old.revision));
    expect(await guest.takeBack(), isTrue);
    expect(await host.courtTakeback(CourtTakebackAction.decline), isTrue);
    expect(host.state.game!.ply, 2);
    expect(await guest.takeBack(), isTrue);
    expect(await guest.courtTakeback(CourtTakebackAction.cancel), isTrue);
    expect(host.state.room!.takeback, isNull);
    await store.updates.close();
  });

  test('a pending request cancels an online AI search before it can submit',
      () async {
    final config = MatchConfig(
        shape: BoardShape.square,
        size: 5,
        court: true,
        starter: SeatId.charcoal,
        seats: const [
          SeatConfig(SeatId.ivory, control: SeatControl.ai),
          SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman),
        ]);
    var room = MatchRoom(
        code: 'UABCDEF',
        host: 'observer',
        config: config,
        owners: const {SeatId.ivory: null, SeatId.charcoal: 'guest'});
    room = room.append(
        'guest', 0, MatchMove.place(const Cell(0, 0), PieceType.flat));
    room = room.claimRunner('observer', DateTime.now());
    final store = MemoryMatchRoomStore()..room = room;
    final search = Completer<MatchMove?>();
    final runner = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'observer',
        store: () => store,
        search: (_, __) => search.future,
        botDelay: Duration.zero);
    final guest = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'guest',
        store: () => store);
    addTearDown(runner.dispose);
    addTearDown(guest.dispose);
    await runner.join('UABCDEF');
    await guest.join('UABCDEF');
    await Future<void>.delayed(Duration.zero);
    expect(runner.state.busy, isTrue);
    expect(await guest.takeBack(), isTrue);
    search.complete(MatchRules.legalMoves(room.replay()).first);
    await Future<void>.delayed(Duration.zero);
    expect(store.room!.moves, isEmpty);
    expect(runner.state.game!.ply, 0);
    expect(runner.state.room!.takeback, isNull);
    expect(runner.canRequestTakeback, isFalse);
    await store.updates.close();
  });

  test('finished Court reconnects to a pending takeback after a network error',
      () async {
    var room = opening(onlineCourt(BoardShape.square, 2));
    room = room.resign('guest-charcoal', SeatId.charcoal);
    final store = MemoryMatchRoomStore()..room = room;
    var logins = 0;
    final host = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async {
          logins++;
          return 'host';
        },
        store: () => store,
        recoveryDelays: const [Duration.zero]);
    addTearDown(host.dispose);
    await host.join('UABCDEF');
    store.updates.addError(TimeoutException('Network interrupted'));
    store.room = room.updateTakeback(
        'guest-charcoal', room.revision, CourtTakebackAction.request);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(logins, greaterThan(1));
    expect(host.state.connected, isTrue);
    expect(host.state.room!.takeback, isNotNull);
    expect(await host.courtTakeback(CourtTakebackAction.approve), isTrue);
    expect(host.state.game!.finished, isFalse);
    await store.updates.close();
  });

  test('eligibility changes do not clear Court when human seats change', () {
    final local = MatchConfig.defaults(BoardShape.square).copyWith(court: true);
    final remote = local.copyWith(seats: const [
      SeatConfig(SeatId.ivory, control: SeatControl.onlineHuman),
      SeatConfig(SeatId.charcoal, control: SeatControl.ai),
    ]);
    expect(remote.court, isTrue);
    expect(remote.clockSeconds, 0);
    expect(MatchConfig.fromMap(remote.toMap()).court, isTrue);
    expect(
        remote
            .copyWith(
                seats: remote.seats
                    .map((s) => s.copyWith(control: SeatControl.ai))
                    .toList())
            .court,
        isFalse);
    expect(
        () => MatchConfig(
            shape: BoardShape.square,
            size: 5,
            seats: local.seats,
            court: true,
            clockSeconds: 60),
        throwsArgumentError);
  });
}
