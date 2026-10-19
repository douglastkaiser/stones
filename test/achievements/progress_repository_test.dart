import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/progression/progress_merge.dart';
import 'package:stones/progression/progress_repository.dart';

class MemoryCache implements ProgressCache {
  final data = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('Disk full');
    data[key] = value;
  }
}

class Remote implements ProgressRemote {
  Remote(this.operation);
  final Future<AccountProgress> Function(AccountProgress) operation;
  @override
  Future<AccountProgress> merge(AccountProgress local) => operation(local);
}

ProgressEvent win(String id) => ProgressEvent(
    id: 'match:$id',
    evidence: ProgressBaseline(counters: {'wins': 1}, matches: {id}));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preferences cache survives restart without touching guest save',
      () async {
    SharedPreferences.setMockInitialValues(
        {'achievement_progression_v2': 'guest'});
    final prefs = await SharedPreferences.getInstance();
    final cache = PreferencesProgressCache(prefs);
    final repo = ProgressRepository(owner: 'alice', cache: cache);
    await Future.wait([repo.record(win('one')), repo.record(win('two'))]);
    final restarted = ProgressRepository(owner: 'alice', cache: cache);
    expect((await restarted.load()).materialize.counters['wins'], 2);
    expect(prefs.getString('achievement_progression_v2'), 'guest');
    final bob = ProgressRepository(owner: 'bob', cache: cache);
    expect((await bob.load()).materialize.counters, isEmpty);
  });

  test('failed writes publish no reward and queue remains retryable', () async {
    final cache = MemoryCache();
    final repo = ProgressRepository(owner: 'alice', cache: cache);
    await repo.record(win('saved'));
    final before = cache.data[repo.cacheKey];
    cache.fail = true;
    await expectLater(repo.record(win('pending')), throwsStateError);
    expect(repo.current!.materialize.counters['wins'], 1);
    expect(cache.data[repo.cacheKey], before);
    cache.fail = false;
    await repo.record(win('pending'));
    expect(repo.current!.materialize.counters['wins'], 2);
  });

  test('offline events survive failed sync, restart, then concurrent retry',
      () async {
    final cacheA = MemoryCache();
    final cacheB = MemoryCache();
    var server = AccountProgress(owner: 'alice');
    final remote = Remote((local) async => server = server.merge(local));
    final a = ProgressRepository(owner: 'alice', cache: cacheA);
    final b = ProgressRepository(owner: 'alice', cache: cacheB);
    await a.record(win('a'));
    await b.record(win('b'));
    await expectLater(
        a.synchronize(Remote((_) async => throw StateError('Offline'))),
        throwsStateError);
    final resumed = ProgressRepository(owner: 'alice', cache: cacheA);
    await resumed.synchronize(remote);
    await b.synchronize(remote);
    await resumed.synchronize(remote);
    await b.synchronize(remote);
    expect(server.materialize.counters['wins'], 2);
    expect(resumed.current!.materialize.counters['wins'], 2);
    expect(b.current!.materialize.counters['wins'], 2);
  });

  test('server commit followed by cache failure retries without double credit',
      () async {
    final cache = MemoryCache();
    final repo = ProgressRepository(owner: 'alice', cache: cache);
    await repo.record(win('local'));
    var server = AccountProgress(owner: 'alice').record(win('remote'));
    final remote = Remote((local) async => server = server.merge(local));
    cache.fail = true;
    await expectLater(repo.synchronize(remote), throwsStateError);
    expect(server.materialize.counters['wins'], 2);
    expect(repo.current!.materialize.counters['wins'], 1);
    cache.fail = false;
    final restarted = ProgressRepository(owner: 'alice', cache: cache);
    await restarted.synchronize(remote);
    expect(restarted.current!.materialize.counters['wins'], 2);
    expect(server.materialize.counters['wins'], 2);
  });

  test('account switch during sync cannot publish Alice progress as Bob',
      () async {
    final cache = MemoryCache();
    final a = ProgressRepository(owner: 'alice', cache: cache);
    await a.record(win('a'));
    final response = Completer<AccountProgress>();
    final entered = Completer<void>();
    final syncing = a.synchronize(Remote((_) {
      entered.complete();
      return response.future;
    }));
    await entered.future;
    final b = ProgressRepository(owner: 'bob', cache: cache);
    await b.record(win('b'));
    response.complete(AccountProgress(owner: 'alice').record(win('remote')));
    await syncing;
    expect(b.current!.materialize.matches, {'b'});
    expect(a.current!.materialize.matches, {'a', 'remote'});
    expect(
        AccountProgress.decode(cache.data[b.cacheKey]!, owner: 'bob')
            .materialize
            .matches,
        {'b'});
  });

  test('foreign server/cache payloads and corrupt saves fail without overwrite',
      () async {
    final cache = MemoryCache();
    final a = ProgressRepository(owner: 'alice', cache: cache);
    await a.record(win('a'));
    final before = cache.data[a.cacheKey];
    await expectLater(
        a.synchronize(Remote((_) async => AccountProgress(owner: 'bob'))),
        throwsStateError);
    expect(cache.data[a.cacheKey], before);
    for (final encoded in [
      AccountProgress(owner: 'bob').encode(),
      '{broken',
      jsonEncode({'version': 999, 'owner': 'alice'}),
    ]) {
      cache.data[a.cacheKey] = encoded;
      final fresh = ProgressRepository(owner: 'alice', cache: cache);
      await expectLater(fresh.record(win('new')), throwsFormatException);
      expect(cache.data[a.cacheKey], encoded);
      expect(fresh.current, isNull);
    }
  });

  test('record queued during sync retains both local and remote evidence',
      () async {
    final repo = ProgressRepository(owner: 'alice', cache: MemoryCache());
    final response = Completer<AccountProgress>();
    final syncing = repo.synchronize(Remote((_) => response.future));
    await repo.record(win('local'));
    expect(repo.current!.materialize.matches, {'local'});
    response.complete(AccountProgress(owner: 'alice').record(win('remote')));
    await syncing;
    expect(repo.current!.materialize.matches, {'local', 'remote'});
  });

  test('legacy v2 import is explicit, normalizes IDs and preserves earned data',
      () async {
    final cache = MemoryCache();
    final repo = ProgressRepository(owner: 'alice', cache: cache);
    final baseline = ProgressBaseline.fromLegacyV2(jsonEncode({
      'version': 2,
      'metrics': {'wins': 9},
      'matches': ['old:20:road'],
      'unlocks': ['unknown-theme'],
      'legacyUnlocks': ['unknown-theme'],
      'tutorials': ['historical-lesson'],
      'puzzles': ['historical-puzzle'],
      'pending': ['unknown-theme'],
    }));
    expect((await repo.load()).materialize.unlocks, isEmpty);
    await repo.importGuest(baseline);
    await repo.importGuest(baseline);
    await repo.record(win('old'));
    final restarted = ProgressRepository(owner: 'alice', cache: cache);
    final result = (await restarted.load()).materialize;
    expect(result.counters['wins'], 9);
    expect(result.unlocks, {'unknown-theme'});
    expect(result.tutorials, {'historical-lesson'});
    expect(result.unaided, isEmpty);
    expect(result.earnedAt, isEmpty);
    expect(() => ProgressBaseline.fromLegacyV2('{"version":3}'),
        throwsFormatException);
  });
}
