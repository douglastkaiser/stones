/// Cooperatively share the browser thread during expensive search. Native
/// callers search in an isolate; they can disable yielding entirely.
class SearchBudget {
  SearchBudget({required this.enabled, this.cancelled, this.thinkingLimit});
  final bool enabled;
  bool Function()? cancelled;
  final Duration? thinkingLimit;
  final Stopwatch _slice = Stopwatch()..start();
  final Stopwatch _total = Stopwatch()..start();

  void restart() {
    _slice.reset();
    _total.reset();
  }

  Future<void>? pauseIfNeeded() {
    if (cancelled?.call() ?? false) throw const SearchCancelled();
    if (thinkingLimit != null && _total.elapsed >= thinkingLimit!) {
      throw const SearchTimedOut();
    }
    if (!enabled || _slice.elapsedMilliseconds < 4) return null;
    return Future<void>.delayed(Duration.zero).then((_) => _slice.reset());
  }
}

class SearchCancelled implements Exception {
  const SearchCancelled();
}

class SearchTimedOut implements Exception {
  const SearchTimedOut();
}
