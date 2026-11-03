import 'package:stones/providers/account_provider.dart';
import 'package:stones/services/account_service.dart';
import '../support/fake_account_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/widgets/saved_online_games.dart';
import 'package:stones/widgets/lazy_collections.dart';

void main() {
  testWidgets(
      'saved-room state survives offscreen history and changing header rows',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'online_rooms_v1': '[{"code":"ABCDEF","uid":"guest","hex":false}]',
    });
    final account = AccountController(
        FakeAccount()
          ..current = const AccountIdentity(uid: 'guest', guest: true),
        hasActiveRoom: () => false);
    await account.initialize();
    var leading = false;
    Widget screen() => ProviderScope(
        overrides: [accountProvider.overrideWith((ref) => account)],
        child: MaterialApp(
            home: Scaffold(
                body: ConstrainedListView(maxWidth: 620, children: [
          if (leading) const SizedBox(height: 50),
          const SavedOnlineGames(key: ValueKey('saved-online-shortcuts')),
          for (var i = 0; i < 100; i++)
            SizedBox(height: 100, child: Text('Game $i')),
        ]))));
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(SavedOnlineGames));
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    position.jumpTo(9000);
    await tester.pumpAndSettle();
    expect(state.mounted, isTrue,
        reason: 'A pending resume must keep its mounted context');
    leading = true;
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(SavedOnlineGames, skipOffstage: false)),
        same(state));
    leading = false;
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(SavedOnlineGames)), same(state));
    await tester.pumpWidget(const SizedBox());
    expect(state.mounted, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyboard traversal reaches every row in a large list',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ConstrainedListView(maxWidth: 620, children: [
      for (var i = 0; i < 100; i++)
        SizedBox(
            height: 100,
            child: TextButton(onPressed: () {}, child: Text('Entry $i')))
    ]))));
    Focus.of(tester.element(find.text('Entry 0'))).requestFocus();
    await tester.pumpAndSettle();
    for (var i = 1; i < 100; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('Entry $i'))).hasFocus, isTrue,
          reason: 'Entry $i must remain reachable using only the keyboard');
    }
    expect(find.text('Entry 99').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'large lists retain focus across scrolling/resize and release unused rows',
      (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget screen() => MaterialApp(
            home: Scaffold(
                body: ConstrainedListView(maxWidth: 620, children: [
          for (var i = 0; i < 100; i++)
            SizedBox(
                height: 100,
                child: TextButton(
                    focusNode: i == 0 ? focus : null,
                    onPressed: () {},
                    child: Text('Row $i')))
        ])));
    await tester.pumpWidget(screen());
    expect(find.text('Row 99'), findsNothing);
    focus.requestFocus();
    await tester.pump();
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    position.jumpTo(9000);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(find.text('Row 0', skipOffstage: false), findsOneWidget);
    tester.view.physicalSize = const Size(900, 600);
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    await tester.scrollUntilVisible(find.text('Row 99'), 300);
    await tester.ensureVisible(find.text('Row 99'));
    await tester.pumpAndSettle();
    expect(find.text('Row 99').hitTestable(), findsOneWidget);
    focus.unfocus();
    await tester.pump();
    await tester.pump();
    expect(find.text('Row 0', skipOffstage: false), findsNothing);
    final offset = position.pixels;
    await tester.pumpWidget(screen());
    expect(position.pixels, offset);
    position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.widgetWithText(TextButton, 'Row 0')).width, 620);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
