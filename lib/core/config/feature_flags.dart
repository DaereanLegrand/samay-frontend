import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';

/// Every kept feature ships behind one of these flags (release gating). A flag
/// is the single release knob for its feature:
///
/// * **live** (`true`) — the feature ships in this build; the flag remains
///   wired as the kill-switch/remote-config knob.
/// * **dark** (`false`) — unreachable until its stack lands; gated screens
///   render the neutral [FlagGate] fallback.
///
/// Flags are read through [featureFlagsProvider] (overridable at app startup) —
/// never through a compile-time constant, so a flag can be flipped per
/// build/environment without a code change.
///
/// Slim build note: the removed features (events, chat, feed, photos,
/// rankings, shards, cosmetics) carry no flag because the code is gone. Adding
/// one back means adding the code, the flag and its entry point together.
enum AppFeatureFlag {
  /// Minigames — the app's whole purpose here. LIVE.
  minigames,

  /// QR join for multi-device partidas (scanner + lobby code). LIVE.
  qr,

  /// In-app notification center. LIVE.
  notifications,

  /// Push notifications (FCM/APNs).
  push,

  /// Prompt-pack purchases (RevenueCat). DARK until a store key is present.
  subscriptions,

  /// Dark-mode theme persistence.
  themePersistence,
}

/// The release-gating flag set. Immutable; every getter defaults to the
/// documented [AppFeatureFlag] state and can be overridden per build via the
/// const constructor (startup/remote-config seam, see [featureFlagsProvider]).
class AppFeatureFlags {
  const AppFeatureFlags({
    this.minigames = true,
    this.qr = true,
    this.notifications = true,
    this.push = false,
    this.subscriptions = false,
    this.themePersistence = false,
  });

  final bool minigames;
  final bool qr;
  final bool notifications;
  final bool push;
  final bool subscriptions;
  final bool themePersistence;

  /// Resolves [flag] to its current state.
  bool isEnabled(AppFeatureFlag flag) => switch (flag) {
    AppFeatureFlag.minigames => minigames,
    AppFeatureFlag.qr => qr,
    AppFeatureFlag.notifications => notifications,
    AppFeatureFlag.push => push,
    AppFeatureFlag.subscriptions => subscriptions,
    AppFeatureFlag.themePersistence => themePersistence,
  };

  @override
  bool operator ==(Object other) =>
      other is AppFeatureFlags &&
      other.minigames == minigames &&
      other.qr == qr &&
      other.notifications == notifications &&
      other.push == push &&
      other.subscriptions == subscriptions &&
      other.themePersistence == themePersistence;

  @override
  int get hashCode => Object.hash(
    minigames,
    qr,
    notifications,
    push,
    subscriptions,
    themePersistence,
  );
}

/// The app-wide flag set. Override in tests with
/// `overrideWithValue(AppFeatureFlags(notifications: false))`.
final featureFlagsProvider = Provider<AppFeatureFlags>((ref) {
  return const AppFeatureFlags();
});

/// One-liner gating for screens: renders [child] when [flag] is enabled,
/// otherwise the [fallback] (default: a neutral "unavailable" empty state).
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

  Widget _defaultFallback(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VEmptyView(
      icon: Icons.hourglass_empty,
      title: l10n.featureUnavailableTitle,
      description: l10n.featureUnavailableBody,
    );
  }
}

/// [isEnabled] for widgets: `ref.isEnabled(AppFeatureFlag.notifications)`.
extension AppFeatureFlagsRefX on WidgetRef {
  bool isEnabled(AppFeatureFlag flag) =>
      read(featureFlagsProvider).isEnabled(flag);
}

/// [isEnabled] for providers and other `Ref` contexts.
extension AppFeatureFlagsRef on Ref {
  bool isEnabled(AppFeatureFlag flag) =>
      read(featureFlagsProvider).isEnabled(flag);
}
