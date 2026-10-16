import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/logging/app_logger.dart';

/// Build-time RevenueCat public SDK keys, injected via `--dart-define`.
///
/// RevenueCat's Flutter SDK is **per-platform keyed**: iOS uses an
/// `appl_…` public key, Android a `goog_…` public key, and local development
/// uses a distinct **Test Store** key (RevenueCat's built-in test environment,
/// which needs no App Store / Play setup). All keys are public by design (they
/// cannot mint purchases) but must never be hardcoded — a build with none of
/// them runs in **stub mode** (purchase UI disabled).
///
/// See https://www.revenuecat.com/docs/getting-started/configuring-sdk and
/// https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store.
const String revenueCatSdkKeyApple = String.fromEnvironment(
  'REVENUECAT_PUBLIC_SDK_KEY_APPLE',
  defaultValue: '',
);
const String revenueCatSdkKeyGoogle = String.fromEnvironment(
  'REVENUECAT_PUBLIC_SDK_KEY_GOOGLE',
  defaultValue: '',
);
const String revenueCatTestStoreKey = String.fromEnvironment(
  'REVENUECAT_TEST_STORE_KEY',
  defaultValue: '',
);

/// The public SDK key that applies to the current build:
///  * debug build with a Test Store key present → the Test Store key;
///  * otherwise iOS → the Apple key, Android → the Google key;
///  * unset / unsupported platform → `''` (stub mode).
///
/// A Test Store key must never be used in a release build (RevenueCat's SDK
/// refuses to run it there), hence the `kDebugMode` gate.
String revenueCatPublicSdkKey() {
  if (kDebugMode && revenueCatTestStoreKey.isNotEmpty) {
    return revenueCatTestStoreKey;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return revenueCatSdkKeyApple;
    case TargetPlatform.android:
      return revenueCatSdkKeyGoogle;
    default:
      return '';
  }
}

/// Billing period a paid tier's CTA purchases.
enum BillingPeriod { monthly, annual }

/// RevenueCat product identifier per (tier, period).
///
/// The app buys by **product id** (never by entitlement id), so the ids here
/// must match the store/RevenueCat products configured per environment (the
/// Test Store products `monthly_pro`/`yearly_pro` and `monthly_vip`/
/// `yearly_vip`). A tier absent from [_byTier] has no purchase path and its
/// CTA is not shown.
class RevenueCatProducts {
  const RevenueCatProducts._();

  static const Map<String, Map<BillingPeriod, String>> _byTier = {
    'pro': {
      BillingPeriod.monthly: 'monthly_pro',
      BillingPeriod.annual: 'yearly_pro',
    },
    'vip': {
      BillingPeriod.monthly: 'monthly_vip',
      BillingPeriod.annual: 'yearly_vip',
    },
  };

  /// The product id for [tier] at [period], or null when the tier is unpriced.
  static String? idFor(String tier, BillingPeriod period) =>
      _byTier[tier]?[period];

  /// Every configured product id (for the availability probe).
  static List<String> allIds() => [
    for (final m in _byTier.values) ...m.values,
  ];
}

/// Minimal RevenueCat customer snapshot consumed by the app — an
/// SDK-agnostic view-model so screens never import the plugin types.
class PurchaserInfo {
  const PurchaserInfo({required this.activeEntitlements});

  /// Active entitlement identifiers (e.g. `pro`, `vip`).
  final Set<String> activeEntitlements;

  bool get hasActiveEntitlement => activeEntitlements.isNotEmpty;
}

/// A purchasable RevenueCat product's display metadata (SDK-agnostic).
class RcProduct {
  const RcProduct({
    required this.id,
    required this.priceString,
    required this.price,
    required this.currencyCode,
  });

  /// The store/RC product identifier.
  final String id;

  /// Localized price label, e.g. `$4.99`.
  final String priceString;

  /// Numeric price (for computing the annual monthly-equivalent + discount).
  final double price;

  /// ISO currency code, e.g. `USD`.
  final String currencyCode;
}

/// Seam over the `purchases_flutter` plugin: the RSDK wiring
/// swaps in the real driver; tests inject a fake. The service only touches the
/// driver when a public SDK key is present — stub mode never reaches the
/// plugin, so unit tests run without platform channels.
abstract class RevenueCatDriver {
  /// Whether the SDK has been configured (see RSDK `Purchases.configure`).
  Future<bool> isConfigured();

  /// The latest customer info, or null when unavailable.
  Future<PurchaserInfo?> currentInfo();

  /// Resolves which of [productIds] are real (purchasable) RevenueCat products
  /// for this configuration, keyed by product id. Unconfigured ids are omitted.
  Future<Map<String, RcProduct>> products(List<String> productIds);

  /// Purchases the RevenueCat product identified by [productId].
  Future<void> purchase(String productId);

  /// Restores the user's previous purchases.
  Future<void> restore();
}

/// Real driver over `purchases_flutter` (RSDK): maps the plugin API onto the
/// seam types. Reachable only when `REVENUECAT_PUBLIC_SDK_KEY` is present.
class PurchasesDriver implements RevenueCatDriver {
  @override
  Future<bool> isConfigured() => rc.Purchases.isConfigured;

