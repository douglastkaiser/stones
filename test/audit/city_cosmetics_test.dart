import 'package:stones/game/completed_match.dart';
import 'package:stones/game/match_review_screen.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/seat_appearance.dart';
import 'package:stones/game/match_study.dart';
import 'package:stones/game/study_screen.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/providers/achievements_provider.dart';
import 'package:stones/providers/cosmetics_provider.dart';
import 'package:stones/providers/elite_theme_provider.dart';
import 'package:stones/widgets/procedural_painters.dart';
import 'package:stones/widgets/theme_gallery.dart';
import '../game/match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

class _Fixture extends MatchController {
  _Fixture(MatchState game)
      : super(
            storage: MemoryMatchStorage(),
            authenticate: () async => 'host',
            store: () => MemoryMatchRoomStore()) {
    state = MatchSession(id: 'city-fixture', game: game);
  }
}

Future<void> capture(
    WidgetTester tester, String name, GlobalKey boundary) async {
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1.5);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File('build/qa/cities/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader('StonesSans')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets(
      'learning goals and revealed hints use city names for legacy and four-seat text',
      (tester) async {
    final container = ProviderContainer(overrides: [
      isBoardThemeUnlockedProvider.overrideWith((ref, city) => true),
    ]);
    addTearDown(container.dispose);
    await container
        .read(cosmeticsProvider.notifier)
        .setPieceStyle(PieceStyle.kyoto);
    final study = MatchStudy(
        id: 'city-hint-fixture',
        title: 'Ownership',
        goal: 'White to play.',
        initial: MatchState.initial(MatchConfig(
            shape: BoardShape.square,
            size: 5,
            seats: SeatId.values.map(SeatConfig.new).toList())),
        puzzle: true,
        moveLimit: 1,
        accepts: (move, step) => true,
        replies: (move) => const [],
        hints: const ['Cover Black; preserve Copper and Jade.'],
        explanation: '');
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: StudyScreen(study: study))));
    await tester.pumpAndSettle();
    expect(find.text('Rice Paper to play.'), findsWidgets);
    await tester.tap(find.text('Let’s play'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hints'));
    await tester.tap(find.text('Hints'));
    await tester.pumpAndSettle();
    expect(find.text('Cover Indigo; preserve Vermilion and Matcha.'),
        findsOneWidget);
    expect(find.text('Cover Black; preserve Copper and Jade.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'all original indices, explicit pairings and wire names remain compatible',
      () async {
    expect(PieceStyle.values.map((s) => s.name), [
      'standard',
      'stone',
      'polishedMarble',
      'morocco',
      'kyoto',
      'celestial'
    ]);
    for (final city in BoardTheme.values) {
      expect(boardForPieces(piecesForBoard(city)), city);
      expect(
          pieceStyleFromWire(piecesForBoard(city).name), piecesForBoard(city));
      final notifier = CosmeticsNotifier();
      await notifier.setBoardTheme(city);
      await notifier.setPieceStyle(PieceStyle.kyoto);
      final loaded = CosmeticsNotifier();
      await loaded.load();
      expect(loaded.state.selectedBoardTheme, city);
      expect(loaded.state.selectedPieceStyle, PieceStyle.kyoto);
      notifier.dispose();
      loaded.dispose();
    }
    expect(pieceStyleFromWire('future-city'), PieceStyle.standard);
    expect(boardThemeFromWire('future-city'), BoardTheme.classicWood);
    final config =
        MatchConfig.defaults(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]);
    final room = MatchRoom(
        code: 'UABCDEF',
        host: 'host',
        config: config,
        owners: {SeatId.ivory: 'host', SeatId.charcoal: 'guest'});
    final unknown = room.toMap()
      ..['boardTheme'] = 'future-city'
      ..['styles'] = {'ivory': 'future-city', 'charcoal': 'celestial'};
    final read = MatchRoom.fromMap(unknown);
    expect(read.boardTheme, BoardTheme.classicWood);
    expect(read.styles[SeatId.ivory], PieceStyle.standard);
    expect(read.styles[SeatId.charcoal], PieceStyle.celestial);
  });

  testWidgets(
      'recorded mixed city review retains owner styles and revokes Jaipur',
      (tester) async {
    final config =
        MatchConfig.defaults(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman),
      SeatConfig(SeatId.copper, control: SeatControl.ai)
    ]);
    final room = MatchRoom(
        code: 'UABCDEF',
        host: 'host',
        config: config,
        owners: {
          SeatId.ivory: 'host',
          SeatId.charcoal: 'guest',
          SeatId.copper: null
        },
        styles: {
          SeatId.ivory: PieceStyle.celestial,
          SeatId.charcoal: PieceStyle.kyoto,
          SeatId.copper: PieceStyle.celestial
        },
        boardTheme: BoardTheme.celestial,
        resigned: SeatId.charcoal);
    final record = CompletedMatch.capture(
        MatchSession(
            id: room.code, uid: 'guest', room: room, game: room.replay()),
        []);
    final loaded = CompletedMatch.fromMap(record.toMap());
    expect(loaded.styles, room.styles);
    expect(loaded.cosmeticHost, 'host');
    expect(loaded.cosmeticOwners,
        {SeatId.ivory: 'host', SeatId.charcoal: 'guest'});
    expect(loaded.cosmeticOwners[SeatId.copper], isNull);
    final eligibility = StreamController<bool>.broadcast();
    await tester.pumpWidget(ProviderScope(overrides: [
      eliteThemeEligibilityProvider.overrideWith((ref, uid) =>
          uid == 'host' ? eligibility.stream : Stream.value(false)),
    ], child: MaterialApp(home: MatchReviewScreen(match: loaded))));
    await tester.pumpAndSettle();
    eligibility.add(true);
    await tester.pumpAndSettle();
    expect(
        tester.widget<BoardView>(find.byType(BoardView)).styles, room.styles);
    eligibility.add(false);
    await tester.pumpAndSettle();
    final board = tester.widget<BoardView>(find.byType(BoardView));
    expect(board.theme, BoardTheme.classicWood);
    expect(board.styles, {
      SeatId.ivory: PieceStyle.standard,
      SeatId.charcoal: PieceStyle.kyoto,
      SeatId.copper: PieceStyle.standard
    });
    expect(loaded.moves, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await eligibility.close();
  });

  test(
      'either historical reward grants both independently selectable city parts',
      () async {
    for (final city in BoardTheme.values.where(
        (c) => c != BoardTheme.classicWood && c != BoardTheme.celestial)) {
      for (final award in [
        BoardThemeData.forTheme(city).requiredAchievement!,
        PieceStyleData.forStyle(piecesForBoard(city)).requiredAchievement!
      ]) {
        SharedPreferences.setMockInitialValues(
            {'achievement_${award.name}': true});
        final container = ProviderContainer();
        await container.read(achievementProvider.notifier).load();
        expect(container.read(isBoardThemeUnlockedProvider(city)), isTrue);
        expect(
            container.read(isPieceStyleUnlockedProvider(piecesForBoard(city))),
            isTrue);
        expect(cityUnlockRequirement(city), contains('either'));
        container.dispose();
      }
    }
  });

  test(
      'Jaipur piece eligibility follows its owner, fails closed and revokes live',
      () async {
    final host = StreamController<bool>.broadcast();
    final guest = StreamController<bool>.broadcast();
    final container = ProviderContainer(overrides: [
      eliteThemeEligibilityProvider.overrideWith(
          (ref, uid) => uid == 'host' ? host.stream : guest.stream)
    ]);
    final hostKey = effectivePieceStyleProvider((PieceStyle.celestial, 'host'));
    final guestKey =
        effectivePieceStyleProvider((PieceStyle.celestial, 'guest'));
    final first =
        container.listen(hostKey, (_, value) {}, fireImmediately: true);
    final second =
        container.listen(guestKey, (_, value) {}, fireImmediately: true);
    expect(first.read(), PieceStyle.standard);
    expect(
        container
            .read(effectivePieceStyleProvider((PieceStyle.celestial, null))),
        PieceStyle.standard);
    host.add(true);
    guest.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(first.read(), PieceStyle.celestial);
    expect(second.read(), PieceStyle.standard);
    host.addError(StateError('eligibility unavailable'));
    await Future<void>.delayed(Duration.zero);
    expect(first.read(), PieceStyle.standard);
    host.add(true);
    guest.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(first.read(), PieceStyle.celestial);
    host.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(first.read(), PieceStyle.standard);
    expect(second.read(), PieceStyle.celestial);
    first.close();
    second.close();
    container.dispose();
    await host.close();
    await guest.close();
  });

  test(
      'all four flat ownership silhouettes differ without color for every city',
      () async {
    final colors =
        PieceStyleData.forStyle(PieceStyle.standard).palettes.first.colors;
    for (final style in PieceStyle.values) {
      final masks = <List<int>>[];
      for (final identity in PieceIdentity.values) {
        final recorder = ui.PictureRecorder();
        ThemedPiecePainter(
                style: style,
                colors: colors,
                type: PieceType.flat,
                identity: identity)
            .paint(Canvas(recorder), const Size(100, 100));
        final picture = recorder.endRecording();
        final image = await picture.toImage(100, 100);
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        masks.add(
            [for (var i = 3; i < bytes.length; i += 4) bytes[i] > 160 ? 1 : 0]);
        image.dispose();
        picture.dispose();
      }
      for (var a = 0; a < 4; a++) {
        for (var b = a + 1; b < 4; b++) {
          expect(
              [
                for (var i = 0; i < masks[a].length; i++)
                  if (masks[a][i] != masks[b][i]) i
              ].length,
              greaterThan(35),
              reason: '$style flat owners $a/$b need distinct silhouettes');
        }
      }
    }
  });

  for (final size in [const Size(320, 568), const Size(1366, 900)]) {
    testWidgets(
        'independent selectors and complete locked previews at $size and 200% text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(overrides: [
        isBoardThemeUnlockedProvider
            .overrideWith((ref, city) => city != BoardTheme.celestial)
      ]);
      addTearDown(container.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                  theme: ThemeData(fontFamily: 'StonesSans'),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: const TextScaler.linear(2)),
                      child: child!),
                  home: const Scaffold(
                      body: SingleChildScrollView(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: ThemeGallery())))))));
      Finder card(String name) =>
          find.ancestor(of: find.text(name), matching: find.byType(Card));
      final useKyoto = find.descendant(
          of: card('Kyoto'),
          matching: find.widgetWithText(FilledButton, 'Use board'));
      await tester.ensureVisible(useKyoto);
      await tester.tap(useKyoto);
      await tester.pumpAndSettle();
      expect(container.read(cosmeticsProvider).selectedBoardTheme,
          BoardTheme.kyoto);
      expect(container.read(cosmeticsProvider).selectedPieceStyle,
          PieceStyle.standard);
      await tester.ensureVisible(find.text('Pieces'));
      await tester.tap(find.text('Pieces'));
      await tester.pumpAndSettle();
      expect(find.text('Use board'), findsNothing);
      final useFlorence = find.descendant(
          of: card('Florence'),
          matching: find.widgetWithText(FilledButton, 'Use pieces'));
      await tester.ensureVisible(useFlorence);
      await tester.tap(useFlorence);
      await tester.pumpAndSettle();
      expect(container.read(cosmeticsProvider).selectedBoardTheme,
          BoardTheme.kyoto);
      expect(container.read(cosmeticsProvider).selectedPieceStyle,
          PieceStyle.polishedMarble);
      await tester.ensureVisible(find.text('Preview Florence'));
      await tester.tap(find.text('Preview Florence'));
      await tester.pumpAndSettle();
      final preview =
          tester.widget<CityPreviewContent>(find.byType(CityPreviewContent));
      expect(preview.theme, BoardTheme.kyoto);
      expect(preview.style, PieceStyle.polishedMarble);
      expect(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(ThemeSample)),
          findsNWidgets(2));
      expect(find.text('Carrara · Trapezoid flat'), findsOneWidget);
      expect(find.text('Lapis · Hexagonal flat'), findsOneWidget);
      expect(
          find.textContaining('Unlock by completing either:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'preview-${size.width.toInt()}', boundary);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preview Jaipur'));
      await tester.tap(find.text('Preview Jaipur'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('current #1 established human'), findsOneWidget);
      expect(find.text('Locked'), findsWidgets);
      expect(container.read(achievementProvider).unlockedAchievements, isEmpty);
      expect(container.read(cosmeticsProvider).selectedPieceStyle,
          PieceStyle.polishedMarble);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Board'));
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();
      await capture(tester, 'gallery-${size.width.toInt()}', boundary);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final size in [const Size(390, 844), const Size(1024, 900)]) {
    for (final shape in BoardShape.values) {
      for (final city in BoardTheme.values) {
        testWidgets(
            '${city.name} four-player ${shape.name} at $size real screen capture',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final config = MatchConfig(
              shape: shape,
              size: shape == BoardShape.square ? 8 : 4,
              seats: SeatId.values.map(SeatConfig.new).toList());
          final initial = MatchState.initial(config);
          final cells = initial.geometry.cells;
          final game = initial.copyWith(ply: 4, board: {
            for (var i = 0; i < 12; i++)
              cells[i + 3]: [
                if (i % 3 == 0)
                  ...SeatId.values.map((id) => Stone(id, PieceType.flat)),
                Stone(SeatId.values[i % 4], PieceType.values[i ~/ 4]),
              ],
          });
          final container = ProviderContainer(overrides: [
            matchProvider.overrideWith((ref) => _Fixture(game)),
            isBoardThemeUnlockedProvider.overrideWith((ref, city) => true),
            effectivePieceStyleProvider
                .overrideWith((ref, selection) => selection.$1),
            effectiveBoardThemeProvider
                .overrideWith((ref, selection) => selection.$1),
          ]);
          addTearDown(container.dispose);
          await container.read(cosmeticsProvider.notifier).setTheme(city);
          final boundary = GlobalKey();
          Widget screen(Brightness brightness) => UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                  theme: ThemeData(
                      brightness: brightness, fontFamily: 'StonesSans'),
                  home: RepaintBoundary(
                      key: boundary, child: const MatchScreen())));
          await tester.pumpWidget(screen(Brightness.light));
          await tester.pumpAndSettle();
          final board = tester.widget<BoardView>(find.byType(BoardView));
          expect(board.styles.values.toSet(), {piecesForBoard(city)});
          expect(find.text('Ch'), findsNothing);
          expect(
              find.textContaining(
                  '${SeatAppearance.label(game.current, piecesForBoard(city))} to play'),
              findsWidgets);
          await capture(tester,
              '${city.name}-${shape.name}-${size.width.toInt()}', boundary);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(screen(Brightness.dark));
          await tester.pumpAndSettle();
          await capture(
              tester,
              '${city.name}-${shape.name}-${size.width.toInt()}-dark',
              boundary);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });
      }
    }
  }
}
