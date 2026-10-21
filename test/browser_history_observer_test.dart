import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/services/app_history_observer.dart';

class _History {
  late void Function(int) changed;
  final events = <String>[];
  late final observer = AppHistoryObserver(
      enabled: true,
      listen: (callback) => changed = callback,
      write: (index, {replace = false, route}) =>
          events.add('${replace ? "replace" : "push"}:$index'),
      move: (delta) => events.add('go:$delta'));
}

MaterialPageRoute<void> _route() =>
    MaterialPageRoute(builder: (_) => const SizedBox.shrink());

void main() {
  test('a pop followed by the next lesson waits for browser acknowledgement',
      () {
    final history = _History();
    final observer = history.observer..initialize();
    final home = _route(), lesson = _route(), next = _route();
    observer.didPush(home, null);
    observer.didPush(lesson, home);
    observer.didPop(lesson, home);
    observer.didPush(next, home);
    expect(history.events, ['replace:0', 'push:1', 'go:-1']);
    history.changed(0);
    expect(history.events, ['replace:0', 'push:1', 'go:-1', 'push:1']);
    observer.didPop(next, home);
    history.changed(0);
    expect(history.events.last, 'go:-1');
    observer.dispose();
  });

  test('rapid app pops traverse each browser entry once', () {
    final history = _History();
    final observer = history.observer..initialize();
    final home = _route(), hub = _route(), lesson = _route();
    observer.didPush(home, null);
    observer.didPush(hub, home);
    observer.didPush(lesson, hub);
    observer.didPop(lesson, hub);
    observer.didPop(hub, home);
    expect(history.events.where((e) => e.startsWith('go:')), ['go:-1']);
    history.changed(1);
    expect(
        history.events.where((e) => e.startsWith('go:')), ['go:-1', 'go:-1']);
    history.changed(0);
    expect(history.events.length, 5);
    observer.dispose();
  });
}
