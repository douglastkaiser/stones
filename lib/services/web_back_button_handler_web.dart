import 'dart:async';
import 'dart:html' as html;

StreamSubscription<html.PopStateEvent>? _popStateSubscription;
bool Function()? _onBackCallback;

/// Initialize the web back button handler.
/// [onBack] is called when the browser back button is pressed.
/// It should return true if the back was handled (undo performed),
/// or false if navigation should proceed.
void initWebBackButtonHandler(bool Function() onBack) {
  _onBackCallback = onBack;

  // Push initial history state so we have something to pop
  pushWebHistoryState();

  // Listen for popstate events (browser back/forward)
  _popStateSubscription = html.window.onPopState.listen((event) {
    if (_onBackCallback != null) {
      final handled = _onBackCallback!();
      if (handled) {
        // Undo was performed - push another state to keep the history stack
        pushWebHistoryState();
      }
      // If not handled, let normal navigation proceed
    }
  });
}

/// Push a new history state (call this when moves are made).
void pushWebHistoryState() {
  html.window.history.pushState({'game': 'stones'}, '', null);
}

/// Clean up the handler when leaving the game screen.
void disposeWebBackButtonHandler() {
  _popStateSubscription?.cancel();
  _popStateSubscription = null;
  _onBackCallback = null;
}
