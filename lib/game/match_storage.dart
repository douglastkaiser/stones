import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalMatchStorage {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> snapshot);
}

class PreferencesMatchStorage implements LocalMatchStorage {
  static const key = 'unified_local_match_v1';
  Future<void> _writes = Future<void>.value();
  @override
  Future<Map<String, dynamic>?> read() async {
    final value = (await SharedPreferences.getInstance()).getString(key);
    if (value == null) return null;
    return Map<String, dynamic>.from(jsonDecode(value));
  }

  @override
  Future<void> write(Map<String, dynamic> snapshot) {
    final encoded = jsonEncode(snapshot);
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, encoded)) {
        throw StateError('Could not save this match');
      }
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}
