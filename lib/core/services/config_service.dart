import 'package:samay/core/logging/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads app-level configuration from the `app_config` table.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11). Injectable: constructed with an explicit client
/// so tests can substitute a mock.
class ConfigService {
  final SupabaseClient client;

  ConfigService({required this.client});

  /// Loads every `app_config` row as a flat `key -> value` map.
  Future<Map<String, String>> fetchAppConfig() async {
    final res = await client.from('app_config').select('key, value');
    final map = <String, String>{};
    for (final row in res) {
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
