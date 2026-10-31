import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/match_rules.dart';
import 'package:stones/game/move_feedback.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/providers/settings_provider.dart';
import 'package:stones/services/sound_manager.dart';
import 'package:stones/widgets/piece_stack_view.dart';
import 'package:stones/theme/tavern_theme.dart';
import 'package:stones/game/match_study.dart';
import 'package:stones/game/study_controller.dart';

import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;
import 'move_feedback_test.dart'
    show RecordedSound, localConfig, flat, other, cap, wall;

class LandingTestController extends MatchController {
  LandingTestController()
      : super(
            storage: MemoryMatchStorage(),
            authenticate: () async => 'test',
            store: MemoryMatchRoomStore.new);
  void replace(MatchState game) => state = state.copyWith(game: game);
  void confirmWhilePaused(MatchMove move) {
    final before = state.game!;
    final after = MatchRules.play(before, move)!;
    state = state.copyWith(
        game: after,
        paused: true,
        moveFeedback:
            MoveFeedbackBatch([ConfirmedMoveFeedback(before, move, after)]));
  }
}

class FailingRecordedSound extends RecordedSound {
  @override
  Future<void> play(GameSound sound) async =>
      throw StateError('Audio unavailable');
}

Finder cell(Cell cell) => find.byKey(ValueKey('cell-${cell.x}-${cell.y}'));
BoardView board(WidgetTester tester) =>
    tester.widget<BoardView>(find.byType(BoardView));

Future<void> mount(WidgetTester tester, LandingTestController controller,
    RecordedSound sound, AppSettingsNotifier settings,
    {bool reducedMotion = false, GlobalKey? capture}) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        matchProvider.overrideWith((ref) => controller),
        soundManagerProvider.overrideWithValue(sound),
        appSettingsProvider.overrideWith((ref) => settings),
      ],
      child: MaterialApp(
          theme: TavernTheme.build(Brightness.light),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reducedMotion),
              child: child!),
          home: RepaintBoundary(key: capture, child: const MatchScreen()))));
  await tester.pumpAndSettle();
  sound.calls.clear();
}

Future<LandingTestController> controller(BoardShape shape) async {
  SharedPreferences.setMockInitialValues({});
  final value = LandingTestController();
  await value.start(localConfig(shape));
  value.replace(value.state.game!.copyWith(ply: 2));
  return value;
}

