import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/connectivity_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/storage_service.dart';

/// App-level configuration from the `app_config` table, with an encrypted
/// local cache (H-09 refresh migration + STOR offline fallback, I-71).
///
/// Every successful fetch is written through to the encrypted Hive
/// `config_cache` box (I-26) — fire-and-forget, write failures are logged,
/// never surfaced. When a fetch fails while the device is offline
/// ([connectivityProvider] false — the I-67 handoff) and the cache holds a
/// config, the cached copy is served instead of the error. Server errors
/// while online are NEVER masked by the cache.
final appConfigProvider = AsyncNotifierProvider<AppConfigNotifier,
    Map<String, String>>(AppConfigNotifier.new);

class AppConfigNotifier extends AsyncNotifier<Map<String, String>> {
  HiveService get _hive => ref.read(hiveServiceProvider);

  /// Manual refresh seam (H-09): re-runs [build] — fresh fetch, cache
  /// write-through on success, offline fallback on failure.
  Future<void> refresh() async => ref.invalidateSelf();

  @override
  Future<Map<String, String>> build() async {
    // Watching connectivity re-runs this build on every online/offline
    // transition: going offline swaps in the cache, coming back online
    // re-fetches. Loading/error states are treated as online (I-67
    // fail-open: `valueOrNull ?? true`) so the cache never masks a server
    // error while connectivity is unknown.
    final offline = ref.watch(connectivityProvider).valueOrNull == false;
    try {
      final config = await ref.watch(configServiceProvider).fetchAppConfig();
      unawaited(_cacheConfig(config));
      return config;
    } catch (e, st) {
      if (offline) {
        final cached = _cachedConfig();
        if (cached != null) return cached;
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  /// Reads the encrypted cache, treating uninitialized/re-created Hive
  /// (I-26 key-loss degradation) as a miss — never a thrown error.
  Map<String, String>? _cachedConfig() {
    try {
      final cached = _hive.getCachedConfig();
      return (cached == null || cached.isEmpty) ? null : cached;
    } catch (e, st) {
      AppLogger.instance.warn('Config cache unreadable: $e', '$st');
      return null;
    }
  }

  /// Fire-and-forget write-through: a cache failure must never fail the
  /// fetch the provider already succeeded on.
  Future<void> _cacheConfig(Map<String, String> config) async {
    try {
      await _hive.cacheConfig(config);
    } catch (e, st) {
      AppLogger.instance.warn('Config cache write failed: $e', '$st');
    }
  }
}
