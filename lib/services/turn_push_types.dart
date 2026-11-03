enum TurnPushPermission {
  available,
  enabled,
  denied,
  unsupported,
  installRequired
}

abstract class TurnPushPlatform {
  Future<TurnPushPermission> permission();
  Future<String?> enable(String vapidKey);
  Future<String?> refresh(String vapidKey);
  Future<void> disable();
  Future<void> bind(String? uid);
  Stream<Map<String, dynamic>> get opened;
  Stream<Map<String, dynamic>> get foreground;
  Stream<String> get tokens;
}
