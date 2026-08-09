library;
import 'dart:typed_data';

import 'package:samay/crypto/codec.dart';
import 'package:samay/crypto/constants.dart';

/// The Samay envelope: binary framing for X3DH init (type 0x01) and ratchet
/// (type 0x02) messages (E2EE-ARCHITECTURE.md §6). Big-endian, fixed-size
/// headers, `ciphertext ‖ tag` payload. The full frame is base64url-encoded
/// (no padding) by the session layer before it lands in `messages.content`
/// (§6.6).
///
/// `tryParse` validates length/magic/version/type BEFORE any crypto is
/// attempted (§6.5) and returns null for anything malformed — unknown
/// future versions are rejected cleanly.
class SamayEnvelope {
  const SamayEnvelope({
    required this.type,
    required this.senderIkDh,
    required this.senderIkSig,
    this.recipientIkDh,
    this.ekA,
    this.spkId,
    this.opkId,
    required this.dhPub,
    required this.pn,
    required this.n,
    required this.ciphertext,
  });

  /// `e2eeEnvelopeTypeInit` (0x01) or `e2eeEnvelopeTypeRatchet` (0x02).
  final int type;

  /// Sender X25519 identity public key (32 bytes) — the wire routing key.
  final Uint8List senderIkDh;

  /// Sender Ed25519 signing public key (32 bytes); zero bytes on type 0x02.
  final Uint8List senderIkSig;

  // --- type 0x01 (init) only ---

  /// Recipient IK_dh as the sender saw it — delivery binding (§6.3).
  final Uint8List? recipientIkDh;

  /// X3DH ephemeral public EKA.
  final Uint8List? ekA;

  /// Signed prekey id used.
  final int? spkId;

  /// One-time prekey id used; `e2eeNoOpkId` when none.
  final int? opkId;

  // --- both types: the ratchet header (§6.1) ---

  final Uint8List dhPub;
  final int pn;
  final int n;

  /// `ciphertext ‖ tag` (GCM).
  final Uint8List ciphertext;

  /// Fixed header size of the init envelope (§6.3): 186 bytes.
  static const int initHeaderSize =
      4 + 1 + 1 + 32 + 32 + 32 + 32 + 4 + 4 + 32 + 4 + 4 + 4;

  /// Fixed header size of the ratchet envelope (§6.4): 114 bytes.
  ///
  /// NOTE: the spec's §6.4 arithmetic prints "= 112" but its own field table
  /// (magic 4 + version 1 + type 1 + ik_dh 32 + ik_sig 32 + dh_pub 32 +
  /// pn 4 + n 4 + ct_len 4) sums to **114** — 112 is a typo in the document.
  /// The field table is authoritative (I-37 confirmed empirically: a 112-byte
  /// header misaligns the ciphertext by 2 bytes and every message fails AEAD).
  static const int ratchetHeaderSize = 4 + 1 + 1 + 32 + 32 + 32 + 4 + 4 + 4;

  /// Encodes the full binary frame (magic … ciphertext).
  Uint8List encode() {
    final header = switch (type) {
      e2eeEnvelopeTypeInit => concatBytes([
        Uint8List.fromList(e2eeEnvelopeMagic),
        u8be(e2eeEnvelopeVersion),
        u8be(e2eeEnvelopeTypeInit),
        senderIkDh,
        senderIkSig,
        recipientIkDh!,
        ekA!,
        u32be(spkId!),
        u32be(opkId!),
        dhPub,
        u32be(pn),
        u32be(n),
        u32be(ciphertext.length),
      ]),
      e2eeEnvelopeTypeRatchet => concatBytes([
        Uint8List.fromList(e2eeEnvelopeMagic),
        u8be(e2eeEnvelopeVersion),
        u8be(e2eeEnvelopeTypeRatchet),
        senderIkDh,
        senderIkSig,
        dhPub,
        u32be(pn),
        u32be(n),
        u32be(ciphertext.length),
      ]),
      _ => throw ArgumentError.value(type, 'type', 'invalid envelope type'),
    };
    return concatBytes([header, ciphertext]);
  }

  /// Parses a frame. Returns null for any malformed input (§6.5):
  /// wrong magic/version/type, truncation, or `ct_len` mismatch.
  static SamayEnvelope? tryParse(Uint8List bytes) {
    if (bytes.length < 4 + 1 + 1) return null;
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != e2eeEnvelopeMagic[i]) return null;
    }
    if (bytes[4] != e2eeEnvelopeVersion) return null;
    final type = bytes[5];

    switch (type) {
      case e2eeEnvelopeTypeInit:
        if (bytes.length < initHeaderSize) return null;
        final ctLen = readU32be(bytes, initHeaderSize - 4);
        if (bytes.length != initHeaderSize + ctLen) return null;
        return SamayEnvelope(
          type: type,
          senderIkDh: Uint8List.sublistView(bytes, 6, 38),
          senderIkSig: Uint8List.sublistView(bytes, 38, 70),
          recipientIkDh: Uint8List.sublistView(bytes, 70, 102),
          ekA: Uint8List.sublistView(bytes, 102, 134),
          spkId: readU32be(bytes, 134),
          opkId: readU32be(bytes, 138),
          dhPub: Uint8List.sublistView(bytes, 142, 174),
          pn: readU32be(bytes, 174),
          n: readU32be(bytes, 178),
          ciphertext: Uint8List.sublistView(bytes, 186),
        );
      case e2eeEnvelopeTypeRatchet:
        if (bytes.length < ratchetHeaderSize) return null;
        final ctLen = readU32be(bytes, ratchetHeaderSize - 4);
        if (bytes.length != ratchetHeaderSize + ctLen) return null;
        return SamayEnvelope(
          type: type,
          senderIkDh: Uint8List.sublistView(bytes, 6, 38),
          senderIkSig: Uint8List.sublistView(bytes, 38, 70),
          dhPub: Uint8List.sublistView(bytes, 70, 102),
          pn: readU32be(bytes, 102),
          n: readU32be(bytes, 106),
          ciphertext: Uint8List.sublistView(bytes, ratchetHeaderSize),
        );
      default:
        return null;
    }
  }
}
