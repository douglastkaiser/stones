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

  for (final code in [
    'missing-initial-state',
    'web-storage-unsupported',
    'popup-blocked',
    'network-request-failed',
  ]) {
    test('$code preserves guest ownership and permits a fresh retry', () async {
      final guest = await controller.ensurePlayer();
      active = true;
      service.failure = FirebaseAuthException(
          code: code, message: 'private OAuth code and token');

      await controller.signInGoogle();

      expect(controller.state.identity?.uid, guest.uid);
      expect(controller.state.identity?.guest, isTrue);
      expect(controller.state.busy, isFalse);
      expect(controller.state.conflict, isFalse);
      expect(controller.state.error, isNotNull);
      expect(controller.state.error, isNot(contains('private OAuth')));
      expect(service.switched, isFalse);

      service.failure = null;
      await controller.signInGoogle();

      expect(service.googleCalls, 2);
      expect(controller.state.identity?.uid, guest.uid);
      expect(controller.state.identity?.guest, isFalse);
      expect(controller.state.error, isNull);
    });
  }

  test('disposing during Google sign-in prevents later state writes', () async {
    await controller.ensurePlayer();
    service.google = Completer<void>();
    final pending = controller.signInGoogle();
    controller.dispose();
    service.google!.complete();
    await pending;
  });

  test('restored Google identity is kept when a chooser is cancelled',
      () async {
    service.current = const AccountIdentity(uid: 'existing', guest: false);
    await controller.initialize();
    service.cancelled = true;

    await controller.signInGoogle();

    expect(controller.state.identity?.uid, 'existing');
    expect(controller.state.identity?.guest, isFalse);
    expect(controller.state.busy, isFalse);
    expect(service.guestCalls, 0);
    expect(service.signOutCalls, 0);
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

  testWidgets('slow sign-in shows help without unlocking a second attempt',
      (tester) async {
    controller.dispose();
    controller = AccountController(service,
        hasActiveRoom: () => active, requireFreshGesture: true);
    await controller.ensurePlayer();
    service.google = Completer<void>();
    final pending = controller.signInGoogle();
    await tester.pump(const Duration(seconds: 29));
    expect(controller.state.notice, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.state.notice, contains('same browser'));
    expect(controller.state.busy, isTrue);
    expect(controller.state.identity?.uid, 'guest');
    await controller.signInGoogle();
    await controller.signOut();
    await expectLater(controller.ensurePlayer(), throwsStateError);
    expect(service.googleCalls, 1);
    expect(service.signOutCalls, 0);

    service.google!.complete();
    await pending;
    expect(controller.state.identity?.uid, 'guest');
    expect(controller.state.identity?.guest, isFalse);
    expect(controller.state.notice, isNull);
    expect(controller.state.busy, isFalse);
    await tester.pump(const Duration(seconds: 60));
    expect(controller.state.notice, isNull);
  });

  testWidgets('slow cancellation retains guest and permits an explicit retry',
      (tester) async {
    await controller.ensurePlayer();
    service.google = Completer<void>();
    service.cancelled = true;
    final pending = controller.signInGoogle();
    await tester.pump(const Duration(seconds: 30));
    final notice = controller.state.notice;
    service.events.add(service.current);
    await tester.pump();
    expect(controller.state.notice, notice);
    expect(controller.state.busy, isTrue);

    service.google!.complete();
    await pending;
    expect(controller.state.identity?.guest, isTrue);
    expect(controller.state.notice, isNull);
    expect(controller.state.error, isNull);
    service.google = null;
    service.cancelled = false;
    await controller.signInGoogle();
    expect(service.googleCalls, 2);
    expect(controller.state.identity?.uid, 'guest');
  });

  testWidgets('slow collision retains the explicit account-switch protection',
      (tester) async {
    await controller.ensurePlayer();
    service.google = Completer<void>();
    final pending = controller.signInGoogle();
    await tester.pump(const Duration(seconds: 30));
    service.failure = FirebaseAuthException(code: 'credential-already-in-use');
    service.google!.complete();
    await pending;
    expect(controller.state.conflict, isTrue);
    expect(controller.state.identity?.uid, 'guest');
    expect(controller.state.notice, isNull);
    await tester.pump(const Duration(seconds: 60));
    expect(controller.state.conflict, isTrue);
    expect(controller.state.notice, isNull);
  });

  testWidgets('a previous attempt cannot show help during a newer attempt',
      (tester) async {
    await controller.initialize();
    await controller.signInGoogle();
    await tester.pump(const Duration(seconds: 29));
    service.google = Completer<void>();
    final pending = controller.signInGoogle();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.state.notice, isNull);
    await tester.pump(const Duration(seconds: 29));
    expect(controller.state.notice, isNotNull);
    service.google!.complete();
    await pending;
  });

  testWidgets('disposing cancels sign-in help and ignores late completion',
      (tester) async {
    await controller.initialize();
    service.google = Completer<void>();
    final pending = controller.signInGoogle();
    controller.dispose();
    await tester.pump(const Duration(seconds: 60));
    service.google!.complete();
    await pending;
    expect(tester.takeException(), isNull);
  });

  test('web preparation requires another tap and coalesces repeated requests',
      () async {
    controller.dispose();
    controller = AccountController(service,
        hasActiveRoom: () => active, requireFreshGesture: true);
    service.initialization = Completer<void>();
    final preparing = controller.signInGoogle();
    expect(controller.state.preparing, isTrue);
    await controller.signInGoogle();
    service.initialization!.complete();
    await preparing;
    expect(service.initializations, 1);
    expect(service.googleCalls, 0);
    expect(controller.state.ready, isTrue);
    expect(controller.state.preparing, isFalse);
    expect(controller.state.notice, contains('Tap Sign in'));

    final signIn = controller.signInGoogle();
    // The service must be invoked synchronously from the second gesture.
    expect(service.googleCalls, 1);
    await signIn;
    expect(controller.state.notice, isNull);
  });

  test('web sign-in does not queue a popup across pending guest creation',
      () async {
    controller.dispose();
    controller = AccountController(service,
        hasActiveRoom: () => active, requireFreshGesture: true);
    await controller.initialize();
    service.guest = Completer<void>();
    final guest = controller.ensurePlayer();
    final preparing = controller.signInGoogle();
    expect(controller.state.preparing, isTrue);
    service.guest!.complete();
    final player = await guest;
    await preparing;
    expect(service.guestCalls, 1);
    expect(service.googleCalls, 0);
    expect(controller.state.identity?.uid, player.uid);
    final signIn = controller.signInGoogle();
    expect(service.googleCalls, 1);
    await signIn;
    expect(controller.state.identity?.uid, player.uid);
    expect(controller.state.identity?.guest, isFalse);
  });

  test('web preparation failure clears preparing and can be retried', () async {
    controller.dispose();
    controller = AccountController(service,
        hasActiveRoom: () => active, requireFreshGesture: true);
    service.failure = FirebaseAuthException(code: 'network-request-failed');
    await controller.signInGoogle();
    expect(controller.state.ready, isFalse);
    expect(controller.state.preparing, isFalse);
    expect(service.googleCalls, 0);
    service.failure = null;
    await controller.signInGoogle();
    expect(controller.state.ready, isTrue);
    expect(service.googleCalls, 0);
    await controller.signInGoogle();
    expect(service.googleCalls, 1);
  });

  test('bootstrap recovery cannot unlock a pending authentication attempt',
      () async {
    await controller.ensurePlayer();
    service.failure = FirebaseAuthException(code: 'network-request-failed');
    await controller.retry();
    expect(controller.state.ready, isFalse);
    service.failure = null;
    service.events.add(service.current);
    await Future<void>.delayed(Duration.zero);
    service.google = Completer<void>();
    final pending = controller.signInGoogle();
    await controller.initialize();
    expect(controller.state.busy, isTrue);
    await controller.signInGoogle();
    expect(service.googleCalls, 1);
    service.google!.complete();
    await pending;
    expect(controller.state.busy, isFalse);
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

  test('a registered player cannot switch identities in an active room',
      () async {
    service.current = const AccountIdentity(uid: 'registered', guest: false);
    await controller.initialize();
    active = true;
    await controller.signInGoogle();
    expect(service.googleCalls, 0);
    expect(controller.state.identity?.uid, 'registered');
    expect(controller.state.error, contains('Leave your current online match'));
  });

  test('web preparation restores a remembered account without a chooser',
      () async {
    controller.dispose();
    controller = AccountController(service,
        hasActiveRoom: () => active, requireFreshGesture: true);
    service.current = const AccountIdentity(uid: 'remembered', guest: false);
    await controller.signInGoogle();
    expect(controller.state.identity?.uid, 'remembered');
    expect(controller.state.notice, isNull);
    expect(service.googleCalls, 0);
    expect(service.guestCalls, 0);
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

  test('multiplayer retries bootstrap without a trip to account settings',
      () async {
    service.failure = FirebaseAuthException(code: 'network-request-failed');
    await expectLater(controller.ensurePlayer(), throwsStateError);
    expect(controller.state.ready, isFalse);
    service.failure = null;
    final players = await Future.wait(
        [controller.ensurePlayer(), controller.ensurePlayer()]);
    expect(players.map((player) => player.uid), ['guest', 'guest']);
    expect(service.initializations, 2);
    expect(service.guestCalls, 1);
    expect(controller.state.ready, isTrue);
    expect(controller.state.error, isNull);
  });

  test('Google sign-in retries after an earlier bootstrap failure', () async {
    service.failure = FirebaseAuthException(code: 'network-request-failed');
    await controller.initialize();
    service.failure = null;
    await controller.signInGoogle();
    expect(service.initializations, 2);
    expect(service.googleCalls, 1);
    expect(controller.state.identity?.uid, 'google');
    expect(controller.state.error, isNull);
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
      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.signOutCalls, 0);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
