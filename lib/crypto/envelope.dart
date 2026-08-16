library;
import 'dart:typed_data';

import 'package:samay/crypto/codec.dart';
import 'package:samay/crypto/constants.dart';

/// The Samay envelope: binary framing for X3DH init (type 0x01), ratchet
/// (type 0x02) and sender-key (type 0x03) messages (E2EE-ARCHITECTURE.md §6;
/// ISSUE 4 adds 0x03 for group chat). Big-endian, fixed-size headers,
/// `ciphertext ‖ tag` payload. The full frame is base64url-encoded (no
/// padding) by the session layer before it lands in `messages.content`
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
    this.groupId,
    this.chainIndex,
    required this.ciphertext,
  });

  /// `e2eeEnvelopeTypeInit` (0x01), `e2eeEnvelopeTypeRatchet` (0x02) or
  /// `e2eeEnvelopeTypeSenderKey` (0x03).
  final int type;

  /// Sender X25519 identity public key (32 bytes) — the wire routing key.
  final Uint8List senderIkDh;

  /// Sender Ed25519 signing public key (32 bytes); zero bytes on type 0x02,
  /// not framed on type 0x03.
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

  // --- types 0x01/0x02: the ratchet header (§6.1) ---

  final Uint8List dhPub;
  final int pn;
  final int n;

  // --- type 0x03 (sender key) only ---

  /// Group identity as 16 raw UUID bytes (ISSUE 4) — binds the sender-key
  /// chain to the group and routes decryption to the right record.
  final Uint8List? groupId;

  /// Sender chain index n — replay/out-of-order handling per sender chain.
  final int? chainIndex;

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

  /// Fixed header size of the sender-key envelope (ISSUE 4):
  /// magic 4 + version 1 + type 1 + sender_ik_dh 32 + group_id 16 +
  /// chain_index 4 + ct_len 4 = **62** bytes. No `sender_ik_sig`, no ratchet
  /// header — the group binding comes from `group_id` (in-header and in the
  /// AEAD associated data) and the sender binding from the distributed
  /// bundle's `ik_dh`.
  static const int senderKeyHeaderSize = 4 + 1 + 1 + 32 + 16 + 4 + 4;

  /// Constructs a type-0x03 sender-key envelope. The 0x01/0x02-only fields
  /// (`sender_ik_sig`, ratchet header) are not framed for this type; the
  /// main constructor's required fields are filled with placeholders.
  factory SamayEnvelope.senderKey({
    required Uint8List senderIkDh,
    required Uint8List groupId,
    required int chainIndex,
    required Uint8List ciphertext,
  }) {
    if (senderIkDh.length != 32) {
      throw ArgumentError.value(senderIkDh.length, 'senderIkDh', 'must be 32 bytes');
    }
    if (groupId.length != e2eeEnvelopeGroupIdLength) {
      throw ArgumentError.value(groupId.length, 'groupId', 'must be 16 bytes');
    }
    return SamayEnvelope(
      type: e2eeEnvelopeTypeSenderKey,
      senderIkDh: senderIkDh,
      senderIkSig: Uint8List(32),
      dhPub: Uint8List(0),
      pn: 0,
      n: 0,
      groupId: groupId,
      chainIndex: chainIndex,
      ciphertext: ciphertext,
    );
  }

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
      e2eeEnvelopeTypeSenderKey => concatBytes([
        Uint8List.fromList(e2eeEnvelopeMagic),
        u8be(e2eeEnvelopeVersion),
        u8be(e2eeEnvelopeTypeSenderKey),
        senderIkDh,
        groupId!,
        u32be(chainIndex!),
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
      case e2eeEnvelopeTypeSenderKey:
        if (bytes.length < senderKeyHeaderSize) return null;
        final ctLen = readU32be(bytes, senderKeyHeaderSize - 4);
        if (bytes.length != senderKeyHeaderSize + ctLen) return null;
        return SamayEnvelope(
          type: type,
          senderIkDh: Uint8List.sublistView(bytes, 6, 38),
          senderIkSig: Uint8List(32),
          dhPub: Uint8List(0),
          pn: 0,
          n: 0,
          groupId: Uint8List.sublistView(bytes, 38, 54),
          chainIndex: readU32be(bytes, 54),
          ciphertext: Uint8List.sublistView(bytes, senderKeyHeaderSize),
        );
      default:
        return null;
    }
  }
}

/// Converts a canonical hyphenated UUID string ("8-4-4-4-12" hex) into its
/// 16 raw bytes for the 0x03 envelope header (ISSUE 4). Throws
/// [ArgumentError] on malformed input (wrong length / non-hex characters).
Uint8List groupIdToBytes(String groupId) {
  final hex = groupId.replaceAll('-', '').toLowerCase();
  if (hex.length != e2eeEnvelopeGroupIdLength * 2) {
    throw ArgumentError.value(
        groupId, 'groupId', 'must be a canonical UUID string');
  }
  final out = Uint8List(e2eeEnvelopeGroupIdLength);
  for (var i = 0; i < e2eeEnvelopeGroupIdLength; i++) {
    final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    if (byte == null) {
      throw ArgumentError.value(
          groupId, 'groupId', 'must contain only hex characters');
    }
    out[i] = byte;
  }
  return out;
}

/// Formats 16 raw UUID bytes back into the canonical hyphenated string
/// (lower-case hex). Throws [ArgumentError] unless [bytes] is 16 bytes long.
String groupIdFromBytes(Uint8List bytes) {
  if (bytes.length != e2eeEnvelopeGroupIdLength) {
    throw ArgumentError.value(
        bytes.length, 'bytes', 'must be 16 bytes (a raw UUID)');
  }
  final hex =
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
