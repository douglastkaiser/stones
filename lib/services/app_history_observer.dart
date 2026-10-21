import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'browser_history_platform.dart' as browser;

/// Keep browser Back/Forward aligned with the visible application route.
class AppHistoryObserver extends NavigatorObserver {
  AppHistoryObserver({
    this.enabled = kIsWeb,
    void Function(void Function(int)) listen = browser.listenHistory,
    void Function(int, {bool replace, String? route}) write =
        browser.writeHistory,
    void Function(int) move = browser.moveHistory,
  })  : _listen = listen,
        _write = write,
        _move = move;
  final bool enabled;
  final void Function(void Function(int)) _listen;
  final void Function(int, {bool replace, String? route}) _write;
  final void Function(int) _move;
  final _routes = <Route<dynamic>>[];
  final _forward = <(WidgetBuilder?, RouteSettings)>[];
  final _pending = <void Function()>[];
  bool _browserNavigation = false;
  int? _expected;
  int _browserIndex = 0;
  void initialize() {
    if (enabled) _listen(_changed);
  }

  void dispose() {
    if (enabled) browser.stopHistory();
    _pending.clear();
  }

  // history.go is asynchronous. A lesson can pop and immediately push its next
  // route; pushing browser history before popstate arrives cancels or redirects
  // that traversal. Serialize writes until the expected traversal is acknowledged.
  void _enqueue(void Function() action) {
    if (!enabled) return;
    _pending.add(action);
    _drain();
  }

  void _drain() {
    while (_expected == null && _pending.isNotEmpty) {
      _pending.removeAt(0)();
    }
  }

  void _changed(int target) {
    _browserIndex = target;
    if (_expected == target) {
      _expected = null;
      _drain();
      return;
    }
    _expected = null;
    _pending.clear();
    _browserNavigation = true;
    while (_routes.length - 1 > target && _routes.length > 1) {
      navigator?.pop();
    }
    while (_routes.length - 1 < target && _forward.isNotEmpty) {
      final route = _forward.removeLast();
      if (route.$1 == null) {
        _browserIndex = _routes.length - 1;
        _write(_browserIndex, replace: true);
        break;
      }
      navigator?.push(
          MaterialPageRoute<void>(builder: route.$1!, settings: route.$2));
    }
    _browserNavigation = false;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    if (_browserNavigation) return;
    _forward.clear();
    final index = _routes.length - 1;
    _enqueue(() {
      _write(index, replace: previousRoute == null, route: route.settings.name);
      _browserIndex = index;
    });
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _forward.add(
        (route is MaterialPageRoute ? route.builder : null, route.settings));
    if (_browserNavigation) return;
    final target = _routes.length - 1;
    _enqueue(() {
      final delta = target - _browserIndex;
      if (delta == 0) return;
      _expected = target;
      _move(delta);
    });
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = _routes.indexOf(oldRoute!);
    if (index >= 0 && newRoute != null) _routes[index] = newRoute;
  }
}
