library;
import 'dart:typed_data';

import 'package:samay/crypto/constants.dart';
import 'package:samay/crypto/e2ee_primitives.dart';

/// X3DH key agreement (R1 §3) with the Samay parameters of
/// E2EE-ARCHITECTURE.md §5: X25519, SHA-256, HKDF info
/// `samay.e2ee.x3dh.v1`, the 32×0xFF `F` marker, and the Ed25519 prekey
/// signature (decision D-2 — XEdDSA is not available in `package:cryptography`).
/// Bob's published prekey bundle as fetched from the server (§5.3).
///
/// `signature` is `Ed25519(IK_sig_B_priv, Encode(SPKB))` — the 32-byte
/// X25519 public key itself, per §3.2/§5.1.
class PrekeyBundle {
  const PrekeyBundle({
    required this.identityKey,
    required this.identitySigKey,
    required this.signedPrekeyId,
    required this.signedPrekey,
    required this.signature,
    this.oneTimePrekeyId,
    this.oneTimePrekey,
  });

  /// Bob's identity DH key (IK_dh_B, 32 bytes).
  final Uint8List identityKey;

  /// Bob's identity signing key (IK_sig_B, 32 bytes, Ed25519 public).
  final Uint8List identitySigKey;

  final int signedPrekeyId;

  /// Bob's signed prekey public (SPKB, 32 bytes) — Alice's initial ratchet key.
  final Uint8List signedPrekey;

  /// Ed25519 signature over `signedPrekey` (64 bytes).
  final Uint8List signature;

  /// One-time prekey id/public, null when the server store is empty (§5.3).
  final int? oneTimePrekeyId;
  final Uint8List? oneTimePrekey;
}

/// Result of the initiator side of X3DH (§5.3).
class X3dhInitiateResult {
  const X3dhInitiateResult({
    required this.sharedSecret,
    required this.ephemeralPublicKey,
  });

  /// The 32-byte shared secret SK feeding RatchetInitAlice.
  final Uint8List sharedSecret;

  /// Alice's X3DH ephemeral public key EKA (goes into the init envelope).
  /// The ephemeral private key is discarded after `x3dhInitiate` returns
  /// (§5.3 step 4: delete EKA_priv and DH outputs from memory).
  final Uint8List ephemeralPublicKey;
}

/// Initiator side of X3DH (Alice, §5.3).
///
/// 1. Verifies `Sig(IK_sig_B, Encode(SPKB))` — aborts with
///    [E2eeCryptoException] on failure (R1 §3.3, closes the forged-prekey
///    weak-forward-secrecy attack R1 §4.5).
/// 2. Generates ephemeral EKA and computes DH1..DH4.
/// 3. `SK = HKDF(salt = 0x00×32, ikm = F ‖ DH1 ‖ DH2 ‖ DH3 [‖ DH4],
///    info = "samay.e2ee.x3dh.v1", L = 32)`.
///
/// The caller keeps [X3dhInitiateResult.ephemeralPublicKey] for the init
/// envelope; everything else is wiped.
Future<X3dhInitiateResult> x3dhInitiate({
  required Uint8List ourIdentityPrivateKey,
  required Uint8List ourIdentityPublicKey,
  required PrekeyBundle bundle,
}) async {
  final sigOk = await ed25519Verify(
    bundle.identitySigKey,
    bundle.signedPrekey,
    bundle.signature,
  );
  if (!sigOk) {
    throw const E2eeCryptoException(
      'X3DH aborted: signed prekey signature verification failed',
    );
  }

  final ourIdentity = E2eeKeyPair(
    privateKey: ourIdentityPrivateKey,
    publicKey: ourIdentityPublicKey,
    type: E2eeKeyType.x25519,
  );
  final ephemeral = await E2eeKeyPair.generate(type: E2eeKeyType.x25519);

  final dh1 = await dh(ourIdentity, bundle.signedPrekey);
  final dh2 = await dh(ephemeral, bundle.identityKey);
  final dh3 = await dh(ephemeral, bundle.signedPrekey);

  final marker = Uint8List.fromList(List.filled(e2eeX3dhFMarkerLength, 0xFF));
  final dhParts = <Uint8List>[dh1, dh2, dh3];
  if (bundle.oneTimePrekey != null) {
    final dh4 = await dh(ephemeral, bundle.oneTimePrekey!);
    dhParts.add(dh4);
  }

  final sk = await hkdfSha256(
    ikm: _concatIkM(marker, dhParts),
    salt: Uint8List(32),
    info: utf8Bytes(e2eeX3dhInfo),
    length: 32,
  );
  return X3dhInitiateResult(
    sharedSecret: sk,
    ephemeralPublicKey: Uint8List.fromList(ephemeral.publicKey),
  );
}

/// Responder side of X3DH (Bob, §5.4): recomputes the same DHs with the
/// stored private keypairs (identity, signed prekey, one-time prekey) and
/// returns the same 32-byte SK. The caller deletes the used one-time prekey
/// private key immediately after use (§5.4 step 2/6 — forward secrecy).
Future<Uint8List> x3dhRespond({
  required Uint8List ourIdentityPrivateKey,
  required E2eeKeyPair ourSignedPrekey,
  required Uint8List? ourOneTimePrekeyPrivateKey,
  required Uint8List theirIdentityPublicKey,
  required Uint8List theirEphemeralPublicKey,
}) async {
  final ourIdentity = E2eeKeyPair(
    privateKey: ourIdentityPrivateKey,
    publicKey: Uint8List(32), // public unused in the DH math below
    type: E2eeKeyType.x25519,
  );

  final dh1 = await dh(ourSignedPrekey, theirIdentityPublicKey);
  final dh2 = await dh(ourIdentity, theirEphemeralPublicKey);
  final dh3 = await dh(ourSignedPrekey, theirEphemeralPublicKey);

  final marker = Uint8List.fromList(List.filled(e2eeX3dhFMarkerLength, 0xFF));
  final dhParts = <Uint8List>[dh1, dh2, dh3];
  if (ourOneTimePrekeyPrivateKey != null) {
    final opk = E2eeKeyPair(
      privateKey: ourOneTimePrekeyPrivateKey,
      publicKey: Uint8List(32),
      type: E2eeKeyType.x25519,
    );
    final dh4 = await dh(opk, theirEphemeralPublicKey);
    dhParts.add(dh4);
  }

  return hkdfSha256(
    ikm: _concatIkM(marker, dhParts),
    salt: Uint8List(32),
    info: utf8Bytes(e2eeX3dhInfo),
    length: 32,
  );
}

Uint8List _concatIkM(Uint8List marker, List<Uint8List> parts) {
  var total = marker.length;
  for (final p in parts) {
    total += p.length;
  }
  final out = Uint8List(total);
  out.setRange(0, marker.length, marker);
  var offset = marker.length;
  for (final p in parts) {
    out.setRange(offset, offset + p.length, p);
    offset += p.length;
  }
  return out;
}
