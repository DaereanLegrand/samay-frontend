import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/crypto/codec.dart';
import 'package:samay/crypto/constants.dart';
import 'package:samay/crypto/e2ee_primitives.dart';
import 'package:samay/crypto/envelope.dart';
import 'package:samay/crypto/interfaces.dart';

/// E2EE group chat — Signal sender-key ("sender-key message") model
///
/// ## Model
///
/// Each member mints a random 32-byte sender-key chain ROOT for the group and
/// distributes it to every active member as a JSON [senderKeyBundleJson]
/// bundle carried as the PLAINTEXT of the ordinary pairwise Double Ratchet
/// session (a type-0x02/0x01 envelope stored in the group's `messages` rows).
/// Afterwards each message is encrypted ONCE with a key derived from the
/// sender's chain and stored as ONE row (type-0x03 envelope) — every member
/// holding the sender's chain decrypts it. This is the fan-out economy of
/// sender keys vs. the §9.6 per-recipient fan-out: one row, N decryptions.
///
/// ## Chain semantics (Signal sender-key chain, per §4.1 `KDF_CK`)
///
/// `deriveMessageKey(ck) → (ck', mk)`; message index n uses the mk derived at
/// the (n+1)-th step from the distributed root. The sender advances its chain
/// per send and discards the old chain key (forward secrecy). Receivers hold
/// the root and derive forward per message; a message with `n <= lastSeenN`
/// is a replay/duplicate/out-of-order and is dropped. Gaps (`n > lastSeenN`)
/// derive through and discard the skipped message keys. The chain is
/// one-way: nobody (not even the sender) can re-decrypt consumed messages.
///
/// ## Group & identity binding
///
/// - The envelope carries the group's UUID (16 raw bytes, §6.2-style fixed
///   header) AND the group is included in the AEAD associated data
///   (`utf8(groupChatId) ‖ groupId`) — a header tamper fails authentication.
/// - The distribution bundle carries the sender's `ik_dh`; decrypting a 0x03
///   envelope verifies the envelope's `sender_ik_dh` equals the stored
///   bundle's — mismatch is a protocol drop (reinstall / identity-change
///   protection, the Signal session-reset analogue).
/// - Like Signal sender keys, the chain authenticates possession of the key,
///   not the user: any member holding the chain can send as that member. The
///   server sees only ciphertext; confidentiality matches the 1:1 path.
///
/// ## Storage (E2EE §8.2 namespace family)
///
/// Records are persisted through [E2eeSessionStore] (itself prefixed
/// `samay.e2ee.session.`):
///
/// | Key (in the session store) | Contents |
/// |---|---|
/// | `group_sender_key:<groupId>:<senderUserId>` | `GroupSenderKeyRecord` JSON (v3: carries `chat_id` + `epoch`) |
/// | `group_sender_key_registry:<groupChatId>` | `{group_id, epoch, senders[], distributed_to{}}` — group-epoch owner + records enum + per-sender distribution target sets |
///
/// The registry bridges the chat layer's `chat_id` to the crypto `group_id`
/// so [membersMissingSenderKey] and [wipeGroupKeys] can enumerate records
/// without a key-listing method on [E2eeSessionStore]. It is written AFTER
/// every record save, so a crash in between leaves an orphan record that is
/// simply re-distributed (the member shows as missing) instead of stranding
/// a member without a chain.
///
///
/// A roster change (member added/removed) wipes the group keys and mints a
/// FRESH chain — a new epoch. The registry OWNS the group-level `epoch`
/// counter (v3): [wipeGroupKeys] never deletes the registry; it clears
/// `senders` + `distributed_to` and bumps the persisted epoch (creating the
/// registry at epoch 1 when absent). Every record minted afterwards stamps
/// the current registry epoch, and the distribution bundle carries it as
/// `epoch`.
///
/// Receivers use the epoch to tell a GENUINE rekey apart from a stale
/// same-epoch duplicate: [processSenderKeyBundle] accepts a bundle whose
/// epoch is HIGHER than the stored record's even when its `chain_index`
/// (0 on a fresh chain) is <= the record's `lastSeenN`. Without that, a
/// rekeyed message (index 0 of the new chain) would hit the old record's
/// replay check and be dropped while the sender still saw "read" ticks
/// (the row was delivered and `mark_messages_read` stamped it).
///
/// Protocol invariants enforced here:
///
/// - **Bounded chain walk (DoS):** the header `chain_index` is
///   attacker-controlled; [decrypt] drops the envelope when
///   `chainIndex - lastSeenN > e2eeSenderKeyMaxSkip` (mirrors
///   double_ratchet's MAX_SKIP) — no derivation, no record advancement.
/// - **Re-distribution:** the bundle carries `chain_index` =
///   the sender record's `lastSentN` so receivers position at the right
///   `lastSeenN` against the root (the invariant `root == C_{lastSeenN+1}`
///   must hold); the registry persists per-sender `distributed_to` target
///   sets so [membersMissingSenderKey] does not re-report members whose
///   bundle was already distributed; and [processSenderKeyBundle] has a
///   no-regress guard — a same-epoch stale/duplicate bundle (`chain_index <=
///   lastSeenN`) never overwrites a live record.
/// - **Epoch + identity rules:** a bundle from a HIGHER epoch (the
///   roster-change rekey) is accepted, a bundle from a LOWER epoch is
///   ignored, and within the SAME epoch only a higher `chain_index` (gap
///   heal) is accepted. An IDENTITY change supersedes the epoch guard: a
///   bundle whose `sender_ik_dh` differs from the stored record's is the
///   sender's genuine NEW identity (reinstall / account-switch /
///   device-change — the bundle arrives decrypted through the pairwise
///   session bound to the row's sender, RLS `sender_id = auth.uid()` on
///   insert; the E2EE §7.5 1:1 `peerIdentityChanged` heal analogue) and is
///   accepted even from a LOWER epoch, replacing the stored record. The
///   same-identity epoch rules above stay intact.
/// - **Distribution contract:**
///   [membersMissingSenderKey] is a PURE candidate computation
///   (active roster minus the sender minus the persisted `distributed_to`
///   targets) — it never persists. The chat layer calls
///   [markSenderKeyDistributed] AFTER each successful distribution-row
///   insert; a member whose pairwise session could not be established is
///   never recorded, so it stays missing for the next send.
/// - **Cross-group confusion guard:** records and bundles carry the chat id
///   (`chat_id`); [decrypt] requires the record loaded via the envelope's
///   `group_id` to belong to the chat the row actually arrived in —
///   mismatch is a silent protocol drop.
/// - **On-device migration:** record/registry JSON are version 3; older
///   state fails `fromJson` and is treated as ABSENT, so devices
///   re-distribute once and stabilize on v3 (no manual migration). An older
///   rekey bundle (epoch 0, no field) is rejected by the bundle-version
///   guard, so receivers never mis-apply an un-epoch'd bundle to a live
///   record.
///
/// ## Logging
///
/// Only identifiers and chain indices are logged — never plaintext, never
/// chain keys or message keys (session.dart discipline).
class GroupE2eeCipher {
  GroupE2eeCipher({
    required E2eeKeyStore keyStore,
    required E2eeSessionStore sessionStore,
    DateTime Function()? clock,
  }) : _keyStore = keyStore,
       _sessionStore = sessionStore,
       _clock = clock ?? DateTime.now;

