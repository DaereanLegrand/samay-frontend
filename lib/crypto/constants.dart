/// E2EE protocol constants (docs/security/E2EE-ARCHITECTURE.md §3, §6).
library;

/// Envelope magic bytes `0x53 0x4D 0x45 0x32` ("SME2").
const List<int> e2eeEnvelopeMagic = [0x53, 0x4D, 0x45, 0x32];

/// Envelope format version (E2EE §6.2). `0x02` is reserved for header
/// encryption / XEdDSA identity unification (§6.7).
const int e2eeEnvelopeVersion = 0x01;

/// Envelope type 0x01: X3DH init message (first message of a session).
const int e2eeEnvelopeTypeInit = 0x01;

/// Envelope type 0x02: Double Ratchet message.
const int e2eeEnvelopeTypeRatchet = 0x02;

/// `opk_id` value meaning "no one-time prekey was used" (§6.3).
const int e2eeNoOpkId = 0xFFFFFFFF;

/// Maximum number of message keys that may be skipped per chain (R2 §8.4,
/// decision D-7: 2000).
const int e2eeMaxSkip = 2000;

/// HKDF `info` strings — MUST be distinct per use (§3.1 domain separation).
const String e2eeX3dhInfo = 'samay.e2ee.x3dh.v1';
const String e2eeRatchetInfo = 'samay.e2ee.rk.v1';
const String e2eeAeadInfo = 'samay.e2ee.aead.v1';
const String e2eeFingerprintInfo = 'samay.e2ee.fingerprint.v1';

/// HMAC domain-separation key for the init-envelope replay marker
/// (X3DH §4.2 blacklist — a digest of public envelope fields).
const String e2eeInitMarkerInfo = 'samay.e2ee.init-marker.v1';

/// Session JSON schema version (§8.3).
const int e2eeSessionJsonVersion = 1;

/// AEAD expansion output: 32-byte AES-256 key ‖ 12-byte nonce (§4.1).
const int e2eeAeadKeyLength = 32;
const int e2eeAeadNonceLength = 12;
const int e2eeAeadExpandedLength = e2eeAeadKeyLength + e2eeAeadNonceLength; // 44

/// Full 128-bit GCM tag (no truncation, R2 §8.6).
const int e2eeTagLength = 16;

/// Hard cap on retained skipped message keys per session (§4.6).
const int e2eeMaxSkippedKeys = 2000;

/// Skipped message keys older than this are pruned on session save (§4.6).
const Duration e2eeSkippedKeyMaxAge = Duration(days: 30);

/// Inactive sessions older than this are deleted at app foreground (§7.7).
const Duration e2eeSessionMaxAge = Duration(days: 90);

/// A session replaced by a newer init envelope is kept as inactive (Sesame
/// §3.2 "insert then activate") for up to this long, so in-flight ciphertext
/// from the old session still decrypts (§7.2 — the MAXLATENCY analog).
const Duration e2eeRetiredSessionMaxAge = Duration(days: 30);

/// Upper bound on kept inactive sessions per chat (Sesame §6.5 bounded
/// storage — oldest are dropped from the tail when exceeded).
const int e2eeMaxInactiveSessions = 2;

/// Signed prekey rotation interval (§5.2: "e.g. once a week").
const Duration e2eeSignedPrekeyRotationAge = Duration(days: 7);

/// Signed prekey retention window after rotation (§5.2: the previous SPK
/// private key is kept for 7 more days to decrypt delayed init messages,
/// then deleted for forward secrecy).
const Duration e2eeSignedPrekeyRetentionAge = Duration(days: 7);

/// One-time prekey batch published per rotation (§5.1: 100).
const int e2eeOneTimePrekeyBatchSize = 100;

/// X3DH `F` marker for X25519: 32 bytes of 0xFF (R1 §2.2).
const int e2eeX3dhFMarkerLength = 32;

/// Ed25519 signature length (bytes).
const int e2eeEd25519SignatureLength = 64;
