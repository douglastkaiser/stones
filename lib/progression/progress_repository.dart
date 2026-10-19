import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'progress_merge.dart';

abstract interface class ProgressCache {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PreferencesProgressCache implements ProgressCache {
  PreferencesProgressCache(this.preferences);
  final SharedPreferences preferences;

  @override
  Future<String?> read(String key) async => preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    if (!await preferences.setString(key, value)) {
      throw StateError('Progress cache write failed');
    }
  }
}

/// Implementations must transactionally merge, never overwrite a remote snapshot.
/// Bound the request in the adapter; a failed request leaves the durable local
/// event set available to retry. The remote response is still checked for owner.
abstract interface class ProgressRemote {
  Future<AccountProgress> merge(AccountProgress local);
}

/// One repository per immutable owner. Auth changes select a fresh repository;
/// completion of Alice's in-flight sync can only update Alice's cache/state.
/// All events remain durable until a future versioned compaction protocol exists.
class ProgressRepository {
  ProgressRepository({required this.owner, required this.cache}) {
    if (owner.isEmpty) throw ArgumentError.value(owner, 'owner');
  }

  final String owner;
  final ProgressCache cache;
  String get cacheKey => 'account_progress_v1:${Uri.encodeComponent(owner)}';
  AccountProgress? _current;
  AccountProgress? get current => _current;
  Future<void> _operations = Future.value();

  Future<T> _queue<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _operations = _operations.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<AccountProgress> _load() async {
    if (_current != null) return _current!;
    final encoded = await cache.read(cacheKey);
    return _current = encoded == null
        ? AccountProgress(owner: owner)
        : AccountProgress.decode(encoded, owner: owner);
  }

  Future<AccountProgress> _save(AccountProgress next) async {
    await cache.write(cacheKey, next.encode());
    return _current = next;
  }

  Future<AccountProgress> load() => _queue(_load);

  Future<AccountProgress> record(ProgressEvent event) =>
      _queue(() async => _save((await _load()).record(event)));

  /// The caller must present an explicit import choice before invoking this.
  /// Reading the legacy save is external; this never modifies its source key.
  Future<AccountProgress> importGuest(ProgressBaseline frozenBaseline) =>
      _queue(() async => _save((await _load()).importBaseline(frozenBaseline)));

  Future<AccountProgress> synchronize(ProgressRemote remote) async {
    final local = await load();
    // Network work stays outside the local write queue so offline/hung sync
    // cannot delay saving another completed game or lesson.
    final received = await remote.merge(local);
    return _queue(() async {
      final latest = await _load();
      // Re-read after the network request to preserve events earned during sync.
      return _save(latest.merge(received));
    });
  }
}
