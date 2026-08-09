/// Central compile-time feature flags (foundation — I-36).
///
/// I-49 owns growing this into the provider-backed release-gating system
/// (`lib/core/feature_flags/**`); this minimal const class is the single seam
/// every in-progress feature checks today. A flag that is `false` must render
/// exactly nothing — zero visual diff until the feature ships.
class AppFeatureFlags {
  AppFeatureFlags._();

  /// Profile screen "Cosméticos" placeholder section (PRFL gap — I-36).
  /// Flips to `true` when the cosmetics shop/equipping stack lands
  /// (phase-10 / COSM spec).
  static const bool showCosmeticsSection = false;
}
