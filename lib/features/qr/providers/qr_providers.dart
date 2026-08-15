import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';

/// QR display-window seconds for the attendance-QR countdown
/// (`qr.display_countdown_seconds` from app_config, seed 15). The screen
/// consumes this via `.valueOrNull ?? 15`, so a failed config fetch is NOT
/// silently hidden: the provider rethrows (observable AsyncError) and the
/// countdown keeps the seed value.
final qrDisplayWindowProvider = FutureProvider<int>((ref) async {
  final config = await ref.read(configServiceProvider).fetchAppConfig();
  return int.tryParse(config['qr.display_countdown_seconds'] ?? '') ?? 15;
});

/// The current user's attendance-QR token row for an event
/// (`event_qr_tokens`, own-row RLS `eqt_read_own`), or `null` when the server
/// has not issued one yet — the pre-activation state (QRAT).
class MyQrTokenNotifier
    extends FamilyAsyncNotifier<Map<String, dynamic>?, String> {
  @override
  Future<Map<String, dynamic>?> build(String eventId) async {
    var row = await ref.read(eventServiceProvider).getMyQrToken(eventId);
    if (row == null) {
      // Self-issuing token (QRAT §Token Fetch Cycle / QEDG `rotate_token` —
      // SQL stand-in, migration 20260814000004): inside the activation
      // window the server issues the first token (returned as a row-shaped
      // map); before the window it answers `not_in_window` and the countdown
      // state stays.
      final issued = await ref.read(eventServiceProvider).rotateQrToken(eventId);
      if (issued != null && issued['status'] == 'ok') {
        return {
          'token': issued['token'],
          'expires_at': issued['expiresAt'],
        };
      }
    }
    return row;
  }

  /// Rotation contract (QRAT §Token Fetch Cycle / QEDG `rotate_token`): the
  /// client countdown calls this at 0s. The server-side rotation (SQL
  /// stand-in for the blocked `qr-token-manager` Edge Function) invalidates
  /// the previous token (`expires_at = now()`) and issues a new one
  /// atomically; the rebuild then re-reads the latest row. A server failure
  /// is logged (never silent) — the rebuild re-reads the current row and the
  /// countdown continues (graceful degradation, I-57).
  Future<void> rotate() async {
    try {
      await ref.read(eventServiceProvider).rotateQrToken(arg);
    } catch (e, st) {
      // Server unreachable — the refresh below shows the current token.
      AppLogger.instance.error('rotate_qr_token failed: $e', '$st');
    }
    ref.invalidateSelf();
  }
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
