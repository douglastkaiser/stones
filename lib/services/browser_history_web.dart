import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter_web_plugins/flutter_web_plugins.dart'
    show setUrlStrategy;

// Navigator 1 otherwise installs its own single-entry history listener.
void configureBrowserNavigation() => setUrlStrategy(null);

web.EventListener? _listener;
void listenHistory(void Function(int) callback) {
  stopHistory();
  _listener = ((web.Event event) {
    final state = (event as web.PopStateEvent).state?.dartify();
    if (state is Map && state['stonesRoute'] is num) {
      callback((state['stonesRoute'] as num).toInt());
    }
  }).toJS;
  web.window.addEventListener('popstate', _listener);
}

void stopHistory() {
  if (_listener != null) web.window.removeEventListener('popstate', _listener);
  _listener = null;
}

void writeHistory(int index, {bool replace = false, String? route}) {
  final state = {'stonesRoute': index}.jsify();
  final current = Uri.parse(web.window.location.href);
  final incoming = route == null ? null : Uri.tryParse(route);
  final parameters = Map<String, String>.from(current.queryParameters);
  if (index == 0) {
    parameters.remove('room');
  } else if (incoming?.queryParameters['room'] != null) {
    parameters['room'] = incoming!.queryParameters['room']!;
  }
  final url = current
      .replace(
          queryParameters: parameters.isEmpty ? null : parameters,
          query: parameters.isEmpty ? '' : null,
          fragment: '')
      .toString();
  if (replace) {
    web.window.history.replaceState(state, '', url);
  } else {
    web.window.history.pushState(state, '', url);
  }
}

void moveHistory(int delta) => web.window.history.go(delta);
