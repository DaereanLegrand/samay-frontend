library;
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:samay/crypto/constants.dart';

/// Pure cryptographic layer over `package:cryptography` (Apache-2.0, dint.dev)
/// for the Samay E2EE stack (E2EE-ARCHITECTURE.md §3).
///
/// All operations are asynchronous (the underlying package is), take and
/// return raw `Uint8List` bytes, and never leak opaque key objects into the
/// ratchet/session layer. `aesGcmDecrypt` fails *cleanly* (returns null on
/// authentication failure) — callers decide how to surface it.
/// Key algorithm discriminator for [E2eeKeyPair].
enum E2eeKeyType { x25519, ed25519 }

/// A 32-byte private / 32-byte public keypair in memory.
///
/// [E2eeKeyPair.fromSeed] is deterministic (fixed seed → fixed pair), which
/// is what makes the known-answer test suite possible. [generate] uses the
/// platform CSPRNG (`cryptography` defaults to `Random.secure()`).
class E2eeKeyPair {
  const E2eeKeyPair({
    required this.privateKey,
    required this.publicKey,
    required this.type,
  });

  final Uint8List privateKey;
  final Uint8List publicKey;
  final E2eeKeyType type;

  static Future<E2eeKeyPair> generate({required E2eeKeyType type}) async {
    final keyPair = switch (type) {
      E2eeKeyType.x25519 => await X25519().newKeyPair(),
      E2eeKeyType.ed25519 => await Ed25519().newKeyPair(),
    };
    final data = await keyPair.extract();
    return E2eeKeyPair(
      privateKey: Uint8List.fromList(data.bytes),
      publicKey: Uint8List.fromList(data.publicKey.bytes),
      type: type,
    );
  }

  static Future<E2eeKeyPair> fromSeed(
    Uint8List seed, {
    required E2eeKeyType type,
  }) async {
    final keyPair = switch (type) {
      E2eeKeyType.x25519 => await X25519().newKeyPairFromSeed(seed),
      E2eeKeyType.ed25519 => await Ed25519().newKeyPairFromSeed(seed),
    };
    final data = await keyPair.extract();
    return E2eeKeyPair(
      privateKey: Uint8List.fromList(data.bytes),
      publicKey: Uint8List.fromList(data.publicKey.bytes),
      type: type,
    );
  }
}

/// Root exception of the E2EE stack. Thrown for protocol-level failures
/// (bad signatures, missing chains, invalid state); *not* for AEAD
/// authentication failures (those return null via `aesGcmDecrypt`).
class E2eeCryptoException implements Exception {
  const E2eeCryptoException(this.message);
  final String message;

  @override
  String toString() => 'E2eeCryptoException: $message';
}

/// X25519 Diffie-Hellman between [ourKeyPair] (X25519) and [theirPublicKey]
/// (32 bytes). Returns the 32-byte shared secret.
///
/// `DH(a, B)` is symmetric: `dh(a, B) == dh(b, A)` (RFC 7748).
Future<Uint8List> dh(E2eeKeyPair ourKeyPair, Uint8List theirPublicKey) async {
  final algorithm = X25519();
  final keyPair = await algorithm.newKeyPairFromSeed(ourKeyPair.privateKey);
  final shared = await algorithm.sharedSecretKey(
    keyPair: keyPair,
    remotePublicKey: SimplePublicKey(theirPublicKey, type: KeyPairType.x25519),
  );
  return Uint8List.fromList(await shared.extractBytes());
}

/// RFC 5869 HKDF-SHA256: `deriveKey(ikm, salt, info, length)`.
///
/// Mapping to the `cryptography` API (the package calls the HKDF salt
/// "nonce"): `secretKey = ikm`, `nonce = salt`, `info = info`.
/// A null [salt] is treated as `0x00 × 32` (HKDF semantics), which is the
/// X3DH salt (§3.1) and the AEAD expansion salt (§4.1). [info] is raw
/// bytes — the Samay domain-separation strings are ASCII (`utf8Bytes`).
Future<Uint8List> hkdfSha256({
  required Uint8List ikm,
  Uint8List? salt,
  required Uint8List info,
  required int length,
}) async {
  final derived = await Hkdf(
    hmac: Hmac.sha256(),
    outputLength: length,
  ).deriveKey(
    secretKey: SecretKey(ikm),
    nonce: salt ?? List<int>.filled(32, 0),
    info: info,
  );
  return Uint8List.fromList(await derived.extractBytes());
}

Uint8List utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value));

/// Deterministic 32-byte fingerprint of [data] — the init-envelope replay
/// marker (X3DH §4.2 blacklist). Implemented as HMAC-SHA256 with a fixed
/// public domain-separation key (the marker is a digest of public envelope
/// fields, never secret; the constant key only separates the domain).
Future<Uint8List> sha256Digest(Uint8List data) async {
  return hmacSha256(utf8Bytes(e2eeInitMarkerInfo), data);
}