  /// Record namespace: `group_sender_key:<groupId>:<senderUserId>` (the
  /// session store prepends its own `samay.e2ee.session.` prefix, so the
  /// effective secure-storage key is
  /// `samay.e2ee.session.group_sender_key:<groupId>:<senderUserId>`).
  static const String senderKeyKeyPrefix = 'group_sender_key:';

  /// Registry namespace: `group_sender_key_registry:<groupChatId>` (see the
  /// class doc — the enumeration bridge for [wipeGroupKeys]).
  static const String senderKeyRegistryKeyPrefix = 'group_sender_key_registry:';

  final E2eeKeyStore _keyStore;
  final E2eeSessionStore _sessionStore;
  final DateTime Function() _clock;

  E2eeIdentityKeys? _identity;

  Future<E2eeIdentityKeys> _identityKeys() async {
    _identity ??= await _keyStore.loadOrCreateIdentity();
    return _identity!;
  }

  // Public API (the chat-layer contract — wired by the service agent)

  /// Encrypts [plaintext] for the group as [senderUserId] and returns the
  /// base64url type-0x03 envelope (one row in `messages.content`).
  ///
  /// Creates the sender's chain on first use (32 random bytes from
  /// `Random.secure()`), derives the message key from the chain (index
  /// `lastSentN`), advances and persists the chain — the consumed chain key
  /// is zeroed in memory (forward secrecy). AEAD associated data =
  /// `utf8(groupChatId) ‖ groupId` (16 raw bytes), binding the message to
  /// the chat AND the crypto group.
  Future<String> encrypt({
    required String groupChatId,
    required String senderUserId,
    required String groupId,
    required String plaintext,
  }) async {
    final identity = await _identityKeys();
    final record = await _ensureOwnRecord(
      groupChatId: groupChatId,
      senderUserId: senderUserId,
      groupId: groupId,
    );
    final chainKey = base64UrlNoPadDecode(record.chainRoot);
    if (chainKey == null || chainKey.length != 32) {
      throw const E2eeCryptoException('corrupt sender-key chain record');
    }
    final derived = await deriveMessageKey(chainKey);
    final chainIndex = record.lastSentN;
    // Forward secrecy: the consumed chain key is dead — zero it in memory
    // before persisting the next one.
    chainKey.fillRange(0, chainKey.length, 0);
    await _saveRecord(
      groupChatId,
      groupId,
      record.copyWith(
        chainRoot: base64UrlNoPadEncode(derived.nextChainKey),
        lastSentN: chainIndex + 1,
      ),
    );

    final expanded = await expandMessageKey(derived.messageKey);
    final groupIdBytes = groupIdToBytes(groupId);
    final ciphertext = await aesGcmEncrypt(
      key: Uint8List.sublistView(expanded, 0, e2eeAeadKeyLength),
      nonce: Uint8List.sublistView(expanded, e2eeAeadKeyLength),
      plaintext: utf8Bytes(plaintext),
      aad: concatBytes([utf8Bytes(groupChatId), groupIdBytes]),
    );
    AppLogger.instance.debug(
      'e2ee group encrypt group=$groupId chat=$groupChatId '
      'sender=$senderUserId chainIndex=$chainIndex',
    );
    return base64UrlNoPadEncode(
      SamayEnvelope.senderKey(
        senderIkDh: identity.ikDhPublic,
        groupId: groupIdBytes,
        chainIndex: chainIndex,
        ciphertext: ciphertext,
      ).encode(),
    );
  }

  /// Builds the distribution bundle for [senderUserId]'s chain: a JSON string
  /// with the `samay.group_sender_key` marker, the group id, the sender's
  /// `ik_dh`, the chat id, the chain root (base64url), the sender's current
  /// `chain_index` (= `lastSentN` — the last message the receivers have
  /// seen; the chain root is ready for message `lastSentN + 1`) and the
  /// record's group `epoch`. Receivers accept a bundle whose epoch is higher
  /// than their stored record's — the roster-change rekey; within the same
  /// epoch the no-regress guard applies. The
  /// chat layer delivers it to each member as the PLAINTEXT of a pairwise
  /// ratchet message and routes inbound plaintexts through
  /// [isSenderKeyBundle].
  ///
  /// Creating the bundle creates the sender's chain when absent (so
  /// distribution always precedes or accompanies the first message).
  Future<String> senderKeyBundleJson({
    required String groupChatId,
    required String senderUserId,
    required String groupId,
  }) async {
    final record = await _ensureOwnRecord(
      groupChatId: groupChatId,
      senderUserId: senderUserId,
      groupId: groupId,
    );
    final identity = await _identityKeys();
    AppLogger.instance.debug(
      'e2ee group sender-key bundle produced group=$groupId chat=$groupChatId '
      'sender=$senderUserId epoch=${record.epoch}',
    );
    return jsonEncode({
      'v': e2eeSenderKeyBundleVersion,
      'kind': e2eeSenderKeyBundleKind,
      'group_id': groupId,
      'chat_id': groupChatId,
      'sender_user_id': senderUserId,
      'sender_ik_dh': base64UrlNoPadEncode(identity.ikDhPublic),
      'chain_root': record.chainRoot,
      'chain_index': record.lastSentN,
      'epoch': record.epoch,
      'created_at': record.createdAt.toIso8601String(),
    });
  }

  /// True when [plaintext] is a sender-key distribution bundle (marker
  /// check) — the chat layer routes pairwise plaintexts through this before
  /// rendering them as messages.
  Future<bool> isSenderKeyBundle(String plaintext) async {
    try {
      final decoded = jsonDecode(plaintext);
      return decoded is Map && decoded['kind'] == e2eeSenderKeyBundleKind;
    } on FormatException {
      return false;
    }
  }

