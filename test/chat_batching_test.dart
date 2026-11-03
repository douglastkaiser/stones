import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stones/services/match_chat_service.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  int writes = 0;
  bool fail = false, reject = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    writes++;
    if (fail) throw StateError('offline');
    if (reject) return false;
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('one batch writes only IDs, deduplicates and serializes across rooms',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    final first = MatchChatService('one', 'alice');
    final second = MatchChatService('two', 'alice');
    final other = MatchChatService('one', 'bob');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(other.dispose);
    final expiry = DateTime.utc(2030);
    final batch = List.generate(50, (i) => ('matches/one/chat/$i', expiry));
    await first.rememberCleanupIds(batch);
    expect(store.writes, 1);
    await first.rememberCleanupIds(batch);
    await first.rememberCleanupIds([]);
    expect(store.writes, 1);
    await Future.wait([
      first.rememberCleanupIds([('matches/one/chat/next', expiry)]),
      second.rememberCleanupIds([('matches/two/chat/next', expiry)]),
      other.rememberCleanupIds([('matches/one/chat/next', expiry)]),
    ]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('chat_cleanup_ids_v1:alice'), hasLength(52));
    expect(prefs.getStringList('chat_cleanup_ids_v1:bob'),
        ['matches/one/chat/next|${expiry.millisecondsSinceEpoch}']);
    expect(store.writes, 4);
    store.fail = true;
    await expectLater(
        first.rememberCleanupIds([('matches/one/chat/retry', expiry)]),
        throwsStateError);
    store.fail = false;
    await first.rememberCleanupIds([('matches/one/chat/retry', expiry)]);
    // A duplicate retries durability after the failed platform write.
    await second.rememberCleanupIds([('matches/two/chat/recovered', expiry)]);
    expect(store.writes, 7);
    store.reject = true;
    await first.rememberCleanupIds([('matches/one/chat/rejected', expiry)]);
    store.reject = false;
    await first.rememberCleanupIds([('matches/one/chat/rejected', expiry)]);
    expect(store.writes, 9);
    final durable = await store.getAll();
    expect(durable['flutter.chat_cleanup_ids_v1:alice'],
        contains('matches/one/chat/rejected|${expiry.millisecondsSinceEpoch}'));
    expect(
        prefs.getStringList('chat_cleanup_ids_v1:alice'),
        contains(
            'matches/two/chat/recovered|${expiry.millisecondsSinceEpoch}'));
  });
}
