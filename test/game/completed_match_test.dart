import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/completed_match.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_review_screen.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

CompletedMatch finished({String? owner, String id = 'game'}) {
  var game = MatchState.initial(MatchConfig.defaults(BoardShape.square));
  final moves = <Map<String, dynamic>>[];
  for (final cell in [const Cell(0, 0), const Cell(1, 0)]) {
    final move = MatchMove.place(cell, PieceType.flat);
    moves.add(move.toMap(game.current));
    game = MatchRules.play(game, move)!;
  }
  return CompletedMatch.capture(
      MatchSession(
          id: id,
          uid: owner,
          game: game.copyWith(
              result: const MatchResult(
                  SeatId.charcoal, ResultReason.resignation))),
      moves);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('history is replayed, immutable and rejects a fabricated road', () {
    final record = finished();
    expect(record.positions.length, 3);
    expect(record.positions.first.board, isEmpty);
    expect(record.finalPosition.ply, 2);
    expect(record.finalPosition.finished, isTrue);
    expect(
        () => record.moves.first['seat'] = 'charcoal', throwsUnsupportedError);
    expect(() => (record.moves.first['drops'] as List).add(1),
        throwsUnsupportedError);
    final forged = record.toMap()..['reason'] = 'road';
    expect(() => CompletedMatch.fromMap(forged), throwsFormatException);
    final wrongTurn = record.toMap()
      ..['moves'] = [
        {...record.moves.first, 'seat': 'charcoal'}
      ];
    expect(() => CompletedMatch.fromMap(wrongTurn), throwsFormatException);
  });

  test('a completed road is retained with its exact intermediate positions',
      () {
    var game = MatchState.initial(MatchConfig.defaults(BoardShape.square));
    final moves = <Map<String, dynamic>>[];
    for (final (x, y) in [
      (4, 0),
      (0, 0),
      (0, 1),
      (4, 1),
      (0, 2),
      (4, 2),
      (0, 3),
      (3, 1),
      (0, 4),
    ]) {
      final move = MatchMove.place(Cell(x, y), PieceType.flat);
      moves.add(move.toMap(game.current));
      game = MatchRules.play(game, move)!;
    }
    final record =
        CompletedMatch.capture(MatchSession(id: 'road', game: game), moves);
    expect(record.result.reason, ResultReason.road);
    expect(record.result.winner, SeatId.ivory);
    expect(record.positions[8].finished, isFalse);
    expect(record.positions[9].finished, isTrue);
    final altered = record.toMap()..['winner'] = 'charcoal';
    expect(() => CompletedMatch.fromMap(altered), throwsFormatException);
  });

  test('concurrent retries are idempotent and cannot replace a finished game',
      () async {
    final storage = CompletedMatchStorage();
    await Future.wait([storage.save(finished()), storage.save(finished())]);
    expect(await storage.list(null), hasLength(1));
    final altered = finished().toMap()..['winner'] = 'ivory';
    await expectLater(
        storage.save(CompletedMatch.fromMap(altered)), throwsStateError);
    expect((await storage.list(null)).single.result.winner, SeatId.charcoal);
  });

  test('shared-room history remains separate for each account and guests',
      () async {
    final storage = CompletedMatchStorage();
    for (final owner in [null, 'guest-id', 'alice', 'bob']) {
      await storage.save(finished(owner: owner));
    }
    expect((await storage.list('alice')).map((m) => m.owner), ['alice']);
    expect((await storage.list('bob')).map((m) => m.owner), ['bob']);
    expect(
        (await storage.list('guest-id', includeGuest: true))
            .map((m) => m.owner)
            .toSet(),
        {null, 'guest-id'});
  });

  test('retry accepts the same history with reordered map fields', () async {
    final storage = CompletedMatchStorage();
    final original = finished();
    await storage.save(original);
    final reordered = original.toMap()
      ..['moves'] = [
        for (final move in original.moves)
          Map<String, dynamic>.fromEntries(move.entries.toList().reversed),
      ];
    await storage.save(CompletedMatch.fromMap(reordered));
    expect(await storage.list(null), hasLength(1));
  });

  test('paged history isolates damage and replays only requested entries',
      () async {
    final storage = CompletedMatchStorage();
    await storage.save(finished(owner: 'alice', id: 'latest'));
    final prefs = await SharedPreferences.getInstance();
    String key(String owner, String id) =>
        '${CompletedMatchStorage.prefix}${Uri.encodeComponent(jsonEncode([
              owner,
              id
            ]))}';
    final brokenReplay = finished(owner: 'alice', id: 'older').toMap()
      ..['completedAt'] = '2020-01-01T00:00:00Z'
      ..['moves'] = [
        {'seat': 'charcoal', 'x': 99, 'y': 99, 'type': 'flat'}
      ];
    await prefs.setString(key('alice', 'older'), jsonEncode(brokenReplay));
    await prefs.setString(key('bob', 'damaged'), 'not json');
    final first = await storage.readPage('alice', limit: 1);
    expect(first.matches.map((m) => m.id), ['latest']);
    expect(first.hasMore, isTrue);
    expect(first.unreadableCount, 0);
    final expanded = await storage.readPage('alice', limit: 10);
    expect(expanded.matches.map((m) => m.id), ['latest']);
    expect(expanded.hasMore, isFalse);
    expect(expanded.unreadableCount, 1);
    expect(prefs.getString(key('alice', 'older')), jsonEncode(brokenReplay));
    await prefs.setString(key('alice', 'bad-json'), 'not json');
    final recovered = await storage.readPage('alice', limit: 10);
    expect(recovered.matches, hasLength(1));
    expect(recovered.unreadableCount, 2);
  });

  testWidgets('a failed rematch save keeps the result and can retry safely',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = MemoryMatchStorage();
    final room = MemoryMatchRoomStore();
    final controller = MatchController(
        storage: storage, authenticate: () async => 'guest', store: () => room);
    await controller.start(MatchConfig.defaults(BoardShape.square));
    await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    await controller.resign(SeatId.ivory);
    final oldId = controller.currentMatchId;
    await tester.pumpWidget(ProviderScope(overrides: [
      matchProvider.overrideWith((ref) => controller),
    ], child: const MaterialApp(home: MatchScreen())));
    await tester.pumpAndSettle();
    storage.failWrites = true;
    await tester.ensureVisible(find.text('Play again'));
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(find.text('Match complete'), findsOneWidget);
    expect(controller.currentMatchId, oldId);
    expect(controller.confirmedMoves, hasLength(1));
    expect(controller.state.game!.finished, isTrue);
    storage.failWrites = false;
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(controller.currentMatchId, isNot(oldId));
    expect(controller.state.game!.ply, 0);
    expect(controller.state.game!.config.starter, SeatId.charcoal);
    expect((await CompletedMatchStorage().list(null)).single.id, oldId);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await room.updates.close();
  });

  test('completion stays pending until its durable write finishes', () async {
    final resultWrite = Completer<void>();
    final room = MemoryMatchRoomStore();
    final controller = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'guest',
        store: () => room,
        completed: (_) => resultWrite.future);
    addTearDown(controller.dispose);
    addTearDown(room.updates.close);
    await controller.start(MatchConfig.defaults(BoardShape.square));
    await controller.resign(SeatId.ivory);
    expect(controller.resultUpdatePending, isTrue);
    expect(controller.canRetryRewards, isFalse);
    var notifications = 0;
    final stop =
        controller.addListener((_) => notifications++, fireImmediately: false);
    resultWrite.complete();
    await Future<void>.delayed(Duration.zero);
    expect(controller.resultUpdatePending, isFalse);
    expect(controller.canRetryRewards, isFalse);
    expect(notifications, greaterThan(0));
    stop();
  });

  testWidgets('review moves through frozen positions without a live controller',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final record = finished();
    await tester
        .pumpWidget(MaterialApp(home: MatchReviewScreen(match: record)));
    expect(find.text('Move 2 of 2'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('First position'));
    await tester.tap(find.byTooltip('First position'));
    await tester.pump();
    expect(find.text('Move 0 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Next move'));
    await tester.pump();
    expect(find.text('Move 1 of 2'), findsOneWidget);
    expect(record.finalPosition.ply, 2);
    expect(record.finalPosition.finished, isTrue);
    expect(tester.takeException(), isNull);
  });
}
