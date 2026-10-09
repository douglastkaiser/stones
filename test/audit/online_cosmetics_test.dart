import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/main.dart';
import 'package:stones/models/models.dart';
import 'package:stones/providers/providers.dart';
import 'package:stones/hex/hex_board.dart';
import 'package:stones/hex/hex_game.dart';
import 'package:stones/hex/hex_room.dart';
import 'package:stones/widgets/procedural_painters.dart';
import 'package:stones/widgets/match_theme_badge.dart';

class SeededOnline extends OnlineGameController {
  SeededOnline(super.ref, OnlineGameSession session) {
    state = OnlineGameState(session: session, localColor: PlayerColor.white);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('player styles survive room serialization with safe legacy fallback',
      () {
    for (final style in PieceStyle.values) {
      final player = OnlineGamePlayer(
          id: 'owner', displayName: 'Owner', pieceStyle: style);
      final room = OnlineGameSession(
          roomCode: 'ABCDEF',
          white: player,
          boardTheme: BoardTheme.morocco,
          black: const OnlineGamePlayer(
              id: 'guest', displayName: 'Guest', pieceStyle: PieceStyle.kyoto));
      final loaded =
          OnlineGameSession.fromSnapshot(room.roomCode, room.toMap());
      expect(loaded.white!.pieceStyle, style);
      expect(loaded.boardTheme, BoardTheme.morocco);
      expect(loaded.copyWith(status: OnlineStatus.playing).boardTheme,
          BoardTheme.morocco);
      expect(loaded.black!.pieceStyle, PieceStyle.kyoto);
      expect(loaded.copyWith(status: OnlineStatus.finished).white!.pieceStyle,
          style);
    }
    for (final value in [null, -1, 'future-style', {}, 'pixel']) {
      expect(
          OnlineGamePlayer.fromMap({'id': 'old', 'pieceStyle': value})
              .pieceStyle,
          PieceStyle.standard);
    }
  });

  test('Hex join, rejoin and replay preserve each seat style', () {
    var room = HexRoom(
        code: 'HABCDEF',
        host: 'host',
        radius: 2,
        boardTheme: BoardTheme.kyoto,
        kinds: const [
          HexSeatKind.localHuman,
          HexSeatKind.remoteHuman,
          HexSeatKind.ai
        ],
        owners: const [
          'host',
          null,
          null
        ],
        pieceStyles: const [
          PieceStyle.morocco,
          PieceStyle.standard,
          PieceStyle.kyoto
        ]);
    room = HexRoom.fromMap(room.toMap())
        .join('guest', pieceStyle: PieceStyle.polishedMarble);
    expect(room.pieceStyles,
        [PieceStyle.morocco, PieceStyle.polishedMarble, PieceStyle.kyoto]);
    expect(identical(room.join('guest', pieceStyle: PieceStyle.stone), room),
        isTrue);
    room = room.append(
        'host', 0, HexMove.place(const HexCell(0, 0), PieceType.flat));
    final loaded = HexRoom.fromMap(room.toMap());
    expect(loaded.replay().ply, 1);
    expect(loaded.pieceStyles, room.pieceStyles);
    expect(loaded.boardTheme, BoardTheme.kyoto);
    final legacy = room.toMap()
      ..remove('pieceStyles')
      ..remove('boardTheme');
    expect(HexRoom.fromMap(legacy).boardTheme, BoardTheme.classicWood);
    expect(HexRoom.fromMap(legacy).pieceStyles,
        List.filled(3, PieceStyle.standard));
    expect(
        () => room.pieceStyles[0] = PieceStyle.stone, throwsUnsupportedError);
  });

  test('only an earned selected set is advertised; old paired rewards count',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(cosmeticsProvider.notifier)
        .setTheme(BoardTheme.morocco);
    expect(container.read(shareablePieceStyleProvider), PieceStyle.standard);
    expect(container.read(shareableBoardThemeProvider), BoardTheme.classicWood);
    final reward =
        BoardThemeData.forTheme(BoardTheme.morocco).requiredAchievement!;
    SharedPreferences.setMockInitialValues(
        {'achievement_${reward.name}': true});
    await container.read(achievementProvider.notifier).load();
    expect(container.read(shareablePieceStyleProvider), PieceStyle.morocco);
    expect(container.read(shareableBoardThemeProvider), BoardTheme.morocco);
  });

