import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';

/// Every feature ships behind one of these flags (release
/// gating). A flag is the single release knob for its feature:
///
/// * **live** (`true`) — the feature ships in this build; the flag remains
///   wired as the kill-switch/remote-config knob (the [FlagGate] fallback is
///   a neutral unavailable state).
/// * **dark** (`false`) — the feature is unreachable until its stack lands;
///   gated screens render the neutral [FlagGate] fallback.
///
/// Flags are read through [featureFlagsProvider] (overridable at app startup)
/// — never through a compile-time constant, so a flag can be
/// flipped per build/environment without a code change.
///
/// ## Adding a feature
///
/// 1. Add a value here (e.g. `karaoke`).
/// 2. Add the matching getter + switch case on [AppFeatureFlags].
/// 3. Default the getter to `false` (dark-first).
/// 4. Gate the entry point: `FlagGate(flag: AppFeatureFlag.karaoke,
///    child: const KaraokeScreen())`.
enum AppFeatureFlag {
  /// Profile "Cosméticos" section (PRFL gap; the shop/equip stack is
  /// future work). Live — the flag is the kill-switch knob.
  cosmeticsSection,

  /// Events core. Live — the flag is the
  /// kill-switch knob.
  events,

  /// E2EE chat (live — `/chat/:chatId` is real).
  chat,

  /// QR attendance + scanner. Live — the flag is the kill-switch knob.
  qr,

  /// Social feed (live: it's the landing tab, so the flag is
  /// the kill-switch/remote-config knob).
  feed,

  /// In-app notification center (live; the flag is
  /// the kill-switch/remote-config knob for the live route).
  notifications,

  /// Subscriptions / paywall. DARK: purchases await the
  /// RevenueCat SDK key — do not flip this flag.
  subscriptions,

  /// Minigames. LIVE — the flag is the kill-switch knob.
  minigames,

  /// Event photo upload + gallery. LIVE — the flag is the
  /// kill-switch knob.
  photoUpload,

  /// End-to-end encryption of chat content — always on while the E2EE
  /// stack is the only chat transport; kept as a flag so a
  /// kill-switch exists.
  e2ee,

  /// Dark-mode theme persistence.
  themePersistence,
}

/// The release-gating flag set. Immutable; every getter defaults to the
/// documented [AppFeatureFlag] state and can be overridden per build via the
/// const constructor (startup/remote-config seam, see [featureFlagsProvider]).
class AppFeatureFlags {
  const AppFeatureFlags({
    this.cosmeticsSection = true,
    this.events = true,
    this.chat = true,
    this.qr = true,
    // NOTE: the feed IS the landing tab — the real feed ships by
    // default (true); flipping to false returns it to the dark state.
    this.feed = true,
    this.notifications = true,
    this.subscriptions = false,
    this.minigames = true,
    this.photoUpload = true,
    this.e2ee = true,
    this.themePersistence = false,
  });

  final bool cosmeticsSection;
  final bool events;
  final bool chat;
  final bool qr;
  final bool feed;
  final bool notifications;
  final bool subscriptions;
  final bool minigames;
  final bool photoUpload;
  final bool e2ee;
  final bool themePersistence;

  /// Resolves [flag] to its current state.
  bool isEnabled(AppFeatureFlag flag) => switch (flag) {
    AppFeatureFlag.cosmeticsSection => cosmeticsSection,
    AppFeatureFlag.events => events,
    AppFeatureFlag.chat => chat,
    AppFeatureFlag.qr => qr,
    AppFeatureFlag.feed => feed,
    AppFeatureFlag.notifications => notifications,
    AppFeatureFlag.subscriptions => subscriptions,
    AppFeatureFlag.minigames => minigames,
    AppFeatureFlag.photoUpload => photoUpload,
    AppFeatureFlag.e2ee => e2ee,
    AppFeatureFlag.themePersistence => themePersistence,
  };

  @override
  bool operator ==(Object other) =>
      other is AppFeatureFlags &&
      other.cosmeticsSection == cosmeticsSection &&
      other.events == events &&
      other.chat == chat &&
      other.qr == qr &&
      other.feed == feed &&
      other.notifications == notifications &&
      other.subscriptions == subscriptions &&
      other.minigames == minigames &&
      other.photoUpload == photoUpload &&
      other.e2ee == e2ee &&
      other.themePersistence == themePersistence;

  @override
  int get hashCode => Object.hash(
    cosmeticsSection,
    events,
    chat,
    qr,
    feed,
    notifications,
    subscriptions,
    minigames,
    photoUpload,
    e2ee,
    themePersistence,
  );
}

/// The app-wide flag set. Override in tests with
/// `overrideWithValue(AppFeatureFlags(events: true))`.
///
/// ## Startup / remote-config seam
///
/// `SamayApp` reads this provider with the const defaults. To drive flags
/// from configuration at startup, override this provider in the
/// `ProviderScope` that boots the app:
///
/// ```dart
/// runApp(ProviderScope(
///   overrides: [featureFlagsProvider.overrideWithValue(_flagsFromConfig())],
///   child: const SamayApp(),
/// ));
/// ```
///
/// `_flagsFromConfig()` may read `app_config` (the
/// `app.*feature.*` keys are not seeded yet; until then every deployment
/// ships the const defaults). Nothing else in the app may read flags from a
/// different source — this provider is the single seam.
final featureFlagsProvider = Provider<AppFeatureFlags>((ref) {
  return const AppFeatureFlags();
});

/// One-liner gating for screens: renders [child] when [flag] is enabled,
/// otherwise the [fallback] (default: a neutral "unavailable" empty state —
/// no coming-soon copy; the per-feature coming-soon screens were retired
/// when every gated feature shipped a real screen).
///
/// ```dart
/// GoRoute(
///   path: RoutePaths.mainEvents,
///   builder: (_, _) => FlagGate(
///     flag: AppFeatureFlag.events,
///     child: const EventsScreen(), // lands behind the flag, dark-first
///   ),
/// )
/// ```
class FlagGate extends ConsumerWidget {
  const FlagGate({
    super.key,
    required this.flag,
    required this.child,
    this.fallback,
  });

  final AppFeatureFlag flag;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(featureFlagsProvider).isEnabled(flag)) return child;
    return fallback ?? _defaultFallback(context);
  }

  /// The default disabled state: a neutral [VEmptyView] — centered icon +
  /// localized title/body. Used today only by the subscriptions kill-switch
  /// (RevenueCat key pending) and by any test flipping a live flag dark.
  Widget _defaultFallback(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VEmptyView(
      icon: Icons.hourglass_empty,
      title: l10n.featureUnavailableTitle,
      description: l10n.featureUnavailableBody,
    );
  }
}

/// [isEnabled] for widgets: `ref.isEnabled(AppFeatureFlag.events)`.
extension AppFeatureFlagsRefX on WidgetRef {
  bool isEnabled(AppFeatureFlag flag) =>
      read(featureFlagsProvider).isEnabled(flag);
}

/// [isEnabled] for providers and other `Ref` contexts (e.g. route gating
/// inside `routerProvider`, where only a `Ref` is available).
extension AppFeatureFlagsRef on Ref {
  bool isEnabled(AppFeatureFlag flag) =>
      read(featureFlagsProvider).isEnabled(flag);
}
