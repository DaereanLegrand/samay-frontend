import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/config_provider.dart';
import 'package:samay/core/services/revenuecat_service.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

/// Subscription tier identifiers, matching `users.subscription_tier`.
class PaywallTier {
  const PaywallTier(this.id, this.titleKey, {this.monthlyKey, this.annualKey});

  final String id;
  final String titleKey;

  /// `app_config` keys for the monthly/annual prices (PEN centimos).
  /// Null for the free tier (always S/ 0.00).
  final String? monthlyKey;
  final String? annualKey;

  bool get isPaid => monthlyKey != null;
}

/// The three tiers of the subscription screen (PLAN spec §6.12: **all tiers
/// visible to all users** — App Store compliance; nothing hidden).
const paywallTiers = <PaywallTier>[
  PaywallTier('free', 'paywallTierFree'),
  PaywallTier(
    'pro',
    'paywallTierPro',
    monthlyKey: 'subs.pro_monthly_price_pen',
    annualKey: 'subs.pro_annual_price_pen',
  ),
  PaywallTier(
    'vip',
    'paywallTierVip',
    monthlyKey: 'subs.vip_monthly_price_pen',
    annualKey: 'subs.vip_annual_price_pen',
  ),
];

/// One comparison row of the tier table (spec §7). Cell values are either
/// plain numbers, the markers `check`/`cross`, or an ARB key resolved through
/// [paywallRowLabel] — data stays const and testable, copy stays localized.
class PaywallRow {
  const PaywallRow(this.labelKey,
      {required this.free, required this.pro, required this.vip});

  final String labelKey;
  final String free;
  final String pro;
  final String vip;
}

/// Tier comparison table rows (spec §7, 8 features).
const paywallRows = <PaywallRow>[
  PaywallRow('paywallRowEvents', free: '3', pro: '10', vip: '100'),
  PaywallRow('paywallRowGroups', free: '5', pro: '20', vip: '100'),
  PaywallRow('paywallRowMembers', free: '14', pro: '256', vip: 'paywallUnlimited'),
  PaywallRow('paywallRowPreshards', free: '10', pro: '1000', vip: '10000'),
  PaywallRow('paywallRowFeed', free: 'cross', pro: 'check', vip: 'check'),
  PaywallRow('paywallRowVideo', free: 'cross', pro: 'check', vip: 'check'),
  PaywallRow(
    'paywallRowCosmetics',
    free: 'paywallLimited',
    pro: 'paywallCosmeticsFull',
    vip: 'paywallCosmeticsFullExclusive',
  ),
  PaywallRow(
    'paywallRowRank',
    free: 'paywallRankMicro',
    pro: 'paywallRankUpToMedium',
    vip: 'paywallRankAll',
  ),
];

/// Resolves a [PaywallRow] label, a tier name, or a cell value key through
/// [l10n]. Numeric literals and the `check`/`cross` markers pass through
/// untouched.
String paywallRowLabel(AppLocalizations l10n, String key) => switch (key) {
      'paywallTierFree' => l10n.paywallTierFree,
      'paywallTierPro' => l10n.paywallTierPro,
      'paywallTierVip' => l10n.paywallTierVip,
      'paywallRowEvents' => l10n.paywallRowEvents,
      'paywallRowGroups' => l10n.paywallRowGroups,
      'paywallRowMembers' => l10n.paywallRowMembers,
      'paywallRowPreshards' => l10n.paywallRowPreshards,
      'paywallRowFeed' => l10n.paywallRowFeed,
      'paywallRowVideo' => l10n.paywallRowVideo,
      'paywallRowCosmetics' => l10n.paywallRowCosmetics,
      'paywallRowRank' => l10n.paywallRowRank,
      'paywallUnlimited' => l10n.paywallUnlimited,
      'paywallLimited' => l10n.paywallLimited,
      'paywallCosmeticsFull' => l10n.paywallCosmeticsFull,
      'paywallCosmeticsFullExclusive' => l10n.paywallCosmeticsFullExclusive,
      'paywallRankMicro' => l10n.paywallRankMicro,
      'paywallRankUpToMedium' => l10n.paywallRankUpToMedium,
      'paywallRankAll' => l10n.paywallRankAll,
      _ => key,
    };

/// Monthly price in PEN centimos for [tierId] from the `app_config` map
/// (spec §6.12 + seed `subs.*` keys). Missing keys fall back to the seeded
/// values; the free tier is always 0.
int paywallMonthlyPrice(String tierId, Map<String, String> config) =>
    switch (tierId) {
      'pro' => int.parse(config['subs.pro_monthly_price_pen'] ?? '1999'),
      'vip' => int.parse(config['subs.vip_monthly_price_pen'] ?? '4999'),
      _ => 0,
    };

/// Annual price in PEN centimos for [tierId] (10× monthly — 2 months free).
int paywallAnnualPrice(String tierId, Map<String, String> config) =>
    switch (tierId) {
      'pro' => int.parse(config['subs.pro_annual_price_pen'] ?? '19990'),
      'vip' => int.parse(config['subs.vip_annual_price_pen'] ?? '49990'),
      _ => 0,
    };

/// Formats a PEN amount given in centimos as the spec's display style
/// (`S/. 19.99` — symbol first, dot decimal separator, 2 decimals): e.g.
/// `1999` → `S/ 19.99`. `es_PE`'s native currency format places the symbol
/// after the amount and uses a comma decimal, so the decimal digits are
/// formatted separately and the `S/ ` prefix is applied here.
String formatPEN(int centimos) {
  final amount = NumberFormat.decimalPatternDigits(
    locale: 'en_US',
    decimalDigits: 2,
  ).format(centimos / 100);
  return 'S/ $amount';
}

