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

  /// The account uid this key material belongs to (Signal model, 2026-08-15:
  /// the identity persists across sign-out; it is bound to the account, not
  /// the session). Null on a fresh install. Used by the auth layer to wipe
  /// material when a DIFFERENT account signs in on the same device.
  Future<String?> ownerUid();

  /// Records the owning account uid after a fresh install / ownership wipe.
  Future<void> setOwnerUid(String uid);

  /// Wipes ALL key material (identity, SPKs, OPKs) — called by
  /// `deleteAccount()` and by the ownership guard on account switch
  /// (E2EE §7.6 — the identity survives a plain sign-out).
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

/// Decrypt outcome tri-state (Signal semantics, 2026-08-16).
///
/// The chat layer must distinguish a protocol-level SILENT drop (replay,
/// stale identity, missing prekey material, no session — Signal's
/// `DuplicateMessageException` / `NoSessionException` cases, which are
/// dropped without any user-visible error) from a GENUINE undecryptable
/// failure (tampered ciphertext / ratchet mismatch — the "Mensaje no
/// descifrable" bubble). The pre-fix `String?` contract conflated the two,
/// which turned replays and re-processed history into bubbles.
class E2eeDecryptResult {
  const E2eeDecryptResult.plaintext(this.plaintext)
      : dropped = false,
        failed = false;

  const E2eeDecryptResult.dropped()
      : plaintext = null,
        dropped = true,
        failed = false;

  const E2eeDecryptResult.failed()
      : plaintext = null,
        dropped = false,
        failed = true;

  /// The decrypted plaintext; null unless [dropped]/[failed] is false.
  final String? plaintext;

  /// True when the message must be silently dropped (duplicate/replay,
  /// stale identity, missing prekey, no session). Never bubbles, never
  /// deletes server-side rows.
  final bool dropped;

  /// True when the message is genuinely undecryptable (tampering / ratchet
  /// mismatch against an existing session) — the UI's bubble.
  final bool failed;
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

  /// Decrypts an envelope into a tri-state result: plaintext, a SILENT drop
  /// (duplicate/stale/missing-material — Signal drops these without any UI
  /// error), or a genuine failure (tampering — the undecryptable bubble).
  Future<E2eeDecryptResult> decrypt({
    required String chatId,
    required String peerUserId,
    required String envelope,
  });

  /// Whether [envelope] is a type-0x01 init (X3DH first message). The chat
  /// layer uses this to roll the session back when the INSERT of the init
  /// fails — otherwise the persisted session believes the init was delivered
  /// and every retry sends undecryptable ratchet messages to a peer that
  /// never received it (2026-08-15 session/insert atomicity bug).
  bool envelopeIsInit(String envelope);

  /// Discards the session: deletes it from the store and zeroes the in-memory
  /// key material (E2EE §7.4). The chat layer calls this to roll back an
  /// initiator session whose init envelope's INSERT failed — the next
  /// [encrypt] re-initiates fresh X3DH instead of resuming a session the
  /// peer never received.
  Future<void> wipe();

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

  /// Ensures the local bundle is published, but ONLY when nothing is
  /// published yet (E2EE §12.2 step 4 auth-lifecycle hook, wired 2026-08-15):
  /// called on session restore to heal accounts that predate the
  /// profile-creation publish — a peer without a bundle cannot receive a
  /// first message. No-op when the own row already exists.
  Future<void> handleMissingSession();
}
