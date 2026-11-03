// Exploratory diagnostics. Run separately from correctness tests:
// flutter test tools/performance_opportunity_probe_test.dart --reporter expanded
// These report work counts / VM observations, never device frame-rate claims.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/screens/settings_screen.dart';
import 'package:stones/screens/achievements_screen.dart';
import 'package:stones/widgets/theme_gallery.dart';
import 'package:stones/screens/leaderboard_screen.dart';
import 'package:stones/providers/elo_provider.dart';
import 'package:stones/models/elo_rating.dart';
import '../test/ratings/rating_system_test.dart' show FakeRatings;
import '../test/support/fake_account_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/completed_match.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';

const _output = String.fromEnvironment('STONES_OPPORTUNITY_OUTPUT',
    defaultValue: 'build/qa/performance-stage2/after-opportunities');

int? _recordedCells(WidgetTester tester) {
  for (final paint
      in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    if (paint.painter.runtimeType.toString() != '_BoardPainter') continue;
    try {
      final dynamic painter = paint.painter;
      return painter.materials?.recordedCells as int?;
    } on NoSuchMethodError {
      return null; // The exact same probe also runs against the baseline.
    }
  }
  return null;
}

int _retained(CompletedMatch match) {
  try {
    final dynamic record = match;
    return record.retainedPositionCount as int;
  } on NoSuchMethodError {
    return match.positions.length;
  }
}

