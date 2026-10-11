import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_setup_form.dart';
import 'package:stones/game/match_setup_screen.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/providers/settings_provider.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

void main() {
  testWidgets(
      'setup respects saved size/clocks and cancelling replacement preserves the game',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {SettingsKeys.boardSize: 6, SettingsKeys.chessClockEnabled: true});
    final storage = MemoryMatchStorage();
    final store = MemoryMatchRoomStore();
    final controller = MatchController(
        storage: storage, authenticate: () async => 'host', store: () => store);
    await controller.start(MatchConfig.defaults(BoardShape.square));
    await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    final id = controller.state.id;
    final container = ProviderContainer(overrides: [
      matchProvider.overrideWith((ref) => controller),
      localMatchStorageProvider.overrideWithValue(storage),
    ]);
    await container.read(appSettingsProvider.notifier).load();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: MatchSetupScreen(shape: BoardShape.square))));
    await tester.pumpAndSettle();
    final config = tester
        .widget<MatchSetupForm>(find.byType(MatchSetupForm))
        .initialConfig;
    expect(config.size, 6);
    expect(config.clockSeconds, 600);
    await tester.ensureVisible(find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    expect(find.text('Replace your saved local game?'), findsOneWidget);
    await tester.tap(find.text('Keep saved game'));
    await tester.pumpAndSettle();
    expect(controller.state.id, id);
    expect(storage.snapshot!['moves'], hasLength(1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await store.updates.close();
  });
}
