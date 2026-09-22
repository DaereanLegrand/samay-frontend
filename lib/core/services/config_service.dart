import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/rest_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads app-level configuration from the `app_config` table.
///
/// Injectable: constructed with an explicit client.
///
/// Migrated to [RestClient]: all table access goes through the typed
/// envelope; the `client` field remains for the auth accessor and
/// compatibility call sites until the facade deletion.
class ConfigService {
  final SupabaseClient client;
  final RestClient rest;

  ConfigService({required this.client}) : rest = RestClient(client: client);

  /// Loads every `app_config` row as a flat `key -> value` map.
  Future<Map<String, String>> fetchAppConfig() async {
    final rows = await rest.list<Map<String, dynamic>>(
      'app_config',
      fromJson: (row) => row,
      select: 'key, value',
    );
    final map = <String, String>{};
    for (final row in rows) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }

  /// Number of shards granted at signup (`economy.user_signup_shards`),
  /// falling back to the hardcoded default of 256 when the config is
  /// unavailable.
  Future<int> getSignupShardGrant() async {
    try {
      final config = await fetchAppConfig();
      return int.parse(config['economy.user_signup_shards'] ?? '256');
    } catch (e, st) {
      AppLogger.instance.error('getSignupShardGrant error: $e', '$st');
      return 256;
    }
  }
}