class _CountingCell extends Cell {
  const _CountingCell(super.x, super.y);
  static int steps = 0;
  @override
  Cell step(Step direction) {
    steps++;
    return _CountingCell(x + direction.x, y + direction.y);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('actual collection mounting at a narrow viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final counts = <String, int>{};
    for (final settings in [true, false]) {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final account = FakeAccount();
      final providers = ProviderContainer(
          overrides: [accountServiceProvider.overrideWithValue(account)]);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: providers,
          child: MaterialApp(
              home: settings
                  ? const SettingsScreen()
                  : const AchievementsScreen())));
      await tester.pumpAndSettle();
      if (settings) {
        await tester.scrollUntilVisible(find.text('Preview Porto'), 300,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Preview Porto'));
        await tester.pumpAndSettle();
        counts['mountedSettingsSamples'] =
            find.byType(ThemeSample).evaluate().length;
      } else {
        final cards = find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_AchievementCard');
        for (var i = 0; i < 30 && cards.evaluate().isEmpty; i++) {
          await tester.drag(
              find.byType(Scrollable).first, const Offset(0, -300));
          await tester.pumpAndSettle();
        }
        expect(cards.evaluate(), isNotEmpty);
        await tester.ensureVisible(cards.first);
        await tester.pumpAndSettle();
        counts['mountedAchievementCards'] = find
            .byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_AchievementCard')
            .evaluate()
            .length;
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      providers.dispose();
      await account.events.close();
    }
    final ratings = FakeRatings()
      ..values = List.generate(
          50,
          (i) => EloRating(
              id: 'audit-row-$i',
              displayName: 'audit-row-$i',
              rating: 2000 - i * 10,
              gamesPlayed: 20));
    final account = FakeAccount();
    final providers = ProviderContainer(overrides: [
      accountServiceProvider.overrideWithValue(account),
      ratingRepositoryProvider.overrideWithValue(ratings),
      eloProvider.overrideWith((ref) => EloController(ratings)),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: providers,
        child: const MaterialApp(home: LeaderboardScreen())));
    await tester.pumpAndSettle();
    counts['mountedLeaderboardRows'] = find
        .byWidgetPredicate(
            (w) => w is Text && w.data?.startsWith('audit-row-') == true)
        .evaluate()
        .length;
    expect(counts['mountedLeaderboardRows'], greaterThan(0));
    await tester.scrollUntilVisible(find.text('audit-row-49'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('audit-row-49'));
    await tester.pumpAndSettle();
    expect(find.text('audit-row-49').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    providers.dispose();
    await account.events.close();
    for (final stream in ratings.streams.values) {
      await stream.close();
    }
    print('OPPORTUNITY ${jsonEncode(counts)}');
    await tester.runAsync(() async {
      final file = File('$_output/collections.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(counts));
    });
  });

  for (final shape in BoardShape.values) {
    testWidgets('${shape.name} selection repaint and staged-map work',
        (tester) async {
      final config = MatchConfig(
          shape: shape,
          size: shape == BoardShape.square ? 8 : 4,
          seats: SeatId.values.map(SeatConfig.new).toList());
      final start = MatchState.initial(config);
      final origin = shape == BoardShape.square
          ? const _CountingCell(0, 0)
          : const _CountingCell(-4, 0);
      final carry = start.geometry.carryLimit;
      final before = start.copyWith(ply: 4, board: {
        origin: List.generate(
            carry, (_) => const Stone(SeatId.ivory, PieceType.flat))
      });
      final drops = [...List.filled(carry - 2, 1), 2];
      final preview =
          MatchRules.previewSpread(before, origin, carry, Step.east, drops);
      expect(preview.position, isNotNull);
      final game = preview.position!;
      Widget screen(Cell selected) => MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 380,
                      height: 380,
                      child: BoardView(
                          game: game,
                          original: before,
                          selected: selected,
                          routeSource: origin,
                          routeDirection: Step.east,
                          drops: drops)))));
      await tester.pumpWidget(screen(origin));
      await tester.pumpAndSettle();
      final recordedBefore = _recordedCells(tester);
      var paints = 0;
      debugOnProfilePaint = (render) {
        if (render is RenderCustomPaint &&
            render.painter.runtimeType.toString() == '_BoardPainter') {
          paints++;
        }
      };
      addTearDown(() => debugOnProfilePaint = null);
      _CountingCell.steps = 0;
      for (var i = 1; i <= 20; i++) {
        await tester.pumpWidget(screen(game.geometry.cells[i]));
        await tester.pumpAndSettle();
      }
      debugOnProfilePaint = null;
      final result = {
        'shape': shape.name,
        'cells': game.geometry.cells.length,
        'dropCount': drops.length,
        'selectionChanges': 20,
        'wholeBoardPainterVisits': paints,
        'staticTextureCellCommandRecordings': recordedBefore == null
            ? paints * game.geometry.cells.length
            : _recordedCells(tester)! - recordedBefore,
        'staticTextureCellReplays': paints * game.geometry.cells.length,
        'instrumentedRouteCellSteps': _CountingCell.steps,
        'scope': 'Legal spread fixture; VM paint/work counts, not FPS',
      };
      print('OPPORTUNITY ${jsonEncode(result)}');
      await tester.runAsync(() async {
        final file = File('$_output/${shape.name}.json');
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode(result));
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('history page scanning, replay retention and repeated pagination',
      () async {
    final config = MatchConfig(
        shape: BoardShape.square,
        size: 8,
        seats: SeatId.values.map(SeatConfig.new).toList());
    var game = MatchState.initial(config);
    final moves = <Map<String, dynamic>>[];
    while (moves.length < 40 && !game.finished) {
      final move = MatchRules.legalMoves(game).first;
      moves.add(move.toMap(game.current));
      game = MatchRules.play(game, move)!;
    }
    if (!game.finished) {
      game = game.copyWith(
          result: const MatchResult(SeatId.ivory, ResultReason.resignation));
    }
    final template = CompletedMatch.capture(
            MatchSession(id: 'probe', uid: 'probe-owner', game: game), moves)
        .toMap();
    final results = <Map<String, Object?>>[];
    for (final count in [100, 500]) {
      final data = <String, Object>{};
      for (var i = 0; i < count; i++) {
        final id = 'probe-$i';
        final record = Map<String, dynamic>.of(template)
          ..['id'] = id
          ..['completedAt'] =
              DateTime.utc(2026).add(Duration(seconds: i)).toIso8601String();
        data['${CompletedMatchStorage.prefix}${Uri.encodeComponent(jsonEncode([
              'probe-owner',
              id
            ]))}'] = jsonEncode(record);
      }
      // This diagnostic intentionally lives outside the correctness test tree.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues(data);
      final storage = CompletedMatchStorage();
      for (final limit in [10, 20, 20]) {
        final watch = Stopwatch()..start();
        final page = await storage.readPage('probe-owner', limit: limit);
        watch.stop();
        final result = {
          'storedMatches': count,
          'movesPerMatch': moves.length,
          'pageLimit': limit,
          'elapsedMicroseconds': watch.elapsedMicroseconds,
          'retainedReplayPositions':
              page.matches.fold<int>(0, (sum, match) => sum + _retained(match)),
          'storedJsonBytes': data.values
              .cast<String>()
              .fold<int>(0, (sum, value) => sum + utf8.encode(value).length),
          'scope':
              'Mock preferences, Flutter VM; not browser/native device latency',
        };
        results.add(result);
        print('OPPORTUNITY ${jsonEncode(result)}');
        expect(page.matches.length, limit);
        expect(page.unreadableCount, 0);
        expect(page.hasMore, isTrue);
      }
    }
    final file = File('$_output/history.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(results));
  });
}
