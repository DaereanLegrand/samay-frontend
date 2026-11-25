import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';

/// Build-time Sentry DSN, injected via `--dart-define=SENTRY_DSN=...`
/// (placeholder `''` default).
///
/// A DSN is a public ingest endpoint (safe to ship by design), but it must
/// never be hardcoded here: a build without the define runs the app in
/// **stub mode** (crash reporting disabled — the
/// sentry_flutter SDK wiring lands when a real backend is adopted; the DSN
/// itself is a deploy-time value).
const String sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: '',
);

/// Non-reversible identifier scrub for crash-report user context
/// (data minimization — SECURITY.md §3, the `CrashReporter` row): SHA-256 hex
/// of [userId].
///
/// The sink never receives the raw id — in particular never an email — and
/// the hash is deterministic, so a crash backend can correlate a user's
/// reports across sessions without ever holding PII. Pure function.
Future<String> hashUserId(String userId) async {
  final digest = await Sha256().hash(utf8.encode(userId));
  return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// The delivery endpoint for crash reports.
///
/// The sentry_flutter SDK wiring (future) implements this with
/// `Sentry.captureException` / `Sentry.configureScope`; tests inject a
/// recording fake; stub mode never touches it. Mirrors the RevenueCatDriver
/// seam.
abstract class CrashSink {
  /// Delivers a crash with its [error], [stack] and optional [context]
  /// key/value pairs.
  Future<void> reportError(
    Object error,
    StackTrace stack, {
    Map<String, String>? context,
  });

  /// Associates the current session with the **scrubbed** [userId]
  /// (SHA-256 hex — see [hashUserId]; never a raw id, never an email).
  void setUser(String userId);

  /// Records a breadcrumb for the crash report's event trail.
  void addBreadcrumb(String message);
}

/// Remote crash-reporting seam (Sentry placeholder).
///
/// Two modes, selected at construction by the presence of the `SENTRY_DSN`
/// dart-define:
///
/// * **stub mode** (no DSN):
///   `isEnabled` is false; `reportError` logs the crash via
///   [AppLogger.error] (error level survives release builds, so a stub-mode
///   build never silently swallows a crash), and `setUser`/`addBreadcrumb`
///   are silent no-ops. No sink is ever touched.
/// * **enabled mode** (DSN present): every call delegates to the injected
///   [CrashSink] (the future sentry_flutter wrapper). `setUser` scrubs the
///   id to a SHA-256 hex hash BEFORE it leaves the process. Enabled builds
///   without a sink (SDK wiring pending) degrade to the stub log.
///
/// `reportError` is **fire-and-forget by contract**: it never throws — a
/// failing sink is caught and logged, so the global error handlers in
/// `lib/main.dart` can call it unawaited without risking a recursion into
/// the very handler that reported the crash.
class CrashReporter {
  CrashReporter({
    String dsn = sentryDsn,
    CrashSink? sink,
  })  : _dsn = dsn,
        _sink = sink {
    if (_dsn.isEmpty) {
      AppLogger.instance.info(
        'CrashReporter stub mode: no SENTRY_DSN dart-define — remote crash '
        'reporting disabled (sentry_flutter wiring pending).',
      );
    }
  }

  final String _dsn;
  final CrashSink? _sink;

  /// True only when a `SENTRY_DSN` dart-define was provided at build time.
  bool get isEnabled => _dsn.isNotEmpty;

  /// Reports a crash to the sink (no-op when disabled).
  ///
  /// Stub mode: logs via [AppLogger.error] — loud in debug, and error level
  /// is NOT compiled out in release, so a stub-mode build never silently
  /// swallows a crash. Enabled mode: delegates to the injected sink; a
  /// throwing sink is caught and logged (fire-and-forget contract — the
  /// global handlers invoke this unawaited).
  Future<void> reportError(
    Object error,
    StackTrace stack, {
    Map<String, String>? context,
  }) async {
    if (!_enabledWithSink()) {
      AppLogger.instance.error('Crash (stub — no SENTRY_DSN): $error', '$stack');
      return;
    }
    try {
      await _sink!.reportError(error, stack, context: context);
    } catch (e, st) {
      AppLogger.instance.error('CrashSink.reportError failed: $e', '$st');
    }
  }

  /// Associates the current session with [userId] — **scrubbed**: the sink
  /// receives only a SHA-256 hex hash of the id (see [hashUserId]), never
  /// the raw value and therefore never an email. No-op when disabled or
  /// when [userId] is null/empty.
  Future<void> setUser(String? userId) async {
    if (!_enabledWithSink()) return;
    if (userId == null || userId.isEmpty) return;
    final scrubbed = await hashUserId(userId);
    try {
      _sink!.setUser(scrubbed);
    } catch (e, st) {
      AppLogger.instance.error('CrashSink.setUser failed: $e', '$st');
    }
  }

  /// Records a breadcrumb on the sink (no-op when disabled). Breadcrumbs are
  /// per-action context for the crash trail; stub mode stays silent so
  /// high-volume context does not flood `samay.log`.
  void addBreadcrumb(String message) {
    if (!_enabledWithSink()) return;
    try {
      _sink!.addBreadcrumb(message);
    } catch (e, st) {
      AppLogger.instance.error('CrashSink.addBreadcrumb failed: $e', '$st');
    }
  }

  /// Enabled AND a sink is present — the real driver exists. An enabled
  /// build without a sink (SDK wiring pending) degrades to the stub log.
  bool _enabledWithSink() => isEnabled && _sink != null;
}

/// The app-wide crash reporter. Tests override the whole provider (e.g.
/// with an enabled reporter backed by a recording sink) — nothing else in
/// the app may construct a reporter directly.
final crashReporterProvider = Provider<CrashReporter>((ref) {
  return CrashReporter();
});
