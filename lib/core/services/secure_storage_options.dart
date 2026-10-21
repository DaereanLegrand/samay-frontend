import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:samay/core/logging/app_logger.dart';

/// iOS keychain accessibility used by every Samay secret:
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (SEC-033).
///
/// `first_unlock_this_device` keeps the item readable while the device is
/// locked (required by the push background isolate, which decides whether an
/// authenticated session exists) but never migrates it to another device via
/// an encrypted backup.
const IOSOptions samayIosOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

/// Android backend used by every Samay secret: `EncryptedSharedPreferences`
/// (AES-256-SIV keys / AES-256-GCM values wrapped by the Keystore). The
/// plugin migrates legacy plain preferences automatically the first time the
/// encrypted store is opened.
const AndroidOptions samayAndroidOptions = AndroidOptions(
  encryptedSharedPreferences: true,
);

/// The app-wide secure storage instance. Every caller must use this (or the
/// same options) instead of `const FlutterSecureStorage()` so keychain
/// accessibility and the Android backend stay consistent.
FlutterSecureStorage samaySecureStorage() => const FlutterSecureStorage(
  iOptions: samayIosOptions,
  aOptions: samayAndroidOptions,
);

/// Storage key marking the one-time SEC-033 accessibility migration done.
const String samaySecureMigrationKey = 'samay.secure.migration.sec033';

/// One-time migration for installs that wrote secrets with the plugin's
/// default iOS accessibility (`unlocked`) and/or the legacy Android
/// preferences backend.
///
/// Android: `EncryptedSharedPreferences` migrates the legacy file on its own
/// (the plugin's `checkAndMigrateToEncrypted`), so re-writing is a no-op.
/// iOS: rewriting each existing key under [samayIosOptions] updates its
/// `kSecAttrAccessible` attribute in place. Best-effort: a failure leaves the
/// marker unset so the next boot retries, and never blocks startup.
Future<void> migrateSamaySecureStorage() async {
  final current = samaySecureStorage();
  try {
    if (await current.read(key: samaySecureMigrationKey) == '1') return;
  } catch (e, st) {
    AppLogger.instance.warn(
      'secure storage migration probe failed: $e',
      '$st',
    );
    return;
  }

  // Legacy instance: the plugin defaults (iOS `unlocked`, Android plain
  // SharedPreferences). Reading is safe; writing under `current` below
  // upgrades the item in place.
  const legacy = FlutterSecureStorage();
  Map<String, String> existing;
  try {
    existing = await legacy.readAll();
  } catch (e, st) {
    AppLogger.instance.warn(
      'secure storage migration read failed: $e',
      '$st',
    );
    return;
  }

  var failed = false;
  for (final entry in existing.entries) {
    if (entry.key == samaySecureMigrationKey) continue;
    try {
      await current.write(key: entry.key, value: entry.value);
    } catch (e, st) {
      failed = true;
      AppLogger.instance.warn(
        'secure storage migration write failed for ${entry.key}: $e',
        '$st',
      );
    }
  }
  if (failed) return;
  try {
    await current.write(key: samaySecureMigrationKey, value: '1');
  } catch (e, st) {
    AppLogger.instance.warn(
      'secure storage migration marker failed: $e',
      '$st',
    );
  }
}
