import 'dart:async';

import 'package:flutter/foundation.dart';

/// `app_config` key for the search-field debounce window in milliseconds.
const searchDebounceMsKey = 'app.search_debounce_ms';

/// Fallback when the debounce config row is missing or unparsable.
const searchDebounceMsDefault = 300;

/// The configured search debounce in milliseconds, or
/// [searchDebounceMsDefault] when unset.
int searchDebounceMs(Map<String, String>? appConfig) =>
    int.tryParse(appConfig?[searchDebounceMsKey] ?? '') ?? searchDebounceMsDefault;

/// Collapses rapid invocations of an action into a single execution that runs
/// once [delay] of quiet has passed since the last call — the standard
/// search-field debounce.
///
/// Every [run] replaces the previous pending action, so N keystrokes inside
/// the window cost exactly one query. Screens own one instance for their
/// lifetime and call [cancel] from `dispose`, which makes the debouncer
/// dispose-safe: no action can fire after the widget is gone.
///
/// Delay is injectable (constructor) and mutable ([delay]) so callers can
/// re-tune it from `app_config`.
class Debouncer {
  Debouncer([this.delay = const Duration(milliseconds: 300)]);

  /// Quiet window between [run] calls. Mutable so callers can re-tune it from
  /// `app_config` while an instance is in use.
  Duration delay;

  Timer? _timer;
  VoidCallback? _pending;

  /// Whether a [run] is currently waiting out its delay.
  bool get isPending => _pending != null;

  /// Cancels any pending timer and schedules [action] to run once after
  /// [delay] of quiet.
  void run(VoidCallback action) {
    _timer?.cancel();
    _pending = action;
    _timer = Timer(delay, () {
      _pending = null;
      action();
    });
  }

  /// Cancels the pending timer; the scheduled action never runs. Safe to call
  /// any number of times (e.g. from `dispose`).
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  /// Runs the pending action now (if one is scheduled) and cancels the timer.
  /// No-op when nothing is pending.
  void flush() {
    final action = _pending;
    cancel();
    if (action != null) action();
  }
}
