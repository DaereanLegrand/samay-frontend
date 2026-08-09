import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/config_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shard economy: group donations, contributions, cosmetics and leaderboards.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11).
class ShardsService {
  final SupabaseClient client;
  final ConfigService config;

  ShardsService({required this.client, required this.config});

  GoTrueClient get auth => client.auth;

  Future<void> donateToGroup(String groupId, int amount) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final userRes = await client.from('users').select('personal_shards').eq('id', user.id).single();
    final currentShards = userRes['personal_shards'] as int;
    if (currentShards < amount) throw Exception('No tienes suficientes shards');

    final appConfig = await config.fetchAppConfig();
    final boostDays = int.parse(appConfig['economy.group_shard_boost_days'] ?? '14');
    final now = DateTime.now();

    await client.rpc('donate_shards_to_group', params: {
      'p_group_id': groupId,
      'p_user_id': user.id,
      'p_amount': amount,
      'p_expires_at': now.add(Duration(days: boostDays)).toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getGroupContributions(String groupId) async {
    final res = await client
        .from('group_shard_contributions')
        .select('id, user_id, shards_contributed, users!inner(username)')
        .eq('group_id', groupId)
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('shards_contributed', ascending: false);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<int> getUserContributionToGroup(String groupId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('group_shard_contributions')
        .select('shards_contributed')
        .eq('group_id', groupId)
        .eq('user_id', user.id)
        .gt('expires_at', DateTime.now().toIso8601String());
    int total = 0;
    for (final row in res) {
      total += row['shards_contributed'] as int;
    }
    return total;
  }

  Future<void> purchaseCosmetic(String cosmeticId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final cosmetic = await client.from('cosmetics').select('shard_cost').eq('id', cosmeticId).single();
    final cost = cosmetic['shard_cost'] as int;

    final userData = await client.from('users').select('personal_shards').eq('id', user.id).single();
    final shards = userData['personal_shards'] as int;
    if (shards < cost) throw Exception('No tienes suficientes shards');

    await client.from('user_cosmetics').insert({
      'user_id': user.id,
      'cosmetic_id': cosmeticId,
      'equipped': false,
      'purchased_at': DateTime.now().toIso8601String(),
    });

    await client.from('shard_ledger').insert({
      'user_id': user.id,
      'delta': -cost,
      'reason': 'cosmetic_purchase',
      'reference_id': cosmeticId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getLeaderboard(String sizeTier) async {
    final res = await client
        .from('group_rank_snapshots')
        .select('group_id, rank_position, score, member_count')
        .eq('size_tier', sizeTier)
        .order('rank_position', ascending: true)
        .limit(100);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