  /// True when [plaintext] is a sender-key REQUEST (marker check) — the chat
  /// layer routes pairwise plaintexts through this BEFORE the bundle check (a
  /// request and a bundle are mutually exclusive kinds).
  Future<bool> isSenderKeyRequest(String plaintext) async {
    try {
      final decoded = jsonDecode(plaintext);
      return decoded is Map && decoded['kind'] == e2eeGroupKeyRequestKind;
    } on FormatException {
      return false;
    }
  }

  /// Builds the distribution REQUEST payload for a member whose device has
  /// no sender-key record for [missingSenderUserId]'s chain: a JSON string
  /// with the `samay.group_key_request` marker, the group id, the chat id
  /// and the id of the member whose chain is missing. The chat layer
  /// delivers it as the PLAINTEXT of a pairwise ratchet message addressed
  /// (via `messages.recipient_id`) to exactly that member — the Signal
  /// retry-request analogue. The
  /// requester's identity is the row's RLS-bound `sender_id`, never a
  /// self-attested field.
  Future<String> senderKeyRequestJson({
    required String groupChatId,
    required String groupId,
    required String missingSenderUserId,
  }) async {
    AppLogger.instance.debug(
      'e2ee group sender-key REQUEST produced group=$groupId chat=$groupChatId '
      'missingSender=$missingSenderUserId',
    );
    return jsonEncode({
      'v': e2eeGroupKeyRequestVersion,
      'kind': e2eeGroupKeyRequestKind,
      'group_id': groupId,
      'chat_id': groupChatId,
      'for_sender_user_id': missingSenderUserId,
    });
  }

  /// Validates a REQUEST payload against [groupChatId]/[groupId] and returns
  /// the id of the member whose chain is being requested (the chat layer
  /// acts on it ONLY when it equals the local user — a request for someone
  /// else's chain is ignored, the cross-chain confusion guard). Returns
  /// null for a malformed/foreign request (wrong marker, version, group id,
  /// chat id, or missing fields) — never throws.
  Future<String?> senderKeyRequestTarget({
    required String json,
    required String groupChatId,
    required String groupId,
  }) async {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    if (map['kind'] != e2eeGroupKeyRequestKind ||
        map['v'] != e2eeGroupKeyRequestVersion ||
        map['group_id'] != groupId ||
        map['chat_id'] != groupChatId) {
      return null;
    }
    final target = map['for_sender_user_id'];
    return target is String ? target : null;
  }