  @override
  Future<PurchaserInfo?> currentInfo() async {
    final info = await rc.Purchases.getCustomerInfo();
    return PurchaserInfo(
      activeEntitlements: info.entitlements.active.keys.toSet(),
    );
  }

  @override
  Future<Map<String, RcProduct>> products(List<String> productIds) async {
    final products = await rc.Purchases.getProducts(productIds);
    return {
      for (final p in products)
        p.identifier: RcProduct(
          id: p.identifier,
          priceString: p.priceString,
          price: p.price,
          currencyCode: p.currencyCode,
        ),
    };
  }

  @override
  Future<void> purchase(String productId) async {
    final products = await rc.Purchases.getProducts([productId]);
    if (products.isEmpty) {
      throw const NotFoundError('RevenueCat product');
    }
    final result = await rc.Purchases.purchase(
      rc.PurchaseParams.storeProduct(products.first),
    );
    AppLogger.instance.debug(
      'RevenueCat purchase succeeded: '
      '${result.storeTransaction.transactionIdentifier}',
    );
  }

  @override
  Future<void> restore() async {
    final info = await rc.Purchases.restorePurchases();
    AppLogger.instance.debug(
      'RevenueCat restore succeeded: ${info.activeSubscriptions}',
    );
  }
}

/// RevenueCat facade.
///
/// Two modes, selected at construction by the presence of the public SDK key:
///
/// * **stub mode** (no key — every build until RSDK ships): `isConfigured()`
///   is false, `currentInfo()` returns null, `restorePurchases()` is a logged
///   no-op, and `purchase()` throws [NotConfiguredError]. Screens must render
///   purchase UI disabled in this mode.
/// * **configured mode** (key present): every call delegates to the injected
///   [RevenueCatDriver] (the `purchases_flutter` wrapper). `Purchases.configure`
///   itself stays in `main.dart` per the RSDK spec (alpha infrastructure,
///   phase-14) — this service never calls it.
class RevenueCatService {
  RevenueCatService({
    RevenueCatDriver? driver,
    String? apiKey,
  })  : _driver = driver ?? PurchasesDriver(),
        _apiKey = apiKey ?? revenueCatPublicSdkKey() {
    if (_apiKey.isEmpty) {
      AppLogger.instance.warn(
        'RevenueCat stub mode: no REVENUECAT_PUBLIC_SDK_KEY_APPLE|_GOOGLE '
        '(or REVENUECAT_TEST_STORE_KEY) dart-define — purchase UI is disabled.',
      );
    }
  }

  final RevenueCatDriver _driver;
  final String _apiKey;

  /// Whether this build runs without a RevenueCat key (purchases disabled).
  /// The synchronous proxy the UI uses for disabled buttons — a configured
  /// build flips it to false so the RSDK wiring needs no screen changes.
  bool get isStubMode => _apiKey.isEmpty;

  /// True when a public SDK key is present AND the SDK is configured.
  Future<bool> isConfigured() async {
    if (_apiKey.isEmpty) return false;
    return _driver.isConfigured();
  }

  /// The current RevenueCat customer info, or null when unconfigured.
  Future<PurchaserInfo?> currentInfo() async {
    if (_apiKey.isEmpty) return null;
    return _driver.currentInfo();
  }

  Map<String, RcProduct>? _available;

  /// The [RcProduct]s from [RevenueCatProducts.allIds] that resolve to a real
  /// RevenueCat product for this configuration, keyed by id. Empty in stub
  /// mode. Cached for the life of the service (the catalog does not change
  /// mid-session).
  Future<Map<String, RcProduct>> availableProducts() async {
    if (_apiKey.isEmpty) return <String, RcProduct>{};
    return _available ??=
        await _driver.products(RevenueCatProducts.allIds());
  }

  /// Purchases [productId]. Throws [NotConfiguredError] in stub mode.
  Future<void> purchase(String productId) async {
    if (_apiKey.isEmpty) throw NotConfiguredError();
    return _driver.purchase(productId);
  }

  /// Restores previous purchases (logged no-op in stub mode).
  Future<void> restorePurchases() async {
    if (_apiKey.isEmpty) {
      AppLogger.instance.warn(
        'RevenueCat stub mode: restorePurchases() skipped.',
      );
      return;
    }
    return _driver.restore();
  }
}

/// The app-wide RevenueCat service. Tests override the whole provider (e.g.
/// with a configured service backed by a fake driver) — nothing else in the
/// app may construct a service directly.
final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService();
});

/// The [RcProduct]s that are actually purchasable in this build, keyed by id
/// (empty in stub mode). The paywall renders a tier's CTA/price only when its
/// product id is present here, so an unavailable product renders nothing rather
/// than a dead button.
final availableRevenueCatProductsProvider =
    FutureProvider<Map<String, RcProduct>>((ref) {
  return ref.read(revenueCatServiceProvider).availableProducts();
});
