import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/services/account_service.dart';
import 'package:stones/widgets/account_card.dart';
import 'support/fake_account_service.dart';

void main() {
  late FakeAccount service;
  late AccountController controller;
  bool active = false;
  setUp(() {
    active = false;
    service = FakeAccount();
    controller = AccountController(service, hasActiveRoom: () => active);
  });
  tearDown(() async {
    if (controller.mounted) controller.dispose();
    await service.events.close();
  });

  test('restores identity before deciding to create a guest', () async {
    service.current = const AccountIdentity(uid: 'restored', guest: false);
    final users = await Future.wait(
        [controller.ensurePlayer(), controller.ensurePlayer()]);
    expect(service.initializations, 1);
    expect(service.guestCalls, 1);
    expect(users.map((u) => u.uid), ['restored', 'restored']);
    expect(controller.state.identity?.uid, 'restored');
  });

  test('linking Google preserves guest seat ownership during a match',
      () async {
    await controller.ensurePlayer();
    active = true;
    await controller.signInGoogle();
    expect(controller.state.identity?.uid, 'guest');
    expect(controller.state.identity?.guest, false);
    expect(service.switched, false);
  });

  test('account collision does not silently switch identity', () async {
    await controller.ensurePlayer();
    service.failure = FirebaseAuthException(code: 'credential-already-in-use');
    await controller.signInGoogle();
    expect(controller.state.conflict, true);
    expect(controller.state.identity?.uid, 'guest');
    expect(service.googleCalls, 1);
    service.failure = null;
    active = true;
    await controller.signInGoogle(useExistingAccount: true);
    expect(service.googleCalls, 1);
    active = false;
    await controller.signInGoogle(useExistingAccount: true);
    expect(controller.state.identity?.uid, 'existing');
  });

  test('cancelled sign-in preserves the guest and resets busy', () async {
    await controller.ensurePlayer();
    service.cancelled = true;
    await controller.signInGoogle();
    expect(controller.state.identity?.uid, 'guest');
    expect(controller.state.busy, false);
    expect(controller.state.error, null);
  });

  test('duplicate Google requests only launch one chooser', () async {
    await controller.initialize();
    service.google = Completer<void>();
    final first = controller.signInGoogle();
    await controller.signInGoogle();
    expect(service.googleCalls, 1);
    expect(controller.state.busy, true);
    service.google!.complete();
    await first;
    expect(controller.state.busy, false);
  });

  test('sign-out is blocked while owning an active room', () async {
    await controller.ensurePlayer();
    active = true;
    await controller.signOut();
    expect(service.signOutCalls, 0);
    active = false;
    await controller.signOut();
    expect(controller.state.identity, null);
  });

  test('failed initialization can be retried', () async {
    service.failure = FirebaseAuthException(code: 'network-request-failed');
    await controller.initialize();
    expect(controller.state.ready, false);
    service.failure = null;
    await controller.retry();
    expect(controller.state.ready, true);
    expect(service.initializations, 2);
  });

  test('disposing during initialization prevents later state writes', () async {
    service.initialization = Completer<void>();
    final pending = controller.initialize();
    controller.dispose();
    service.initialization!.complete();
    await pending;
  });

  test('auth stream removes stale identity and handles errors', () async {
    await controller.ensurePlayer();
    service.events.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.identity, null);
    service.events
        .addError(FirebaseAuthException(code: 'network-request-failed'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.error, contains('connection'));
  });

  test('error copy gives recovery steps without leaking SDK details', () {
    expect(accountErrorMessage(FirebaseAuthException(code: 'popup-blocked')),
        contains('Allow popups'));
    expect(
        accountErrorMessage(PlatformException(
            code: 'sign_in_failed', message: 'private token')),
        isNot(contains('private token')));
  });

  for (final width in [320.0, 1000.0]) {
    testWidgets('account controls fit at $width and large text',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      service.initialization = Completer<void>();
      await tester.pumpWidget(ProviderScope(
        overrides: [accountProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
            home: MediaQuery(
          data: MediaQueryData(
              size: Size(width, 1000),
              textScaler: const TextScaler.linear(1.5)),
          child:
              const Scaffold(body: SingleChildScrollView(child: AccountCard())),
        )),
      ));
      await tester.pump();
      expect(find.text('Connecting…'), findsOneWidget);
      expect(tester.takeException(), null);
      service.initialization!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();
      expect(find.text('player@example.com'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.signOutCalls, 0);
      expect(tester.takeException(), null);
    });
  }
}
