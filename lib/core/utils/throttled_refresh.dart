/// the 15s refetch throttle for the shell-tab providers'
/// `refresh()` paths — the reference app's `lastFetchedAt` guard, the "don't refetch the
/// world on every tab switch" feel.
///
/// Notifiers mix this in, call [markFetched] at the end of a successful
/// `build()`, and gate `refresh()` on [shouldRefetch]. Only the
/// pull-to-refresh/retry path is throttled: real invalidation from actions
/// (`ref.invalidate(...)` on accept/decline/create/leave) bypasses it
/// entirely, so the throttle can never mask an action's result.
///
/// The window is a getter so tests can shrink it (the app default is 15s).
mixin ThrottledRefresh {
  /// Minimum age of the last successful fetch before `refresh()` may refetch.
  Duration get refreshThrottle => const Duration(seconds: 15);

  DateTime? _lastFetchedAt;

  /// Records the fetch time — call at the end of a successful `build()`.
  /// Failures are NOT recorded, so a retry after an error is never throttled.
  void markFetched() => _lastFetchedAt = DateTime.now();

  /// True when no fetch has succeeded yet or the last one is older than
  /// [refreshThrottle] — the `refresh()` gate.
  bool shouldRefetch() {
    final last = _lastFetchedAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= refreshThrottle;
  }
}
