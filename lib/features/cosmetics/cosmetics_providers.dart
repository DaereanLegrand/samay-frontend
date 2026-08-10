import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/shards_service.dart';
import 'package:samay/features/profile/profile_providers.dart';

/// Failure kinds for a cosmetic purchase, mapped to friendly localized
/// messages by the shop screen (I-62 — COSM purchase flow error mapping).
enum CosmeticPurchaseFailure { insufficientShards, tierRequirement }

/// Typed purchase error so the UI never pattern-matches raw exception
/// strings. Thrown by [MyCosmeticsNotifier.purchase] after translating the
/// service's typed guards.
class CosmeticPurchaseException implements Exception {
  const CosmeticPurchaseException(this.failure);

  final CosmeticPurchaseFailure failure;
}

/// Whether the catalog item's `tier_requirement` exceeds the user's tier
/// (`free < pro < vip` — same rank table as the service guard).
bool isCosmeticLocked(Map<String, dynamic> item, String userTier) {
  final required = item['tier_requirement'] as String? ?? 'free';
  return tierRank(required) > tierRank(userTier);
}

/// Catalog items are filtered into the three personal tabs (Marcos/Fondos/
/// Insignias); `group_cover`/`group_badge` are bought via the group voting
/// flow (GCOS, not part of the personal shop).
String cosmeticsTypeOf(Map<String, dynamic> item) =>
    item['type'] as String? ?? '';

class CosmeticsCatalogNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  ShardsService get _shards => ref.read(shardsServiceProvider);

  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _shards.listCosmetics();
  }

  /// Re-runs [build] (pull-to-refresh, finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// The public cosmetics catalog (`cosmetics_read_all` RLS), cheapest first.
final cosmeticsCatalogProvider =
    AsyncNotifierProvider<CosmeticsCatalogNotifier, List<Map<String, dynamic>>>(
      CosmeticsCatalogNotifier.new,
    );

class MyCosmeticsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  ShardsService get _shards => ref.read(shardsServiceProvider);

  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _shards.getMyCosmetics();
  }

  /// Re-runs [build] after equip/purchase mutations.
  Future<void> refresh() async => ref.invalidateSelf();

  /// Purchases [cosmeticId] (COSM flow: `purchaseCosmetic` deducts +
  /// `shard_ledger` + `user_cosmetics`), then refreshes the catalog, the
  /// owned set and the profile balance so the shop reflects the new state.
  Future<void> purchase(String cosmeticId) async {
    try {
      await _shards.purchaseCosmetic(cosmeticId);
    } on InsufficientShardsException {
      throw const CosmeticPurchaseException(
        CosmeticPurchaseFailure.insufficientShards,
      );
    } on TierRequirementException {
      throw const CosmeticPurchaseException(
        CosmeticPurchaseFailure.tierRequirement,
      );
    }
    await Future.wait([
      ref.read(cosmeticsCatalogProvider.notifier).refresh(),
      ref.read(myCosmeticsProvider.notifier).refresh(),
      ref.read(myProfileProvider.notifier).refresh(),
    ]);
  }

  /// Equips/unequips one owned cosmetic (auto-unequips same type when
  /// equipping — one equipped per type per COSM spec).
  Future<void> setEquipped(String userCosmeticId, bool equipped) async {
    await _shards.setCosmeticEquipped(userCosmeticId, equipped);
    await refresh();
  }
}

/// The current user's owned cosmetics (`user_cosmetics_read_own` RLS).
final myCosmeticsProvider =
    AsyncNotifierProvider<MyCosmeticsNotifier, List<Map<String, dynamic>>>(
      MyCosmeticsNotifier.new,
    );
