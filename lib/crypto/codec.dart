library;
import 'dart:convert';
import 'dart:typed_data';

/// Binary framing and base64url helpers for the Samay envelope
/// (E2EE-ARCHITECTURE.md §6). All integers are big-endian (network byte order).
/// Encodes [value] as one byte.
Uint8List u8be(int value) => Uint8List.fromList([value & 0xFF]);

/// Encodes [value] as four big-endian bytes (u32).
Uint8List u32be(int value) => Uint8List.fromList([
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
]);

/// Reads one byte at [offset].
int readU8(Uint8List bytes, int offset) => bytes[offset];

/// Reads four big-endian bytes at [offset] as an unsigned 32-bit integer.
int readU32be(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

/// Concatenates [parts] into one byte sequence.
Uint8List concatBytes(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (sum, p) => sum + p.length);
  final out = Uint8List(total);
  var offset = 0;
  for (final part in parts) {
    out.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return out;
}

/// Encodes the fixed 40-byte ratchet header `dh_pub(32) ‖ pn(4) ‖ n(4)`
/// (E2EE §6.1 `header_bytes`). Single definition shared by the ratchet AD
/// and the envelope framing so the two can never drift apart.
Uint8List encodeHeaderBytes(Uint8List dhPub, int pn, int n) =>
    concatBytes([Uint8List.fromList(dhPub), u32be(pn), u32be(n)]);

/// Base64url (RFC 4648 §5, no padding) — the wire encoding of the envelope
/// stored in `messages.content` (E2EE §6.6).
String base64UrlNoPadEncode(Uint8List bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Decodes base64url text (padding tolerated, rejected input → null).
Uint8List? base64UrlNoPadDecode(String text) {
  try {
    final normalized = base64Url.normalize(text);
    return Uint8List.fromList(base64Url.decode(normalized));
  } on FormatException {
    return null;
  }
}
