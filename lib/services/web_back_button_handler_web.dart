import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool Function()? _onBackCallback;
web.EventListener? _popStateListener;

/// Initialize the web back button handler.
/// [onBack] is called when the browser back button is pressed.
/// It should return true if the back was handled (undo performed),
/// or false if navigation should proceed.
void initWebBackButtonHandler(bool Function() onBack) {
  // Clean up any existing listener first to prevent duplicates
  disposeWebBackButtonHandler();

  _onBackCallback = onBack;

  // Push initial history state so we have something to pop
  pushWebHistoryState();

  // Listen for popstate events (browser back/forward)
  _popStateListener = ((web.Event event) {
    if (_onBackCallback != null) {
      final handled = _onBackCallback!();
      if (handled) {
        // Undo was performed - push another state to keep the history stack
        pushWebHistoryState();
      }
      // If not handled, let normal navigation proceed
    }
  }).toJS;

  web.window.addEventListener('popstate', _popStateListener);
}

/// Push a new history state (call this when moves are made).
void pushWebHistoryState() {
  web.window.history.pushState({'game': 'stones'}.jsify(), '', null);
}

/// Clean up the handler when leaving the game screen.
void disposeWebBackButtonHandler() {
  if (_popStateListener != null) {
    web.window.removeEventListener('popstate', _popStateListener);
    _popStateListener = null;
  }
  _onBackCallback = null;
}