/// The user's explicit current tier ('free'/'pro'/'vip') from the auth state,
/// or null when the GoTrue user JSON carries no `subscription_tier` (RCBH has
/// not landed) — a null resolves to NO badge, never a claim of the free tier.
///
/// NOTE (I-61): the GoTrue user JSON does not yet carry `subscription_tier`
/// end-to-end (`UserService.getUserProfile` now selects the column — I-62 —
/// but the auth-state user map is only populated by RCBH's fallback sync) —
/// this reads `user['subscription_tier']` (or the `user_metadata` fallback)
/// when present and otherwise returns null. The RCBH client fallback sync
/// (SBAS) will populate it end-to-end.
String? currentTierFromAuth(AuthState authState) {
  final user = authState.user;
  if (user == null) return null;
  final raw = user['subscription_tier'] ??
      (user['user_metadata'] is Map<String, dynamic>
          ? (user['user_metadata'] as Map<String, dynamic>)['subscription_tier']
          : null);
  if (raw is String && (raw == 'free' || raw == 'pro' || raw == 'vip')) {
    return raw;
  }
  return null;
}

/// Subscription paywall (PLAN spec §6.12 + `PLAN-subscription-plans-paywall`):
/// transparent pricing for **all** tiers (Free/PRO/VIP, monthly + annual),
/// prices from `app_config` (`subs.*_price_pen`, seeded) — never hardcoded —
/// the "Actual" badge on the current tier, and purchase buttons that stay
/// disabled (with a "Próximamente" tooltip) while RevenueCat is in stub mode.
///
/// Monochrome: flat tier cards, the white display hero (the redundant
/// AppBar title is gone — ORCHESTRATION directive #8: one hero per screen
/// max).
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  Future<void> _purchase(BuildContext context, WidgetRef ref, String tierId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(revenueCatServiceProvider).purchase(tierId);
    } catch (e, _) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toAppError().message)),
      );
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(revenueCatServiceProvider).restorePurchases();
    } catch (e, _) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toAppError().message)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final authState = ref.watch(authStateProvider);
    final stubMode = ref.watch(revenueCatServiceProvider).isStubMode;

    return Scaffold(
      appBar: AppBar(),
      body: config.when(
        loading: () => const VLoadingView(),
        error: (error, _) => ErrorView(
          message: error.toAppError().message,
          onRetry: () => ref.invalidate(appConfigProvider),
        ),
        data: (appConfig) {
          final currentTier = currentTierFromAuth(authState.valueOrNull ?? const AuthState());
          return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                // The single display hero (LUXE directive #8): the AppBar
                // title is removed — the header owns the screen.
                VDisplayText(text: l10n.paywallHeader, size: 32),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.paywallAllTiersVisible,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final tier in paywallTiers) ...[
                  _TierCard(
                    tier: tier,
                    l10n: l10n,
                    config: appConfig,
                    isCurrent: currentTier == tier.id,
                    stubMode: stubMode,
                    onUpgrade: tier.isPaid
                        ? () => _purchase(context, ref, tier.id)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const SizedBox(height: AppSpacing.sm),
                Tooltip(
                  message: l10n.comingSoonSoon,
                  child: VButton.outlined(
                    label: l10n.paywallRestore,
                    onPressed: stubMode ? null : () => _restore(context, ref),
                  ),
                ),
              ],
            );
        },
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final PaywallTier tier;
  final AppLocalizations l10n;
  final Map<String, String> config;
  final bool isCurrent;
  final bool stubMode;
  final VoidCallback? onUpgrade;

  const _TierCard({
    required this.tier,
    required this.l10n,
    required this.config,
    required this.isCurrent,
    required this.stubMode,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final monthly = paywallMonthlyPrice(tier.id, config);
    final annual = paywallAnnualPrice(tier.id, config);

    // Monochrome flat tier cards; the current tier carries the emphasized
    // badge.
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  paywallRowLabel(l10n, tier.titleKey),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isCurrent)
                VBadge.emphasized(label: l10n.paywallCurrentBadge),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${formatPEN(monthly)}${l10n.paywallPerMonth}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (tier.isPaid) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.paywallAnnualEquivalent(
                '${formatPEN((annual / 12).round())}${l10n.paywallPerMonth}',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
          const SizedBox(height: AppSpacing.md),
          for (final row in paywallRows) _FeatureRow(row: row, l10n: l10n),
          if (onUpgrade != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Tooltip(
              message: l10n.comingSoonSoon,
              child: VButton.emphasized(
                label: tier.id == 'pro'
                    ? l10n.paywallUpgradePro
                    : l10n.paywallUpgradeVip,
                onPressed: stubMode ? null : onUpgrade,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final PaywallRow row;
  final AppLocalizations l10n;

  const _FeatureRow({required this.row, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              paywallRowLabel(l10n, row.labelKey),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _FeatureCell(value: row.free, l10n: l10n),
          const SizedBox(width: AppSpacing.md),
          _FeatureCell(value: row.pro, l10n: l10n),
          const SizedBox(width: AppSpacing.md),
          _FeatureCell(value: row.vip, l10n: l10n),
        ],
      ),
    );
  }
}

class _FeatureCell extends StatelessWidget {
  final String value;
  final AppLocalizations l10n;

  const _FeatureCell({required this.value, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final text = paywallRowLabel(l10n, value);
    if (value == 'check') {
      return const Icon(Icons.check, size: 16, color: AppColors.white);
    }
    if (value == 'cross') {
      return const Icon(Icons.close, size: 16, color: AppColors.mutedStrong);
    }
    return SizedBox(
      width: 88,
      child: Text(text, textAlign: TextAlign.right),
    );
  }
}
