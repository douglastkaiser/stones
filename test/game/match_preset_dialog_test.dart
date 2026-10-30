import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_preset.dart';
import 'package:stones/game/match_preset_dialog.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_screen.dart';
import 'package:stones/game/match_setup_fields.dart';
import 'package:stones/game/match_setup_screen.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

Future<void> selectOption(
    WidgetTester tester, Finder field, String option) async {
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> openPreset(WidgetTester tester, MatchPreset preset) async {
  await tester.ensureVisible(find.text(preset.label));
  await tester.tap(find.text(preset.label));
  await tester.pumpAndSettle();
  expect(find.byType(MatchPresetDialog), findsOneWidget);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final shape in BoardShape.values) {
    for (final preset in [MatchPreset.learn, MatchPreset.computer]) {
      testWidgets(
          '${shape.name} ${preset.name} quick start offers all four levels and uses selected size',
          (tester) async {
        final storage = MemoryMatchStorage();
        final store = MemoryMatchRoomStore();
        final controller = MatchController(
            storage: storage,
            authenticate: () async => 'host',
            store: () => store);
        await tester.pumpWidget(ProviderScope(overrides: [
          matchProvider.overrideWith((ref) => controller),
          localMatchStorageProvider.overrideWithValue(storage),
        ], child: MaterialApp(home: MatchSetupScreen(shape: shape))));
        await tester.pumpAndSettle();
        await openPreset(tester, preset);
        expect(storage.snapshot, isNull);
        expect(controller.state.game, isNull);
        expect(
            tester
                .widget<MatchBoardSizeField>(
                    find.byType(MatchBoardSizeField).last)
                .size,
            shape == BoardShape.square ? 5 : 2);
        final levelField = find.byType(MatchBotLevelField);
        await tester.tap(levelField);
        await tester.pumpAndSettle();
        for (final label in ['Easy', 'Medium', 'Hard', 'Expert']) {
          expect(find.text(label), findsWidgets);
        }
        await tester.tap(find.text('Medium').last);
        await tester.pumpAndSettle();
        await selectOption(tester, levelField, 'Hard');
        await selectOption(tester, levelField, 'Easy');
        await selectOption(tester, levelField, 'Expert');
        await selectOption(tester, find.byType(MatchBoardSizeField).last,
            shape == BoardShape.square ? '6 × 6' : 'Radius 3 · 37 cells');
        await tester.tap(find.widgetWithText(FilledButton, 'Start game').last);
        await tester.pumpAndSettle();
        expect(find.byType(MatchScreen), findsOneWidget);
        final config = controller.state.game!.config;
        expect(config.shape, shape);
        expect(config.size, shape == BoardShape.square ? 6 : 3);
        expect(config.seats.length, shape == BoardShape.square ? 2 : 3);
        expect(config.seats.first.control, SeatControl.localHuman);
        expect(
            config.seats.skip(1).every((seat) =>
                seat.control == SeatControl.ai &&
                seat.level == BotLevel.expert),
            isTrue);
        expect(config.court, preset == MatchPreset.learn);
        expect(config.clockSeconds, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await store.updates.close();
      });
    }

    for (final preset in [MatchPreset.sameDevice, MatchPreset.online]) {
      testWidgets(
          '${shape.name} ${preset.name} offers Court with four human seats',
          (tester) async {
        final storage = MemoryMatchStorage();
        final store = MemoryMatchRoomStore();
        var authentications = 0;
        final controller = MatchController(
            storage: storage,
            authenticate: () async {
              authentications++;
              return 'host';
            },
            store: () => store);
        await tester.pumpWidget(ProviderScope(overrides: [
          matchProvider.overrideWith((ref) => controller),
          localMatchStorageProvider.overrideWithValue(storage),
        ], child: MaterialApp(home: MatchSetupScreen(shape: shape))));
        await tester.pumpAndSettle();
        await openPreset(tester, preset);
        expect(authentications, 0);
        expect(storage.snapshot, isNull);
        await selectOption(tester,
            find.byType(DropdownButtonFormField<int>).last, '4 players');
        await selectOption(tester, find.byType(MatchBoardSizeField).last,
            shape == BoardShape.square ? '6 × 6' : 'Radius 3 · 37 cells');
        final court = find.widgetWithText(SwitchListTile, 'Court Mode');
        await tester.ensureVisible(court);
        expect(tester.widget<SwitchListTile>(court).value, isFalse);
        await tester.tap(court);
        await tester.pumpAndSettle();
        await tester.tap(find
            .widgetWithText(FilledButton,
                preset == MatchPreset.online ? 'Create room' : 'Start game')
            .last);
        await tester.pumpAndSettle();
        final config = controller.state.game!.config;
        expect(config.court, isTrue);
        expect(config.clockSeconds, 0);
        expect(config.seats, hasLength(4));
        expect(config.size, shape == BoardShape.square ? 6 : 3);
        expect(config.seats.every((s) => s.control != SeatControl.ai), isTrue);
        expect(authentications, preset == MatchPreset.online ? 1 : 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await store.updates.close();
      });
    }

    for (final count in [2, 3, 4]) {
      testWidgets(
          '${shape.name} online quick start creates $count seats at the selected size',
          (tester) async {
        final storage = MemoryMatchStorage();
        final store = MemoryMatchRoomStore();
        var authentications = 0;
        final controller = MatchController(
            storage: storage,
            authenticate: () async {
              authentications++;
              return 'host';
            },
            store: () => store);
        await tester.pumpWidget(ProviderScope(overrides: [
          matchProvider.overrideWith((ref) => controller),
          localMatchStorageProvider.overrideWithValue(storage),
        ], child: MaterialApp(home: MatchSetupScreen(shape: shape))));
        await tester.pumpAndSettle();
        await openPreset(tester, MatchPreset.online);
        expect(authentications, 0);
        expect(store.room, isNull);
        expect(find.byType(MatchBotLevelField), findsNothing);
        await selectOption(
            tester,
            find
                .descendant(
                    of: find.byType(MatchPresetDialog),
                    matching: find.byType(DropdownButtonFormField<int>))
                .last,
            '$count players');
        await selectOption(tester, find.byType(MatchBoardSizeField).last,
            shape == BoardShape.square ? '4 × 4' : 'Radius 4 · 61 cells');
        await tester.tap(find.widgetWithText(FilledButton, 'Create room').last);
        await tester.pumpAndSettle();
        expect(find.byType(MatchScreen), findsOneWidget);
        final config = store.room!.config;
        expect(authentications, 1);
        expect(config.shape, shape);
        expect(config.size, 4);
        expect(config.seats.length, count);
        expect(config.seats.first.control, SeatControl.localHuman);
        expect(
            config.seats
                .skip(1)
                .every((seat) => seat.control == SeatControl.onlineHuman),
            isTrue);
        expect(
            config.profile,
            shape == BoardShape.square && count == 2
                ? RulesProfile.standardTak
                : RulesProfile.sharedRoads);
        expect(storage.snapshot, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await store.updates.close();
      });
    }
  }

  testWidgets('cancelling quick setup keeps an active game and its saved moves',
      (tester) async {
    final storage = MemoryMatchStorage();
    final store = MemoryMatchRoomStore();
    final controller = MatchController(
        storage: storage, authenticate: () async => 'host', store: () => store);
    await controller.start(MatchConfig.defaults(BoardShape.square));
    await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    final id = controller.state.id;
    final saved = storage.snapshot;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          matchProvider.overrideWith((ref) => controller),
          localMatchStorageProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(
            home: MatchSetupScreen(shape: BoardShape.square))));
    await tester.pumpAndSettle();
    for (final preset in [
      MatchPreset.learn,
      MatchPreset.computer,
      MatchPreset.online,
      MatchPreset.sameDevice
    ]) {
      await openPreset(tester, preset);
      await selectOption(
          tester, find.byType(MatchBoardSizeField).last, '8 × 8');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(MatchPresetDialog), findsNothing);
      expect(find.text('Replace your saved local game?'), findsNothing);
      expect(
          ProviderScope.containerOf(
                  tester.element(find.byType(MatchSetupScreen)))
              .read(matchProvider)
              .id,
          id);
      expect(controller.state.canPlay, isTrue);
      expect(storage.snapshot, saved);
    }
    await tester.pumpWidget(const SizedBox());
    await store.updates.close();
  });

  for (final preset in [
    MatchPreset.learn,
    MatchPreset.computer,
    MatchPreset.online,
    MatchPreset.sameDevice
  ]) {
    testWidgets('${preset.name} popup fits a narrow screen with large text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showDialog<MatchConfig>(
                          context: context,
                          builder: (_) => MatchPresetDialog(
                              preset: preset, shape: BoardShape.square)),
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final start = find.widgetWithText(FilledButton,
          preset == MatchPreset.online ? 'Create room' : 'Start game');
      expect(start.hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.byType(MatchBoardSizeField));
      expect(find.byType(MatchBoardSizeField).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
