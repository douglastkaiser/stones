import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'turn_push_types.dart';
import 'turn_push_native.dart'
    if (dart.library.js_interop) 'turn_push_web.dart';

const turnAlertsReleased = bool.fromEnvironment('STONES_TURN_ALERTS_ENABLED');
const turnAlertsVapidKey = String.fromEnvironment('STONES_PUSH_VAPID_KEY');

DocumentReference<Map<String, dynamic>> turnAlertPreferences(
        FirebaseFirestore db, String uid) =>
    db
        .collection('playerGames')
        .doc(uid)
        .collection('preferences')
        .doc('notifications');

class TurnNotificationService {
  TurnNotificationService({TurnPushPlatform? platform})
      : platform = platform ?? createTurnPushPlatform();
  final TurnPushPlatform platform;
  final _opened = StreamController<Map<String, dynamic>>.broadcast();
  final _foreground = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get opened => _opened.stream;
  Stream<Map<String, dynamic>> get foreground => _foreground.stream;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> _work = Future.value();
  String? _uid;
  String? _boundUid;

  bool _current(String uid) =>
      _uid == uid && FirebaseAuth.instance.currentUser?.uid == uid;
  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('turn_notification_device_v1');
    if (id != null) return id;
    id =
        base64UrlEncode(List.generate(18, (_) => Random.secure().nextInt(256)));
    if (!await prefs.setString('turn_notification_device_v1', id)) {
      throw StateError(
          'Could not remember notification settings on this device.');
    }
    return id;
  }

  DocumentReference<Map<String, dynamic>> _device(String uid, String id) =>
      FirebaseFirestore.instance
          .collection('playerGames')
          .doc(uid)
          .collection('devices')
          .doc(id);

  Future<void> _register(String uid, String token) async {
    final id = await _deviceId();
    if (!_current(uid)) return;
    await _device(uid, id).set({
      'token': token,
      'enabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 15));
  }

  /// Serialize rebinding: a late logout must never delete the new login's token.
  Future<void> setIdentity(String? uid) {
    _uid = uid;
    final operation = _work.then((_) => _setIdentity(uid));
    _work = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _setIdentity(String? uid) async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    if (!turnAlertsReleased) return;
    if (_boundUid != null && _boundUid != uid) {
      // Invalidate the transport token even if old-account remote cleanup is denied.
      await platform.disable();
    }
    _boundUid = uid;
    await platform.bind(uid);
    if (uid == null) {
      await platform.disable();
      return;
    }
    if (!_current(uid)) return;
    void deliver(Map<String, dynamic> data,
        StreamController<Map<String, dynamic>> target) {
      if (_current(uid) && data['uid'] == uid) target.add(data);
    }

    _subscriptions.add(platform.opened
        .listen((data) => deliver(data, _opened), onError: (Object _) {}));
    _subscriptions.add(platform.foreground
        .listen((data) => deliver(data, _foreground), onError: (Object _) {}));
    _subscriptions.add(platform.tokens.listen((token) {
      if (_current(uid)) {
        unawaited(_register(uid, token).catchError((Object _) {}));
      }
    }));
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('turn_alerts_device_enabled') != true) return;
    if (await platform.permission() != TurnPushPermission.enabled) return;
    final token = await platform.refresh(turnAlertsVapidKey);
    if (token != null) await _register(uid, token);
  }

  Future<TurnPushPermission> permission() => platform.permission();
  Future<void> enableDevice(String uid) async {
    if (!turnAlertsReleased || (kIsWeb && turnAlertsVapidKey.isEmpty)) {
      throw StateError(
          'Turn notifications are not available in this build yet.');
    }
    // Start the permission request in the original tap, before storage/network awaits.
    final pending = platform.enable(turnAlertsVapidKey);
    final token = await pending;
    if (!_current(uid)) return;
    if (token == null) {
      throw StateError('Notification permission was not granted.');
    }
    await platform.bind(uid);
    await _register(uid, token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('turn_alerts_device_enabled', true);
  }

  Future<void> disableDevice(String uid) async {
    await platform.bind(null);
    await platform.disable();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('turn_alerts_device_enabled', false);
    if (_current(uid)) {
      await _device(uid, await _deviceId())
          .delete()
          .timeout(const Duration(seconds: 15));
    }
  }

  Future<void> beforeSignOut() async {
    if (!turnAlertsReleased) return;
    final uid = _uid;
    // Revoke locally even when remote cleanup is unavailable.
    await platform.bind(null);
    try {
      await platform.disable().timeout(const Duration(seconds: 5));
    } catch (_) {}
    if (uid != null && _current(uid)) {
      try {
        await _device(uid, await _deviceId())
            .delete()
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    _uid = null;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _opened.close();
    await _foreground.close();
  }
}

final turnNotificationService = TurnNotificationService();
