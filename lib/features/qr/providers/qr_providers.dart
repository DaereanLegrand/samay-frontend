/// Outcome of a `validate_code` RPC call.
enum QrScanResult {
  confirmed,
  alreadyScanned,
  notInvited,
  notInWindow,
  notHost,
  invalidCode,
}

/// Maps the RPC payload (`status` field, 07_code.sql) to the typed outcome
/// the scanner UI switches on. Unknown/missing statuses fall back to
/// [QrScanResult.invalidCode].
QrScanResult qrScanResultFromMap(Map<String, dynamic>? data) {
  final status = data?['status'] as String? ?? 'invalid_code';
  return switch (status) {
    'confirmed' => QrScanResult.confirmed,
    'already_scanned' => QrScanResult.alreadyScanned,
    'not_invited' => QrScanResult.notInvited,
    'not_in_window' => QrScanResult.notInWindow,
    'not_host' => QrScanResult.notHost,
    _ => QrScanResult.invalidCode,
  };
}
