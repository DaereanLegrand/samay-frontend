import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injection seam for the `connectivity_plus` plugin (a platform plugin that
/// cannot run in widget tests): callers/tests substitute this function
/// instead of mocking the platform channel — the same pattern as
/// [PermissionService]'s injectable seams.
typedef ConnectivityStream = Stream<bool> Function();

/// Injection seam for the one-shot connectivity check.
typedef ConnectivityCheck = Future<bool> Function();

/// Collapses a `connectivity_plus` status report into the boolean the UI
/// needs: `none` → false (offline), any interface → true (online).
///
/// Pure function — unit-testable without the plugin. `connectivity_plus`
/// guarantees the list is never empty and only ever contains `none` as its
/// single element when offline; an empty list would be treated as offline
/// (fail-safe).
bool hasNetworkConnection(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

Stream<bool> _defaultStream() =>
    Connectivity().onConnectivityChanged.map(hasNetworkConnection);

Future<bool> _defaultCheck() async =>
    hasNetworkConnection(await Connectivity().checkConnectivity());

/// Single seam for every connectivity need in the app: the global
/// offline banner today, the offline-cache fallbacks tomorrow. All
/// future network-status code must go through this service instead of calling
/// `connectivity_plus` directly, so the `none`→offline mapping stays
/// consistent and testable.
///
/// Both platform calls are injectable ([onConnectivityChanged], [isConnected])
/// — the default implementations talk to the plugin, tests substitute fakes.
/// Note: the plugin reports *interface* availability, not internet reachability
/// (a captive-portal Wi-Fi still reports `wifi`) — errors keep surfacing as
/// errors; the banner is an UX hint, not a gate.
class ConnectivityService {
  ConnectivityService({
    ConnectivityStream? onConnectivityChanged,
    ConnectivityCheck? isConnected,
  })  : _onConnectivityChanged = onConnectivityChanged ?? _defaultStream,
        _isConnected = isConnected ?? _defaultCheck;

  final ConnectivityStream _onConnectivityChanged;
  final ConnectivityCheck _isConnected;

  /// Live stream of connected/offline transitions (true = any network
  /// interface, false = none). The plugin already applies distinct, so
  /// duplicate status reports do not produce duplicate events.
  Stream<bool> get onConnectivityChanged => _onConnectivityChanged();

  /// One-shot check of the current status.
  Future<bool> isConnected() => _isConnected();
}

/// Riverpod wiring for [ConnectivityService]. Override in tests to
/// inject a fake stream/check and exercise the banner, providers, and future
/// offline-cache consumers in isolation.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});
