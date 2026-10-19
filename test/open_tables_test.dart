import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/open_tables.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/game/match_controller.dart';
import 'package:stones/game/match_provider.dart';
import 'package:stones/game/join_room_screen.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/providers/player_profile_provider.dart';
import 'package:stones/screens/open_tables_screen.dart';
import 'package:stones/services/account_service.dart';
import 'package:stones/widgets/open_table_control.dart';
import 'support/fake_account_service.dart';
import 'community_ui_test.dart' show Profiles;
import 'game/match_controller_test.dart'
    show MemoryMatchRoomStore, MemoryMatchStorage;

class Tables implements OpenTablesRepository {
  final listings = <String, String>{};
  Completer<void>? refreshing;
  int publications = 0, refreshes = 0;
  @override
  Future<List<OpenTable>> list() async => [
        for (final entry in listings.entries)
          OpenTable(
              host: entry.key,
              code: entry.value,
              shape: 'square',
              size: 5,
              players: 2,
              seenAt: DateTime.now())
      ];
  @override
  Future<bool> isPublished(String host, String code) async =>
      listings[host] == code;
  @override
  Future<void> publish(String host, String code, {bool refresh = false}) async {
    publications++;
    if (refresh) {
      refreshes++;
      await refreshing?.future;
      if (listings[host] != code) throw const OpenTableReplaced();
    }
    listings[host] = code;
  }

  @override
  Future<void> withdraw(String host, String code) async {
    if (listings[host] == code) listings.remove(host);
  }
}

void main() {
  testWidgets('browsing as guest never joins a seat before confirmation',
      (tester) async {
    final tables = Tables()..listings['host'] = 'UABCDEF';
    final account = FakeAccount();
    final profiles = Profiles();
    addTearDown(account.events.close);
    addTearDown(profiles.changes.close);
    await tester.pumpWidget(ProviderScope(overrides: [
      accountServiceProvider.overrideWithValue(account),
      playerProfileRepositoryProvider.overrideWithValue(profiles),
      openTablesRepositoryProvider.overrideWithValue(tables),
    ], child: const MaterialApp(home: OpenTablesScreen())));
    await tester.pumpAndSettle();
    expect(account.googleCalls, 0);
    await tester.tap(find.text('Open table'));
    await tester.pumpAndSettle();
    expect(find.byType(JoinRoomScreen), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'UABCDEF');
    expect(account.guestCalls, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
      'host restores opt-in and a withdrawn listing cannot be resurrected by refresh',
      (tester) async {
    final tables = Tables()..listings['host'] = 'UABCDEF';
    final account = FakeAccount()
      ..current = const AccountIdentity(uid: 'host', guest: true);
    final auth = AccountController(account, hasActiveRoom: () => false);
    await auth.initialize();
    final rooms = MemoryMatchRoomStore();
    final controller = MatchController(
        storage: MemoryMatchStorage(),
        authenticate: () async => 'host',
        store: () => rooms);
    await controller
        .start(MatchConfig.defaults(BoardShape.square).copyWith(seats: const [
      SeatConfig(SeatId.ivory),
      SeatConfig(SeatId.charcoal, control: SeatControl.onlineHuman)
    ]));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          accountProvider.overrideWith((ref) => auth),
          matchProvider.overrideWith((ref) => controller),
          openTablesRepositoryProvider.overrideWithValue(tables),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: OpenTableControl(uid: 'host', code: 'UABCDEF')))));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    expect(tables.publications, 0);
    tables.refreshing = Completer<void>();
    await tester.pump(const Duration(minutes: 1));
    expect(tables.refreshes, 1);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull);
    tables.listings.clear();
    tables.refreshing!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    await tester.pump(const Duration(minutes: 2));
    expect(tables.listings, isEmpty);
    expect(tables.refreshes, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await rooms.updates.close();
    await account.events.close();
  });
}
