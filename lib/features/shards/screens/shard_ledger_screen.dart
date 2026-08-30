import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/models/ledger_entry.dart';
import 'package:samay/features/profile/providers/profile_providers.dart';
import 'package:samay/features/shards/logic/shard_ledger_formatters.dart';
import 'package:samay/features/shards/providers/shard_ledger_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

/// Localized label for a `shard_reason` enum value (SLED display mapping
/// table — 9 reasons). Unknown values fall back to the raw data string so a
/// future enum addition never renders blank.
String shardReasonLabel(AppLocalizations l10n, String reason) {
  return switch (reason) {
    'event_attendance' => l10n.shardsReasonEventAttendance,
    'cosmetic_purchase' => l10n.shardsReasonCosmeticPurchase,
    'group_donation' => l10n.shardsReasonGroupDonation,
    'minigame_wager' => l10n.shardsReasonMinigameWager,
    'minigame_win' => l10n.shardsReasonMinigameWin,
    'minigame_refund' => l10n.shardsReasonMinigameRefund,
    'subscription_grant' => l10n.shardsReasonSubscriptionGrant,
    'admin_grant' => l10n.shardsReasonAdminGrant,
    'feed_post' => l10n.shardsReasonFeedPost,
    _ => reason,
  };
}

/// Descriptive icon per `shard_reason` (SLED icon column; Material glyphs
/// for the spec's emoji/arrows). Fallback: the shard diamond.
IconData shardReasonIcon(String reason) {
  return switch (reason) {
    'event_attendance' => Icons.check_circle_outline,
    'cosmetic_purchase' => Icons.shopping_cart_outlined,
    'group_donation' => Icons.arrow_upward,
    'minigame_wager' => Icons.casino_outlined,
    'minigame_win' => Icons.emoji_events_outlined,
    'minigame_refund' => Icons.undo,
    'subscription_grant' => Icons.star_outline,
    'admin_grant' => Icons.auto_awesome,
    'feed_post' => Icons.edit_note,
    _ => Icons.diamond_outlined,
  };
}

/// Localized label for a `preshard_reason` enum value (SLED display mapping
/// table — 6 reasons). Same raw-value fallback as [shardReasonLabel].
String preshardReasonLabel(AppLocalizations l10n, String reason) {
  return switch (reason) {
    'purchased' => l10n.preshardsReasonPurchased,
    'subscription_grant' => l10n.preshardsReasonSubscriptionGrant,
    'event_pool_set' => l10n.preshardsReasonEventPoolSet,
    'event_pool_consumed' => l10n.preshardsReasonEventPoolConsumed,
    'event_pool_returned' => l10n.preshardsReasonEventPoolReturned,
    'admin_grant' => l10n.preshardsReasonAdminGrant,
    _ => reason,
  };
}

/// Descriptive icon per `preshard_reason`. Fallback: the shard diamond.
IconData preshardReasonIcon(String reason) {
  return switch (reason) {
    'purchased' => Icons.shopping_bag_outlined,
    'subscription_grant' => Icons.star_outline,
    'event_pool_set' => Icons.savings_outlined,
    'event_pool_consumed' => Icons.account_balance_wallet_outlined,
    'event_pool_returned' => Icons.replay,
    'admin_grant' => Icons.auto_awesome,
    _ => Icons.diamond_outlined,
  };
}

/// The shard & preshard ledger (SLED spec): header balances (personal shards
/// earned + preshards bought/granted, with the economy note), two tabs
/// (Shards / Preshards) over the newest-first movement lists — each entry
/// shows the reason icon + localized label, the delta (+gold / −gray
/// strikethrough), the timestamp and the short reference id — plus
/// pull-to-refresh and empty/error states. Monochrome hairline rows; the
/// flat gold delta figures carry the currency meaning, the shard diamond
/// stays the currency accent (§5.6).
class ShardLedgerScreen extends ConsumerStatefulWidget {
  const ShardLedgerScreen({super.key});

  @override
  ConsumerState<ShardLedgerScreen> createState() => _ShardLedgerScreenState();
}

