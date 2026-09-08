/// Outcome of a `validate_qr_token` RPC call (QRSC error-handling contract).
enum QrScanResult {
  confirmed,
  expired,
  alreadyScanned,
  notInvited,
  notInWindow,
  notHost,
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
    'not_host' => QrScanResult.notHost,
    _ => QrScanResult.invalidToken,
  };
}
