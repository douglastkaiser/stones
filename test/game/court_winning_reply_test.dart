import 'package:flutter/material.dart' hide Step;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/match_threats.dart';
import 'package:stones/models/piece.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

MatchConfig _config(BoardShape shape, {bool court = true}) => MatchConfig(
        shape: shape,
        size: shape == BoardShape.square ? 3 : 2,
        court: court,
        seats: const [
          SeatConfig(SeatId.ivory),
          SeatConfig(SeatId.charcoal, control: SeatControl.ai),
        ]);

// Replayable positions before a human overlooks the AI's road threat.
Map<String, dynamic> _snapshot(BoardShape shape, {bool court = true}) {
  final config = _config(shape, court: court);
  final placements = shape == BoardShape.square
      ? [
          (const Cell(0, 0), PieceType.flat),
          (const Cell(2, 2), PieceType.flat),
          (const Cell(2, 1), PieceType.flat),
          (const Cell(1, 0), PieceType.flat),
        ]
      : [
          (const Cell(-2, 0), PieceType.flat),
          (const Cell(0, 1), PieceType.flat),
          (const Cell(-1, 2), PieceType.standing),
          (const Cell(-1, 0), PieceType.flat),
          (const Cell(0, 2), PieceType.standing),
          (const Cell(0, 0), PieceType.flat),
          (const Cell(1, 1), PieceType.standing),
          (const Cell(1, 0), PieceType.flat),
        ];
  var game = MatchState.initial(config);
  final records = <Map<String, dynamic>>[];
  for (final (cell, type) in placements) {
    final move = MatchMove.place(cell, type);
    records.add(move.toMap(game.current));
    game = MatchRules.play(game, move)!;
    expect(game.finished, isFalse);
  }
  return {
    'id': 'court-${shape.name}',
    'config': config.toMap(),
    'moves': records
  };
}

MatchMove _mistake(BoardShape shape) => shape == BoardShape.square
    ? MatchMove.place(const Cell(1, 2), PieceType.flat)
    : MatchMove.place(const Cell(-2, 1), PieceType.standing);

MatchController _controller(MemoryMatchStorage storage,
        {Future<MatchMove?> Function(MatchState, BotLevel)? search}) =>
    MatchController(
        storage: storage,
        authenticate: () async => 'host',
        store: () => MemoryMatchRoomStore(),
        botDelay: Duration.zero,
        search: search ?? (_, __) async => null);

Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

Future<void> _walkIntoThreat(
    MatchController controller, BoardShape shape) async {
  expect(await controller.resumeLocal(), isTrue);
  controller.pause(false);
  expect(await controller.play(_mistake(shape)), isTrue);
  await _waitFor(() =>
      controller.state.courtWinningReply != null && !controller.state.busy);
}

