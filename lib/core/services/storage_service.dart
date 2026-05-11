import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  Future<void> storeToken(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> retrieveToken(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> deleteToken(String key) async {
    await _storage.delete(key: key);
  }
}

class HiveService {
  static const _configBox = 'config_cache';
  static const _photoBox = 'photo_cache';
  static const _messageBox = 'message_cache';
  static const _notificationBox = 'notification_cache';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_configBox);
    await Hive.openBox<String>(_photoBox);
    await Hive.openBox<String>(_messageBox);
    await Hive.openBox<String>(_notificationBox);
  }

  Future<void> cacheConfig(Map<String, String> config) async {
    final box = Hive.box<String>(_configBox);
    await box.putAll(config);
  }

  Map<String, String>? getCachedConfig() {
    final box = Hive.box<String>(_configBox);
    if (box.isEmpty) return null;
    return box.toMap().map((k, v) => MapEntry(k, v));
  }
}
