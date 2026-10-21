import 'package:flutter/material.dart';
import 'browser_history_platform.dart' as browser;

/// Keep browser Back/Forward aligned with the visible application route.
class AppHistoryObserver extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];
  final _forward = <(WidgetBuilder?, RouteSettings)>[];
  bool _browserNavigation = false;
  int? _expected;
  void initialize() => browser.listenHistory(_changed);
  void dispose() => browser.stopHistory();
  void _changed(int target) {
    if (_expected == target) {
      _expected = null;
      return;
    }
    _browserNavigation = true;
    while (_routes.length - 1 > target && _routes.length > 1) {
      navigator?.pop();
    }
    while (_routes.length - 1 < target && _forward.isNotEmpty) {
      final route = _forward.removeLast();
      if (route.$1 == null) {
        browser.writeHistory(_routes.length - 1, replace: true);
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
    browser.writeHistory(_routes.length - 1,
        replace: previousRoute == null, route: route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _forward.add(
        (route is MaterialPageRoute ? route.builder : null, route.settings));
    if (_browserNavigation) return;
    _expected = _routes.length - 1;
    browser.moveHistory(-1);
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