  /// Validates and persists a distribution bundle for [senderUserId]'s chain
  /// (the chat layer passes the message row's `sender_id` and the group's
  /// uuid). Invalid input is logged and ignored — never thrown to the UI:
  /// wrong marker/version, `group_id` mismatch, `chat_id` mismatch,
  /// `sender_user_id` mismatch, missing/malformed `ik_dh`, `chain_root`,
  /// `chain_index` or `epoch`, and the member's OWN bundle (its `ik_dh`
  /// equals the local identity — a replayed own distribution must not
  /// clobber the live sending chain).
  ///
  /// [expectedSenderIkDh]: the base64url X25519
  /// identity key BOUND to the pairwise session that delivered this bundle
  /// ([E2eeMessageCipher.boundPeerIkDh]). The bundle's `sender_ik_dh` is
  /// SELF-ATTESTED — the bundle minting device writes it — while
  /// `sender_user_id` is only RLS-bound to the row's sender. A malicious
  /// member can therefore mint a bundle with `sender_user_id = M` but
  /// `sender_ik_dh = <S's published key>` (learned legitimately), and
  /// receivers would accept it, breaking the identity binding. When
  /// [expectedSenderIkDh] is non-null the bundle is accepted ONLY if its
  /// `sender_ik_dh` constant-time-equals it — the pairwise session (X3DH,
  /// possession-based) authenticates the sender, not the bundle's
  /// self-claim. A mismatch is IGNORED on every acceptance path (fresh
  /// record, identity change, epoch rekey, gap heal). Null (no session /
  /// unknown peer) skips the binding check.
  ///
  /// Epoch-aware no-regress guard:
  ///
  /// - no existing record → accepted (fresh chain);
  /// - the bundle's `sender_ik_dh` differs from the stored record's —
  ///   reinstall / account-switch / device-change (the E2EE §7.5 1:1
  ///   `peerIdentityChanged` heal analogue) → ACCEPTED REGARDLESS OF EPOCH:
  ///   the bundle only ever arrives decrypted through the pairwise session
  ///   bound to the message row's `sender_id` (RLS `sender_id = auth.uid()`
  ///   on insert), so the pairwise session authenticates the sender's NEW
  ///   identity — the fresh chain supersedes the stored record even
  ///   when its epoch is lower;
  /// - `bundle.epoch > record.epoch` → ACCEPTED — a genuine rekey: the
  ///   roster-change wipe minted a fresh chain whose index restarts at 0,
  ///   so the `chain_index <= lastSeenN` guard MUST NOT apply (otherwise the
  ///   legitimate rekey bundle is swallowed, the receiver never learns the
  ///   new key, and every rekeyed message is dropped);
  /// - `bundle.epoch < record.epoch` → ignored (stale bundle from an old
  ///   epoch replaying after the rekey);
  /// - `bundle.epoch == record.epoch && chain_index <= lastSeenN` →
  ///   ignored;
  /// - `bundle.epoch == record.epoch && chain_index > lastSeenN` →
  ///   accepted (gap heal — the receiver is behind on the same chain).
  ///
  /// The stored record's `epoch` is the bundle's; `lastSeenN = chainIndex
  /// - 1` (the invariant `root == C_{lastSeenN+1}` holds unchanged). The
  /// accepted record's chain is fresh, so a rekeyed index 0 is decryptable.
  Future<void> processSenderKeyBundle({
    required String groupChatId,
    required String senderUserId,
    required String groupId,
    required String bundleJson,
    String? expectedSenderIkDh,
  }) async {
    final identity = await _identityKeys();
    final map = _decodeBundle(bundleJson, groupChatId);
    if (map == null) return;
    if (map['kind'] != e2eeSenderKeyBundleKind) {
      _ignore(groupChatId, 'wrong kind (${map['kind']})');
      return;
    }
    if (map['v'] != e2eeSenderKeyBundleVersion) {
      _ignore(groupChatId, 'unsupported version (${map['v']})');
      return;
    }
    if (map['group_id'] != groupId) {
      _ignore(groupChatId, 'group_id mismatch (${map['group_id']})');
      return;
    }
    if (map['chat_id'] != groupChatId) {
      _ignore(groupChatId, 'chat_id mismatch (${map['chat_id']})');
      return;
    }
    if (map['sender_user_id'] != senderUserId) {
      _ignore(groupChatId, 'sender_user_id mismatch (${map['sender_user_id']})');
      return;
    }
    final senderIkDh = map['sender_ik_dh'];
    final chainRoot = map['chain_root'];
    final chainIndex = map['chain_index'];
    final epoch = map['epoch'];
    if (senderIkDh is! String ||
        chainRoot is! String ||
        chainIndex is! int ||
        chainIndex < 0 ||
        epoch is! int ||
        epoch < 0) {
      _ignore(groupChatId,
          'missing or malformed sender_ik_dh/chain_root/chain_index/epoch');
      return;
    }
    final ikDhBytes = base64UrlNoPadDecode(senderIkDh);
    final rootBytes = base64UrlNoPadDecode(chainRoot);
    if (ikDhBytes == null || ikDhBytes.length != 32) {
      _ignore(groupChatId, 'sender_ik_dh is not a 32-byte key');
      return;
    }
    if (rootBytes == null || rootBytes.length != 32) {
      _ignore(groupChatId, 'chain_root is not a 32-byte key');
      return;
    }
    // Own-bundle echo: a replayed distribution of OUR OWN chain must not
    // replace the live sending chain (the distributed root is stale the
    // moment the first message is sent). Detected cryptographically — the
    // bundle's ik_dh is our own identity key.
    if (constantTimeEquals(ikDhBytes, identity.ikDhPublic)) {
      AppLogger.instance.debug(
        'e2ee group sender-key bundle IGNORED group=$groupId chat=$groupChatId '
        'sender=$senderUserId — own bundle echo (ik_dh is the local identity)',
      );
      return;
    }
    // Identity binding: the bundle's `sender_ik_dh`
    // is SELF-ATTESTED — the minting device writes it — while
    // `sender_user_id` is only RLS-bound to the message row. When the chat
    // layer passes the delivering pairwise session's BOUND peer identity
    // (E2eeMessageCipher.boundPeerIkDh) it MUST match the bundle's ik_dh, or
    // the bundle is ignored on every acceptance path — the pairwise session
    // (X3DH, possession-based) authenticates the sender. Null skips the check.
    final expected = expectedSenderIkDh;
    if (expected != null) {
      final expectedBytes = base64UrlNoPadDecode(expected);
      if (expectedBytes == null || expectedBytes.length != 32) {
        _ignore(groupChatId,
            'malformed expectedSenderIkDh (not a 32-byte X25519 key)');
        return;
      }
      if (!constantTimeEquals(ikDhBytes, expectedBytes)) {
        AppLogger.instance.warn(
          'e2ee group sender-key bundle IGNORED group=$groupId '
          'chat=$groupChatId sender=$senderUserId — bundle sender_ik_dh '
          'does not match the delivering pairwise session\'s bound peer '
          'identity; the bundle is never accepted',
        );
        return;
      }
    }
    // Epoch-aware no-regress guard: a stale bundle must never overwrite a
    // live record. Only a bundle from a HIGHER epoch (roster-change rekey),
    // a same-epoch gap heal (chain_index > lastSeenN), or a bundle whose
    // `sender_ik_dh` differs from the stored record's (reinstall /
    // account-switch / device-change — the sender's genuine NEW identity,
    // authenticated by the pairwise session the bundle arrived in) is
    // accepted.
    final existing = await _loadRecord(groupId, senderUserId);
    if (existing != null) {
      final existingIkDh = base64UrlNoPadDecode(existing.senderIkDh);
      final identityChanged =
          existingIkDh != null && !constantTimeEquals(ikDhBytes, existingIkDh);
      if (identityChanged) {
        // Identity change supersedes the epoch guard: the pairwise session
        // the bundle arrived in binds the row's sender_id to its NEW
        // identity (RLS `sender_id = auth.uid()` on insert), so the fresh
        // chain is the sender's genuine reinstall-era chain — it replaces
        // the pre-reinstall record even when its epoch is lower.
        AppLogger.instance.debug(
          'e2ee group sender-key bundle ACCEPTED group=$groupId '
          'chat=$groupChatId sender=$senderUserId — sender_ik_dh changed '
          '(reinstall / device change): the fresh chain (epoch=$epoch) '
          'supersedes the pre-reinstall record (epoch=${existing.epoch})',
        );
      } else if (epoch < existing.epoch) {
        AppLogger.instance.warn(
          'e2ee group sender-key bundle IGNORED group=$groupId '
          'chat=$groupChatId sender=$senderUserId — bundle epoch=$epoch < '
          'record epoch=${existing.epoch} (stale bundle from an old epoch; '
          'the rekeyed record is kept)',
        );
        return;
      } else if (epoch == existing.epoch && chainIndex <= existing.lastSeenN) {
        AppLogger.instance.warn(
          'e2ee group sender-key bundle IGNORED group=$groupId '
          'chat=$groupChatId sender=$senderUserId chain_index=$chainIndex '
          '— same-epoch stale/duplicate bundle (epoch=$epoch, <= existing '
          'lastSeenN=${existing.lastSeenN}; live record kept)',
        );
        return;
      }
    }
    await _saveRecord(
      groupChatId,
      groupId,
      GroupSenderKeyRecord(
        chatId: groupChatId,
        senderUserId: senderUserId,
        senderIkDh: senderIkDh,
        chainRoot: chainRoot,
        lastSentN: 0,
        // chain_index is the chain position at distribution; the next
        // acceptable index is chain_index, nothing below may be accepted
        // (Signal sender-key iteration semantics; -1 accepts index 0). The
        // invariant root == C_{lastSeenN+1} holds: the bundle's root is
        // ready for message chain_index + 1.
        lastSeenN: chainIndex - 1,
        epoch: epoch,
        createdAt: _clock(),
      ),
    );
    AppLogger.instance.debug(
      'e2ee group sender-key bundle processed group=$groupId chat=$groupChatId '
      'sender=$senderUserId chain_index=$chainIndex epoch=$epoch',
    );
  }