/// HMAC-SHA256 (RFC 2104) of [data] keyed by [key].
Future<Uint8List> hmacSha256(Uint8List key, Uint8List data) async {
  final mac = await Hmac.sha256().calculateMac(data, secretKey: SecretKey(key));
  return Uint8List.fromList(mac.bytes);
}

/// The symmetric-ratchet chain step `KDF_CK`:
///
/// ```
/// ck_next = HMAC-SHA256(key = ck, data = 0x02)
/// mk = HMAC-SHA256(key = ck, data = 0x01)
/// ```
///
/// Returns `(nextChainKey, messageKey)` — deterministic, both 32 bytes.
Future<({Uint8List nextChainKey, Uint8List messageKey})> deriveMessageKey(
  Uint8List chainKey,
) async {
  final messageKey = await hmacSha256(chainKey, Uint8List.fromList([0x01]));
  final nextChainKey = await hmacSha256(chainKey, Uint8List.fromList([0x02]));
  return (nextChainKey: nextChainKey, messageKey: messageKey);
}

/// Expands a 32-byte message key into the AEAD key + nonce pair (§4.1):
///
/// ```
/// (key32, nonce12) = HKDF-SHA256(salt = 0x00×32, ikm = mk,
///                                info = "samay.e2ee.aead.v1", L = 44)
/// ```
///
/// The nonce is *derived from the message key* — never random, never
/// transmitted. Since each message key is used exactly
/// once, the nonce is unique per (key, message) by construction.
Future<Uint8List> expandMessageKey(Uint8List messageKey) => hkdfSha256(
  ikm: messageKey,
  salt: Uint8List(32),
  info: utf8Bytes(e2eeAeadInfo),
  length: e2eeAeadExpandedLength,
);

/// AES-256-GCM encryption. [key] is 32 bytes, [nonce] 12 bytes.
/// Returns `ciphertext ‖ tag` — the layout used by
/// the envelope (§6.3/§6.4 `ciphertext` field).
Future<Uint8List> aesGcmEncrypt({
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List plaintext,
  required Uint8List aad,
}) async {
  final cipher = AesGcm.with256bits();
  final box = await cipher.encrypt(
    plaintext,
    secretKey: SecretKey(key),
    nonce: nonce,
    aad: aad,
  );
  return concatWithTag(box);
}

/// AES-256-GCM decryption of `ciphertext ‖ tag`.
///
/// Returns null on ANY authentication failure (wrong key, tampered
/// ciphertext, tampered tag, wrong nonce, wrong aad) — never throws raw
/// package exceptions. Length < tag is a clean failure, not an exception.
Future<Uint8List?> aesGcmDecrypt({
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List ciphertext,
  required Uint8List aad,
}) async {
  if (ciphertext.length < e2eeTagLength) return null;
  final cipher = AesGcm.with256bits();
  final box = SecretBox(
    Uint8List.sublistView(ciphertext, 0, ciphertext.length - e2eeTagLength),
    nonce: nonce,
    mac: Mac(Uint8List.sublistView(ciphertext, ciphertext.length - e2eeTagLength)),
  );
  try {
    final clear = await cipher.decrypt(box, secretKey: SecretKey(key), aad: aad);
    return Uint8List.fromList(clear);
  } on SecretBoxAuthenticationError {
    return null;
  } catch (_) {
    return null;
  }
}

/// Constant-time byte comparison. Different lengths return false without
/// leaking length difference via early return (both loops run to the end of
/// the shorter input).
bool constantTimeEquals(Uint8List a, Uint8List b) {
  final len = a.length < b.length ? a.length : b.length;
  var diff = a.length ^ b.length;
  for (var i = 0; i < len; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Ed25519 signature over [message] with the 32-byte [privateKey] seed.
Future<Uint8List> ed25519Sign(Uint8List privateKey, Uint8List message) async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(privateKey);
  final signature = await algorithm.sign(message, keyPair: keyPair);
  return Uint8List.fromList(signature.bytes);
}

/// Verifies a 64-byte Ed25519 [signature] over [message] against
/// [publicKey]. Returns false on any mismatch (never throws).
Future<bool> ed25519Verify(
  Uint8List publicKey,
  Uint8List message,
  Uint8List signature,
) async {
  if (signature.length != e2eeEd25519SignatureLength) return false;
  try {
    return await Ed25519().verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
  } on ArgumentError {
    return false;
  }
}

Uint8List concatWithTag(SecretBox box) {
  final out = Uint8List(box.cipherText.length + box.mac.bytes.length);
  out.setRange(0, box.cipherText.length, box.cipherText);
  out.setRange(box.cipherText.length, out.length, box.mac.bytes);
  return out;
}
