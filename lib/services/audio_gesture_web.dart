import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Flutter's DOM accessibility buttons can activate without a canvas pointer
/// event. Capture trusted browser gestures as well, including keyboard input.
void Function() listenForAudioGesture(void Function() unlock) {
  final listener = ((web.Event event) {
    if (event.isTrusted) unlock();
  }).toJS;
  const events = ['pointerdown', 'keydown', 'click'];
  for (final event in events) {
    web.document.addEventListener(event, listener, true.toJS);
  }
  return () {
    for (final event in events) {
      web.document.removeEventListener(event, listener, true.toJS);
    }
  };
}
