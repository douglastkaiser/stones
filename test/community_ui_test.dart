import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/screens/main_menu_screen.dart';
import 'package:stones/providers/elo_provider.dart';
import 'package:stones/services/sound_manager.dart';
import 'ratings/rating_system_test.dart' show FakeRatings, QuietRatingSound;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/providers/player_profile_provider.dart';
import 'package:stones/services/player_profile_repository.dart';
import 'package:stones/services/account_service.dart';
import 'package:stones/widgets/player_name.dart';
import 'package:stones/widgets/player_name_editor.dart';
import 'package:stones/widgets/room_invitation_actions.dart';
import 'package:stones/game/match_table_layout.dart';
import 'package:stones/game/open_tables.dart';
import 'package:stones/game/room_invitation.dart';
import 'support/fake_account_service.dart';

class Profiles implements PlayerProfileRepository {
  final names = <String, String>{};
  final changes = StreamController<void>.broadcast();
  @override
  Stream<String?> watch(String uid) async* {
    yield names[uid];
    await for (final _ in changes.stream) {
      yield names[uid];
    }
  }

  @override
  Future<void> rename(String uid, String name) async {
    names[uid] = validatePlayerName(name);
    changes.add(null);
  }
}

void main() {
  test('player names reject empty, oversized and control characters', () {
    expect(validatePlayerName('  Road builder  '), 'Road builder');
    for (final name in ['', '   ', 'x' * 41, 'one\ntwo', 'one\u0000two']) {
      expect(() => validatePlayerName(name), throwsFormatException);
    }
  });
  test('stale open tables disappear without a cloud cleanup job', () {
    final now = DateTime.utc(2026);
    OpenTable table(Duration age) => OpenTable(
        host: 'host',
        code: 'UABCDEF',
        shape: 'square',
        size: 5,
        players: 2,
        seenAt: now.subtract(age));
    expect(table(const Duration(minutes: 2)).fresh(now), isTrue);
    expect(table(const Duration(minutes: 3)).fresh(now), isFalse);
  });
  test(
      'QR payloads reuse invitation validation rather than stripping foreign URLs',
      () {
    for (final code in ['UABCDEF', 'HABCDEF', 'ABC123']) {
      expect(roomCodeFromInvitation(roomInvitation(code).toString()), code);
    }
    expect(() => roomCodeFromInvitation('https://evil.example/UABCDEF'),
        throwsStateError);
  });
  testWidgets(
      'home offers Google sign-in and opens the chosen player name as a profile',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final account = FakeAccount();
    final profiles = Profiles()..names['google'] = 'Chosen name';
    final ratings = FakeRatings();
    await tester.pumpWidget(ProviderScope(overrides: [
      accountServiceProvider.overrideWithValue(account),
      playerProfileRepositoryProvider.overrideWithValue(profiles),
      ratingRepositoryProvider.overrideWithValue(ratings),
      soundManagerProvider.overrideWithValue(QuietRatingSound()),
    ], child: const MaterialApp(home: MainMenuScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Google'), findsOneWidget);
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();
    expect(account.googleCalls, 1);
    expect(find.text('Chosen name'), findsOneWidget);
    await tester.tap(find.text('Chosen name'));
    await tester.pumpAndSettle();
    expect(find.text('Edit player name'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await account.events.close();
    await profiles.changes.close();
    for (final stream in ratings.streams.values) {
      await stream.close();
    }
  });

  testWidgets('rename updates two profile readers and isolates another account',
      (tester) async {
    final profiles = Profiles();
    final account = FakeAccount()
      ..current = const AccountIdentity(
          uid: 'alice', guest: false, name: 'Google name');
    final controller = AccountController(account, hasActiveRoom: () => false);
    await controller.initialize();
    addTearDown(profiles.changes.close);
    addTearDown(account.events.close);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          accountProvider.overrideWith((ref) => controller),
          playerProfileRepositoryProvider.overrideWithValue(profiles),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: Column(children: [
          PlayerName(uid: 'alice', fallback: 'Google name'),
          PlayerName(uid: 'alice', fallback: 'Player'),
          PlayerName(uid: 'bob', fallback: 'Bob'),
          PlayerNameEditor(uid: 'alice', fallback: 'Google name'),
        ])))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit player name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Road builder');
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();
    expect(find.text('Road builder'), findsNWidgets(2));
    expect(find.text('Bob'), findsOneWidget);
    expect(profiles.names, {'alice': 'Road builder'});
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'top invitation exposes QR and copy controls without scrolling the game',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: RoomInvitationBar(code: 'UABCDEF'))));
    expect(find.text('Room UABCDEF'), findsOneWidget);
    await tester.tap(find.text('Invite / QR'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(roomInvitation('UABCDEF').toString()), findsOneWidget);
    expect(find.text('Copy code'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
  });
  for (final size in [const Size(390, 844), const Size(1366, 900)]) {
    testWidgets(
        'viewport layout has no empty scroll tail at $size and a stable board',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final expanded = ValueNotifier(false);
      addTearDown(expanded.dispose);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ValueListenableBuilder<bool>(
                  valueListenable: expanded,
                  builder: (_, value, __) => MatchTableLayout(
                      playerCount: 2,
                      board: const ColoredBox(color: Colors.brown),
                      players: const SizedBox(height: 60),
                      status: const Text('Your turn'),
                      controls: SizedBox(height: value ? 120 : 65),
                      details: const SizedBox())))));
      final board = find.byKey(const ValueKey('stable-board'));
      final before = tester.getRect(board);
      if (size.width > 1000) expect(before.width, greaterThan(680));
      for (final state
          in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
        expect(state.position.maxScrollExtent, 0);
      }
      expanded.value = true;
      await tester.pump();
      expect(tester.getRect(board), before);
      expect(tester.takeException(), isNull);
    });
  }
}