  /// Decrypts a type-0x03 envelope from [senderUserId]. Tri-state result:
  ///
  /// - `dropped` (silent, Signal semantics): undecodable/foreign envelope,
  ///   no record for the sender (NoSession), the record's chat binding does
  ///   not match the chat the row arrived in,
  ///   envelope `sender_ik_dh` != the stored bundle's (identity changed),
  ///   `n <= lastSeenN` (replay / duplicate / out-of-order), a chain gap
  ///   beyond [e2eeSenderKeyMaxSkip] (DoS cap — dropped WITHOUT deriving
  ///   anything and WITHOUT advancing the record), or the sender's own echo.
  /// - `failed` (the undecryptable bubble): AEAD authentication failure
  ///   (tampering). The chain is NOT advanced on failure (atomicity §4.5
  ///   analogue) — the record only advances on success.
  Future<E2eeDecryptResult> decrypt({
    required String groupChatId,
    required String senderUserId,
    required String envelope,
  }) async {
    final identity = await _identityKeys();
    final bytes = base64UrlNoPadDecode(envelope);
    if (bytes == null) return const E2eeDecryptResult.dropped();
    final parsed = SamayEnvelope.tryParse(bytes);
    if (parsed == null || parsed.type != e2eeEnvelopeTypeSenderKey) {
      return const E2eeDecryptResult.dropped();
    }
    final groupIdBytes = parsed.groupId;
    final chainIndex = parsed.chainIndex;
    if (groupIdBytes == null || chainIndex == null) {
      return const E2eeDecryptResult.dropped();
    }
    // Own-message echo: sender-key chains are one-way (forward secrecy) —
    // the sender discards every used key, so its own sent history is never
    // decryptable. The chat layer skips own rows; a stray echo is a
    // protocol drop, never a bubble.
    if (constantTimeEquals(parsed.senderIkDh, identity.ikDhPublic)) {
      return const E2eeDecryptResult.dropped();
    }
    final groupId = groupIdFromBytes(groupIdBytes);
    final record = await _loadRecord(groupId, senderUserId);
    if (record == null) {
      AppLogger.instance.warn(
        'e2ee group envelope DROPPED group=$groupId chat=$groupChatId '
        'sender=$senderUserId — no sender-key record (bundle never '
        'processed; Signal NoSession semantics)',
      );
      // missingChain: the drop is the requestable class — this device has
      // no chain material for the sender, so the chat layer asks the sender
      // to re-distribute.
      return const E2eeDecryptResult.dropped(missingChain: true);
    }
    // cross-group chat binding: the record is routed by the envelope's
    // groupId only, but it was distributed in ONE chat. A row carrying this
    // chain into ANY OTHER chat is a protocol drop — never shown there
    // (the AEAD aad binds the chat, but the chain itself must not leak
    // across chats either).
    if (record.chatId != groupChatId) {
      AppLogger.instance.warn(
        'e2ee group envelope DROPPED group=$groupId chat=$groupChatId '
        'sender=$senderUserId — record bound to chat ${record.chatId} '
        '(cross-group chain confusion)',
      );
      return const E2eeDecryptResult.dropped();
    }
    final storedIkDh = base64UrlNoPadDecode(record.senderIkDh);
    if (storedIkDh == null ||
        !constantTimeEquals(parsed.senderIkDh, storedIkDh)) {
      AppLogger.instance.warn(
        'e2ee group envelope DROPPED group=$groupId chat=$groupChatId '
        'sender=$senderUserId — envelope senderIkDh does not match the '
        'stored bundle (identity changed / session reset)',
      );
      // missingChain: the stored record is bound to a stale identity — this
      // device needs the sender's FRESH chain (reinstall-era bundle), so the
      // chat layer requests a re-distribution.
      return const E2eeDecryptResult.dropped(missingChain: true);
    }
    if (chainIndex <= record.lastSeenN) {
      AppLogger.instance.warn(
        'e2ee group envelope DROPPED group=$groupId chat=$groupChatId '
        'sender=$senderUserId chainIndex=$chainIndex — <= lastSeenN='
        '${record.lastSeenN} (replay / duplicate / out-of-order)',
      );
      return const E2eeDecryptResult.dropped();
    }
    // bounded gap walk: the header chain_index is attacker-controlled —
    // an unbounded derivation walk is a remote CPU DoS (u32-max index ≈
    // 4.29e9 HKDF steps, re-run on every reload/redelivery). Dart ints are
    // 64-bit, so the subtraction itself cannot overflow; a huge chainIndex
    // simply yields a huge gap. Drop WITHOUT deriving and WITHOUT advancing
    // the record (mirrors double_ratchet MAX_SKIP semantics).
    if (chainIndex - record.lastSeenN > e2eeSenderKeyMaxSkip) {
      AppLogger.instance.warn(
        'e2ee group envelope DROPPED group=$groupId chat=$groupChatId '
        'sender=$senderUserId chainIndex=$chainIndex — gap '
        '${chainIndex - record.lastSeenN} exceeds e2eeSenderKeyMaxSkip '
        '($e2eeSenderKeyMaxSkip) (bounded gap walk)',
      );
      return const E2eeDecryptResult.dropped();
    }
    final chainKey = base64UrlNoPadDecode(record.chainRoot);
    if (chainKey == null || chainKey.length != 32) {
      return const E2eeDecryptResult.dropped();
    }
    // Walk the chain from the record's position to chainIndex, discarding
    // every skipped message key (gap derivation). `current` ends as the
    // chain key for index chainIndex + 1.
    var current = chainKey;
    Uint8List messageKey = Uint8List(0);
    for (var i = record.lastSeenN + 1; i <= chainIndex; i++) {
      final step = await deriveMessageKey(current);
      current = step.nextChainKey;
      messageKey = step.messageKey;
      if (i < chainIndex) {
        step.messageKey.fillRange(0, step.messageKey.length, 0); // discarded
      }
    }
    final expanded = await expandMessageKey(messageKey);
    final plaintext = await aesGcmDecrypt(
      key: Uint8List.sublistView(expanded, 0, e2eeAeadKeyLength),
      nonce: Uint8List.sublistView(expanded, e2eeAeadKeyLength),
      ciphertext: parsed.ciphertext,
      aad: concatBytes([utf8Bytes(groupChatId), groupIdBytes]),
    );
    if (plaintext == null) {
      // AEAD failure — tampering. The chain must NOT advance: consuming the
      // message key here would silently desync this member (§4.5 atomicity).
      AppLogger.instance.warn(
        'e2ee group envelope FAILED group=$groupId chat=$groupChatId '
        'sender=$senderUserId chainIndex=$chainIndex — AEAD authentication '
        'failure (tampering)',
      );
      return const E2eeDecryptResult.failed();
    }
    await _saveRecord(
      groupChatId,
      groupId,
      record.copyWith(
        chainRoot: base64UrlNoPadEncode(current),
        lastSeenN: chainIndex,
      ),
    );
    try {
      return E2eeDecryptResult.plaintext(utf8.decode(plaintext));
    } on FormatException {
      AppLogger.instance.warn(
        'e2ee group envelope FAILED group=$groupId chat=$groupChatId '
        'sender=$senderUserId chainIndex=$chainIndex — authenticated '
        'plaintext is not valid UTF-8',
      );
      return const E2eeDecryptResult.failed();
    }
  }