Map<String, dynamic> _multiplayerSnapshot(BoardShape shape, int players) {
  final config = MatchConfig(
      shape: shape,
      size: shape == BoardShape.square ? 5 : 2,
      court: true,
      seats: [
        const SeatConfig(SeatId.ivory),
        for (final id in SeatId.values.skip(1).take(players - 1))
          SeatConfig(id, control: SeatControl.ai),
      ]);
  var game = MatchState.initial(config);
  final line = [
    for (var x = shape == BoardShape.square ? 0 : -2;
        x <= (shape == BoardShape.square ? 4 : 2);
        x++)
      Cell(x, 0),
  ];
  var placed = 0;
  final records = <Map<String, dynamic>>[];
  while (placed < line.length - 1 || game.current != SeatId.ivory) {
    final owner = game.opening ? config.next(game.current) : game.current;
    final cell = owner == SeatId.charcoal
        ? line[placed++]
        : game.geometry.cells.firstWhere(
            (cell) => !line.contains(cell) && game.stackAt(cell).isEmpty);
    final move = MatchMove.place(
        cell,
        game.opening || owner == SeatId.charcoal
            ? PieceType.flat
            : PieceType.standing);
    records.add(move.toMap(game.current));
    game = MatchRules.play(game, move)!;
    expect(game.finished, isFalse);
  }
  return {
    'id': 'court-$shape-$players',
    'config': config.toMap(),
    'moves': records
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final shape in BoardShape.values) {
    for (final players in [3, 4]) {
      test(
          '$shape with $players seats pauses and rewinds to the human decision',
          () async {
        final before = _multiplayerSnapshot(shape, players);
        final storage = MemoryMatchStorage()..snapshot = before;
        final host = _controller(storage);
        addTearDown(host.dispose);
        await host.resumeLocal();
        host.pause(false);
        final game = host.state.game!;
        final mistake = MatchMove.place(
            game.geometry.cells.firstWhere(
                (cell) => cell.y != 0 && game.stackAt(cell).isEmpty),
            PieceType.standing);
        expect(await host.play(mistake), isTrue);
        await _waitFor(
            () => host.state.courtWinningReply != null && !host.state.busy);
        expect(host.state.game!.current, SeatId.charcoal);
        expect(host.state.game!.finished, isFalse);
        expect(await host.takeBack(), isTrue);
        expect(host.state.game!.ply, (before['moves'] as List).length);
        expect(host.state.canPlay, isTrue);
      });
    }
    test(
        '$shape pauses before a winning AI reply and durably rewinds the human',
        () async {
      final before = _snapshot(shape);
      final storage = MemoryMatchStorage()..snapshot = before;
      var searches = 0;
      final host = _controller(storage, search: (_, __) async {
        searches++;
        return null;
      });
      await _walkIntoThreat(host, shape);
      final position = host.state.game!;
      final reply = host.state.courtWinningReply!;
      expect(host.state.paused, isTrue);
      expect(host.state.canPlay, isFalse);
      expect(position.finished, isFalse);
      expect(searches, 0);
      expect(MatchRules.play(position, reply)!.result!.winner, SeatId.charcoal);
      expect(storage.snapshot!['moves'], hasLength(position.ply));
      expect(storage.snapshot!['courtWinningReply'], isNotNull);
      host.pause(false);
      expect(host.state.paused, isTrue);
      expect(await host.play(reply, bot: true), isFalse);
      host.dispose();

      final resumed = _controller(storage);
      addTearDown(resumed.dispose);
      expect(await resumed.resumeLocal(), isTrue);
      expect(resumed.state.courtWinningReply, isNotNull);
      expect(resumed.state.paused, isTrue);
      expect(await resumed.takeBack(), isTrue);
      expect(resumed.state.game!.ply, (before['moves'] as List).length);
      expect(resumed.state.game!.current, SeatId.ivory);
      expect(resumed.state.canPlay, isTrue);
      expect(resumed.state.courtWinningReply, isNull);
      expect(storage.snapshot!['courtWinningReply'], isNull);
      expect(storage.snapshot!['moves'], before['moves']);
      // A genuine defensive move lets Court continue without a false pause.
      final defense = shape == BoardShape.square
          ? MatchMove.place(const Cell(2, 0), PieceType.standing)
          : MatchMove.spread(const Cell(0, 1), Step.northWest, [1]);
      expect(await resumed.play(defense), isTrue);
      await _waitFor(() => !resumed.state.busy);
      expect(await findCourtWinningReply(resumed.state.game!), isNull);
      expect(resumed.state.courtWinningReply, isNull);
    });

    test('$shape can explicitly allow the win and still take it back',
        () async {
      final storage = MemoryMatchStorage()..snapshot = _snapshot(shape);
      final host = _controller(storage);
      addTearDown(host.dispose);
      await _walkIntoThreat(host, shape);
      expect(await host.continueCourt(), isTrue);
      expect(host.state.game!.result!.winner, SeatId.charcoal);
      expect(host.state.courtWinningReply, isNull);
      expect(await host.continueCourt(), isFalse);
      expect(await host.takeBack(), isTrue);
      expect(host.state.canPlay, isTrue);
      expect(host.state.game!.ply, (_snapshot(shape)['moves'] as List).length);
    });

    test('$shape ordinary AI play does not pause at an immediate loss',
        () async {
      final storage = MemoryMatchStorage()
        ..snapshot = _snapshot(shape, court: false);
      final host = _controller(storage,
          search: (game, _) async => MatchRules.legalMoves(game).firstWhere(
              (move) =>
                  MatchRules.play(game, move)?.result?.winner == game.current));
      addTearDown(host.dispose);
      await host.resumeLocal();
      host.pause(false);
      expect(await host.play(_mistake(shape)), isTrue);
      await _waitFor(() => host.state.game!.finished);
      expect(host.state.courtWinningReply, isNull);
      expect(host.state.game!.result!.winner, SeatId.charcoal);
    });

    test('$shape detects a movement-only capstone flattening win and flat wins',
        () async {
      final initial = MatchState.initial(_config(shape));
      final road = initial.copyWith(ply: 3, board: {
        for (var x = shape == BoardShape.square ? 0 : -2; x <= 2; x++)
          Cell(x, 0): [
            Stone(
                x == (shape == BoardShape.square ? 1 : 0)
                    ? SeatId.ivory
                    : SeatId.charcoal,
                x == (shape == BoardShape.square ? 1 : 0)
                    ? PieceType.standing
                    : PieceType.flat)
          ],
        Cell(shape == BoardShape.square ? 1 : 0, 1): const [
          Stone(SeatId.charcoal, PieceType.capstone)
        ],
        if (shape == BoardShape.hex)
          const Cell(-1, 1): const [Stone(SeatId.ivory, PieceType.standing)],
      });
      expect(MatchRules.road(road, SeatId.charcoal), isEmpty);
      final reply = await findCourtWinningReply(road);
      expect(reply, isNotNull);
      expect(reply!.type, isNull);
      expect(MatchRules.play(road, reply)!.result!.reason, ResultReason.road);
      final flats = initial.copyWith(ply: 3, reserves: {
        SeatId.ivory: const Reserve(5, 0),
        SeatId.charcoal: const Reserve(1, 0),
      });
      final flatReply = await findCourtWinningReply(flats);
      expect(flatReply, isNotNull);
      expect(MatchRules.play(flats, flatReply!)!.result!.reason,
          ResultReason.flats);
      final tied = flats.copyWith(board: {
        const Cell(0, 0): const [Stone(SeatId.ivory, PieceType.flat)]
      });
      expect(await findCourtWinningReply(tied), isNull);
      expect(await findCourtWinningReply(initial), isNull);
      expect(await findCourtWinningReply(road.copyWith(ply: 4)), isNull);
    });

    for (final size in [const Size(390, 600), const Size(844, 390)]) {
      for (final takeBack in [true, false]) {
        testWidgets(
            '$shape at $size exposes both pause choices; rewind=$takeBack',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final storage = MemoryMatchStorage()..snapshot = _snapshot(shape);
          final host = _controller(storage);
          await tester.runAsync(() => _walkIntoThreat(host, shape));
          await tester.pumpWidget(ProviderScope(
              overrides: [matchProvider.overrideWith((_) => host)],
              child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: const TextScaler.linear(1.5)),
                      child: child!),
                  home: const MatchScreen())));
          await tester.pumpAndSettle();
          expect(find.text('Court Mode paused'), findsOneWidget);
          expect(find.text('Take back').hitTestable(), findsOneWidget);
          expect(find.text('Let AI play').hitTestable(), findsOneWidget);
          await tester.tap(find.text(takeBack ? 'Take back' : 'Let AI play'));
          await tester.pumpAndSettle();
          expect(host.state.courtWinningReply, isNull);
          expect(host.state.game!.finished, !takeBack);
          if (takeBack) expect(host.state.canPlay, isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        });
      }
    }
  }

  test('failed takeback or AI commit keeps the Court decision retryable',
      () async {
    const shape = BoardShape.square;
    final storage = MemoryMatchStorage()..snapshot = _snapshot(shape);
    final host = _controller(storage);
    addTearDown(host.dispose);
    await _walkIntoThreat(host, shape);
    final game = host.state.game;
    storage.failWrites = true;
    expect(await host.takeBack(), isFalse);
    expect(host.state.paused, isTrue);
    expect(host.state.courtWinningReply, isNotNull);
    expect(await host.continueCourt(), isFalse);
    expect(host.state.game, same(game));
    expect(host.state.paused, isTrue);
    expect(host.state.courtWinningReply, isNotNull);
    storage.failWrites = false;
    expect(await host.takeBack(), isTrue);
    expect(host.state.canPlay, isTrue);
  });
}
