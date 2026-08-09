import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:samay/app.dart';
import 'package:samay/core/config/env_config.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/secure_session_storage.dart';
import 'package:samay/core/services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.instance.init();

  FlutterError.onError = (details) {
    final level = AppLogger.instance.knownBenignError(details.exception);
    if (level != null) {
      AppLogger.instance.log(level, 'Flutter error: ${details.exception}');
      return;
    }
    final message = 'Flutter error: ${details.exception}';
    final stack = details.stack?.toString() ?? '';
    AppLogger.instance.error(message, stack);
    unawaited(AppLogger.instance.markCrash(message, stack));
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final level = AppLogger.instance.knownBenignError(error);
    if (level != null) {
      AppLogger.instance.log(level, 'Unhandled error: $error');
      return true;
    }
    final message = 'Unhandled error: $error';
    AppLogger.instance.error(message, stack.toString());
    unawaited(AppLogger.instance.markCrash(message, stack.toString()));
    return true;
  };

  final recovered = await AppLogger.instance.recoverCrashMarker();
  if (recovered != null) {
    AppLogger.instance.warn('Recovered from a previous crash:\n$recovered');
    // TODO(LOG-03): recovery UI ("Vive recovered from a previous crash"
    // banner/dialog) is future work.
  }

  // SEC-10 / M-32 (I-26): encrypted Hive caches (config, photo URLs,
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
    // SEC-11 / M-33 (I-25): persist the session (access JWT + refresh token)
    // and the PKCE code verifier in flutter_secure_storage (iOS Keychain /
    // Android Keystore) instead of the SDK's in-memory/shared-preferences
    // default. detectSessionInUri: false — deep-link session recovery is not
    // used on mobile (invite links are handled by the router, I-66).
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(),
      pkceAsyncStorage: SecurePkceStorage(),
      detectSessionInUri: false,
      // SEC-04 / H-22 (I-30): explicit PKCE — the code verifier is persisted
      // by SecurePkceStorage above (the SDK default is already pkce, but
      // pinning it makes the flow explicit and immune to default drift).
      authFlowType: AuthFlowType.pkce,
    ),
  );
  runApp(const ProviderScope(child: SamayApp()));
}