  /// True when [envelope] is a type-0x03 sender-key message — the chat layer
  /// routes inbound rows through this before the pairwise 1:1 path.
  Future<bool> isSenderKeyEnvelope(String envelope) async {
    final bytes = base64UrlNoPadDecode(envelope);
    if (bytes == null) return false;
    return SamayEnvelope.tryParse(bytes)?.type == e2eeEnvelopeTypeSenderKey;
  }

  /// Active members who still need [senderUserId]'s distribution bundle, as
  /// known to THIS device: [activeMemberIds] minus the sender itself minus
  /// the members already recorded as this (group, sender)'s distribution
  /// TARGET SET (so a member is never re-distributed to on every send). The
  /// chat layer calls
  /// this on the local member's cipher before each distribution round (group
  /// open, membership change) and sends the bundle to the returned members.
  ///
  /// PURE computation: it NEVER
  /// persists. The chat layer calls [markSenderKeyDistributed] AFTER each
  /// successful distribution-row insert; a member whose pairwise session
  /// could not be established is never recorded and stays missing for the
  /// next send. A roster change wipes the registry ([wipeGroupKeys],
  /// service side), so a fresh member is reported missing and
  /// re-distributed.
  Future<List<String>> membersMissingSenderKey({
    required String groupChatId,
    required String senderUserId,
    required List<String> activeMemberIds,
  }) async {
    final registry = await _loadRegistry(groupChatId);
    final distributedTo =
        registry?.distributedTo[senderUserId] ?? const <String>[];
    return [
      for (final member in activeMemberIds)
        if (member != senderUserId && !distributedTo.contains(member)) member,
    ];
  }

  /// Persists [memberIds] as part of [senderUserId]'s distribution target
  /// set for [groupChatId]. The chat layer calls this AFTER each
  /// successful distribution-row insert — never before: a member that was
  /// NOT actually distributed to (no published prekey bundle, insert
  /// failure) must remain missing so the next send retries it. The registry
  /// is created here when absent (epoch 0 until the first record save or
  /// wipe adopts the group id / epoch).
  Future<void> markSenderKeyDistributed({
    required String groupChatId,
    required String senderUserId,
    required List<String> memberIds,
  }) async {
    final registry = await _loadRegistry(groupChatId);
    final existing = registry?.distributedTo[senderUserId] ?? const <String>[];
    if (memberIds.isEmpty && existing.isNotEmpty) return; // nothing new
    final merged = {...existing, ...memberIds}.toList()..sort();
    await _sessionStore.saveSession(
      _registryKey(groupChatId),
      _GroupRegistry(
        groupId: registry?.groupId,
        senders: registry?.senders ?? <String>{},
        distributedTo: {
          ...?registry?.distributedTo,
          senderUserId: merged,
        },
        epoch: registry?.epoch ?? 0,
      ).toJson(),
    );
  }

  /// Removes [memberIds] from [senderUserId]'s distribution target set for
  /// [groupChatId] — the persistence half of the retry protocol:
  /// a member whose device REQUESTED this sender's chain is un-marked so
  /// [membersMissingSenderKey] reports them again and the next distribution
  /// round re-sends the bundle (the deadlock heal: a member who
  /// missed/stale-processed the bundle is otherwise marked distributed and
  /// never re-keyed). Members that were never marked are a no-op; an absent
  /// registry is a no-op too (nothing can be marked yet — a request can only
  /// arrive for a chain that was actually distributed).
  Future<void> unmarkSenderKeyDistributed({
    required String groupChatId,
    required String senderUserId,
    required List<String> memberIds,
  }) async {
    final registry = await _loadRegistry(groupChatId);
    if (registry == null) return;
    final existing = registry.distributedTo[senderUserId] ?? const <String>[];
    final remaining = existing.where((m) => !memberIds.contains(m)).toList();
    if (remaining.length == existing.length) return; // nothing to unmark
    await _sessionStore.saveSession(
      _registryKey(groupChatId),
      _GroupRegistry(
        groupId: registry.groupId,
        senders: registry.senders,
        distributedTo: {
          ...registry.distributedTo,
          senderUserId: remaining,
        },
        epoch: registry.epoch,
      ).toJson(),
    );
  }

  /// Deletes every sender-key record of the group (own chain AND all
  /// received chains) — the chat layer calls this when a member is REMOVED.
  /// The next [encrypt] mints a fresh chain root and re-distributes it, so
  /// the removed member's copies are useless going forward (hard rekey; no
  /// limit is placed on this path). Records are enumerated through the
  /// persisted registry (see the class doc).
  ///
  /// The registry is NEVER deleted — it owns the group-level `epoch`
  /// counter: [membersMissingSenderKey] reports every member missing until
  /// the fresh key is distributed, and the epoch bump (creating the
  /// registry at epoch 1 when absent) makes receivers holding an OLD-epoch
  /// record ACCEPT the fresh distribution bundle.
  Future<void> wipeGroupKeys(String groupChatId) async {
    final registry = await _loadRegistry(groupChatId);
    if (registry == null) {
      // No registry yet — create it owning the NEW epoch (1): the next
      // minted records/bundles carry epoch 1, so receivers with an
      // old-epoch record accept the rekey.
      await _sessionStore.saveSession(
        _registryKey(groupChatId),
        _GroupRegistry(groupId: null, senders: <String>{}, epoch: 1).toJson(),
      );
      AppLogger.instance.debug(
        'e2ee group wipe chat=$groupChatId — no sender-key registry; '
        'created it at epoch 1 (next send re-keys)',
      );
      return;
    }
    // A registry created by markSenderKeyDistributed alone has no group_id
    // yet — and no records (senders is only populated by record saves).
    final groupId = registry.groupId;
    if (groupId != null) {
      for (final sender in registry.senders.toList()) {
        await _sessionStore.deleteSession(_recordKey(groupId, sender));
      }
    }
    // Registry survives the wipe (it owns the epoch): clear the records +
    // distribution sets and bump the epoch.
    await _sessionStore.saveSession(
      _registryKey(groupChatId),
      _GroupRegistry(
        groupId: groupId,
        senders: <String>{},
        distributedTo: <String, List<String>>{},
        epoch: registry.epoch + 1,
      ).toJson(),
    );
    AppLogger.instance.debug(
      'e2ee group wipe chat=$groupChatId group=$groupId — deleted '
      '${registry.senders.length} sender-key record(s), epoch '
      '${registry.epoch} → ${registry.epoch + 1}; next send re-keys',
    );
  }

