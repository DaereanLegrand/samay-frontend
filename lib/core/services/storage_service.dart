class SecureStorageService {
  Future<void> storeToken(String key, String value) async {
    throw UnimplementedError('storeToken');
  }

  Future<String?> retrieveToken(String key) async {
    throw UnimplementedError('retrieveToken');
  }

  Future<void> deleteToken(String key) async {
    throw UnimplementedError('deleteToken');
  }
}

class HiveService {
  Future<void> init() async {
    throw UnimplementedError('HiveService.init');
  }

  Future<void> cacheConfig(Map<String, String> config) async {
    throw UnimplementedError('cacheConfig');
  }

  Future<Map<String, String>?> getCachedConfig() async {
    throw UnimplementedError('getCachedConfig');
  }
}
