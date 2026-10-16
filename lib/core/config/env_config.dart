/// Build-time environment configuration.
///
/// Supabase values are injected at compile time via `--dart-define` (or
/// `--dart-define-from-file=.env`, see Makefile) and read with
/// `String.fromEnvironment` — nothing is bundled as a Flutter asset anymore.
///
/// Keys are only defined when passed to the compiler: the raw const getters
/// resolve to `''` otherwise, and the validated getters convert that into a
/// fail-fast [StateError] so a misconfigured build dies at startup instead of
/// shipping against an empty URL (same behavior as the previous runtime
/// .env loader's missing-var path).
class EnvConfig {
  EnvConfig._();

  /// Raw compile-time value of `--dart-define=SUPABASE_URL=...` (`''` when
  /// not provided — the `defaultValue` is baked in at compile time).
  static const String supabaseUrlRaw = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Raw compile-time value of `--dart-define=SUPABASE_ANON_KEY=...`.
  static const String supabaseAnonKeyRaw = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Raw compile-time value of `--dart-define=APP_ENV=...` (`dev` when not
  /// provided). Values: `dev` | `staging` | `prod` (the Makefile `ENV`).
  static const String appEnvRaw = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// The build's environment tag. `prod` is the only value that makes the
  /// paywall show custom `app_config` prices; every other value shows the
  /// localized RevenueCat product price.
  static String get appEnv => appEnvRaw;

  /// Whether this is a production build (custom pricing, no RC price).
  static bool get isProd => appEnv == 'prod';

  /// Supabase REST API base URL (anon JWT).
  static String get supabaseUrl => validate(supabaseUrlRaw, 'SUPABASE_URL');

  /// Supabase publishable anon key (safe to ship by design — it cannot
  /// bypass RLS).
  static String get supabaseAnonKey =>
      validate(supabaseAnonKeyRaw, 'SUPABASE_ANON_KEY');

  /// Pure validation seam (unit-tested in `test/core/env_config_test.dart`):
  /// returns [url] when non-blank, otherwise throws a [StateError] naming
  /// [key]. Public so the missing-var behavior is testable without a
  /// compile-time define.
  static String validate(String url, String key) {
    if (url.trim().isEmpty) {
      throw StateError('Missing required env variable: $key');
    }
    return url;
  }
}