Iterable<GameSound> contacts(RecordedSound sound) => sound.calls
    .where((s) => s.name.startsWith('landing') || s == GameSound.wallFlatten);

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('STONES_CAPTURE_LANDINGS')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/landings/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final font in [('StonesLora', 'Lora'), ('StonesSans', 'Roboto')]) {
      await (FontLoader(font.$1)
            ..addFont(rootBundle.load('assets/fonts/${font.$2}-Regular.ttf')))
          .load();
    }
  });
  for (final shape in BoardShape.values) {
    testWidgets(
        '$shape previews stay quiet; confirmed contact plays exactly once',
        (tester) async {
      final game = await controller(shape);
      final sound = RecordedSound();
      final settings = AppSettingsNotifier();
      final captureKey = GlobalKey();
      await mount(tester, game, sound, settings, capture: captureKey);
      final bounds = tester.getRect(find.byType(BoardView));
      await tester.tap(cell(const Cell(0, 0)));
      await tester.pumpAndSettle();
      expect(board(tester).original, isNotNull);
      expect(board(tester).landing, isNull);
      expect(contacts(sound), isEmpty);
      await tester.tap(cell(const Cell(0, 0)));
      await tester.pump();
      expect(board(tester).landing, isNotNull);
      expect(find.byKey(const ValueKey('landing-layer-0')), findsOneWidget);
      expect(contacts(sound), isEmpty);
      await capture(tester, captureKey, '${shape.name}-approach');
      await tester.pump(const Duration(milliseconds: 99));
      expect(contacts(sound), isEmpty);
      await tester.pump(const Duration(milliseconds: 3));
      expect(contacts(sound), hasLength(1));
      await tester.pump(const Duration(milliseconds: 20));
      await capture(tester, captureKey, '${shape.name}-contact');
      await tester.pumpAndSettle();
      expect(board(tester).landing, isNull);
      expect(contacts(sound), hasLength(1));
      expect(tester.getRect(find.byType(BoardView)), bounds);
      await tester
          .tap(cell(const Cell(0, 0))); // Inspection cannot replay contact.
      await tester.pumpAndSettle();
      expect(contacts(sound), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '$shape spread lands above supports, crushes once and stays bounded',
        (tester) async {
      final game = await controller(shape);
      game.replace(game.state.game!.copyWith(board: {
        const Cell(0, 0): [other, flat, cap],
        const Cell(1, 0): List.filled(30, other),
        const Cell(2, 0): [wall],
      }));
      final sound = RecordedSound();
      final settings = AppSettingsNotifier();
      final captureKey = GlobalKey();
      await mount(tester, game, sound, settings, capture: captureKey);
      await game.play(MatchMove.spread(const Cell(0, 0), Step.east, [1, 1]));
      await tester.pump();
      final stack = tester.widget<PieceStackView>(find.descendant(
          of: cell(const Cell(1, 0)), matching: find.byType(PieceStackView)));
      expect(stack.landingStart, 30);
      expect(stack.pieces.length, 31);
      expect(stack.pieces.last.owner, SeatId.ivory.label);
      expect(find.byKey(const ValueKey('landing-layer-29')), findsNothing);
      expect(find.byKey(const ValueKey('landing-layer-30')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 101));
      expect(contacts(sound), hasLength(1));
      await capture(tester, captureKey, '${shape.name}-spread');
      await tester.pump(const Duration(milliseconds: 35));
      expect(contacts(sound).last, GameSound.wallFlatten);
      expect(contacts(sound), hasLength(2));
      await tester.pumpAndSettle();
      expect(contacts(sound), hasLength(2));
      expect(board(tester).game.stackAt(const Cell(0, 0)), [other]);
      expect(board(tester).game.stackAt(const Cell(2, 0)).last, cap);
      expect(tester.takeException(), isNull);
    });
  }

  for (final reduced in [false, true]) {
    testWidgets(
        'motion disabled (system=$reduced) retains independent contact audio',
        (tester) async {
      final game = await controller(BoardShape.square);
      final sound = RecordedSound();
      final settings = AppSettingsNotifier();
      if (!reduced) await settings.setPlacementAnimationsEnabled(false);
      await mount(tester, game, sound, settings, reducedMotion: reduced);
      await game.play(MatchMove.place(const Cell(0, 0), PieceType.capstone));
      await tester.pump();
      expect(board(tester).landing, isNull);
      expect(find.byKey(const ValueKey('landing-layer-0')), findsNothing);
      expect(contacts(sound), [GameSound.landingWoodHeavy]);
      await tester.pumpAndSettle();
      expect(contacts(sound), hasLength(1));
    });
  }

  testWidgets(
      'muting keeps motion; disabling motion settles the active landing',
      (tester) async {
    final game = await controller(BoardShape.square);
    final sound = RecordedSound();
    final settings = AppSettingsNotifier();
    await settings.setSoundMuted(true);
    await mount(tester, game, sound, settings);
    await game.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    await tester.pump();
    expect(board(tester).landing, isNotNull);
    await tester.pump(const Duration(milliseconds: 60));
    await settings.setPlacementAnimationsEnabled(false);
    await tester.pump();
    expect(board(tester).landing, isNull);
    expect(board(tester).game.stackAt(const Cell(0, 0)), [flat]);
    await settings.setPlacementAnimationsEnabled(true);
    await tester.pump();
    expect(
        board(tester).landing, isNull); // Re-enabling cannot replay a landing.
    await tester.pumpAndSettle();
    expect(sound.calls, isEmpty);
  });

  testWidgets(
      'new input, position replacement, and background cancel pending contact',
      (tester) async {
    final game = await controller(BoardShape.square);
    final sound = RecordedSound();
    final settings = AppSettingsNotifier();
    await mount(tester, game, sound, settings);
    await game.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    await tester.pump();
    await tester.tap(cell(const Cell(1, 0)));
    await tester.pumpAndSettle();
    expect(board(tester).landing, isNull);
    expect(board(tester).original, isNotNull); // Input worked without waiting.
    expect(contacts(sound), isEmpty);
    final before = game.state.game!;
    await game.play(MatchMove.place(const Cell(1, 1), PieceType.flat));
    await tester.pump();
    game.replace(before);
    await tester.pumpAndSettle();
    expect(contacts(sound), isEmpty);
    await game.play(MatchMove.place(const Cell(1, 1), PieceType.flat));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 400));
    expect(board(tester).landing, isNull);
    expect(contacts(sound), isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(contacts(sound), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('winning moves keep their landing and result sounds distinct',
      (tester) async {
    final game = await controller(BoardShape.square);
    game.replace(game.state.game!.copyWith(board: {
      for (var x = 0; x < 4; x++) Cell(x, 0): [flat],
    }));
    final sound = RecordedSound();
    await mount(tester, game, sound, AppSettingsNotifier());
    await game.play(MatchMove.place(const Cell(4, 0), PieceType.flat));
    await tester.pump();
    expect(game.state.game!.finished, true);
    await tester.pump(const Duration(milliseconds: 101));
    expect(contacts(sound), hasLength(1));
    expect(sound.calls.where((s) => s == GameSound.win), isEmpty);
    await tester.pumpAndSettle();
    expect(sound.calls.where((s) => s == GameSound.win), hasLength(1));
    expect(contacts(sound), hasLength(1));
  });

  testWidgets(
      'learning presents confirmed replies in order without delaying state',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final initial =
        MatchState.initial(localConfig(BoardShape.square)).copyWith(ply: 2);
    final study = StudyController(MatchStudy(
      id: 'feedback',
      title: 'Feedback',
      goal: 'Continue',
      explanation: '',
      initial: initial,
      puzzle: true,
      moveLimit: 2,
      accepts: (_, step) => true,
      replies: (_) => [MatchMove.place(const Cell(1, 0), PieceType.flat)],
      hints: const [],
    ));
    final sound = RecordedSound();
    await tester.pumpWidget(ProviderScope(overrides: [
      matchProvider.overrideWith((ref) => study),
      soundManagerProvider.overrideWithValue(sound),
    ], child: const MaterialApp(home: MatchScreen())));
    await tester.pumpAndSettle();
    sound.calls.clear();
    await study.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    await tester.pump();
    expect(study.state.game!.ply, 4); // Both moves already committed.
    expect(board(tester).game.ply, 4); // Semantics and input use final state.
    expect(board(tester).landing!.after.ply, 3);
    await tester.pump(const Duration(milliseconds: 101));
    expect(contacts(sound), hasLength(1));
    await tester.pump(const Duration(milliseconds: 180));
    expect(board(tester).landing!.after.ply, 4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 101));
    expect(contacts(sound), hasLength(2));
    await tester.pumpAndSettle();
    expect(board(tester).landing, isNull);
    expect(contacts(sound), hasLength(2));
  });

  testWidgets('covered routes and disposal discard pending contact',
      (tester) async {
    final game = await controller(BoardShape.square);
    final sound = RecordedSound();
    await mount(tester, game, sound, AppSettingsNotifier());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await game.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    await tester.pump();
    unawaited(navigator.push<void>(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('Other screen')))));
    await tester.pumpAndSettle();
    expect(contacts(sound), isEmpty);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(board(tester).landing, isNull);
    expect(contacts(sound), isEmpty);
    await game.play(MatchMove.place(const Cell(1, 0), PieceType.flat));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
    expect(contacts(sound), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional audio failure cannot prevent placement or settling',
      (tester) async {
    final game = await controller(BoardShape.square);
    await mount(tester, game, FailingRecordedSound(), AppSettingsNotifier());
    expect(await game.play(MatchMove.place(const Cell(0, 0), PieceType.flat)),
        true);
    await tester.pumpAndSettle();
    expect(game.state.game!.stackAt(const Cell(0, 0)), [flat]);
    expect(board(tester).landing, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a move arriving while paused stays settled on resume',
      (tester) async {
    final game = await controller(BoardShape.square);
    final sound = RecordedSound();
    await mount(tester, game, sound, AppSettingsNotifier());
    game.confirmWhilePaused(MatchMove.place(const Cell(0, 0), PieceType.flat));
    await tester.pumpAndSettle();
    expect(board(tester).landing, isNull);
    expect(contacts(sound), isEmpty);
    game.pause(false);
    await tester.pumpAndSettle();
    expect(board(tester).landing, isNull);
    expect(contacts(sound), isEmpty);
    expect(board(tester).game.stackAt(const Cell(0, 0)), [flat]);
  });
}
