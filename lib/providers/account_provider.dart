import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../hex/hex_match_provider.dart';
import '../game/match_provider.dart';
import '../services/account_service.dart';
import 'online_game_provider.dart';

class AccountState {
  const AccountState(
      {this.ready = false,
      this.busy = false,
      this.identity,
      this.error,
      this.conflict = false});
  final bool ready;
  final bool busy;
  final AccountIdentity? identity;
  final String? error;
  final bool conflict;
}

class AccountController extends StateNotifier<AccountState> {
  AccountController(this.service, {required this.hasActiveRoom})
      : super(const AccountState());
  final AccountService service;
  final bool Function() hasActiveRoom;
  Future<void>? _initialization;
  Future<AccountIdentity>? _guest;
  StreamSubscription<AccountIdentity?>? _subscription;

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      await service.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      state = AccountState(ready: true, identity: service.current);
      _subscription ??= service.changes.listen((user) {
        if (mounted) {
          state = AccountState(ready: true, busy: state.busy, identity: user);
        }
      }, onError: (Object error) {
        if (mounted) {
          state = AccountState(
              ready: true,
              busy: state.busy,
              identity: state.identity,
              error: accountErrorMessage(error));
        }
      });
    } catch (error) {
      if (mounted) state = AccountState(error: accountErrorMessage(error));
    }
  }

  Future<void> retry() async {
    if (state.busy) return;
    _initialization = null;
    await initialize();
  }

  Future<void> signInGoogle({bool useExistingAccount = false}) async {
    if (state.busy) return;
    try {
      if (_guest != null) await _guest;
    } catch (error) {
      if (mounted) {
        state = AccountState(
            ready: state.ready,
            identity: state.identity,
            error: accountErrorMessage(error));
      }
      return;
    }
    if (!mounted) return;
    if (!state.ready) await initialize();
    if (!mounted || !state.ready || state.busy) return;
    if (useExistingAccount && hasActiveRoom()) {
      state = AccountState(
          ready: true,
          identity: state.identity,
          conflict: true,
          error: 'Leave your current online match before switching accounts.');
      return;
    }
    state = AccountState(ready: true, busy: true, identity: state.identity);
    try {
      await service.signInGoogle(useExistingAccount: useExistingAccount);
      if (mounted) state = AccountState(ready: true, identity: service.current);
    } catch (error) {
      if (mounted) {
        state = AccountState(
            ready: true,
            identity: service.current,
            error: accountErrorMessage(error),
            conflict: error is FirebaseAuthException &&
                ['credential-already-in-use', 'email-already-in-use']
                    .contains(error.code));
      }
    }
  }

  Future<AccountIdentity> ensurePlayer() =>
      _guest ??= _ensurePlayer().whenComplete(() => _guest = null);
  Future<AccountIdentity> _ensurePlayer() async {
    await initialize();
    if (!mounted) throw StateError('Account screen closed');
    if (!state.ready) throw StateError(state.error ?? 'Unable to connect');
    if (state.busy) {
      throw StateError('Finish account sign-in before joining a match.');
    }
    final player = await service.ensurePlayer();
    if (mounted) state = AccountState(ready: true, identity: player);
    return player;
  }

  Future<void> signOut() async {
    if (state.busy || !state.ready || _guest != null) return;
    if (hasActiveRoom()) {
      state = AccountState(
          ready: true,
          identity: state.identity,
          error: 'Leave your current online match before signing out.');
      return;
    }
    state = AccountState(ready: true, busy: true, identity: state.identity);
    try {
      await service.signOut();
      if (mounted) state = const AccountState(ready: true);
    } catch (error) {
      if (mounted) {
        state = AccountState(
            ready: true,
            identity: service.current,
            error: accountErrorMessage(error));
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final accountServiceProvider =
    Provider<AccountService>((ref) => FirebaseAccountService(() async {
          await ref.read(onlineGameProvider.notifier).initialize();
          if (!ref.read(onlineGameProvider.notifier).firebaseInitialized) {
            throw FirebaseAuthException(code: 'network-request-failed');
          }
        }));
final StateNotifierProvider<AccountController, AccountState> accountProvider =
    StateNotifierProvider<AccountController, AccountState>((ref) =>
        AccountController(ref.read(accountServiceProvider),
            hasActiveRoom: () =>
                ref.read(onlineGameProvider).session != null ||
                ref.read(hexMatchProvider).room != null ||
                ref.read(matchProvider).room != null ||
                (ref.read(matchProvider).busy &&
                    ref.read(matchProvider).game == null)));
