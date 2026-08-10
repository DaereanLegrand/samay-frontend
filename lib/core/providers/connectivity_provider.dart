import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/services/connectivity_service.dart';

/// Live connectivity status: `true` = any network interface is available,
/// `false` = none (offline).
///
/// ## Optimistic by design (I-67)
///
/// The first state is [AsyncLoading] — consumers render `valueOrNull ?? true`
/// so the UI never flashes a false "offline" state while the platform's first
/// status is still arriving. Stream errors (e.g. the plugin being unavailable)
/// also fall back to connected via `valueOrNull` — fail-open: the banner is a
/// hint, never a gate.
///
/// Consumed by the global [ConnectivityBanner]; the offline-cache fallbacks
/// (I-71) will key off the same provider.
final connectivityProvider = StreamProvider.autoDispose<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onConnectivityChanged;
});