  // Internals

  /// Loads or creates [senderUserId]'s own chain record for [groupId]
  /// (creating it mints a 32-byte root from `Random.secure()` and binds the
  /// current identity's `ik_dh`). A minted record stamps the CURRENT
  /// registry group epoch (0 when no registry exists yet) — the epoch the
  /// distribution bundle carries, so receivers can distinguish the fresh
  /// post-rekey chain from the stale one.
  Future<GroupSenderKeyRecord> _ensureOwnRecord({
    required String groupChatId,
    required String senderUserId,
    required String groupId,
  }) async {
    final existing = await _loadRecord(groupId, senderUserId);
    if (existing != null) return existing;
    final random = Random.secure();
    final root = Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
    final identity = await _identityKeys();
    final registry = await _loadRegistry(groupChatId);
    final epoch = registry?.epoch ?? 0;
    final record = GroupSenderKeyRecord(
      chatId: groupChatId,
      senderUserId: senderUserId,
      senderIkDh: base64UrlNoPadEncode(identity.ikDhPublic),
      chainRoot: base64UrlNoPadEncode(root),
      lastSentN: 0,
      lastSeenN: -1,
      epoch: epoch,
      createdAt: _clock(),
    );
    await _saveRecord(groupChatId, groupId, record);
    AppLogger.instance.debug(
      'e2ee group sender-key chain created group=$groupId chat=$groupChatId '
      'sender=$senderUserId epoch=$epoch',
    );
    return record;
  }

  Future<GroupSenderKeyRecord?> _loadRecord(
    String groupId,
    String senderUserId,
  ) async {
    final raw = await _sessionStore.loadSession(_recordKey(groupId, senderUserId));
    return raw == null ? null : GroupSenderKeyRecord.fromJson(raw);
  }

  Future<void> _saveRecord(
    String groupChatId,
    String groupId,
    GroupSenderKeyRecord record,
  ) async {
    await _sessionStore.saveSession(
      _recordKey(groupId, record.senderUserId),
      record.toJson(),
    );
    // Registry AFTER the record (see the class doc): a crash in between
    // leaves an orphan record that the member re-distributes to heal, never
    // a member stranded without a chain.
    await _registerSenders(groupChatId, groupId, [record.senderUserId]);
  }

  String _recordKey(String groupId, String senderUserId) =>
      '$senderKeyKeyPrefix$groupId:$senderUserId';

  String _registryKey(String groupChatId) =>
      '$senderKeyRegistryKeyPrefix$groupChatId';

  Future<_GroupRegistry?> _loadRegistry(String groupChatId) async {
    final raw = await _sessionStore.loadSession(_registryKey(groupChatId));
    return raw == null ? null : _GroupRegistry.fromJson(raw);
  }

  Future<void> _registerSenders(
    String groupChatId,
    String groupId,
    List<String> senders,
  ) async {
    final registry = await _loadRegistry(groupChatId);
    if (registry == null) {
      await _sessionStore.saveSession(
        _registryKey(groupChatId),
        _GroupRegistry(
          groupId: groupId,
          senders: senders.toSet(),
          epoch: 0,
        ).toJson(),
      );
      return;
    }
    if (registry.groupId != null && registry.groupId != groupId) {
      // The chat layer must pass a consistent groupId per chat. If it ever
      // changes, records under the previous group id become non-enumerable
      // (orphans) — surface it loudly, then adopt the new id.
      AppLogger.instance.warn(
        'e2ee group registry group mismatch chat=$groupChatId '
        'registered=${registry.groupId} requested=$groupId — the chat layer '
        'changed the group id; records under the previous id are orphaned',
      );
    }
    await _sessionStore.saveSession(
      _registryKey(groupChatId),
      _GroupRegistry(
        groupId: groupId,
        senders: {...registry.senders, ...senders},
        distributedTo: registry.distributedTo,
        epoch: registry.epoch,
      ).toJson(),
    );
  }