class _ShardLedgerScreenState extends ConsumerState<ShardLedgerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ledgerAsync = ref.watch(shardLedgerProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final personalShards = (profile?['personal_shards'] as num?)?.toInt() ?? 0;
    final preshards = (profile?['preshards'] as num?)?.toInt() ?? 0;

    return Scaffold(
      body: VHeaderBar(
        title: l10n.shardsLedgerTitle,
        child: Column(
          children: [
            _BalanceHeader(
              personalShards: personalShards,
              preshards: preshards,
              l10n: l10n,
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.white,
              // §2.4: unselected tab labels are informational text at normal
              // size — muted #666666 fails 1.4.3 (3.66:1); mutedStrong is AA.
              unselectedLabelColor: AppColors.mutedStrong,
              indicatorColor: AppColors.white,
              tabs: [
                Tab(text: l10n.shardsLedgerTabShards),
                Tab(text: l10n.shardsLedgerTabPreshards),
              ],
            ),
            Expanded(
              child: ledgerAsync.when(
                // U-25 (§5.8): the ledger is a list-y first load with nothing
                // on screen, so the row skeleton stands in (U-22's handoff
                // named shard_ledger → VSkeletonList). Pull-to-refresh keeps
                // the list visible — the skeleton only ever replaces a blank
                // frame.
                skipLoadingOnRefresh: true,
                loading: () => const VSkeletonList(),
                error: (error, _) => ErrorView(
                  message: l10n.shardsLedgerLoadError,
                  onRetry: () =>
                      ref.read(shardLedgerProvider.notifier).refresh(),
                ),
                data: (ledger) => _buildLedger(l10n, ledger),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedger(AppLocalizations l10n, ShardLedgerData ledger) {
    final isShards = _tabController.index == 0;
    final entries = isShards ? ledger.shards : ledger.preshards;
    final total = isShards ? ledger.shardTotal : ledger.preshardTotal;

    if (entries.isEmpty) {
      return VEmptyView(
        icon: Icons.receipt_long,
        title: l10n.shardsLedgerEmpty,
        description: l10n.shardsLedgerEmptyBody,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(shardLedgerProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: entries.length + 1,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _NetHeader(total: total, l10n: l10n);
          }
          final entry = entries[index - 1];
          return _LedgerTile(
            entry: entry,
            icon: isShards
                ? shardReasonIcon(entry.reason)
                : preshardReasonIcon(entry.reason),
            label: isShards
                ? shardReasonLabel(l10n, entry.reason)
                : preshardReasonLabel(l10n, entry.reason),
            l10n: l10n,
          );
        },
      ),
    );
  }
}

/// The economy summary header (SLED "Economy summary on profile screen"
/// balances — also rendered here so the ledger is self-contained): earned vs
/// bought/granted with the "no expiran / solo eventos" note (monochrome
/// hairline card).
class _BalanceHeader extends StatelessWidget {
  final int personalShards;
  final int preshards;
  final AppLocalizations l10n;

  const _BalanceHeader({
    required this.personalShards,
    required this.preshards,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: VCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.shardsLedgerEarned,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.mutedStrong),
                  ),
                ),
                const VShardIcon(size: AppIconSizes.sm),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.profileShardsCount(personalShards),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.shardsLedgerBought,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.mutedStrong),
                  ),
                ),
                Text(
                  l10n.profilePreshardsCount(preshards),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${l10n.shardsLedgerEarnedNote} ${l10n.shardsLedgerPreshardsNote}',
              style: const TextStyle(
                color: AppColors.mutedStrong,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Net of the visible side (derived totals from the provider): a positive
/// net renders as a flat [AppColors.discoGold] figure.
class _NetHeader extends StatelessWidget {
  final int total;
  final AppLocalizations l10n;

  const _NetHeader({required this.total, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final positive = total >= 0;
    final text = '${positive ? '+' : ''}$total';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            l10n.shardsLedgerNet,
            style: const TextStyle(color: AppColors.mutedStrong),
          ),
          const SizedBox(width: AppSpacing.sm),
          _GradientDelta(
            text: text,
            positive: positive,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A signed shard delta — positive values render as a flat
/// [AppColors.discoGold] figure (currency token); negative stays
/// `mutedStrong` strikethrough (loss).
class _GradientDelta extends StatelessWidget {
  const _GradientDelta({
    required this.text,
    required this.positive,
    this.style,
  });

  final String text;
  final bool positive;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? const TextStyle();
    if (!positive) {
      return Text(
        text,
        style: base.copyWith(
          color: AppColors.mutedStrong,
          decoration: TextDecoration.lineThrough,
        ),
      );
    }
    return Text(text, style: base.copyWith(color: AppColors.discoGold));
  }
}

class _LedgerTile extends StatelessWidget {
  final LedgerEntry entry;
  final IconData icon;
  final String label;
  final AppLocalizations l10n;

  const _LedgerTile({
    required this.entry,
    required this.icon,
    required this.label,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final positive = entry.delta >= 0;
    final reference = shortReferenceId(entry.referenceId);

    // XL-17: the row is a hairline list row — no glass card, no glow, no
    // shard diamond beside the delta (the flat gold delta already carries
    // the "+" accent; the diamond is the balance-card token).
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSizes.md, color: AppColors.white),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatLedgerTimestamp(entry.createdAt, l10n.localeName),
                  style: const TextStyle(
                    color: AppColors.mutedStrong,
                    fontSize: 12,
                  ),
                ),
                if (reference.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.shardsLedgerReference(reference),
                    style: const TextStyle(
                      color: AppColors.mutedStrong,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _GradientDelta(
            text: '${positive ? '+' : ''}${entry.delta}',
            positive: positive,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
