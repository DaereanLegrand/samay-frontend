import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/models/ledger_entry.dart';
import 'package:samay/core/services/config_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when [ShardsService.purchaseCosmetic] finds the user's
/// `personal_shards` below the item's `shard_cost`. Typed so the cosmetics
/// feature maps it to a friendly localized message.
class InsufficientShardsException implements Exception {
  const InsufficientShardsException({
    required this.required,
    required this.balance,
  });

  final int required;
  final int balance;
}

/// Thrown when [ShardsService.purchaseCosmetic] finds the user's
/// `subscription_tier` below the item's `tier_requirement` (COSM spec step 2).
class TierRequirementException implements Exception {
  const TierRequirementException();
}

/// Rank for `subscription_tier` / `tier_requirement` comparisons:
/// `free < pro < vip`. Shared by the service guard and the shop's lock UI.
int tierRank(String tier) => switch (tier) {
  'vip' => 2,
  'pro' => 1,
  _ => 0,
};

/// Shard economy: group donations, contributions, cosmetics and leaderboards.
class ShardsService {
  final SupabaseClient client;
  final ConfigService config;

  ShardsService({required this.client, required this.config});

  GoTrueClient get auth => client.auth;

  Future<void> donateToGroup(String groupId, int amount) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final userRes = await client
        .from('users')
        .select('personal_shards')
        .eq('id', user.id)
        .single();
    final currentShards = userRes['personal_shards'] as int;
    if (currentShards < amount) {
      throw ConflictError(
        'No tienes suficientes shards',
        code: 'insufficient_shards',
      );
    }

    final appConfig = await config.fetchAppConfig();
    final boostDays = int.parse(
      appConfig['economy.group_shard_boost_days'] ?? '14',
    );
    final now = DateTime.now();

    await client.rpc(
      'donate_shards_to_group',
      params: {
        'p_group_id': groupId,
        'p_user_id': user.id,
        'p_amount': amount,
        'p_expires_at': now.add(Duration(days: boostDays)).toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getGroupContributions(
    String groupId,
  ) async {
    final res = await client
        .from('group_shard_contributions')
        // Join through the security-barrier user_search_view — the
        // raw `users` join is own-row-only under RLS, so contributor rows of
        // co-members silently vanished from the leaderboard/contributors.
        // `avatar_url` rides along (20260815000001) so the contributors
        // section renders the co-member's photo.
        .select(
          'id, user_id, shards_contributed, '
          'users:user_search_view!inner(username, avatar_url)',
        )
        .eq('group_id', groupId)
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('shards_contributed', ascending: false);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// The current user's shard movement history (SLED spec — `sl_read_own`
  /// RLS), newest first. Immutable rows: [LedgerEntry] is a read-only
  /// display projection, never written back.
  Future<List<LedgerEntry>> getShardLedger({int limit = 100}) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client
        .from('shard_ledger')
        .select('id, delta, reason, reference_id, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final row in res) LedgerEntry.fromJson(row)];
  }

  /// The current user's preshard movement history (SLED spec — `pl_read_own`
  /// RLS), newest first. Same immutable shape as [getShardLedger] — preshards
  /// never convert to `personal_shards` (economy firewall).
  Future<List<LedgerEntry>> getPreshardLedger({int limit = 100}) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client
        .from('preshard_ledger')
        .select('id, delta, reason, reference_id, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final row in res) LedgerEntry.fromJson(row)];
  }

  Future<int> getUserContributionToGroup(String groupId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
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
    if (user == null) throw const UnauthorizedError();

    final cosmetic = await client
        .from('cosmetics')
        .select('shard_cost, tier_requirement')
        .eq('id', cosmeticId)
        .single();
    final cost = cosmetic['shard_cost'] as int;
    final requiredTier = cosmetic['tier_requirement'] as String? ?? 'free';

    final userData = await client
        .from('users')
        .select('personal_shards, subscription_tier')
        .eq('id', user.id)
        .single();
    final shards = userData['personal_shards'] as int;
    if (shards < cost) {
      throw InsufficientShardsException(required: cost, balance: shards);
    }
    final userTier = userData['subscription_tier'] as String? ?? 'free';
    if (tierRank(requiredTier) > tierRank(userTier)) {
      throw const TierRequirementException();
    }

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

  /// The public cosmetics catalog (COSM spec; `cosmetics_read_all` RLS).
  Future<List<Map<String, dynamic>>> listCosmetics() async {
    final res = await client
        .from('cosmetics')
        .select('id, name, type, asset_url, shard_cost, tier_requirement')
        .order('shard_cost', ascending: true);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// The current user's ownership rows (`user_cosmetics_read_own` RLS),
  /// each joined with its cosmetic (type/name/cost — the shop needs them to
  /// render owned/equipped state without a second lookup).
  Future<List<Map<String, dynamic>>> getMyCosmetics() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client
        .from('user_cosmetics')
        .select(
          'id, cosmetic_id, equipped, purchased_at, '
          'cosmetics!inner(id, name, type, asset_url, shard_cost, '
          'tier_requirement)',
        )
        .eq('user_id', user.id)
        .order('purchased_at', ascending: true);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Equips/unequips one owned cosmetic (`user_cosmetics_update_own` RLS —
  /// own rows only). Equipping auto-unequips the other owned items of the
  /// same type (COSM spec "one equipped per type").
  Future<void> setCosmeticEquipped(String userCosmeticId, bool equipped) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    if (equipped) {
      final target = await client
          .from('user_cosmetics')
          .select('cosmetic_id, cosmetics!inner(type)')
          .eq('id', userCosmeticId)
          .eq('user_id', user.id)
          .single();
      final type = (target['cosmetics'] as Map)['type'] as String;

      final mine = await client
          .from('user_cosmetics')
          .select('id, cosmetics!inner(type)')
          .eq('user_id', user.id);
      for (final row in mine) {
        final otherType = (row['cosmetics'] as Map)['type'] as String;
        if (row['id'] != userCosmeticId && otherType == type) {
          await client
              .from('user_cosmetics')
              .update({'equipped': false})
              .eq('id', row['id'] as String);
        }
      }
    }

    await client
        .from('user_cosmetics')
        .update({'equipped': equipped})
        .eq('id', userCosmeticId)
        .eq('user_id', user.id);
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