  Map<String, dynamic>? _decodeBundle(String bundleJson, String groupChatId) {
    Object? decoded;
    try {
      decoded = jsonDecode(bundleJson);
    } on FormatException {
      _ignore(groupChatId, 'malformed JSON');
      return null;
    }
    if (decoded is! Map) {
      _ignore(groupChatId, 'not a JSON object');
      return null;
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _ignore(String groupChatId, String reason) {
    AppLogger.instance.warn(
      'e2ee group sender-key bundle IGNORED chat=$groupChatId — $reason',
    );
  }
}

/// A member's sender-key chain state for one group, persisted as
/// JSON under `group_sender_key:<groupId>:<senderUserId>`.
///
/// [chainRoot] is the CURRENT chain key (base64url, 32 bytes): for the
/// sender's own record it is the live sending chain and advances per send;
/// for received records it starts at the distributed root and advances per
/// decrypt. [lastSeenN] is -1 until the first message is accepted (`n <=
/// lastSeenN` → replay/duplicate/out-of-order drop). The chain key is the
/// only secret in the record — it lives in the platform keystore like every
/// other E2EE secret (§8).
///
/// [chatId] is the chat the chain was distributed in (cross-group
/// binding): decryption only accepts envelopes arriving in that chat.
///
/// [epoch] is the group epoch the chain was minted in (the registry's
/// group-level counter; 0 when no registry existed). Receivers compare it
/// against the bundle's epoch to tell a GENUINE rekey (higher epoch) from a
/// same-epoch stale/duplicate; [decrypt] itself does NOT check it — the
/// record IS the epoch.
///
/// Schema version 3. Older v1/v2 records (no `chat_id` / no `epoch`) are
/// rejected by [fromJson] — on-device state migration is simply "treated as
/// absent": decrypt drops (NoSession semantics), the sender re-distributes
/// once, and a v3 record replaces the old one.
class GroupSenderKeyRecord {
  const GroupSenderKeyRecord({
    required this.chatId,
    required this.senderUserId,
    required this.senderIkDh,
    required this.chainRoot,
    required this.lastSentN,
    required this.lastSeenN,
    required this.createdAt,
    this.epoch = 0,
  });

  /// The chat this chain was distributed in (the bundle's `chat_id`).
  final String chatId;

  /// The member whose chain this is (the message row's `sender_id`).
  final String senderUserId;

  /// Sender X25519 identity public key (base64url) — the identity binding:
  /// decryption verifies the envelope's `sender_ik_dh` against this.
  final String senderIkDh;

  /// Current chain key, base64url (32 bytes) — see the class doc.
  final String chainRoot;

  /// Index of the last message SENT on this chain (own record only).
  final int lastSentN;

  /// Index of the last message SEEN on this chain (-1 = none yet).
  final int lastSeenN;

  /// The group epoch this chain was minted in (the registry's counter at
  /// record creation; 0 when no registry existed). Rekeys bump it.
  final int epoch;

  /// When this device created the record.
  final DateTime createdAt;

  GroupSenderKeyRecord copyWith({
    String? chainRoot,
    int? lastSentN,
    int? lastSeenN,
    int? epoch,
  }) => GroupSenderKeyRecord(
    chatId: chatId,
    senderUserId: senderUserId,
    senderIkDh: senderIkDh,
    chainRoot: chainRoot ?? this.chainRoot,
    lastSentN: lastSentN ?? this.lastSentN,
    lastSeenN: lastSeenN ?? this.lastSeenN,
    epoch: epoch ?? this.epoch,
    createdAt: createdAt,
  );

  String toJson() => jsonEncode({
    'version': e2eeSenderKeyRecordVersion,
    'chat_id': chatId,
    'sender_user_id': senderUserId,
    'sender_ik_dh': senderIkDh,
    'chain_root': chainRoot,
    'last_sent_n': lastSentN,
    'last_seen_n': lastSeenN,
    'epoch': epoch,
    'created_at': createdAt.toIso8601String(),
  });

  /// Parses a persisted record. Returns null for malformed JSON, a chain
  /// root that is not 32 bytes, a malformed `ik_dh` (corrupt/foreign
  /// record → treated as absent: decrypt drops, encrypt re-keys), or an
  /// unsupported schema version (older v1/v2 records lack `chat_id` /
  /// `epoch` — also treated as absent; the member is re-distributed once,
  /// then stable).
  static GroupSenderKeyRecord? fromJson(String json) {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    final version = map['version'];
    final chatId = map['chat_id'];
    final senderUserId = map['sender_user_id'];
    final senderIkDh = map['sender_ik_dh'];
    final chainRoot = map['chain_root'];
    final lastSentN = map['last_sent_n'];
    final lastSeenN = map['last_seen_n'];
    final epoch = map['epoch'];
    final createdAt = map['created_at'];
    if (version != e2eeSenderKeyRecordVersion ||
        chatId is! String ||
        senderUserId is! String ||
        senderIkDh is! String ||
        chainRoot is! String ||
        lastSentN is! int ||
        lastSeenN is! int ||
        epoch is! int ||
        createdAt is! String) {
      return null;
    }
    final root = base64UrlNoPadDecode(chainRoot);
    final ikDh = base64UrlNoPadDecode(senderIkDh);
    if (root == null || root.length != 32) return null;
    if (ikDh == null || ikDh.length != 32) return null;
    final created = DateTime.tryParse(createdAt);
    if (created == null) return null;
    return GroupSenderKeyRecord(
      chatId: chatId,
      senderUserId: senderUserId,
      senderIkDh: senderIkDh,
      chainRoot: chainRoot,
      lastSentN: lastSentN,
      lastSeenN: lastSeenN,
      epoch: epoch,
      createdAt: created,
    );
  }
}

/// Per-chat enumeration bridge (see [GroupE2eeCipher] class doc): persisted
/// under `group_sender_key_registry:<groupChatId>` as
/// `{"version":3,"group_id":...,"epoch":N,"senders":[...],"distributed_to":{sender:[...]}}`.
///
/// [groupId] is null until the first record save supplies it (a registry
/// created by [GroupE2eeCipher.markSenderKeyDistributed] alone has no
/// records and thus no group id yet).
///
/// [epoch] is the group-level epoch counter (0 until the first wipe).
/// [GroupE2eeCipher.wipeGroupKeys] never deletes the
/// registry; it clears `senders` + `distributed_to` and bumps [epoch], so
/// the next distribution bundle carries a higher epoch and receivers
/// holding an old-epoch record accept it. Schema version 3; older v1/v2
/// registries are rejected by [fromJson] — treated as
/// absent (nothing distributed yet → one re-distribution round, then
/// stable).
class _GroupRegistry {
  _GroupRegistry({
    required this.groupId,
    required this.senders,
    this.distributedTo = const {},
    this.epoch = 0,
  });

  final String? groupId;
  final Set<String> senders;

  /// Per-sender distribution target sets: for each sender, the
  /// members its bundle has been distributed to — [membersMissingSenderKey]
  /// excludes exactly these (plus the sender itself) from the active roster.
  final Map<String, List<String>> distributedTo;

  /// The group-level epoch counter: bumped on every [wipeGroupKeys], minted
  /// into every new record + distribution bundle.
  final int epoch;

  String toJson() => jsonEncode({
    'version': e2eeSenderKeyRegistryVersion,
    'group_id': groupId,
    'epoch': epoch,
    'senders': senders.toList()..sort(),
    'distributed_to': {
      for (final entry in distributedTo.entries)
        entry.key: (entry.value.toList()..sort()),
    },
  });

  static _GroupRegistry? fromJson(String json) {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    final version = map['version'];
    final groupId = map['group_id'];
    final senders = map['senders'];
    final distributedTo = map['distributed_to'];
    final epoch = map['epoch'];
    if (version != e2eeSenderKeyRegistryVersion ||
        senders is! List ||
        (groupId != null && groupId is! String) ||
        (distributedTo != null && distributedTo is! Map) ||
        (epoch != null && epoch is! int)) {
      return null;
    }
    final targets = <String, List<String>>{};
    if (distributedTo is Map) {
      for (final entry in distributedTo.entries) {
        if (entry.key is! String || entry.value is! List) return null;
        targets[entry.key as String] =
            (entry.value as List).whereType<String>().toList();
      }
    }
    return _GroupRegistry(
      groupId: groupId as String?,
      senders: senders.whereType<String>().toSet(),
      distributedTo: targets,
      epoch: (epoch as int?) ?? 0,
    );
  }
}