  testWidgets(
      'locked opponent pieces render online, including buried inspection; local play resets',
      (tester) async {
    const session = OnlineGameSession(
        roomCode: 'ABCDEF',
        status: OnlineStatus.playing,
        boardTheme: BoardTheme.morocco,
        white: OnlineGamePlayer(
            id: 'host', displayName: 'Host', pieceStyle: PieceStyle.morocco),
        black: OnlineGamePlayer(
            id: 'guest', displayName: 'Guest', pieceStyle: PieceStyle.kyoto));
    final container = ProviderContainer(overrides: [
      onlineGameProvider.overrideWith((ref) => SeededOnline(ref, session)),
    ]);
    addTearDown(container.dispose);
    container.read(gameSessionProvider.notifier).state =
        const GameSessionConfig(mode: GameMode.online);
    final board = Board.empty(5)
        .setStack(
            const Position(2, 2),
            const PieceStack([
              Piece(type: PieceType.flat, color: PlayerColor.black),
              Piece(type: PieceType.capstone, color: PlayerColor.white)
            ]))
        .placePiece(const Position(2, 3),
            const Piece(type: PieceType.standing, color: PlayerColor.black));
    container.read(gameStateProvider.notifier).loadState(
        GameState.initial(5).copyWith(board: board, phase: GamePhase.playing));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: GameScreen())));
    Set<BoardTheme> boardThemes() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<BoardSurfacePainter>()
        .map((painter) => painter.theme.theme)
        .toSet();
    expect(boardThemes(), {BoardTheme.morocco});
    Set<PieceStyle> paintedStyles() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<ThemedPiecePainter>()
        .map((painter) => painter.style)
        .toSet();
    expect(
        paintedStyles(), containsAll([PieceStyle.morocco, PieceStyle.kyoto]));
    final cell = find
        .byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_BoardCell')
        .at(12);
    await tester.longPress(cell);
    await tester.pump();
    expect(
        paintedStyles(), containsAll([PieceStyle.morocco, PieceStyle.kyoto]));
    expect(container.read(isPieceStyleUnlockedProvider(PieceStyle.kyoto)),
        isFalse);
    expect(container.read(cosmeticsProvider).selectedPieceStyle,
        PieceStyle.standard);
    container.read(gameSessionProvider.notifier).state =
        const GameSessionConfig();
    await tester.pump();
    expect(paintedStyles(), {PieceStyle.standard});
    expect(boardThemes(), {BoardTheme.classicWood});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Hex renders remote seat styles without granting them to the viewer',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var game = HexGame.initial();
    for (final cell in [
      const HexCell(0, 0),
      const HexCell(1, 0),
      const HexCell(0, 1)
    ]) {
      game = HexRules.play(game, HexMove.place(cell, PieceType.flat))!;
    }
    final boundaryKey = GlobalKey();
    Future<List<int>> render(List<PieceStyle>? styles) async {
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              home: Center(
                  child: SizedBox(
                      width: 320,
                      height: 320,
                      child: RepaintBoundary(
                          key: boundaryKey,
                          child: HexBoard(
                              game: game,
                              pieceStyles: styles,
                              boardTheme: styles == null
                                  ? null
                                  : BoardTheme.morocco)))))));
      await tester.pump();
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List().toList();
      }))!;
    }

    final local = await render(null);
    final remote =
        await render([PieceStyle.morocco, PieceStyle.kyoto, PieceStyle.stone]);
    expect(remote, isNot(orderedEquals(local)));
    expect(container.read(achievementProvider).unlockedAchievements, isEmpty);
    expect(container.read(cosmeticsProvider).selectedPieceStyle,
        PieceStyle.standard);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opponent theme badge explains unlock with a read-only preview',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: Scaffold(
                body: MatchThemeBadge(
                    label: 'Opponent', style: PieceStyle.morocco)))));
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    expect(find.textContaining('Earn either reward'), findsOneWidget);
    expect(find.text('Use'), findsNothing);
    expect(container.read(achievementProvider).unlockedAchievements, isEmpty);
    expect(container.read(cosmeticsProvider).selectedPieceStyle,
        PieceStyle.standard);
  });
}
