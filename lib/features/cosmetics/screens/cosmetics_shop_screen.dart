import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/features/cosmetics/providers/cosmetics_providers.dart';
import 'package:samay/features/profile/providers/profile_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

/// LUXE v2 family for this screen — **violet** (the LUXE restyle pass (historical) map:
/// cosmetics → violet).
final AppGradient _family = AppGradients.familyOf('cosmetics');

/// The personal cosmetics shop (COSM spec): catalog grid over the three
/// personal categories (Marcos/Fondos/Insignias), shard-only purchases with a
/// confirm dialog, and equip/unequip for owned items (one equipped per type).
///
/// LUXE v2: violet liquid-glass cards with the equipped state in the violet
/// family (accent badge + stronger glow); the gold shard icon is the
/// currency accent (§5.6).
class CosmeticsShopScreen extends ConsumerStatefulWidget {
  const CosmeticsShopScreen({super.key});

  @override
  ConsumerState<CosmeticsShopScreen> createState() =>
      _CosmeticsShopScreenState();
}

class _CosmeticsShopScreenState extends ConsumerState<CosmeticsShopScreen>
    with SingleTickerProviderStateMixin {
  /// Selected personal category; the catalog is filtered by cosmetic type.
  late final TabController _tabController;

  /// The user_cosmetics row currently being bought/equipped (button spinner).
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTypes.length, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// [cosmetic_type] values shown per tab, in the COSM tab order. Group types
  /// (group_cover/group_badge) are bought via the GCOS voting flow, not here.
  static const _tabTypes = ['avatar_frame', 'profile_bg', 'badge'];

  String _tabLabel(AppLocalizations l10n, int index) =>
      switch (_tabTypes[index]) {
        'avatar_frame' => l10n.cosmeticsTabFrames,
        'profile_bg' => l10n.cosmeticsTabBackgrounds,
        _ => l10n.cosmeticsTabBadges,
      };

  String _typeLabel(AppLocalizations l10n, String type) => switch (type) {
    'avatar_frame' => l10n.cosmeticsTabFrames,
    'profile_bg' => l10n.cosmeticsTabBackgrounds,
    'badge' => l10n.cosmeticsTabBadges,
    _ => type,
  };

  String _tierLabel(AppLocalizations l10n, String tier) => switch (tier) {
    'vip' => l10n.cosmeticsTierVip,
    'pro' => l10n.cosmeticsTierPro,
    _ => l10n.cosmeticsTierFree,
  };

  Future<void> _confirmPurchase(Map<String, dynamic> item) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.cosmeticsPurchaseTitle),
        content: Text(
          l10n.cosmeticsPurchaseConfirm(
            item['name']?.toString() ?? '',
            (item['shard_cost'] as num?)?.toInt() ?? 0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.cosmeticsBuy),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _purchase(item);
  }

  Future<void> _purchase(Map<String, dynamic> item) async {
    final l10n = AppLocalizations.of(context);
    final id = item['id'] as String;
    setState(() => _busyId = id);
    try {
      await ref.read(myCosmeticsProvider.notifier).purchase(id);
      _showMessage(l10n.cosmeticsPurchaseSuccess);
    } on CosmeticPurchaseException catch (e) {
      _showMessage(_purchaseFailureMessage(l10n, e.failure));
    } catch (e) {
      _showMessage(e.toAppError().message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _purchaseFailureMessage(
    AppLocalizations l10n,
    CosmeticPurchaseFailure failure,
  ) {
    return switch (failure) {
      CosmeticPurchaseFailure.insufficientShards =>
        l10n.errorsInsufficientShards,
      CosmeticPurchaseFailure.tierRequirement => l10n.cosmeticsTierRequired,
    };
  }

  Future<void> _toggleEquipped(Map<String, dynamic> owned) async {
    final id = owned['id'] as String;
    final equipped = owned['equipped'] as bool? ?? false;
    setState(() => _busyId = id);
    try {
      await ref.read(myCosmeticsProvider.notifier).setEquipped(id, !equipped);
    } catch (e) {
      _showMessage(e.toAppError().message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalogAsync = ref.watch(cosmeticsCatalogProvider);
    final ownedAsync = ref.watch(myCosmeticsProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final personalShards = (profile?['personal_shards'] as num?)?.toInt() ?? 0;
    final userTier = profile?['subscription_tier']?.toString() ?? 'free';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cosmeticsShopTitle)),
      body: Column(
        children: [
          _BalanceBar(shards: personalShards),
          Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AppColors.white,
                // §2.4: unselected tab labels are informational text at
                // normal size — muted #666666 fails 1.4.3 (3.66:1);
                // mutedStrong is AA.
                unselectedLabelColor: AppColors.mutedStrong,
                indicatorColor: AppColors.white,
                tabs: [
                  for (var i = 0; i < _tabTypes.length; i++)
                    Tab(text: _tabLabel(l10n, i)),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
          Expanded(
            child: catalogAsync.when(
                // U-25 (§5.8): the shop is a grid first load with nothing on
                // screen — the §5.3 card-grid skeleton stands in (U-22's
                // handoff suggested VSkeletonList, but the shop renders a
                // 2-column card grid, so VSkeletonGrid is the closer shape).
                loading: () => const VSkeletonGrid(rows: 2, columns: 2),
                error: (e, _) => ErrorView(
                  message: e.toAppError().message,
                  onRetry: () =>
                      ref.read(cosmeticsCatalogProvider.notifier).refresh(),
                ),
                data: (catalog) {
                  final visible = catalog
                      .where(
                        (item) =>
                            item['type'] == _tabTypes[_tabController.index],
                      )
                      .toList();
                  final ownedByCosmeticId = {
                    for (final owned in ownedAsync.valueOrNull ?? const [])
                      owned['cosmetic_id'] as String: owned,
                  };
                  if (visible.isEmpty) {
                    return VEmptyView(
                      icon: Icons.style_outlined,
                      title: l10n.cosmeticsEmptyCatalog,
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      final owned = ownedByCosmeticId[item['id'] as String];
                      return _CosmeticCard(
                        item: item,
                        owned: owned,
                        locked: isCosmeticLocked(item, userTier),
                        busy: _busyId == item['id'],
                        typeLabel: _typeLabel(
                          l10n,
                          item['type']?.toString() ?? '',
                        ),
                        tierLabel: _tierLabel(
                          l10n,
                          item['tier_requirement']?.toString() ?? 'free',
                        ),
                        l10n: l10n,
                        onBuy: () => _confirmPurchase(item),
                        onToggleEquipped: owned == null
                            ? null
                            : () => _toggleEquipped(owned),
                      );
                    },
                  );
                },
              ),
          ),
        ],
      ),
    );
  }
}

/// Current `personal_shards` (profile provider) — the currency the shop
/// spends. LUXE: violet glass card; the gold diamond marks the balance (§5.6).
class _BalanceBar extends StatelessWidget {
  final int shards;

  const _BalanceBar({required this.shards});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: VCard(
        child: Row(
          children: [
            const VShardIcon(),
            const SizedBox(width: 12),
            Text(
              l10n.profileShardsCount(shards),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, dynamic>? owned;
  final bool locked;
  final bool busy;
  final String typeLabel;
  final String tierLabel;
  final AppLocalizations l10n;
  final VoidCallback onBuy;
  final VoidCallback? onToggleEquipped;

  const _CosmeticCard({
    required this.item,
    required this.owned,
    required this.locked,
    required this.busy,
    required this.typeLabel,
    required this.tierLabel,
    required this.l10n,
    required this.onBuy,
    required this.onToggleEquipped,
  });

  bool get _equipped => owned?['equipped'] as bool? ?? false;

  String get _name => item['name']?.toString() ?? '';

  int get _cost => (item['shard_cost'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final hasTierRequirement =
        (item['tier_requirement']?.toString() ?? 'free') != 'free';

    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  typeLabel.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedStrong,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (locked)
                const Icon(Icons.lock, size: 16, color: AppColors.muted),
              if (owned != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 88),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    // LUXE: the equipped badge is the violet-family accent
                    // (never pink — 2026-08-12 directive); owned-but-idle
                    // keeps the muted flat accent.
                    child: VBadge.accent(
                      label: l10n.cosmeticsOwned,
                      gradient: _equipped ? _family : null,
                      color: _equipped ? null : AppColors.mutedStrong,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const VShardIcon(size: 12),
              const SizedBox(width: 6),
              Text(
                '$_cost',
                style: TextStyle(
                  color: locked ? AppColors.muted : AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (hasTierRequirement)
                Flexible(
                  child: Text(
                    l10n.cosmeticsRequiresTier(tierLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedStrong,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: owned == null
                ? VButton.outlined(
                    label: l10n.cosmeticsBuyWithCost(_cost),
                    gradient: _family,
                    loading: busy,
                    onPressed: locked ? null : onBuy,
                  )
                : VButton.emphasized(
                    label: _equipped
                        ? l10n.cosmeticsEquipped
                        : l10n.cosmeticsEquip,
                    gradient: _family,
                    loading: busy,
                    onPressed: onToggleEquipped,
                  ),
          ),
        ],
      ),
    );
  }
}
