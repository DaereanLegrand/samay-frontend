import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';

/// QR display-window seconds for the attendance-QR countdown
/// (`qr.display_countdown_seconds` from app_config, seed 15). Falls back to
/// the seed value when the config table is unreachable — the QR still
/// rotates; only the label precision degrades.
final qrDisplayWindowProvider = FutureProvider<int>((ref) async {
  try {
    final config = await ref.read(configServiceProvider).fetchAppConfig();
    return int.tryParse(config['qr.display_countdown_seconds'] ?? '') ?? 15;
  } catch (_) {
    return 15;
  }
});

/// The current user's attendance-QR token row for an event
/// (`event_qr_tokens`, own-row RLS `eqt_read_own`), or `null` when the server
/// has not issued one yet — the pre-activation state (QRAT) or EEDG/QEDG
/// not deployed.
class MyQrTokenNotifier
    extends FamilyAsyncNotifier<Map<String, dynamic>?, String> {
  @override
  Future<Map<String, dynamic>?> build(String eventId) async {
    return ref.read(eventServiceProvider).getMyQrToken(eventId);
  }

  /// Rotation contract (QRAT §Token Fetch Cycle / QEDG `rotate_token`): the
  /// client countdown calls this at 0s. The server-side rotation (Edge
  /// Function `qr-token-manager` — QEDG/EEDG, blocked) will invalidate the
  /// previous token (`expires_at = now()`) and issue a new one. Until that
  /// lands, `rotate()` re-fetches the current token: a rotation that never
  /// happened server-side yields the same row and the client keeps showing
  /// the last token the server issued (graceful degradation — see the I-57
  /// daily log for the EEDG handoff).
  Future<void> rotate() async => ref.invalidateSelf();
}

/// The current user's attendance-QR token row for [eventId].
final myQrTokenProvider = AsyncNotifierProvider.family<MyQrTokenNotifier,
    Map<String, dynamic>?, String>(MyQrTokenNotifier.new);

/// Outcome of a `validate_qr_token` RPC call (QRSC error-handling contract).
enum QrScanResult {
  confirmed,
  expired,
  alreadyScanned,
  notInvited,
  notInWindow,
  notPromotor,
  invalidToken,
}

/// Maps the RPC payload (`status` field, migration 20260809000005) to the
/// typed outcome the scanner UI switches on. Unknown/missing statuses fall
/// back to [QrScanResult.invalidToken].
QrScanResult qrScanResultFromMap(Map<String, dynamic>? data) {
  final status = data?['status'] as String? ?? 'invalid_token';
  return switch (status) {
    'confirmed' => QrScanResult.confirmed,
    'expired' => QrScanResult.expired,
    'already_scanned' => QrScanResult.alreadyScanned,
    'not_invited' => QrScanResult.notInvited,
    'not_in_window' => QrScanResult.notInWindow,
    'not_promotor' => QrScanResult.notPromotor,
    _ => QrScanResult.invalidToken,
  };
}
