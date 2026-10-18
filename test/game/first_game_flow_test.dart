import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/invitation_navigation.dart';
import 'package:stones/game/join_room_screen.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/match_setup_form.dart';
import 'package:stones/game/match_state.dart';
import 'package:stones/game/match_room.dart';
import 'package:stones/game/room_invitation.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/widgets/room_invitation_actions.dart';
import 'match_controller_test.dart'
    show MemoryMatchStorage, MemoryMatchRoomStore;

class _FullRoomStore extends MemoryMatchRoomStore {
  @override
  Future<MatchRoom> join(String code, String uid) async =>
      throw StateError('Room is full');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final code in ['UABCDEF', 'HABCDEF', 'ABC123']) {
    test('canonical invitation round trips $code and accepts old codes', () {
      expect(roomCodeFromInvitation('  ${code.toLowerCase()}  '), code);
      final link = roomInvitation(code);
      expect(
          link.toString(), 'https://www.douglastkaiser.com/stones/?room=$code');
      expect(roomCodeFromInvitation(link.toString()), code);
      expect(roomCodeFromInvitation('/stones/?room=$code'), code);
      expect(
          roomCodeFromInvitation(
              'https://douglastkaiser.github.io/stones/?room=$code'),
          code);
    });
  }
  for (final bad in [
    '',
    'UABCD',
    'UABC123',
    'https://example.com/stones/?room=UABCDEF',
    'http://www.douglastkaiser.com/stones/?room=UABCDEF',
    'https://www.douglastkaiser.com.evil.test/stones/?room=UABCDEF',
    'https://someone@www.douglastkaiser.com/stones/?room=UABCDEF',
    'https://www.douglastkaiser.com:444/stones/?room=UABCDEF',
    '/stones/?room=UABCDEF&room=HABCDEF',
    '/other/?room=UABCDEF',
    '/stones/?room=UABCDEF#other',
    '/stones/',
    '/stones/?room=',
  ]) {
    test('rejects ambiguous or foreign invitation $bad', () {
      expect(() => roomCodeFromInvitation(bad), throwsStateError);
    });
  }

  for (final mode in ['Android', 'web', 'preview web']) {
    final web = mode != 'Android';
    testWidgets(
        'cold $mode invitation opens a join form without claiming a seat',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
              onGenerateInitialRoutes: (route) => initialInvitationRoutes(
                  web ? '/' : '/stones/?room=UABCDEF',
                  home: const Scaffold(body: Text('Home')),
                  browserUri: web
                      ? Uri.parse(mode == 'preview web'
                          ? 'https://www.douglastkaiser.com/stones/pr/finishing-game/?room=UABCDEF'
                          : 'https://www.douglastkaiser.com/stones/?room=UABCDEF')
                      : null),
              onGenerateRoute: invitationRoute)));
      await tester.pumpAndSettle();
      expect(find.byType(JoinRoomScreen), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '/stones/?room=UABCDEF');
      expect(find.text('Join room'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  }

  testWidgets('warm platform invitation opens the same non-claiming screen',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
            home: Scaffold(body: Text('Existing screen')),
            onGenerateRoute: invitationRoute)));
    await tester.binding.handlePushRoute('/stones/?room=HABCDEF');
    await tester.pumpAndSettle();
    expect(find.byType(JoinRoomScreen), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '/stones/?room=HABCDEF');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Existing screen'), findsOneWidget);
  });

  testWidgets(
      'declining an invitation leaves the current position and save intact',
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
    await controller.start(MatchConfig.defaults(BoardShape.square));
    await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    final id = controller.state.id;
    await tester.pumpWidget(ProviderScope(overrides: [
      matchProvider.overrideWith((ref) => controller),
    ], child: const MaterialApp(home: JoinRoomScreen(invitation: 'UABCDEF'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join room'));
    await tester.pumpAndSettle();
    expect(find.text('Switch to another game?'), findsOneWidget);
    await tester.tap(find.text('Keep current game'));
    await tester.pumpAndSettle();
    expect(controller.state.id, id);
    expect(controller.state.game!.ply, 1);
    expect(storage.snapshot!['moves'], hasLength(1));
    expect(authentications, 0);
    expect(find.text('Join room'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await store.updates.close();
  });

  test('a rejected room join preserves a playable local game and its save',
      () async {
    final storage = MemoryMatchStorage();
    final store = _FullRoomStore();
    final controller = MatchController(
        storage: storage, authenticate: () async => 'host', store: () => store);
    await controller.start(MatchConfig.defaults(BoardShape.square));
    await controller.play(MatchMove.place(const Cell(0, 0), PieceType.flat));
    final id = controller.state.id;
    await expectLater(controller.join('UABCDEF'), throwsStateError);
    expect(controller.state.id, id);
    expect(controller.state.canPlay, isTrue);
    expect(controller.state.game!.ply, 1);
    await controller.play(MatchMove.place(const Cell(1, 0), PieceType.flat));
    expect(storage.snapshot!['moves'], hasLength(2));
    controller.dispose();
    await store.updates.close();
  });

  testWidgets(
      'invalid invitation shows recovery without replacing active state',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
            home:
                JoinRoomScreen(invitation: 'https://bad.test/?room=UABCDEF'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join room'));
    await tester.pumpAndSettle();
    expect(find.text('Paste a Stones invitation link or enter its room code.'),
        findsOneWidget);
    expect(find.text('Join room'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening game settings and changing clock preserves mixed seats',
      (tester) async {
    final config =
        MatchConfig.defaults(BoardShape.hex).addPlayer().copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman),
      SeatConfig(SeatId.copper, control: SeatControl.ai),
      SeatConfig(SeatId.jade),
    ]);
    MatchConfig? started;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MatchSetupForm(
                    initialConfig: config,
                    onStart: (value) async {
                      started = value;
                    })))));
    await tester.ensureVisible(find.text('Game settings'));
    await tester.tap(find.text('Game settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('clock-0')));
    await tester.tap(find.byKey(const ValueKey('clock-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 minutes').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create room'));
    await tester.tap(find.text('Create room'));
    await tester.pumpAndSettle();
    expect(started!.clockSeconds, 300);
    expect(started!.seats.map((s) => s.control),
        config.seats.map((s) => s.control));
    expect(started!.shape, BoardShape.hex);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invitation link and code have separate copy fallbacks',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: RoomInvitationActions(code: 'UABCDEF'))));
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, 'https://www.douglastkaiser.com/stones/?room=UABCDEF');
    await tester.tap(find.text('Copy code'));
    await tester.pumpAndSettle();
    expect(copied, 'UABCDEF');
  });
}
