import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Attendance-code domain (Stage 5, 2026-09-08).
///
/// The attendance screen shows a plain QR encoding a 24-hex code derived
/// authenticator-style (TOTP-like) from a per-(event, attendee) secret + the
/// current time window:
///
///   code = left(hex(hmac_sha256("samay.code.v1:{counter}", secret)), 24)
///
/// This MUST byte-match the server derivation in 07_code.sql — the server is
/// authoritative at validation, so both sides must agree. The code rotates
/// every `code.window_seconds` (seed 10); the host/staff scanner reads the
/// QR's payload and validates it via the `validate_code` RPC.
/// Domain-separated per the crypto policy (approved: HMAC-SHA256).

/// Domain-separation prefix of the HMAC message (matches SQL exactly).
const String codeDomainPrefix = 'samay.code.v1:';

/// Number of hex digits each code carries (matches the server contract).
const int codeDigitCount = 24;

/// A fresh fetch of the attendee's code for one event, as the server returns
/// it (`get_my_code`, 07_code.sql): the current window's code plus everything
/// the device needs to derive later windows locally (secret + window bounds
/// in UTC epoch seconds).
@immutable
class CodeSession {
  const CodeSession({
    required this.code,
    required this.secret,
    required this.counter,
    required this.windowSeconds,
    required this.windowStart,
    required this.windowEnd,
    required this.serverNowMs,
  });

  /// The 24-hex code for [counter].
  final String code;

  /// 64-hex per-(event, attendee) HMAC secret. Held in memory only — never
  /// persisted, never logged.
  final String secret;

  /// Time-window counter that [code] belongs to.
  final int counter;

  /// Window length in seconds (code.window_seconds, seed 10).
  final int windowSeconds;

  /// UTC epoch seconds at which [counter]'s window began.
  final int windowStart;

  /// UTC epoch seconds at which [counter]'s window ends (code regenerates).
  final int windowEnd;

  /// The SERVER's UTC epoch milliseconds when this session was issued
  /// (`get_my_code`). The device anchors its (possibly skewed) wall clock to
  /// this so rotation and the border ring agree with the server's lattice.
  final int serverNowMs;

  factory CodeSession.fromJson(Map<String, dynamic> json) {
    return CodeSession(
      code: json['code'] as String,
      secret: json['secret'] as String,
      counter: (json['counter'] as num).toInt(),
      windowSeconds: (json['windowSeconds'] as num).toInt(),
      windowStart: (json['windowStart'] as num).toInt(),
      windowEnd: (json['windowEnd'] as num).toInt(),
      serverNowMs: (json['serverNowMs'] as num).toInt(),
    );
  }

  /// Derives the 24-hex code for [targetCounter] (>= current) from [secret].
  /// Used to pre-render the code at the next window boundary so regeneration
  /// is seamless — no network round-trip inside the event.
  Future<String> codeFor(int targetCounter) =>
      deriveCode(secret, targetCounter);
}

/// Outcome of a `get_my_code` fetch (mirrors the RPC statuses).
enum CodeFetchStatus { ok, notInWindow, notInvited }

/// A code fetch as the attendee screen needs it: a session when [ok], or a
/// non-fatal state (pre-activation / not invited) otherwise.
@immutable
class CodeFetch {
  const CodeFetch.ok(this.session, this.serverOffsetMs)
      : status = CodeFetchStatus.ok;
  const CodeFetch.notInWindow()
      : status = CodeFetchStatus.notInWindow,
        session = null,
        serverOffsetMs = 0;
  const CodeFetch.notInvited()
      : status = CodeFetchStatus.notInvited,
        session = null,
        serverOffsetMs = 0;

  final CodeFetchStatus status;
  final CodeSession? session;

  /// Server-clock minus device-wall-clock at fetch time, in milliseconds
  /// (measured as `serverNowMs - deviceMidpoint` around the RPC). 0 for every
  /// non-ok state. The screen adds it to `DateTime.now()` to read server time.
  final int serverOffsetMs;

  /// Maps the RPC jsonb payload to a [CodeFetch]; infra failures surface as
  /// thrown exceptions from the caller (provider AsyncError), never here.
  factory CodeFetch.fromRpc(Map<String, dynamic>? json, int serverOffsetMs) {
    final status = json?['status'] as String? ?? 'not_in_window';
    return switch (status) {
      'ok' => CodeFetch.ok(CodeSession.fromJson(json!), serverOffsetMs),
      'not_invited' => const CodeFetch.notInvited(),
      _ => const CodeFetch.notInWindow(),
    };
  }
}

/// Derives a 24-hex code for [secret] at [counter] (HMAC-SHA256, domain
/// separated). Async via `package:cryptography`; byte-identical to the
/// server's code derivation in 07_code.sql.
Future<String> deriveCode(String secretHex, int counter) async {
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode('$codeDomainPrefix$counter'),
    secretKey: SecretKey(_hexToBytes(secretHex)),
  );
  final full = _bytesToHex(mac.bytes);
  return full.substring(0, codeDigitCount);
}

List<int> _hexToBytes(String hex) {
  final bytes = List<int>.generate(hex.length ~/ 2, (i) {
    return int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  });
  return bytes;
}

String _bytesToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
