import 'package:firebase_messaging/firebase_messaging.dart';
import 'turn_push_types.dart';

TurnPushPlatform createTurnPushPlatform() => _NativePush();

class _NativePush implements TurnPushPlatform {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  @override
  Future<TurnPushPermission> permission() async {
    if (!await _messaging.isSupported()) return TurnPushPermission.unsupported;
    final settings = await _messaging.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        TurnPushPermission.enabled,
      AuthorizationStatus.denied => TurnPushPermission.denied,
      AuthorizationStatus.notDetermined => TurnPushPermission.available,
    };
  }

  @override
  Future<String?> enable(String vapidKey) async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return null;
    }
    return _messaging.getToken();
  }

  @override
  Future<String?> refresh(String vapidKey) => _messaging.getToken();
  @override
  Future<void> disable() => _messaging.deleteToken();
  @override
  Future<void> bind(String? uid) async {}
  @override
  Stream<String> get tokens => _messaging.onTokenRefresh;
  @override
  Stream<Map<String, dynamic>> get foreground =>
      FirebaseMessaging.onMessage.map((message) => message.data);
  @override
  Stream<Map<String, dynamic>> get opened async* {
    final initial = await _messaging.getInitialMessage();
    if (initial != null) yield initial.data;
    yield* FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);
  }
}
