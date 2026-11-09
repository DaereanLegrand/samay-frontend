import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:samay/core/config/env_config.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/config_provider.dart';
import 'package:samay/features/profile/providers/profile_providers.dart';
import 'package:samay/core/services/revenuecat_service.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/core/theme/app_palette_context.dart';

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
  const PaywallRow(
    this.labelKey, {
    required this.free,
    required this.pro,
    required this.vip,
  });

  final String labelKey;
  final String free;
  final String pro;
  final String vip;
}

/// Tier comparison table rows (spec §7, 8 features).
const paywallRows = <PaywallRow>[
  PaywallRow('paywallRowEvents', free: '3', pro: '10', vip: '100'),
  PaywallRow('paywallRowGroups', free: '5', pro: '20', vip: '100'),
  PaywallRow(
    'paywallRowMembers',
    free: '14',
    pro: '256',
    vip: 'paywallUnlimited',
  ),
  PaywallRow('paywallRowPreshards', free: '10', pro: '1000', vip: '10000'),
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

/// Price labels for a paid tier's card: the monthly headline, the annual
/// monthly-equivalent (with the `/mo` suffix applied), and the computed saving
/// percent. `prod` builds source these from `app_config` (custom prices); every
/// other environment sources them from the resolved RevenueCat products (no
/// app_config fallback).
class TierPricing {
  const TierPricing({
    this.monthlyLabel,
    this.annualEquivalentLabel,
    this.discountPercent,
  });

  /// e.g. `$4.99` (RC) or `S/ 19.99` (prod).
  final String? monthlyLabel;

  /// The annual price expressed per month, e.g. `$4.17/mo` (RC) or
  /// `S/ 16.66/mo` (prod). Null when there is no annual price.
  final String? annualEquivalentLabel;

  /// Computed saving percent (from the set prices). Null when unavailable.
  final int? discountPercent;
}

/// Resolves a tier's [TierPricing] from the environment's price source.
TierPricing tierPricing({
  required PaywallTier tier,
  required Map<String, String> config,
  required Map<String, RcProduct> rcProducts,
  required String perMonthSuffix,
}) {
  // The free tier is always S/ 0.00 (no product, no discount).
  if (!tier.isPaid) return TierPricing(monthlyLabel: formatPEN(0));
  if (EnvConfig.isProd) {
    final monthly = paywallMonthlyPrice(tier.id, config);
    final annual = paywallAnnualPrice(tier.id, config);
    if (monthly <= 0) return const TierPricing();
    final eq = annual / 12;
    return TierPricing(
      monthlyLabel: formatPEN(monthly),
      annualEquivalentLabel: '${formatPEN(eq.round())}$perMonthSuffix',
      discountPercent: savingPercent(monthly.toDouble(), eq),
    );
  }
  final monthly = rcProducts[
      RevenueCatProducts.idFor(tier.id, BillingPeriod.monthly) ?? ''];
  if (monthly == null) return const TierPricing();
  final annual = rcProducts[
      RevenueCatProducts.idFor(tier.id, BillingPeriod.annual) ?? ''];
  String? annualEq;
  int? percent;
  if (annual != null && monthly.price > 0) {
    final currency = NumberFormat.simpleCurrency(
      name: monthly.currencyCode,
      decimalDigits: 2,
    );
    final eq = annual.price / 12;
    annualEq = '${currency.format(eq)}$perMonthSuffix';
    percent = savingPercent(monthly.price, eq);
  }
  return TierPricing(
    monthlyLabel: monthly.priceString,
    annualEquivalentLabel: annualEq,
    discountPercent: percent,
  );
}

/// The saving percent of paying annually vs monthly, computed from the set
/// prices: `round((1 - annualMonthlyEquivalent / monthly) * 100)`, clamped at 0.
int savingPercent(double monthly, double annualMonthlyEquivalent) {
  if (monthly <= 0) return 0;
  final pct = ((1 - annualMonthlyEquivalent / monthly) * 100).round();
  return pct < 0 ? 0 : pct;
}

/// The user's explicit current tier ('free'/'pro'/'vip') from the auth state,
/// or null when the user JSON carries no `subscription_tier` — a null resolves
/// to NO badge, never a claim of the free tier.
///
/// Reads `user['subscription_tier']` (or the `user_metadata` fallback) when
/// present, otherwise returns null.
String? currentTierFromProfile(Map<String, dynamic>? profile) {
  if (profile == null) return null;
  final raw = profile['subscription_tier'];
  if (raw is! String || (raw != 'free' && raw != 'pro' && raw != 'vip')) {
    return null;
  }
  if (raw == 'free') return raw;
  final expires = DateTime.tryParse(
    profile['subscription_expires_at']?.toString() ?? '',
  );
  // D6/Q21: paid requires a future expiry; 24h action grace included.
  if (expires == null ||
      !expires.add(const Duration(hours: 24)).isAfter(DateTime.now())) {
    return null;
  }
  return raw;
}

/// Subscription paywall (PLAN spec §6.12 + `PLAN-subscription-plans-paywall`):
/// transparent pricing for **all** tiers (Free/PRO/VIP), prices from
/// `app_config` (`subs.*_price_pen`, seeded) — never hardcoded — the "Actual"
/// badge on the current tier, and a monthly/annual toggle that selects which
/// product a paid tier's CTA buys.
///
/// A tier CTA renders only when its product id is actually purchasable in this
/// build ([availableRevenueCatProductsProvider]); otherwise it renders nothing
/// — there is no "coming soon" placeholder. In a stub build (no RevenueCat key)
/// the route is behind `AppFeatureFlag.subscriptions` and unreachable.
///
/// Monochrome: flat tier cards and a single white display hero (one hero per
/// screen; no AppBar title).
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  /// Billing period selected for the paid CTAs (default monthly).
  BillingPeriod _period = BillingPeriod.monthly;

  Future<void> _purchase(String productId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(revenueCatServiceProvider).purchase(productId);
    } catch (e, _) {
      messenger.showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(revenueCatServiceProvider).restorePurchases();
    } catch (e, _) {
      messenger.showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final iapEnabled = EnvConfig.iapEnabled;
    final stubMode =
        !iapEnabled || ref.watch(revenueCatServiceProvider).isStubMode;
    final available = ref.watch(availableRevenueCatProductsProvider);

    return Scaffold(
      body: VHeaderBar(
        child: config.when(
          loading: () => const VLoadingView(),
          error: (error, _) => ErrorView(
            message: error.toAppError().message,
            onRetry: () => ref.invalidate(appConfigProvider),
          ),
          data: (appConfig) {
            final currentTier = currentTierFromProfile(profile);
            final products =
                available.valueOrNull ?? const <String, RcProduct>{};
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                // The single display hero: the AppBar title is removed and the
                // header owns the screen.
                VDisplayText(text: l10n.paywallHeader, size: 32),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.paywallAllTiersVisible,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                // Monthly / annual selection for the paid CTAs.
                _PeriodToggle(
                  period: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final tier in paywallTiers) ...[
                  _TierCard(
                    tier: tier,
                    l10n: l10n,
                    isCurrent: currentTier == tier.id,
                    stubMode: stubMode,
                    productId: RevenueCatProducts.idFor(tier.id, _period),
                    availableProducts: products,
                    pricing: tierPricing(
                      tier: tier,
                      config: appConfig,
                      rcProducts: products,
                      perMonthSuffix: l10n.paywallPerMonth,
                    ),
                    onBuy: _purchase,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                // Restore is offered only when a real store is configured;
                // otherwise (or in stub mode) nothing is rendered.
                if (!stubMode) ...[
                  const SizedBox(height: AppSpacing.sm),
                  VButton.outlined(
                    label: l10n.paywallRestore,
                    onPressed: _restore,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TierCard extends StatefulWidget {
  final PaywallTier tier;
  final AppLocalizations l10n;
  final bool isCurrent;
  final bool stubMode;

  /// The RC product id for the selected period, or null when the tier is
  /// unpriced.
  final String? productId;

  /// Products that are actually purchasable in this build (keyed by id).
  final Map<String, RcProduct> availableProducts;

  /// Resolved price labels for this tier (env-based price source).
  final TierPricing pricing;
  final ValueChanged<String> onBuy;

  const _TierCard({
    required this.tier,
    required this.l10n,
    required this.isCurrent,
    required this.stubMode,
    required this.productId,
    required this.availableProducts,
    required this.pricing,
    required this.onBuy,
  });

  @override
  State<_TierCard> createState() => _TierCardState();
}

class _TierCardState extends State<_TierCard> {
  /// The tier comparison is progressive disclosure: the card stays compact
  /// (title, price, CTA) until the user opens the feature rows.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final l10n = widget.l10n;
    final pricing = widget.pricing;
    final current = widget.isCurrent
        ? VBadge.emphasized(label: l10n.paywallCurrentBadge)
        : null;
    final productId = widget.productId;
    // The CTA is shown only when this build can actually buy the product;
    // otherwise the card renders no button at all.
    final canBuy = !widget.stubMode &&
        productId != null &&
        widget.availableProducts.containsKey(productId);

    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  paywallRowLabel(l10n, tier.titleKey),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ?current,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Headline: the monthly price (RC priceString, or custom app_config).
          if (pricing.monthlyLabel != null)
            Text(
              '${pricing.monthlyLabel}${l10n.paywallPerMonth}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          // Subtitle: the annual monthly-equivalent + the computed saving %.
          if (tier.isPaid &&
              pricing.annualEquivalentLabel != null &&
              pricing.discountPercent != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.paywallAnnualEquivalent(
                pricing.annualEquivalentLabel!,
                '${pricing.discountPercent}',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (canBuy) ...[
            const SizedBox(height: AppSpacing.lg),
            VButton.emphasized(
              label: tier.id == 'pro'
                  ? l10n.paywallUpgradePro
                  : l10n.paywallUpgradeVip,
              onPressed: () => widget.onBuy(productId),
            ),
          ],
          Align(
            alignment: Alignment.center,
            child: IconButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              tooltip: l10n.commonMoreOptions,
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: context.palette.mutedForeground,
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, thickness: 1, color: context.palette.hairline),
            const SizedBox(height: AppSpacing.md),
            for (final row in paywallRows) _FeatureRow(row: row, l10n: l10n),
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
      return Icon(Icons.check, size: 16, color: context.palette.foreground);
    }
    if (value == 'cross') {
      return Icon(Icons.close, size: 16, color: context.palette.mutedForeground);
    }
    return SizedBox(width: 88, child: Text(text, textAlign: TextAlign.right));
  }
}

/// Monthly / annual selection that decides which product a paid CTA buys.
class _PeriodToggle extends StatelessWidget {
  final BillingPeriod period;
  final ValueChanged<BillingPeriod> onChanged;

  const _PeriodToggle({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SegmentedButton<BillingPeriod>(
        segments: [
          ButtonSegment(
            value: BillingPeriod.monthly,
            label: Text(l10n.paywallBillingMonthly),
          ),
          ButtonSegment(
            value: BillingPeriod.annual,
            label: Text(l10n.paywallBillingAnnual),
          ),
        ],
        selected: {period},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}
