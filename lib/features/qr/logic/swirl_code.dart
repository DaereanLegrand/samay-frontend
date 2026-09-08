import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Swirl attendance-code domain (Stage 4, 2026-09-08).
///
/// The attendance screen shows a 24-hex code derived authenticator-style
/// (TOTP-like) from a per-(event, attendee) secret + the current time window:
///
///   code = left(hex(hmac_sha256("samay.swirl.v1:{counter}", secret)), 24)
///
/// This MUST byte-match the server derivation in
/// `public.event_swirl_code` (supabase/migrations/060_events/07_swirl.sql) —
/// the server is authoritative at validation, so both sides must agree.
/// Domain-separated per the crypto policy (approved: HMAC-SHA256).

/// Domain-separation prefix of the HMAC message (matches SQL exactly).
const String swirlDomainPrefix = 'samay.swirl.v1:';

/// Number of hex digits each swirl code carries (matches the server contract).
const int swirlDigitCount = 24;

/// A fresh fetch of the attendee's swirl for one event, as the server returns
/// it (`get_my_swirl_code`, 060_events/07_swirl.sql): the current window's
/// code plus everything the device needs to derive later windows locally
/// (secret + window bounds in UTC epoch seconds).
@immutable
class SwirlSession {
  const SwirlSession({
    required this.code,
    required this.secret,
    required this.counter,
    required this.windowSeconds,
    required this.windowStart,
    required this.windowEnd,
  });

  /// The 24-hex code for [counter].
  final String code;

  /// 64-hex per-(event, attendee) HMAC secret. Held in memory only — never
  /// persisted, never logged.
  final String secret;

  /// Time-window counter that [code] belongs to.
  final int counter;

  /// Window length in seconds (swirl.window_seconds, seed 30).
  final int windowSeconds;

  /// UTC epoch seconds at which [counter]'s window began.
  final int windowStart;

  /// UTC epoch seconds at which [counter]'s window ends (code regenerates).
  final int windowEnd;

  factory SwirlSession.fromJson(Map<String, dynamic> json) {
    return SwirlSession(
      code: json['code'] as String,
      secret: json['secret'] as String,
      counter: (json['counter'] as num).toInt(),
      windowSeconds: (json['windowSeconds'] as num).toInt(),
      windowStart: (json['windowStart'] as num).toInt(),
      windowEnd: (json['windowEnd'] as num).toInt(),
    );
  }

  /// Derives the 24-hex code for [targetCounter] (>= current) from [secret].
  /// Used to pre-render the code at the next window boundary so regeneration
  /// is seamless — no network round-trip inside the event.
  Future<String> codeFor(int targetCounter) =>
      deriveSwirlCode(secret, targetCounter);
}

/// Outcome of a `get_my_swirl_code` fetch (mirrors the RPC statuses).
enum SwirlFetchStatus { ok, notInWindow, notInvited }

/// A swirl fetch as the attendee screen needs it: a session when [ok], or a
/// non-fatal state (pre-activation / not invited) otherwise.
@immutable
class SwirlFetch {
  const SwirlFetch.ok(this.session) : status = SwirlFetchStatus.ok;
  const SwirlFetch.notInWindow()
      : status = SwirlFetchStatus.notInWindow,
        session = null;
  const SwirlFetch.notInvited()
      : status = SwirlFetchStatus.notInvited,
        session = null;

  final SwirlFetchStatus status;
  final SwirlSession? session;

  /// Maps the RPC jsonb payload to a [SwirlFetch]; infra failures surface as
  /// thrown exceptions from the caller (provider AsyncError), never here.
  factory SwirlFetch.fromRpc(Map<String, dynamic>? json) {
    final status = json?['status'] as String? ?? 'not_in_window';
    return switch (status) {
      'ok' => SwirlFetch.ok(SwirlSession.fromJson(json!)),
      'not_invited' => const SwirlFetch.notInvited(),
      _ => const SwirlFetch.notInWindow(),
    };
  }
}

/// Derives a 24-hex code for [secret] at [counter] (HMAC-SHA256, domain
/// separated). Async via `package:cryptography`; byte-identical to the
/// server's `event_swirl_code(secret, counter)`.
Future<String> deriveSwirlCode(String secretHex, int counter) async {
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode('$swirlDomainPrefix$counter'),
    secretKey: SecretKey(_hexToBytes(secretHex)),
  );
  final full = _bytesToHex(mac.bytes);
  return full.substring(0, swirlDigitCount);
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
