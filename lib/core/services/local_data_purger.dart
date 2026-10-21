import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/local_notifications_service.dart';
import 'package:samay/core/services/storage_service.dart';

/// Removes every account-scoped artifact a previous session left on the
/// device: encrypted Hive caches (messages, notifications, photo URLs,
/// friends, feed, minigame summaries, config/prefs), the network-image disk
/// cache and the in-memory image cache, and posted generic notifications
/// (SEC-033).
///
/// Called on logout/account switch and by the explicit "Borrar datos
/// locales" action. Best-effort throughout: a failing cache must never block
/// the auth transition.
class LocalDataPurger {
  LocalDataPurger({HiveService? hive}) : _hive = hive ?? HiveService();

  final HiveService _hive;

  Future<void> purge() async {
    await _purgeHive();
    await _purgeImages();
    await LocalNotificationsService.instance.cancelAll();
  }

  Future<void> _purgeHive() async {
    try {
      await _hive.purgeAll();
    } catch (e, st) {
      AppLogger.instance.warn('local Hive purge failed: $e', '$st');
    }
  }

  Future<void> _purgeImages() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (e, st) {
      AppLogger.instance.warn('network image cache purge failed: $e', '$st');
    }
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e, st) {
      AppLogger.instance.warn('in-memory image cache purge failed: $e', '$st');
    }
  }
}
