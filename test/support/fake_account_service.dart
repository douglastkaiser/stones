import 'dart:async';
import 'package:stones/services/account_service.dart';

class FakeAccount extends AccountService {
  final events = StreamController<AccountIdentity?>.broadcast();
  @override
  AccountIdentity? current;
  int initializations = 0;
  int guestCalls = 0;
  int googleCalls = 0;
  int signOutCalls = 0;
  bool switched = false;
  Object? failure;
  bool cancelled = false;
  Completer<void>? initialization;
  Completer<void>? google;
  @override
  Stream<AccountIdentity?> get changes => events.stream;
  @override
  Future<void> initialize() async {
    initializations++;
    await initialization?.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<AccountIdentity> ensurePlayer() async {
    guestCalls++;
    return current ??= const AccountIdentity(uid: 'guest', guest: true);
  }

  @override
  Future<AccountIdentity?> signInGoogle(
      {bool useExistingAccount = false}) async {
    googleCalls++;
    switched = useExistingAccount;
    await google?.future;
    if (failure != null) throw failure!;
    if (cancelled) return null;
    return current = AccountIdentity(
      uid: useExistingAccount ? 'existing' : current?.uid ?? 'google',
      guest: false,
      name: 'Player',
      email: 'player@example.com',
    );
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    current = null;
  }
}
