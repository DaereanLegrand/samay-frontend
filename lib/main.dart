import 'dart:async';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:samay/app.dart';
import 'package:samay/core/config/env_config.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/deep_links/deep_link_handler.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/crash_reporter.dart';
import 'package:samay/core/services/push_service.dart';
import 'package:samay/core/services/revenuecat_service.dart';
import 'package:samay/core/services/secure_session_storage.dart';
import 'package:samay/core/services/storage_service.dart';

/// Global Flutter error handler.
///
/// Order is deliberate: benign errors are
/// downgraded via [AppLogger.knownBenignError] and return early (never reach
/// the reporter); real errors are logged via [AppLogger.error], recorded with
/// [AppLogger.markCrash], then reported fire-and-forget to [reporter]
///, and finally presented via
/// [FlutterError.presentError]. Extracted as a top-level function so the
/// wiring is directly testable with an injected reporter.
void handleFlutterError(FlutterErrorDetails details, CrashReporter reporter) {
  final level = AppLogger.instance.knownBenignError(details.exception);
  if (level != null) {
    AppLogger.instance.log(level, 'Flutter error: ${details.exception}');
    return;
  }
  final message = 'Flutter error: ${details.exception}';
  final stack = details.stack?.toString() ?? '';
  AppLogger.instance.error(message, stack);
  unawaited(AppLogger.instance.markCrash(message, stack));
  unawaited(
    reporter.reportError(
      details.exception,
      details.stack ?? StackTrace.current,
      context: const {'handler': 'flutterError'},
    ),
  );
  FlutterError.presentError(details);
}

/// Global platform/async error handler.
///
/// Same deliberate order as [handleFlutterError]: benign errors downgrade
/// and return `true` early; real errors log, crash-mark, then report
/// fire-and-forget to [reporter], and `return true` keeps the app running.
/// Extracted as a top-level function so the wiring is directly testable
/// with an injected reporter.
bool handlePlatformError(
  Object error,
  StackTrace stack,
  CrashReporter reporter,
) {
  final level = AppLogger.instance.knownBenignError(error);
  if (level != null) {
    AppLogger.instance.log(level, 'Unhandled error: $error');
    return true;
  }
  final message = 'Unhandled error: $error';
  AppLogger.instance.error(message, stack.toString());
  unawaited(AppLogger.instance.markCrash(message, stack.toString()));
  unawaited(
    reporter.reportError(error, stack, context: const {'handler': 'platform'}),
  );
  return true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.instance.init();

  // one reporter instance for the app's lifetime; stub mode (no
  // SENTRY_DSN dart-define) keeps reportError a logged no-op.
  final crashReporter = CrashReporter();
  FlutterError.onError = (details) =>
      handleFlutterError(details, crashReporter);

  PlatformDispatcher.instance.onError = (error, stack) =>
      handlePlatformError(error, stack, crashReporter);

  final recovered = await AppLogger.instance.recoverCrashMarker();
  if (recovered != null) {
    AppLogger.instance.warn('Recovered from a previous crash:\n$recovered');
  }

  // encrypted Hive caches (config, photo URLs,
  // messages, notifications). Init before Supabase so the config cache is
  // ready for first reads. The caches are disposable — any init failure
  // (e.g. missing platform plugins in exotic environments) must degrade to
  // "no local caches", never block boot.
  try {
    await HiveService().init();
  } catch (e, st) {
    AppLogger.instance.warn(
      'Hive cache init failed; app continues without local caches: $e',
      '$st',
    );
  }

  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
    // persist the session (access JWT + refresh token)
    // and the PKCE code verifier in flutter_secure_storage (iOS Keychain /
    // Android Keystore) instead of the SDK's in-memory/shared-preferences
    // default. detectSessionInUri: false — deep-link session recovery is not
    // used on mobile.
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(),
      pkceAsyncStorage: SecurePkceStorage(),
      detectSessionInUri: false,
      // explicit PKCE — the code verifier is persisted
      // by SecurePkceStorage above (the SDK default is already pkce, but
      // pinning it makes the flow explicit and immune to default drift).
      authFlowType: AuthFlowType.pkce,
    ),
  );
  // RevenueCat (RSDK): configure the SDK only when the build carries a public
  // SDK key for this platform (vault-fetched via `RC=true`, passed as
  // --dart-define=REVENUECAT_PUBLIC_SDK_KEY_APPLE|_GOOGLE, or
  // REVENUECAT_TEST_STORE_KEY in debug). Without one the app stays in stub
  // mode (no store calls). `logIn(<supabase uid>)` sets RevenueCat's
  // app_user_id to the Supabase user, so the `revenuecat-webhook` can resolve
  // the account; `logOut` on sign-out. Any failure degrades to no RC — never
  // blocks boot.
  final rcKey = revenueCatPublicSdkKey();
  try {
    if (rcKey.isNotEmpty) {
      await rc.Purchases.configure(rc.PurchasesConfiguration(rcKey));
      final auth = Supabase.instance.client.auth;
      Future<void> syncRevenueCatUser(Session? session) async {
        try {
          if (session != null) {
            await rc.Purchases.logIn(session.user.id);
          } else {
            await rc.Purchases.logOut();
          }
        } catch (e) {
          AppLogger.instance.warn('RevenueCat logIn/logOut failed: $e');
        }
      }

      auth.onAuthStateChange.listen(
        (data) => unawaited(syncRevenueCatUser(data.session)),
      );
      await syncRevenueCatUser(auth.currentSession);
    }
  } catch (e) {
    AppLogger.instance.warn('RevenueCat configure skipped: $e');
  }

  // EINV: wire the app_links platform stream into the deep-link seam.
  // `AppLinks()` is touched here (before runApp) so the cold-start link is
  // captured: `uriLinkStream` delivers the initial link exactly once
  // (Android's native `initialLinkSent` guard) plus every later link, and
  // `DeepLinkListener` (mounted in SamayApp) forwards each to the handler.
  // Platform config (Android intent-filter / iOS Associated Domains) is
  // work — see DEPLOYMENT-PLACEHOLDER.md R01 (`app.samay.example.com`).
  final container = ProviderContainer(
    overrides: [
      deepLinkStreamProvider.overrideWithValue(
        AppLinks().uriLinkStream.map((uri) => uri.toString()),
      ),
      // Subscriptions turn on iff this build carries a RevenueCat key (any
      // env/platform); push turns on in debug only (the debug keystore SHA-1 is
      // registered on the Android API key). Release without an RC key stays
      // dark (subscriptions = false).
      featureFlagsProvider.overrideWithValue(
        AppFeatureFlags(
          push: kDebugMode &&
              !const bool.fromEnvironment('SAMAY_TEST_NO_PUSH'),
          subscriptions: rcKey.isNotEmpty,
        ),
      ),
    ],
  );
  // Push (Track 2, dark-first): initialise only when AppFeatureFlag.push is
  // enabled, so a config-less build never prompts for notification permission
  // or hard-fails. PushService degrades to a logged no-op on any error.
  if (container.read(featureFlagsProvider).isEnabled(AppFeatureFlag.push)) {
    await container.read(pushServiceProvider).initialize();
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      // LOG-03: a recovered crash marker surfaces as the dismissible
      // recovery banner (CrashRecoveryBanner inside SamayApp's builder).
      child: SamayApp(recoveredFromCrash: recovered != null),
    ),
  );
}
