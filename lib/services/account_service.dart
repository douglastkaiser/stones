import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AccountIdentity {
  const AccountIdentity(
      {required this.uid, required this.guest, this.name, this.email});
  final String uid;
  final bool guest;
  final String? name;
  final String? email;
}

abstract class AccountService {
  Future<void> initialize();
  AccountIdentity? get current;
  Stream<AccountIdentity?> get changes;
  Future<AccountIdentity?> signInGoogle({bool useExistingAccount = false});
  Future<AccountIdentity> ensurePlayer();
  Future<void> signOut();
}

/// Firebase identity owns multiplayer seats. Play Games is a separate optional
/// integration and must never be a prerequisite for authenticating here.
class FirebaseAccountService implements AccountService {
  FirebaseAccountService(this.bootstrap);
  final Future<void> Function() bootstrap;
  GoogleSignIn? _google;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => _google ??= GoogleSignIn(scopes: ['email']);
  static AccountIdentity? identity(User? user) => user == null
      ? null
      : AccountIdentity(
          uid: user.uid,
          guest: user.isAnonymous,
          name: user.displayName,
          email: user.email);

  @override
  Future<void> initialize() async {
    await bootstrap();
    await _auth.authStateChanges().first;
  }

  @override
  AccountIdentity? get current => identity(_auth.currentUser);
  @override
  Stream<AccountIdentity?> get changes => _auth.userChanges().map(identity);

  @override
  Future<AccountIdentity?> signInGoogle(
      {bool useExistingAccount = false}) async {
    final guest = _auth.currentUser;
    final link = guest?.isAnonymous == true && !useExistingAccount;
    try {
      UserCredential result;
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        result = link
            ? await guest!.linkWithPopup(provider)
            : await _auth.signInWithPopup(provider);
      } else {
        if (defaultTargetPlatform != TargetPlatform.android) {
          throw FirebaseAuthException(code: 'unsupported-platform');
        }
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;
        final tokens = await googleUser.authentication;
        if (tokens.idToken == null) {
          throw FirebaseAuthException(code: 'missing-google-token');
        }
        final credential = GoogleAuthProvider.credential(
            idToken: tokens.idToken, accessToken: tokens.accessToken);
        result = link
            ? await guest!.linkWithCredential(credential)
            : await _auth.signInWithCredential(credential);
      }
      return identity(result.user);
    } on FirebaseAuthException catch (error) {
      if ([
        'popup-closed-by-user',
        'cancelled-popup-request',
        'web-context-cancelled'
      ].contains(error.code)) {
        return null;
      }
      rethrow;
    } on PlatformException catch (error) {
      if (['sign_in_canceled', 'sign_in_cancelled'].contains(error.code)) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AccountIdentity> ensurePlayer() async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
    if (user == null) throw FirebaseAuthException(code: 'missing-user');
    return identity(user)!;
  }

  @override
  Future<void> signOut() async {
    // Sign Firebase out first so a failed optional native cleanup cannot leave
    // the app silently authenticated after the UI reports a sign-out.
    await _auth.signOut();
    if (!kIsWeb && _google != null) {
      try {
        await _google!.signOut();
      } catch (_) {}
    }
  }
}

String accountErrorMessage(Object error) {
  if (error is TimeoutException) {
    return 'Connection took too long. Check your network and retry.';
  }
  final code = error is FirebaseAuthException
      ? error.code
      : error is PlatformException
          ? error.code
          : '';
  return switch (code) {
    'network-request-failed' ||
    'network_error' =>
      'Could not reach Google. Check your connection and try again.',
    'popup-blocked' =>
      'Your browser blocked the sign-in window. Allow popups for Stones, then try again.',
    'unauthorized-domain' =>
      'Google sign-in is not configured for this website. Please contact support.',
    'operation-not-allowed' =>
      'This sign-in method is not enabled for Stones. Please contact support.',
    'credential-already-in-use' ||
    'email-already-in-use' =>
      'This Google account already has a Stones account. Your guest games are still on this device. You can keep them or explicitly switch to the existing account.',
    'account-exists-with-different-credential' =>
      'This email already uses another sign-in method. Sign in with that method before linking Google.',
    'too-many-requests' =>
      'Too many sign-in attempts. Wait a little before trying again.',
    'user-disabled' => 'This account is disabled. Please contact support.',
    'sign_in_failed' ||
    'missing-google-token' =>
      'Google could not verify this Android app. Update Stones and try again. If it persists, report your app version to support.',
    'unsupported-platform' =>
      'Google account sign-in is available on Android and in the browser.',
    _ => 'Sign-in could not finish. Please try again.',
  };
}
