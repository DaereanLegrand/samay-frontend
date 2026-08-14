library;
import 'dart:typed_data';

import 'package:samay/crypto/e2ee_primitives.dart';
import 'package:samay/crypto/x3dh.dart';

/// The four swappable E2EE interfaces (E2EE-ARCHITECTURE.md §10.4).
///
/// The chat layer (I-38) depends ONLY on these abstract types: swapping the
/// implementation (e.g. to `libsignal_protocol_dart` later) is a matter of
/// new concrete classes behind the same contracts — the UI never changes
/// (verified by V-06).
/// A user's long-term identity keypair set (E2EE §5.1, decision D-2):
/// X25519 DH identity + Ed25519 signing identity.
class E2eeIdentityKeys {
  const E2eeIdentityKeys({
    required this.ikDhPrivate,
    required this.ikDhPublic,
    required this.ikSigPrivate,
    required this.ikSigPublic,
    required this.registrationId,
  });

  final Uint8List ikDhPrivate;
  final Uint8List ikDhPublic;
  final Uint8List ikSigPrivate;
  final Uint8List ikSigPublic;

  /// `Random.secure()` uint32 in [1, 0x3FFF] (libsignal `generateRegistrationId`).
  final int registrationId;
}

/// A published signed prekey (SPK) with its Ed25519 signature.
class SignedPrekeyRecord {
  const SignedPrekeyRecord({
    required this.id,
    required this.keyPair,
    required this.signature,
    required this.createdAt,
  });

  final int id;
  final E2eeKeyPair keyPair;
  final Uint8List signature;
  final DateTime createdAt;
}

/// A published one-time prekey (OPK).
class OneTimePrekeyRecord {
  const OneTimePrekeyRecord({
    required this.id,
    required this.keyPair,
    required this.createdAt,
  });

  final int id;
  final E2eeKeyPair keyPair;
  final DateTime createdAt;
}

/// Device-local key material (E2EE §8 — flutter_secure_storage namespaces,
/// keys NEVER leave the device).
///
/// Concrete implementations: `SecureE2eeKeyStore`, `MemoryE2eeKeyStore`
/// (`lib/crypto/e2ee_key_store.dart`).
abstract class E2eeKeyStore {
  /// Loads or creates (once) the identity keypairs + registration id (§5.1).
  Future<E2eeIdentityKeys> loadOrCreateIdentity();

  /// The current signed prekey; rotates when older than 7 days (§5.2) and
  /// retains the previous SPK private key for 7 more days (delayed init
  /// messages).
  Future<SignedPrekeyRecord> currentSignedPrekey();

  /// Forces a signed prekey rotation.
  Future<void> rotateSignedPrekey();

  /// Number of unpublished one-time prekeys left in the store.
  Future<int> oneTimePrekeyCount();

  /// Generates and stores [n] fresh one-time prekeys (private keys local).
  Future<List<OneTimePrekeyRecord>> generateOneTimePrekeys(int n);

  /// Loads the private keypair for signed prekey [id] (current or retained).
  Future<E2eeKeyPair?> loadSignedPrekeyPrivate(int id);

  /// Loads the private keypair for one-time prekey [id], null if consumed.
  Future<E2eeKeyPair?> loadOneTimePrekeyPrivate(int id);

  /// Deletes a consumed one-time prekey (forward secrecy, R1 §3.4).
  Future<void> deleteOneTimePrekey(int id);

  /// Wipes ALL key material (identity, SPKs, OPKs) — called by
  /// `deleteAccount()` / `signOut()` (E2EE §7.6).
  Future<void> wipeAll();
}

/// Per-chat session persistence (E2EE §7.3, §8.2/§8.3).
///
/// Sessions are stored as JSON strings (`samay.e2ee.session.<chatId>`);
/// the store is deliberately format-agnostic apart from the lifecycle
/// fields it needs for the 90-day expiry sweep and the `ik_dh → chatId`
/// routing index (§7.1).
abstract class E2eeSessionStore {
  /// Loads the raw session JSON for [chatId]; null when absent or expired
  /// (idle past [e2eeSessionMaxAge], §7.7).
  Future<String?> loadSession(String chatId);

  /// Persists the session JSON (called after EVERY encrypt/decrypt, §7.3).
  Future<void> saveSession(String chatId, String json);

  /// Deletes the session for [chatId].
  Future<void> deleteSession(String chatId);

  /// `ik_dh (base64url) → chatId` routing index for inbound messages (§7.1).
  Future<Map<String, String>> sessionIndex();

  /// Deletes sessions idle past [maxAgeDays] days (app-foreground sweep).
  Future<void> sweepExpiredSessions({int maxAgeDays = 90});

  /// Wipes ALL persisted sessions for this account — called by
  /// `deleteAccount()` / `signOut()` together with `E2eeKeyStore.wipeAll`
  /// (E2EE §7.6: key material must not survive logout/account deletion).
  Future<void> wipeAll();
}

/// The chat-facing cipher contract. The concrete orchestrator is
/// `E2eeSession` (`lib/crypto/session.dart`).
abstract class E2eeMessageCipher {
  /// Encrypts [plaintext] for the peer and returns the wire envelope as a
  /// base64url (no padding) string — stored opaquely in `messages.content`
  /// (E2EE §6.6). The first message of a session is a type-0x01 init
  /// envelope; everything after is type-0x02.
  Future<String> encrypt({
    required String chatId,
    required String peerUserId,
    required String plaintext,
  });

  /// Decrypts an envelope. Returns null when the message is undecryptable
  /// (garbage, tampered, unknown session, expired) — the caller drops it.
  Future<String?> decrypt({
    required String chatId,
    required String peerUserId,
    required String envelope,
  });

  /// True when the peer's published identity key differs from the one bound
  /// to the stored session (reinstall / device change, E2EE §7.5).
  Future<bool> peerIdentityChanged(String peerUserId);
}

/// Server prekey RPCs (§9.3 — `fetch_prekey_bundle`, `publish_prekeys`).
/// The Supabase-backed implementation ships with I-38; I-37 only defines the
/// contract (and tests use an in-memory fake server).
abstract class E2eePrekeyService {
  /// Fetches the peer's current prekey bundle (rate-limited server-side,
  /// §5.5). Null when the peer has no published keys.
  Future<PrekeyBundle?> fetchBundle(String peerUserId);

  /// Publishes identity + signed prekey + one-time prekeys for the local
  /// user (called at profile creation and on SPK rotation, §9.3).
  Future<void> publishAll();
}
