import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';

/// Build-time PostHog project API key, injected via
/// `--dart-define=POSTHOG_API_KEY=...` (placeholder `''` default).
///
/// The key is a public project key (safe to ship by design — DEPLOYMENT-
/// PLACEHOLDER.md §2.1), but it must never be hardcoded here: a build without
/// the define runs the app in **stub mode** (telemetry disabled — the
/// posthog_flutter SDK wiring lands when a key exists).
const String posthogApiKey = String.fromEnvironment(
  'POSTHOG_API_KEY',
  defaultValue: '',
);

/// Build-time PostHog host, injected via `--dart-define=POSTHOG_HOST=...`.
/// Used by the future SDK wiring; the
/// service's enabled state keys off [posthogApiKey] alone.
const String posthogHost = String.fromEnvironment(
  'POSTHOG_HOST',
  defaultValue: '',
);

/// Terms whose (case-insensitive) presence in a property key marks it as
/// PII (SECURITY.md §2.8): stripped from every telemetry payload.
const List<String> _piiKeyTerms = ['email', 'password', 'token', 'phone'];

/// Value substituted for redacted PII keys.
const String _redacted = '[redacted]';

/// Maximum length for string property values; longer values are truncated.
const int _maxPropertyValueLength = 500;

/// Sanitizes a telemetry property map (PII contract, SECURITY.md §2.8):
///
/// * keys containing any blocklisted term (`email`, `password`, `token`,
///   `phone` — case-insensitive, substring match so `user_email`,
///   `access_token` etc. are caught) keep their key but the value becomes
///   `[redacted]` — the schema stays stable for the analytics backend;
/// * string values longer than 500 chars are truncated to 500 + `…`;
/// * non-string values and everything else pass through unchanged (nested
///   maps/lists are NOT recursed — telemetry properties are flat by design).
///
/// Pure function — unit-tested in `test/services/telemetry_service_test.dart`.
Map<String, dynamic> sanitizeProperties(Map<String, dynamic> properties) {
  final sanitized = <String, dynamic>{};
  for (final entry in properties.entries) {
    final key = entry.key;
    if (_isPiiKey(key)) {
      sanitized[key] = _redacted;
      continue;
    }
    final value = entry.value;
    if (value is String && value.length > _maxPropertyValueLength) {
      sanitized[key] =
          '${value.substring(0, _maxPropertyValueLength)}…';
      continue;
    }
    sanitized[key] = value;
  }
  return sanitized;
}

bool _isPiiKey(String key) {
  final lower = key.toLowerCase();
  return _piiKeyTerms.any(lower.contains);
}

/// The delivery endpoint for telemetry events.
///
/// The posthog_flutter SDK wiring (future) implements this with `PostHog()
/// .capture()/.identify()/.reset()`; tests inject a recording fake; stub mode
/// never touches it. Mirrors the RevenueCatDriver seam pattern so the
/// crash-reporter seam can follow the same shape.
abstract class TelemetrySink {
  /// Delivers a sanitized [event] with its [properties].
  void track(String event, Map<String, dynamic> properties);

  /// Associates the current session with [userId].
  void identify(String userId);

  /// Clears the stored user association (sign-out / account switch).
  void reset();
}

/// Product-analytics seam.
///
/// Two modes, selected at construction by the presence of the
/// `POSTHOG_API_KEY` dart-define:
///
/// * **stub mode** (no key — every build until the SDK wiring lands):
///   `isEnabled` is false; `track` logs through [AppLogger.info] (compiled
///   out in release builds) and `identify`/`reset` are silent no-ops. No
///   PII ever reaches a log file in this mode — nothing is logged at all in
///   release, and debug builds log only the event name.
/// * **enabled mode** (key present): every call delegates to the injected
///   [TelemetrySink] (the future posthog_flutter wrapper). `track` runs
///   [sanitizeProperties] first — PII keys are redacted and oversized
///   values truncated BEFORE they leave the process.
class TelemetryService {
  TelemetryService({
    String apiKey = posthogApiKey,
    String host = posthogHost,
    TelemetrySink? sink,
  })  : _apiKey = apiKey,
        _sink = sink {
    if (_apiKey.isEmpty) {
      AppLogger.instance.info(
        'Telemetry stub mode: no POSTHOG_API_KEY dart-define — analytics '
        'disabled (I-68 foundation; posthog_flutter wiring lands later).',
      );
    }
  }

  final String _apiKey;
  final TelemetrySink? _sink;

  /// True only when a `POSTHOG_API_KEY` dart-define was provided at build
  /// time. `POSTHOG_HOST` is required for the SDK init but does not gate
  /// the service.
  bool get isEnabled => _apiKey.isNotEmpty;

  /// Records [event] with optional [properties] (PII-sanitized first).
  ///
  /// Stub mode: logs the event name via [AppLogger.info] (level gated in
  /// release — never reaches the log file in a release build).
  void track(String event, {Map<String, dynamic>? properties}) {
    if (!_enabledWithSink()) {
      AppLogger.instance.info(
        'Telemetry (stub): track("$event") skipped — no POSTHOG_API_KEY '
        'dart-define.',
      );
      return;
    }
    _sink!.track(event, sanitizeProperties(properties ?? const {}));
  }

  /// Associates the current session with [userId] (no-op when disabled or
  /// when [userId] is null/empty).
  void identify(String? userId) {
    if (!_enabledWithSink()) return;
    if (userId == null || userId.isEmpty) return;
    _sink!.identify(userId);
  }

  /// Clears the user association (sign-out / account switch; no-op when
  /// disabled).
  void reset() {
    if (!_enabledWithSink()) return;
    _sink!.reset();
  }

  /// Enabled AND a sink is present — the real driver exists. An enabled
  /// build without a sink (SDK wiring pending) degrades to the stub log.
  bool _enabledWithSink() => isEnabled && _sink != null;
}

/// The app-wide telemetry service. Tests override the whole provider (e.g.
/// with an enabled service backed by a recording sink) — nothing else in the
/// app may construct a service directly.
final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return TelemetryService();
});
