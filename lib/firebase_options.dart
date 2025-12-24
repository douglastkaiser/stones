import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// SECURITY NOTE: Firebase API keys are designed to be included in client-side
/// code and are not secret. They identify your Firebase project but do not grant
/// access to your data. Security is enforced by Firestore Security Rules (see
/// firestore.rules) and Firebase Authentication, not by keeping API keys secret.
/// See: https://firebase.google.com/docs/projects/api-keys
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDU8twgc4E0ZR-pcIBHwIqMx0Wdty1_LwM',
    appId: '1:984712752792:web:eda06c6c598e3971e96aed',
    messagingSenderId: '984712752792',
    projectId: 'stones-9a6a0',
    authDomain: 'stones-9a6a0.firebaseapp.com',
    storageBucket: 'stones-9a6a0.firebasestorage.app',
    measurementId: 'G-8BM3W3Q70J',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyABTcneFEI7SBi3Vymbgqw2x51iwislTzc',
    appId: '1:984712752792:android:9473fc91365ae8c3e96aed',
    messagingSenderId: '984712752792',
    projectId: 'stones-9a6a0',
    storageBucket: 'stones-9a6a0.firebasestorage.app',
  );

  // TODO: Add your iOS Firebase configuration
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '984712752792',
    projectId: 'stones-9a6a0',
    storageBucket: 'stones-9a6a0.firebasestorage.app',
    iosBundleId: 'com.example.stones',
  );

  // TODO: Add your macOS Firebase configuration
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_MACOS_API_KEY',
    appId: 'REPLACE_WITH_MACOS_APP_ID',
    messagingSenderId: '984712752792',
    projectId: 'stones-9a6a0',
    storageBucket: 'stones-9a6a0.firebasestorage.app',
    iosBundleId: 'com.example.stones',
  );

  // TODO: Add your Windows Firebase configuration
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WINDOWS_API_KEY',
    appId: 'REPLACE_WITH_WINDOWS_APP_ID',
    messagingSenderId: '984712752792',
    projectId: 'stones-9a6a0',
    storageBucket: 'stones-9a6a0.firebasestorage.app',
  );
}
