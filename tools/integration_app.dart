// Emulator-only entry point. Never used by production builds or publication.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stones/main.dart';
import 'package:stones/providers/account_provider.dart';
import 'package:stones/services/account_service.dart';
import 'package:stones/services/browser_history_platform.dart'
    show configureBrowserNavigation;

Future<void> main() async {
  configureBrowserNavigation();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: 'demo-stones-key',
          appId: '1:123456789:web:stones-emulator',
          messagingSenderId: '123456789',
          projectId: 'demo-stones-hex',
          authDomain: 'localhost'));
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8088);
  await launchStones(
      container: ProviderContainer(overrides: [
    accountServiceProvider
        .overrideWithValue(FirebaseAccountService(() async {})),
  ]));
}
