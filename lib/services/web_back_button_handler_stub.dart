/// Stub implementation for non-web platforms.
/// On mobile, PopScope handles the back button natively.

void initWebBackButtonHandler(bool Function() onBack) {
  // No-op on non-web platforms
}

void pushWebHistoryState() {
  // No-op on non-web platforms
}

void disposeWebBackButtonHandler() {
  // No-op on non-web platforms
}
