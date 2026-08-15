# Samay — E2EE Chat Architecture (X3DH + Double Ratchet)

**Owner:** D-07 (E2EE architecture doc) · **Reviewed:** 2026-08-13 · **Status:** authoritative design spec — implementation landed (I-37/81722ef); deviations recorded as errata below
**Drives:** `I-37` (crypto core — `lib/crypto/**`) and `I-38` (chat integration — `lib/features/chat/**`, `chat_service`, prekey server migration)

> Companion docs: `docs/security/SECURITY.md` (D-06 — threat model, crypto policy §3, gap G-09),
> `docs/specs/steps/phase-07-chat/CHAT-chat-system-core.md`, `CHPT-chat-participation-access-rules.md`,
> `CHMC-message-cap-reporting.md`; `docs/specs/steps/phase-00-foundation/SECU-rls-policies.md`;
> `supabase/migrations/20260510000001_full_schema.sql` (chats/messages/chat_participants, RLS, message_cap trigger).

---

## 0. Implementation Status & Errata (2026-08-13, HEAD 18b8c8b)

I-37/I-38 landed (commits `81722ef`, `e0eab3c`; 2026-08-09..13). `lib/crypto/` ships 10
modules (codec, constants, x3dh, double_ratchet, envelope, session, e2ee_key_store,
e2ee_primitives, e2ee_prekey_service, interfaces); chat is live with E2EE. The spec
sections below remain authoritative for the *design*; this block records where the
implementation differs or went further. **125 unit tests in `test/crypto/`.**

### 0.1 Implemented beyond the spec (add to the design)

| Feature | Where | Spec gap |
|---|---|---|
| **Init-envelope replay protection** | `lib/crypto/e2ee_primitives.dart:115-116`, `session.dart:35-37,323-326` — HKDF marker `samay.e2ee.init-marker.v1` (`constants.dart:32`) over `sender_ik_dh ‖ ekA ‖ spk_id ‖ opk_id`; identical replayed init dropped without re-decrypting | §4.2/§5.4 do not define replay mitigation (X3DH §4.2); **implemented, add subsection to §4.2** |
| **Session convergence (≤ 2 inactive)** | `constants.dart:54-61` (`e2eeMaxInactiveSessions = 2`, retired max age 30 d); `session.dart:28-33` — on init, match against inactive sessions first, activate, demote old active (Sesame §3.4 convergence) | §7.2 says "last-processed-wins … kept inactive 30 d" without the bounded-inactive convergence |
| **Failed-init restore** | `session.dart:40,306,348,392,420` — snapshot before init/decrypt; auth failure restores prior session (Sesame §3.4 error handling) | §4.5 atomicity covers decrypt only; init path documented in code, not spec |
| **Persisted `last_init_marker`** | `session.dart:247,304,591` — replay marker serialized in session JSON (`$8.3` schema extension) | §8.3 JSON schema lacks the field |
| **Server-side SPK expiry** | `e2ee_identity_keys.signed_prekey_expires_at` (`20260809000003:33`), enforced client-side by `e2ee_prekey_service.dart:79,122-130` | §5.2 says server "keeps the last 2"; the expiry column is undocumented in §9.1 |
| **In-app key material wipe on ban** | `session.dart:192-193` wipes sessions/replay markers; account wipe on `deleteAccount` (I-6 acceptance) | — |
| **Session/insert atomicity + unacknowledged-init heal (2026-08-15)** | `session.dart` — Signal `unacknowledgedPreKeyMessage` semantics: while the peer hasn't acknowledged the init (first decrypted ratchet reply), every outbound message re-initiates with a FRESH init envelope (new ekA — required because our init replay protection drops identical inits); the peer can always (re)establish the session. Plus `chat_service.dart` rolls the session back when an init's INSERT fails. Fixes the live A→B invisible-message bug (ratchets sent into a session the peer never received) | §12.2 assumes the insert always lands; the ack state machine + `envelopeIsInit`/`wipe` contract live on `E2eeMessageCipher` |

### 0.2 Spec claims NOT shipped (deviations)

| Claim | Status | Where tracked |
|---|---|---|
| §5.5 + §9.1: `prekey_fetch_log` table + 10 fetches/hour rate limit on `fetch_prekey_bundle` | **Not shipped** — no `prekey_fetch_log` table, no fetch RPC (bundle fetch is a plain RLS read of `e2ee_identity_keys`); deferred to S-10 (comment in `20260809000003:73-78`) | SECURITY.md G-25 |
| §9.1/§9.3/§12.2: three-table server model (`user_devices`, `signed_prekeys`, `one_time_prekeys`) + migration `2026XXXXXXXX_e2ee_prekeys.sql` | **Merged into ONE table** `e2ee_identity_keys` (public keys, SPK + its Ed25519 signature + expiry, OPK batch consumed in a transaction), migration `20260809000003_e2ee_tables.sql` — deviation documented in the migration header | §9.1 corrected inline below |
| §8.1/§12.1: bump `flutter_secure_storage` to `^11.0.0` | **Open follow-up** — still `^9.2.4` (`pubspec.yaml:17`); I-37 accepted the existing version | §8.1 note below |

### 0.3 Verification notes (re-run 2026-08-13)

- `test/crypto/` = 125 `test(` (x3dh 10, prekey 10, session 23, primitives 25, key_store 21, envelope 13, ratchet 23).
- `rg "plaintext" lib/crypto/` → zero persistence of plaintext; only envelope bytes reach `messages.content` (opt-003 asserts non-plaintext).
- All §10.4 interfaces implemented in `lib/crypto/interfaces.dart`; chat UI depends only on the interfaces (V-06 verified).

---

## 0. Sources & References

| # | Source | URL |
|---|--------|-----|
| R1 | Signal — X3DH Key Agreement Protocol (rev 1, 2016) | https://signal.org/docs/specifications/x3dh/ |
| R2 | Signal — Double Ratchet Algorithm (rev 4, 2025) | https://signal.org/docs/specifications/doubleratchet/ |
| R3 | Signal — Sesame: Session Management for Async Message Encryption (rev 2, 2017) | https://signal.org/docs/specifications/sesame/ |
| R4 | RFC 7748 — Elliptic Curves for Security (X25519) | https://www.rfc-editor.org/rfc/rfc7748 |
| R5 | RFC 5869 — HKDF | https://www.rfc-editor.org/rfc/rfc5869 |
| R6 | RFC 2104 — HMAC | https://www.rfc-editor.org/rfc/rfc2104 |
| R7 | XEdDSA — signature scheme used by Signal for prekey signing | https://signal.org/docs/specifications/xeddsa/ |
| R8 | `cryptography` Dart package (dint.dev, Apache-2.0) — X25519, Ed25519, AES-GCM, HKDF, HMAC | https://pub.dev/packages/cryptography |
| R9 | `cryptography_flutter` — platform-backed crypto for Android/iOS/macOS | https://pub.dev/packages/cryptography_flutter |
| R10 | `libsignal_protocol_dart` (MixinNetwork, GPL-3.0 — evaluated, NOT chosen, see §11) | https://pub.dev/packages/libsignal_protocol_dart |
| R11 | libsignal (official Rust libsignal — no maintained Flutter bindings) | https://github.com/signalapp/libsignal |
| R12 | `flutter_secure_storage` — iOS Keychain / Android Keystore | https://pub.dev/packages/flutter_secure_storage |
| R13 | Supabase Realtime — Postgres changes with filters | https://supabase.com/docs/guides/realtime/postgres-changes |
| R14 | OWASP MASTG — cryptography & storage chapters | https://mas.owasp.org/MASTG/0x04g-Testing-Cryptography/, https://mas.owasp.org/MASTG/0x05d-Testing-Data-Storage/ |

---

## 1. Scope, Goals, Non-Goals

### 1.1 Directive (user)

- User anonymity is **NOT** a feature. Identity is real (email, username) and server-visible.
- Security must be **Signal-grade**: confidentiality, integrity, forward secrecy, post-compromise security for chat contents.
- The server must only ever see **ciphertext** for message contents — never plaintext, never keys.

### 1.2 Scope

- 1:1 direct chats and group/event chats share the same wire format. MVP ratchet design targets **1:1 sessions**; group chat is implemented as a per-{sender→recipient} session fan-out in a later step (§9.6) — the envelope is identical either way.
- Text messages E2EE. Media (images/videos in Supabase Storage) is **NOT** E2EE at MVP — explicit limitation (§9.7).
- Single device per user at MVP (no multi-device session fan-out). Session management follows the parts of Sesame (R3) that apply to single-device async messaging: active session per chat, identity-change detection on reinstall, stale-session deletion.

### 1.3 Non-goals (MVP)

- Header encryption (R2 §4) — reserved as post-MVP upgrade (§6.7).
- Post-quantum ratchets (Triple Ratchet / SPQR, R2 §5–§6) — reserved; the design keeps domain-separated HKDF `info` strings so adding a second ratchet layer later is a wire-format-version bump, not a rewrite.
- Sealed Sender / sender anonymity toward the server — documented metadata exposure (§9.5).
- Multi-device sync, retry requests and delivery receipts (R3 §4.1), session expiration timers (R3 §4.2).

---

## 2. Threat Model

Assets, actors and trust boundaries are defined in `docs/security/SECURITY.md` §1. This section specializes the model for chat.

### 2.1 Assets

| Asset | Location | Protection |
|-------|----------|------------|
| Identity DH keypair (X25519) | device, flutter_secure_storage | used in X3DH DH1/DH2 (R1 §3.3); binds the session |
| Identity signing keypair (Ed25519) | device, flutter_secure_storage | signs the signed prekey (R1 §3.2) |
| Signed prekey + one-time prekeys | private in storage, public on server | X3DH forward secrecy (R1 §4.6) |
| Ratchet session state (RK, chain keys, DHs/DHr, skipped keys) | device, flutter_secure_storage | Double Ratchet FS/PCS (R2 §8) |
| Message plaintext | device memory only, transient | AES-256-GCM |
| Message ciphertext + envelope | server (`messages.content`) | opaque to server |

### 2.2 Adversaries and guarantees

| Adversary | Capability | What they get | Why safe |
|-----------|------------|---------------|----------|
| **Server compromise (passive, full DB)** | Read all tables incl. `messages.content`, prekey tables | Ciphertext + envelope headers (public keys, message numbers, sizes, metadata) | X3DH + Double Ratchet; keys never leave devices (R1 §4.7, R2) |
| **Server compromise (active, "malicious server")** | Substitute prekey bundles, drop/reorder/delay messages | Can fail delivery; can MITM *only if users never authenticate identity keys*; cannot read past traffic when one-time prekeys were used (R1 §4.6) | Alice verifies `Sig(IK_sig, Encode(SPKB))` (R1 §3.3); fingerprint compare is the user-level countermeasure (§8.4) |
| **Network attacker** | Passive TLS interception, Realtime WS sniffing | Metadata only (TLS encrypts); ciphertext if TLS broken | TLS 1.2+ (SECURITY.md §2.9); E2EE is the last line |
| **Device theft (locked)** | Physical device | Nothing | flutter_secure_storage = Keychain/Keystore, unlocked-device accessibility (R12) |
| **Device theft (unlocked/rooted)** | Read process memory, storage | Keys are not in plaintext files; ratchet state may be in memory during use | Mitigated: keys survive sign-out but are wiped on account switch/delete (§7.6); no plaintext backups (§9.4); accepted residual risk (S-18 scope) |
| **Key compromise (identity)** | Own the identity private key | Impersonate the user going forward | Session keys are per-session; identity key compromise does NOT decrypt old ciphertext unless prekeys also compromised (R1 §4.6); reinstall/re-key procedure (§7.5) |
| **Key compromise (ratchet state at time T)** | Own RK + chain keys | Messages encrypted before T: safe (FS); after T: readable until next DH ratchet step heals (PCS) | DH ratchet gives break-in recovery within a few messages (R2 §8.2) |

### 2.3 Requirements distilled

1. **Confidentiality:** server and network never see plaintext.
2. **Integrity:** every message authenticated (AEAD over envelope header — header tampering fails decryption).
3. **Forward secrecy:** compromise of long-term keys must not decrypt past messages (one-time prekeys + DH ratchet).
4. **Post-compromise security:** after a state leak, security recovers within one DH ratchet step (R2 §8.2).
5. **Out-of-order/loss resilience:** skipped message keys allow decryption of out-of-order messages (R2 §2.6).
6. **No key reuse:** unique message key per message; nonce derived from the message key (§4.1).

---

## 3. Cryptographic Primitives & Parameters (FINAL)

> Fixes SECURITY.md §3.1 "E2EE" row to concrete, implementable values. All integers big-endian unless noted.

| Purpose | Construction | Parameters |
|---------|-------------|------------|
| Curve / key agreement | **X25519** (R4) | 32-byte keys; `cryptography` package `X25519()` (R8) |
| Prekey signature | **Ed25519** (R8 `Ed25519()`) | 32-byte pub, 64-byte sig over the 32-byte SPKB encoding. *Deviation note below.* |
| Hash | SHA-256 | `Sha256()` (R8) |
| HKDF | RFC 5869, HMAC-SHA256 | `Hkdf(hmac: Hmac.sha256(), outputLength: …)` (R8) |
| HMAC | HMAC-SHA256 (R6) | used for KDF chains |
| AEAD | **AES-256-GCM** (`AesGcm.with256bits()`, R8) | 32-byte key, 12-byte nonce, 16-byte tag |
| Randomness | `Random.secure()` (R8 default) / `SecureRandom.fast()` | all key generation, one-time prekeys, X3DH ephemeral |
| Registration id | `Random.secure()` uint32 in [1, 0x3FFF] | mirrors libsignal `generateRegistrationId` |

**Identity-key deviation (documented, spec-blessed):** R1 §2.2 defines the prekey signature as XEdDSA over the identity key (R7). XEdDSA is not available in the `cryptography` package, and implementing it by hand is the single largest correctness risk in this stack. SECURITY.md §3.1 already authorizes **"Ed25519 (or XEdDSA per R4)"**. Therefore:

- Identity keypair = **two** long-term keypairs:
  - `IK_dh` — X25519, used for X3DH DH1/DH2 (R1 §3.3). This is "the identity key" in the DH sense.
  - `IK_sig` — Ed25519, used to produce `Sig(IK_sig_priv, Encode(SPKB))`.
- Both public keys travel in the prekey bundle and in the X3DH `AD` (§6.1), so the signature is cryptographically bound to the DH identity.
- Consequence: the X3DH "weak forward secrecy via forged prekeys" attack (R1 §4.5) is closed exactly as in the spec — a forged bundle fails the Ed25519 verification against `IK_sig`, which Alice has already bound to `IK_dh` via AD.
- Migration path to strict XEdDSA (or a single Ed25519 identity with X25519 conversion) is confined to `lib/crypto/keys.dart`; envelope `version = 0x02` is reserved for it.

### 3.1 HKDF domain separation (`info` strings — MUST be distinct)

| Use | `info` (ASCII) | Length |
|-----|----------------|--------|
| X3DH SK derivation | `samay.e2ee.x3dh.v1` | 32 |
| Ratchet KDF_RK | `samay.e2ee.rk.v1` | 64 (RK'‖CK) |
| Message-key → AEAD key+nonce expansion | `samay.e2ee.aead.v1` | 44 (32 key ‖ 12 nonce) |
| (Reserved) header encryption | `samay.e2ee.header.v1` | — |
| Fingerprint | `samay.e2ee.fingerprint.v1` | 30 |
| Init-envelope replay marker | `samay.e2ee.init-marker.v1` (`constants.dart:32`) | 32 — HMAC marker over the init header (§0.1) |

---

## 4. Ratchet Construction (Double Ratchet, exact)

Implements R2 §3 (the non-HE variant) with the recommended algorithms of R2 §7.2.

### 4.1 External functions

```
GENERATE_DH()       → X25519 keypair (cryptography X25519().newKeyPair())
DH(dh_pair, dh_pub) → X25519 shared secret (32 bytes)
KDF_RK(rk, dh_out)  → HKDF-SHA256(salt = rk, ikm = dh_out, info = "samay.e2ee.rk.v1", L = 64)
                      returns (rk', ck) — first 32 bytes new root key, last 32 bytes chain key
KDF_CK(ck)          → (ck_next, mk) where:
                      ck_next = HMAC-SHA256(key = ck, data = 0x02)   // single byte 0x02
                      mk      = HMAC-SHA256(key = ck, data = 0x01)   // single byte 0x01
ENCRYPT(mk, pt, ad) → (ct ‖ tag) where:
                      (key32, nonce12) = HKDF-SHA256(salt = 0x00×32, ikm = mk,
                                                     info = "samay.e2ee.aead.v1", L = 44)
                      ct ‖ tag = AES-256-GCM(key32, nonce12, associatedData = ad, plaintext = pt)
DECRYPT(mk, ct‖tag, ad) → pt, throws on auth failure
HEADER(dh_pair, pn, n)  → { dh: 32B, pn: u32, n: u32 }
MAX_SKIP = 2000
```

Notes:

- Nonce is **derived from the message key** (R2 §7.2 option "derived as an additional output from KDF_CK"), never random, never transmitted. Since each message key is used exactly once, the nonce is unique per (key, message) by construction — no nonce-reuse class, and the 96-bit nonce is fixed.
- Tag is the full 128-bit GCM tag (no truncation; R2 §8.6).

### 4.2 State

```
class RatchetState {
  X25519KeyPair DHs;       // self ratchet keypair (sending)
  Uint8List?    DHr;       // remote ratchet public key (32 bytes)
  Uint8List     RK;        // root key (32)
  Uint8List?    CKs;       // sending chain key (32)
  Uint8List?    CKr;       // receiving chain key (32)
  int Ns = 0;              // sending message number
  int Nr = 0;              // receiving message number
  int PN = 0;              // messages in previous sending chain
  Map<(Uint8List dhPub, int n), Uint8List> MKSKIPPED;  // skipped message keys
  String role;             // "initiator" | "responder"
}
```

### 4.3 Initialization (exact pseudocode from R2 §3.3)

```
// Alice (initiator), after X3DH produced SK and Bob's signed prekey public SPKB:
RatchetInitAlice:
  DHs = GENERATE_DH()
  DHr = SPKB
  (RK, CKs) = KDF_RK(SK, DH(DHs, DHr))
  CKr = null; Ns = 0; Nr = 0; PN = 0; MKSKIPPED = {}

// Bob (responder), on receiving Alice's X3DH init message (SPK used = spk_id):
RatchetInitBob:
  DHs = stored private key of signed prekey spk_id   // Bob's initial ratchet pair is his SPK (R2 §7.1)
  DHr = null
  RK = SK
  CKs = null; CKr = null; Ns = 0; Nr = 0; PN = 0; MKSKIPPED = {}
```

### 4.4 Encrypt (`RatchetEncrypt`)

```
RatchetSendKey:
  (CKs, mk) = KDF_CK(CKs)          // error if CKs == null
  n = Ns; Ns += 1; return n, mk

RatchetEncrypt(state, plaintext, AD):
  (n, mk) = RatchetSendKey(state)
  header = HEADER(DHs, PN, n)
  ct = ENCRYPT(mk, plaintext, CONCAT(AD, header))
  return header, ct
```

### 4.5 Decrypt (`RatchetDecrypt`)

```
TrySkippedMessageKeys:  // if (header.dh, header.n) in MKSKIPPED → pop and return mk
SkipMessageKeys(until):
  if Nr + MAX_SKIP < until → throw RatchetError('skip limit exceeded')
  if CKr != null:
    while Nr < until:
      (CKr, mk) = KDF_CK(CKr)
      MKSKIPPED[(DHr, Nr)] = mk
      Nr += 1
DHRatchet(header):
  PN = Ns; Ns = 0; Nr = 0
  DHr = header.dh
  (RK, CKr) = KDF_RK(RK, DH(DHs, DHr))
  DHs = GENERATE_DH()
  (RK, CKs) = KDF_RK(RK, DH(DHs, DHr))

RatchetDecrypt(state, header, ciphertext, AD):
  mk = TrySkippedMessageKeys(state, header)
  if mk == null:
    if header.dh != DHr:
      SkipMessageKeys(state, header.pn)
      DHRatchet(state, header)
    SkipMessageKeys(state, header.n)
    if CKr == null → throw RatchetError('no receiving chain')
    (CKr, mk) = KDF_CK(CKr)
    Nr += 1
  return DECRYPT(mk, ciphertext, CONCAT(AD, header))
```

**Atomicity rule (R2 §3.5):** if decryption throws (auth failure, skip limit), ALL state mutations made during this call are discarded. Implement by snapshotting the session before decrypt and restoring on failure (or operating on a copy).

### 4.6 Skipped-key deletion policy (R2 §8.4)

- Hard cap: `MKSKIPPED` ≤ 2000 entries per session. Exceeding → `RatchetError`.
- Server's `chat.message_cap` = 1000 bounds how many messages can be skipped while still deliverable; the client-side cap covers the rest.
- Pruning happens on session save (after each successful decrypt — deterministic event, R2 §8.7); entries older than 30 days are dropped.

---

## 5. X3DH Key Agreement (exact)

Implements R1 §3 with the parameters of §3.

### 5.1 Key publishing (per user, at profile creation — `E2eeKeyStore`)

1. Generate once: `IK_dh` (X25519), `IK_sig` (Ed25519), `registration_id`.
2. Generate signed prekey `SPKB` (X25519) + `Sig(IK_sig_priv, Encode(SPKB))` where `Encode(SPKB)` = the raw 32-byte X25519 public key.
3. Generate **100** one-time prekeys `OPKB_i` (X25519), ids 0..99.
4. Publish to server (§9.3):
   - `user_devices`: IK_dh, IK_sig, registration_id.
   - `signed_prekeys`: spk_id, public key, signature, created_at.
   - `one_time_prekeys`: opk_id, public key, created_at.
5. Private keys stay on device in flutter_secure_storage (§8).

### 5.2 Signed prekey rotation (R1 §3.2, "e.g. once a week")

- Every **7 days** (rolling, checked at app foreground): generate new SPK, publish, and **retain the previous SPK private key for 7 more days** to decrypt delayed init messages. After 7 days the old SPK private key is deleted.
- Server keeps the last 2 signed prekeys (current + previous) for bundle delivery; bundle fetch always returns the **current** one.

### 5.3 Sending the initial message (Alice → Bob)

1. Alice fetches Bob's bundle via `fetch_prekey_bundle(bob_id)` (§9.3): `{IK_dh_B, IK_sig_B, spk_id, SPKB, sig, opk_id?, OPKB?}`.
2. Verify `Ed25519.verify(sig, message: SPKB, publicKey: IK_sig_B)`; abort on failure (R1 §3.3).
3. Generate ephemeral `EKA` (X25519). Compute:

```
DH1 = X25519(IK_dh_A_priv, SPKB)
DH2 = X25519(EKA_priv,      IKB)      // IKB = IK_dh_B
DH3 = X25519(EKA_priv,      SPKB)
DH4 = X25519(EKA_priv,      OPKB)     // only if bundle contained an OPK
SK  = HKDF-SHA256(salt = 0x00×32,
                  ikm = F ‖ DH1 ‖ DH2 ‖ DH3 [‖ DH4],
                  info = "samay.e2ee.x3dh.v1", L = 32)
      where F = 32 bytes of 0xFF (X25519 curve marker, R1 §2.2)
```

4. Delete `EKA_priv` and DH outputs from memory.
5. Build `AD_base` (§6.1) = `Encode(IK_dh_A) ‖ Encode(IK_dh_B) ‖ Encode(IK_sig_A) ‖ Encode(IK_sig_B)`, sorted lexicographically by the two DH keys (role-independent).
6. Init the ratchet: `RatchetInitAlice(SK, SPKB)`.
7. Encrypt the first message with the ratchet (§4.4) and wrap in the **init envelope** (type `0x01`, §6.3).

### 5.4 Receiving the initial message (Bob)

1. Parse envelope type `0x01`. Extract `sender_ik_dh`, `sender_ik_sig`, `ek_a`, `spk_id`, `opk_id`.
2. Load `IK_dh_B_priv`, `IK_sig_B_priv`, and the private key for `spk_id` (current or retained). If `opk_id != 0xFFFFFFFF`, load that OPK private key and **delete it immediately after use** (forward secrecy, R1 §3.4).
3. Recompute the four DHs with the same formulas, derive `SK`.
4. Build the same `AD_base` (recomputed from stored identity keys + envelope sender keys).
5. `RatchetInitBob(SK, spk_priv_pair)`; decrypt the message payload with `RatchetDecrypt`.
6. On success: delete used OPK private key. On auth failure: abort, discard everything (R1 §3.4).

### 5.5 Bundle fetch rate limiting

`fetch_prekey_bundle` is a `SECURITY DEFINER` RPC with `SET search_path = ''` (pattern: `check_signup_email`, migration 20260724000001) enforcing **10 fetches/hour per caller** (server-trust requirement R1 §4.7: prevent OPK draining). Counter lives in `prekey_fetch_log` (user_id, fetched_at); window prune on insert.

> **ERRATA (2026-08-13): NOT SHIPPED.** There is no `fetch_prekey_bundle` RPC and no
> `prekey_fetch_log`; bundle fetch is a plain RLS-scoped read of `e2ee_identity_keys`
> (`20260809000003`). Rate limiting deferred to S-10 (see §0.2 / SECURITY.md G-25).

---

## 6. Message Envelope & Payload Format (FINAL)

Binary format, network byte order (big-endian integers). No JSON anywhere on the wire.

### 6.1 Associated data

```
AD_base  = Encode(IK_dh_A) ‖ Encode(IK_dh_B) ‖ Encode(IK_sig_A) ‖ Encode(IK_sig_B)   // 128 bytes
           where A = lexicographically-smaller IK_dh of the two, B = the other
AD_msg   = AD_base ‖ header_bytes                                                     // +40 bytes
header_bytes = dh_pub(32) ‖ pn(4) ‖ n(4)                                              // fixed 40 bytes
```

`header_bytes` is the exact byte encoding used in the envelope header (fixed length ⇒ no length prefix needed, R2 §3.1 CONCAT rule). GCM `associatedData` = `AD_msg`.

**Fingerprint** (safety UI, §8.4): first 30 bytes of `HKDF-SHA256(salt = 0x00×32, ikm = AD_base, info = "samay.e2ee.fingerprint.v1", L = 30)`, displayed as 5×6-hex groups.

### 6.2 Envelope frame (all types)

| Field | Size | Value |
|-------|------|-------|
| magic | 4 B | `0x53 0x4D 0x45 0x32` ("SME2") |
| version | 1 B | `0x01` |
| type | 1 B | `0x01` init (X3DH) · `0x02` ratchet |
| sender_ik_dh | 32 B | sender X25519 identity public key |
| sender_ik_sig | 32 B | sender Ed25519 signing public key (init only; type 0x02 → 32 zero bytes) |

### 6.3 Type 0x01 — X3DH init message (first message Alice→Bob)

| Field | Size | Notes |
|-------|------|-------|
| magic | 4 B | |
| version | 1 B | `0x01` |
| type | 1 B | `0x01` |
| sender_ik_dh | 32 B | |
| sender_ik_sig | 32 B | |
| recipient_ik_dh | 32 B | Bob's IK_dh as Alice saw it — delivery binding |
| ek_a | 32 B | X3DH ephemeral public |
| spk_id | 4 B | u32, signed prekey used |
| opk_id | 4 B | u32, one-time prekey used; `0xFFFFFFFF` if none |
| dh_pub | 32 B | ratchet header: Alice's DHs |
| pn | 4 B | u32, `0` (no previous sending chain) |
| n | 4 B | u32, `0` |
| ct_len | 4 B | u32, ciphertext length in bytes |
| ciphertext | ct_len B | `ct ‖ tag` (GCM) |

Fixed header: 4+1+1+32+32+32+32+4+4+32+4+4+4 = **186 bytes**.

### 6.4 Type 0x02 — ratchet message

| Field | Size | Notes |
|-------|------|-------|
| magic | 4 B | |
| version | 1 B | `0x01` |
| type | 1 B | `0x02` |
| sender_ik_dh | 32 B | session routing key (client uses it, ignores chat metadata) |
| sender_ik_sig | 32 B | zeros (present only to keep framing fixed) |
| dh_pub | 32 B | ratchet public key |
| pn | 4 B | u32 previous chain length |
| n | 4 B | u32 message number |
| ct_len | 4 B | u32 |
| ciphertext | ct_len B | `ct ‖ tag` |

Fixed header: 4+1+1+32+32+32+4+4+4 = **114 bytes**.

> **ERRATA (I-37, 2026-08-09; corrected by EF-05):** the original spec printed
> "= 112 bytes", but the field table above sums to 114. The implemented codec
> (`lib/crypto/envelope.dart`, `ratchetHeaderSize = 4+1+1+32+32+32+4+4+4 = 114`)
> is authoritative: a 112-byte header misaligns `ct_len` by 2 bytes and every
> ratchet envelope fails AEAD (I-37 verified empirically; see MISTAKE-1 in
> `docs/history/phase-02-flutter-foundation/2026-08-09_I37-e2ee-core.md`).

### 6.5 Parse rules

- Length validation BEFORE any crypto: `ct_len` must equal `envelope.length - header_size`; mismatch → drop.
- Unknown magic/version/type → drop (future versions rejected cleanly).
- `recipient_ik_dh` mismatch (type 0x01) → drop.
- Type 0x02 whose `sender_ik_dh` has no session → drop (no auto-session creation from ratchet messages; only init messages create sessions, per Sesame R3 §3.4).

### 6.6 Wire storage

The full envelope (magic…ciphertext) is **base64url-encoded (no padding)** and stored in `messages.content`. Server treats it as an opaque blob. (base64url-text chosen over `bytea` for PostgREST/Realtime ergonomics; the blob is still ciphertext from the server's perspective.)

### 6.7 Reserved upgrade paths

- `version = 0x02`: XEdDSA identity unification and/or header encryption (R2 §4). Header encryption turns `header_bytes` into `HENCRYPT(...)` output and adds `HKs/NHKs` state; `AD_msg` changes accordingly. New `type 0x03` = ratchet-with-encrypted-header.
- `version = 0x03`: Triple Ratchet hybrid (R2 §6). Framing gains a second header section.

---

## 7. Session Lifecycle

Follows Sesame (R3) semantics reduced to single-device async messaging.

### 7.1 Session identity & lookup

- A session is identified by `(chatId, peerUserId)` on the client. Wire-level routing uses `sender_ik_dh`.
- On receiving any message: look up the session by `sender_ik_dh` first (a `ik_dh → chatId` index is maintained alongside sessions, §8.2); fall back to `chatId` from the DB row. If the two disagree → drop (identity binding failure).

### 7.2 Session creation

- First outbound message to a peer: fetch bundle (§5.3), run X3DH, `RatchetInitAlice`, send type-0x01 envelope, persist session.
- First inbound init message: §5.4 flow creates the responder session, persist, decrypt payload.
- **Simultaneous initiation** (both sides send type-0x01 within one session lifetime): **convergence** — the incoming init is matched against the ≤ 2 kept inactive sessions first; the match becomes active and the previous active session is demoted to inactive (Sesame §3.2 "insert then activate" / §3.4 convergence; bounded by `e2eeMaxInactiveSessions = 2`). Failed init restores the prior session (§0.1). Acceptable at MVP (single device, rare); documented behavior, not silent.

### 7.3 Session storage & resumption

- Persist `RatchetState` serialized (§8.3) to flutter_secure_storage after **every** encrypt/decrypt (atomicity §4.5 guarantees state consistency).
- Resumption: on app start / chat open, load the session for `chatId`; if present, continue the ratchet; if absent and the peer has a bundle → new session (§7.2).

### 7.4 Out-of-order & loss handling

- Per R2 §2.6: skipped keys stored in `MKSKIPPED`; out-of-order messages decrypt via `TrySkippedMessageKeys`.
- Gap > MAX_SKIP (2000) → `RatchetError` → message dropped, session preserved; the next DH ratchet step naturally re-synchronizes the peer.

### 7.5 Re-key on device reinstall

- Reinstall ⇒ new identity keypairs ⇒ server `user_devices` row replaced (upsert).
- Peer behavior (Sesame conditional update, R3 §3.2/§6.1): on bundle fetch, if `IK_dh` differs from the value bound to the stored session → **retire that session** (keep it for decrypting in-flight ciphertext up to 30 days, then delete) and create a fresh session for the new identity.
- MVP UX: chat shows "El otro usuario reinstaló la app / cambió de dispositivo" once (flag persisted per peer). Fingerprint re-verification UI is post-MVP (S-07/S-20 gate item).

### 7.6 Key material lifecycle (Signal model, revised 2026-08-15)

- **Sign-out KEEPS the material** (identity, prekeys, sessions) — the keys are
  bound to the ACCOUNT, not the session, exactly like Signal: a same-account
  re-sign-in decrypts old chats without re-key. `signOut()` no longer wipes.
- **Account switch wipes** (`AuthNotifier._ensureE2eeKeysPublished` ownership
  guard): the key store records `owner_uid` (`samay.e2ee.owner_uid`); when a
  DIFFERENT account signs in, `E2eeKeyStore.wipeAll()` + session wipe run
  BEFORE the heal publishes, so keys never cross accounts.
- **`deleteAccount()` MUST call `E2eeKeyStore.wipeAll()`** (identity keys,
  prekeys, all sessions) after the server call succeeds.
- Server side needs no key material (it never had any);
  `hard_delete_expired_users()` cron already anonymizes `messages`
  (`supabase/migrations/20260510000002_cron.sql:19`).
- A regenerated identity (reinstall, delete+re-register) is healed at the
  next session restore: `handleMissingSession` republishes when the published
  `identity_key` differs from the local identity (stale-row recovery —
  peers' inits are addressed to material this device actually holds).

### 7.7 Session expiry

- Inactive sessions older than 90 days are deleted at app foreground (bounded storage, R3 §6.5).

---

## 8. Key Storage (flutter_secure_storage)

### 8.1 Package

`flutter_secure_storage` — already a dependency (`pubspec.yaml:17`, `^9.2.4`). I-37 should **bump to `^11.0.0`** (R12) for: Android Keystore RSA-OAEP + AES-GCM by default, backup-aware cipher migration, `AndroidOptions` controls. Config:

> **ERRATA (2026-08-13):** the bump is an **open follow-up** — I-37 shipped on `^9.2.4`
> (the `AndroidOptions(migrateWithBackup: true)` config works from 9.x); revisit before
> release (see §0.2 / MASVS S7.1 follow-up).

```dart
const storage = FlutterSecureStorage(
  aOptions: AndroidOptions(migrateWithBackup: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);
```

`first_unlock` (not `unlocked`) so keys survive until first unlock after reboot and avoid background-access gaps.

### 8.2 Key namespaces (exact keys)

| Key | Contents |
|-----|----------|
| `samay.e2ee.identity.dh.priv` / `.pub` | X25519 identity (raw 32 B, base64url) |
| `samay.e2ee.identity.sig.priv` / `.pub` | Ed25519 identity |
| `samay.e2ee.registration_id` | u32 as decimal string |
| `samay.e2ee.spk.priv.<id>` | signed prekey private keys (current + 1 retained) |
| `samay.e2ee.spk.meta` | JSON: `{current_id, rotated_at, retired_id}` |
| `samay.e2ee.opk.priv.<id>` | one-time prekey private keys |
| `samay.e2ee.opk.meta` | JSON: `{count, threshold}` |
| `samay.e2ee.session.<chatId>` | serialized `RatchetState` (§8.3) |
| `samay.e2ee.session.index` | JSON map `ik_dh → chatId` (wire routing, §7.1) |

The existing `SecureStorageService` (`lib/core/services/storage_service.dart:4-18`) is extended (or replaced by `E2eeKeyStore`) with these keys; auth tokens (I-25/I-30) keep their own namespace.

### 8.3 Session serialization

```jsonc
{
  "version": 1,
  "role": "initiator|responder",
  "peer_ik_dh": "<b64>",
  "peer_ik_sig": "<b64>",
  "dhs_priv": "<b64>",
  "dhr_pub": "<b64|null>",
  "rk": "<b64>",
  "cks": "<b64|null>",
  "ckr": "<b64|null>",
  "ns": 0, "nr": 0, "pn": 0,
  "skipped": [ {"dh": "<b64>", "n": 3, "mk": "<b64>"} ],
  "created_at": "ISO8601", "last_used_at": "ISO8601"
}
```

`AD_base` is NOT stored — recomputed from stored identity keys + the session's peer keys (self-describing, prevents key drift). `MKSKIPPED` keys are `(dh_pub, n)` pairs.

### 8.4 Backup policy — EXPLICIT

- **NO plaintext backups. No cloud sync of key material. No export.**
- Android: `android:allowBackup="false"` in `AndroidManifest.xml` (R12 requires it; otherwise Keystore-wrapped SharedPreferences break after restore AND key material can be exfiltrated via adb backup). I-28/M-27 owns manifest changes.
- iOS: Keychain items are NOT included in iTunes/iCloud device backups by default with `first_unlock` accessibility; verify entitlements (`keychain-access-groups`, R12) and do NOT enable iCloud Keychain sync for app keys.
- Hive (`storage_service.dart:20-44`, `message_cache`) must NEVER store keys or plaintext messages — E2EE messages live only in memory or as the encrypted envelope in Postgres. (I-26's Hive encryption is orthogonal defense-in-depth.)

### 8.5 Ephemeral key hygiene

- X3DH ephemeral `EKA`, DH outputs, message keys, plaintext: **memory only**, zeroed/GC'd; never persisted, never logged.
- Message keys are deleted immediately after use (single-use, R2 §2.2). Skipped keys are the only retained keys, bounded (§4.6).

---

## 9. Server Model (Supabase)

### 9.1 What the server stores

| Table/column | Content | Notes |
|--------------|---------|-------|
| `messages.content` | base64url `SamayEnvelope` (ciphertext) | opaque blob; RLS unchanged (`messages_read_participant`, `messages_insert_own`, full_schema.sql:742-753) |
| `messages.*` (existing) | id, chat_id, sender_id, media_url, reported, created_at | unchanged |
| `e2ee_identity_keys` (NEW — **single-table model**, migration `20260809000003`) | user_id PK, ik_dh, ik_sig, registration_id, spk_id, spk_public, spk_signature, **signed_prekey_expires_at**, opk_batch (jsonb), created_at, updated_at | public keys + Ed25519 SPK sig + expiry; OPK batch consumed in a transaction |

> **ERRATA (2026-08-13):** the three-table model below (`user_devices`,
> `signed_prekeys`, `one_time_prekeys` + `prekey_fetch_log`) was **merged into the
> single `e2ee_identity_keys` table** by `20260809000003_e2ee_tables.sql` (deviation
> documented in its header). No `prekey_fetch_log` exists (§0.2). All three tables
> were specified pre-I-37; the RLS/RPC design in §9.3 applies to the single table.

### 9.2 What the server must NOT store

- ❌ Private keys of any kind (never uploaded).
- ❌ Message plaintext (never in `content`, never in logs, never in Realtime payloads beyond the envelope).
- ❌ Device lists beyond the single MVP device row (multi-device fan-out adds `device_id` — the design reserves the column, does not add it now).

### 9.3 RLS + RPC design (I-38 server step)

- **ERRATA (2026-08-13):** implemented as RLS on the single `e2ee_identity_keys` table —
  SELECT/INSERT/UPDATE/DELETE own-row policies + `FORCE ROW LEVEL SECURITY`
  (`20260809000003:46-62`); no SECURITY DEFINER RPCs (no rate limiting — §0.2).
- (Design as originally specified, for the three-table model:) `user_devices`:
  SELECT to `authenticated` (bundle fetch), INSERT/UPDATE own row (`user_id = auth.uid()`), FORCE RLS (per I-31 pattern).
- `signed_prekeys`: SELECT to `authenticated`, INSERT/DELETE own.
- `one_time_prekeys`: INSERT own, SELECT **denied** (direct reads would let clients drain the pool — consumption happens inside the RPC with `FOR UPDATE`).
- `fetch_prekey_bundle(p_peer_id uuid)` — `SECURITY DEFINER`, `SET search_path = ''`, REVOKE/GRANT to `authenticated` (pattern: migration 20260724000001 `check_signup_email`):
  1. rate-limit check (§5.5)
  2. `SELECT ... FROM user_devices WHERE user_id = p_peer_id`
  3. current `signed_prekeys` row
  4. `SELECT ... FROM one_time_prekeys WHERE user_id = p_peer_id AND used_at IS NULL ORDER BY opk_id LIMIT 1 FOR UPDATE SKIP LOCKED` → mark `used_at = now()`
  5. return JSON bundle (§5.3)
- `publish_prekeys(p_ik_dh, p_ik_sig, p_registration_id, p_spk_id, p_spk_pub, p_spk_sig, p_opks jsonb)` — upserts own device row + prekeys in one transaction.
- All new tables: `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` (I-31 pattern).
- `ALTER TABLE messages REPLICA IDENTITY FULL;` + `ALTER PUBLICATION supabase_realtime ADD TABLE messages;` (Realtime full-row delivery, R13).

### 9.4 Realtime delivery design

- Keep the existing per-chat channel pattern (`lib/core/providers/realtime_provider.dart` + `realtime_service.dart`; the I-52 lifecycle provider refactor carries it): channel `messages:$chatId`, `onPostgresChanges(insert, table: messages, filter: chat_id=eq.<chatId>)` — the filter form is supported (R13).
- RLS governs membership (existing `messages_read_participant`).
- The client receives the **envelope blob** and decrypts locally. Realtime is a delivery channel for opaque blobs — it carries ciphertext only.
- No new presence/channel-join metadata beyond what exists today (S-11 audits channel abuse).

### 9.5 Metadata exposure — accepted (Signal's stance)

The server knows: who talks to whom (chat_participants + sender_id/chat_id on every message), timestamps, message sizes, message counts, envelope public keys. Signal's own servers see equivalent delivery metadata (R3 §6.3; Signal's published metadata-minimization stance) — Signal protects *contents*, not *graph*, and so does Samay. Sealed Sender (hiding the sender from the server) is post-MVP. This is a **documented, accepted** exposure — no anonymity claims.

### 9.6 Group/event chat fan-out (later step, same wire format)

Group and event chats reuse the identical 1:1 envelope: the sender encrypts once per recipient and inserts N rows (one per member) into `messages` with the same chat_id. No protocol change; only fan-out logic in `chat_service` plus a per-recipient `messages` row. The `messages.sender_id`/`chat_id` schema, RLS, and message_cap trigger are untouched. (Not MVP: MVP ships 1:1 only; group fan-out is I-38 follow-up work.)

### 9.7 Media (non-E2EE at MVP — explicit limitation)

`media_url` media in Storage is NOT encrypted at MVP (E2EE applies to message contents). Documented in SECURITY.md §2.5 (bucket policies are S-09/I-59 scope). A future media-encryption step encrypts blobs with a session-derived key before upload — the envelope reserves `type 0x04` for media-key transfer messages. **Server sees no chat text, ever; server MAY see media bytes at MVP.**

---

## 10. Double Ratchet Decision: Custom Implementation (RECOMMENDED)

### 10.1 Options evaluated

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **A. `libsignal_protocol_dart` (R10)** | Battle-tested protocol port; gives X3DH+ratchet+stores for free | **GPL-3.0** (viral — would force the whole app GPL, unacceptable for a commercial product); wire format is Signal-server-shaped (prekey REST endpoints, protobuf messages) — does not map to opaque Supabase blobs without a custom server shim anyway; low activity (11 open issues, port lags upstream); hides the state machine behind stores, so the "swappable core" requirement is still work | ❌ Not chosen |
| **B. Official `libsignal` Rust via FFI (R11)** | Upstream Signal code | No maintained Flutter/Dart bindings; Rust toolchain in mobile builds; bindgen/CI burden; same server-format mismatch | ❌ Not chosen |
| **C. Custom implementation on `cryptography` (R8)** | Apache-2.0 (compatible); full control of the wire format = opaque blobs in Supabase; R1/R2 give exact algorithms + pseudocode; testable against known-answer vectors; satisfies the "ratchet can be swapped" interface requirement; no dependency on a dying port | We own correctness — mitigated by the mandatory test matrix (§12) and the S-07 audit | ✅ **CHOSEN** |

### 10.2 Rationale (summary)

The security property we need is *a correct X3DH + Double Ratchet*. The specs are implementable line-by-line (R1 §3, R2 §3 with pseudocode). The only reason to take libsignal would be to avoid implementing crypto — but Option A still requires: a prekey server protocol we would have to build, GPL acceptance, and adapting its session model to our storage. Option C is *less* total work than A given our Supabase-blob server model, and keeps licensing clean.

### 10.3 API sketch (I-37 `lib/crypto/`)

```
lib/crypto/
  constants.dart      // magic, version, info strings, MAX_SKIP, limits
  codec.dart          // u32/u8 framing, base64url helpers
  keys.dart           // generateIdentityKeys(), X25519/Ed25519 wrappers
  hkdf.dart           // hkdfSha256(info, salt, ikm, len)
  x3dh.dart           // X3dhState, initiateX3dh(), respondX3dh()
  ratchet.dart        // RatchetState, RatchetInitAlice/Bob, RatchetEncrypt/Decrypt
  envelope.dart       // SamayEnvelope encode/parse (types 0x01/0x02)
  key_store.dart      // E2eeKeyStore (flutter_secure_storage impl of §8)
  session_store.dart  // E2eeSessionStore (flutter_secure_storage impl of §7.3)
  cipher.dart         // E2eeMessageCipher (orchestrates x3dh+ratchet+envelope)
  prekey_service.dart // E2eePrekeyService (publish/fetch via Supabase RPCs)
```

### 10.4 Interfaces (refactorability — the "swap without touching chat UI" contract)

```dart
abstract class E2eeKeyStore {
  Future<E2eeIdentityKeys> loadOrCreateIdentity();          // §5.1
  Future<SignedPrekeyRecord> currentSignedPrekey();          // rotates if >7d old
  Future<void> rotateSignedPrekey();
  Future<int> oneTimePrekeyCount();
  Future<List<OneTimePrekeyRecord>> generateOneTimePrekeys(int n);
  Future<void> wipeAll();
}

abstract class E2eeSessionStore {
  Future<RatchetState?> loadSession(String chatId);
  Future<void> saveSession(String chatId, RatchetState state);   // prunes skipped keys (§4.6)
  Future<void> deleteSession(String chatId);
  Future<Map<String, String>> sessionIndex();                    // ik_dh → chatId
}

abstract class E2eeMessageCipher {
  /// Encrypt plaintext for peer; returns the wire envelope bytes (base64url-ready).
  Future<Uint8List> encrypt({required String chatId, required String peerUserId, required Uint8List plaintext});

  /// Decrypt an envelope. Returns null when undecryptable (dropped message).
  Future<Uint8List?> decrypt({required String chatId, required String peerUserId, required Uint8List envelope});

  /// True if the peer's stored identity changed (reinstall detection, §7.5).
  Future<bool> peerIdentityChanged(String peerUserId);
}

abstract class E2eePrekeyService {
  Future<PrekeyBundle> fetchBundle(String peerUserId);       // RPC, §5.3
  Future<void> publishAll();                                  // RPC, §9.3
}
```

`lib/core/services/chat_service.dart` (I-38) and the chat UI depend ONLY on these four interfaces. Swapping the implementation to `libsignal_protocol_dart` later = new concrete classes behind the same interfaces + an envelope adapter; UI untouched (verified by V-06).

---

## 11. Test Matrix (mandatory, per DEVELOPMENT-WORKFLOW §3)

### 11.1 Unit tests — `test/crypto/` (I-37)

| # | Test | Verifies |
|---|------|----------|
| U1 | X3DH known-answer vector (deterministic keys, recorded expected SK) | SK derivation incl. F-prefix, DH1-4 ordering, with/without OPK |
| U2 | `KDF_RK` determinism + output split (rk′, ck) | HKDF info separation |
| U3 | `KDF_CK` 0x01/0x02 domain separation (mk ≠ ck_next) | HMAC chain step |
| U4 | AEAD expansion: 44 bytes (32 key + 12 nonce), unique per mk | nonce-by-construction |
| U5 | Ratchet ping-pong: A→B→A→B… 200 messages, states converge | DH ratchet symmetry (R2 §3) |
| U6 | Encrypt-then-decrypt round-trip incl. multiple DH-ratchet turns | full loop |
| U7 | Out-of-order: skip 5, deliver later; decrypt via MKSKIPPED | R2 §2.6 |
| U8 | Skip-limit: gap > MAX_SKIP → RatchetError, state unchanged | bounded storage, atomicity |
| U9 | Header tamper (flip a bit in pn/n/dh_pub) → auth failure, state discarded | AD binding, atomicity |
| U10 | Envelope parse: truncated/oversized/garbage/magic/version/type cases → drop | §6.5 |
| U11 | Envelope round-trip 0x01 and 0x02, byte-exact encode/decode | framing |
| U12 | Session serialize → wipe memory → restore → continue ratchet | §8.3 persistence |
| U13 | Identity change: new bundle ik_dh ≠ session peer → session retire path | §7.5 (Sesame) |
| U14 | Simultaneous init: two init sessions, last-processed wins | §7.2 |
| U15 | Fingerprint: stable, 30 bytes, symmetric for both parties | §6.1 |
| U16 | Ciphertext uniqueness: same plaintext twice → different envelopes | nonce/key derivation |

### 11.2 Integration tests — `integration_test/e2ee_flow_test.dart` + `test/opt-003-chat.sh` (I-38)

Two in-memory "clients" (the real `lib/crypto/`) against a fake server implementing §9 semantics (or the real Supabase testing stack on ports 54382/54386):

| # | Scenario |
|---|----------|
| I1 | A publishes keys → B fetches bundle → B sends init → A decrypts → 100-message exchange, both states serialize/restore mid-flow |
| I2 | Delivery reorder queue (drop 3, shuffle 10) → all decrypt in the end |
| I3 | B wipes device (identity + sessions), reinstalls, republishes → A's next send re-keys (new session), old session retired |
| I4 | Server-side tamper: modify `messages.content` blob → recipient's auth failure path, message dropped, session healthy |
| I5 | opt-003 (curl, backend): `messages.content` for E2EE chats is a base64url envelope — assert NOT plaintext UTF-8; assert prekey RPCs rate-limit at the 11th fetch |
| I6 | Account deletion wipes keys (auth_provider integration) |

### 11.3 Acceptance gate (both agents)

- `flutter test` (incl. `test/crypto/`) green; `dart analyze` clean; `go test ./...` untouched; `test/opt-003-chat.sh` green against the stack; S-07 crypto audit before chat ships (SECURITY.md §5.2).
- Negative proof: `rg` over `lib/crypto/ lib/core/services/chat_service.dart` shows zero plaintext writes to any persistence layer (only envelope bytes to Postgres, only keys to flutter_secure_storage).

---

## 12. I-37 / I-38 Implementation Plan

### 12.1 I-37 — Crypto core (`lib/crypto/**`, pubspec)

| Step | Deliverable | Acceptance |
|------|-------------|------------|
| 1 | pubspec: add `cryptography ^2.9.0`, `cryptography_flutter ^2.3.4`; bump `flutter_secure_storage` to `^11.0.0` (→ **deferred, still ^9.2.4** — §0.2) | `flutter pub get` clean; S-02 CVE scan re-run |
| 2 | `constants.dart`, `codec.dart`, `hkdf.dart`, `keys.dart` | U2–U4, U15 green |
| 3 | `x3dh.dart` | U1 green |
| 4 | `ratchet.dart` | U5–U9 green |
| 5 | `envelope.dart` | U10, U11 green |
| 6 | `key_store.dart`, `session_store.dart` (secure-storage impls) | U12–U14 green; keys under §8.2 namespaces; no plaintext anywhere |
| 7 | `cipher.dart`, `prekey_service.dart` | I1 (unit-level, fake server) green |
| 8 | `test/crypto/*` full matrix + `README` | full matrix green; `dart analyze` clean |

**I-37 done =** all 16 unit tests green, interfaces in §10.4 exported, zero plaintext persistence, no chat-UI imports.

### 12.2 I-38 — Chat integration (`lib/features/chat/**`, `chat_service`, server migration)

| Step | Deliverable | Acceptance |
|------|-------------|------------|
| 1 | Migration `2026XXXXXXXX_e2ee_prekeys.sql` (→ landed as **`20260809000003_e2ee_tables.sql`, single `e2ee_identity_keys` table** — §9.1 errata): prekey tables + RLS + FORCE RLS + REPLICA IDENTITY FULL + realtime publication | pgTAP cases added (I-77 pattern) |
| 2 | `E2eePrekeyService` wired to the two RPCs; publish on profile creation; rotate SPK on foreground when >7d | opt-003 asserts bundle round-trip + rate limit |
| 3 | `lib/core/services/chat_service.dart` = `E2eeMessageCipher` + `messages` table ops: `sendMessage` encrypts → stores envelope; `loadMessages` decrypts; `subscribeToMessages` decrypts Realtime envelope | I1–I4 green (fake + real stack) |
| 4 | Key lifecycle hooks in auth: publish on `createProfile`, wipe on account switch/`deleteAccount` (**landed 2026-08-15** — `AuthNotifier._ensureE2eeKeysPublished`: `createProfile` → `publishAll()`; session restore / `signedIn` → ownership guard (wipe on account switch) + `handleMissingSession()` heal that also republishes on identity mismatch; `signOut` KEEPS material per §7.6 Signal model; `_wipeE2eeMaterial` wipes on switch/delete) | I6 green |
| 5 | `integration_test/e2ee_flow_test.dart` + `test/opt-003-chat.sh` | I5 green |
| 6 | Wire `RoutePaths.chat` to the real chat screen (**landed** — ChatScreen live at app_router.dart:414-420, replaces `VComingSoonScreen`) with decrypt path | chat UI shows decrypted text; undecryptable → "Mensaje no disponible" |

**I-38 done =** two clients exchange E2EE messages end-to-end through the stack; server DB dump of `messages` contains only envelopes; opt-003 + integration test green; S-07 audit opened.

### 12.3 Ownership & dependencies

- I-37 owns `lib/crypto/**` + `pubspec.yaml` crypto deps (FILE-OWNERSHIP.md).
- I-38 owns `lib/features/chat/**`, `lib/core/services/chat_service.dart`, the E2EE migration (FILE-OWNERSHIP.md; migration numbering per `supabase/migrations/` convention).
- Depends on: I-01 (integration suite conventions), I-31 (FORCE RLS pattern), I-25/I-30 (SecureStorage + auth wiring), I-56 (chat screen foundation), I-52 (Realtime lifecycle). S-07 audits the result before chat ships (SECURITY.md G-09).

---

## 13. Design Decisions & Open Questions (resolved)

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| D1 | libsignal vs custom | **Custom** (§10) | GPL-3.0; wire format; licensing; swappable-core requirement |
| D2 | Identity key | **X25519 DH + Ed25519 signing pair**, both in AD | XEdDSA unavailable in `cryptography`; SECURITY.md §3.1 authorizes Ed25519 |
| D3 | AEAD | AES-256-GCM, nonce derived from message key | R2 §7.2 option; zero nonce-reuse class; SECURITY.md §3.1 |
| D4 | Envelope format | Binary (magic+version+type), base64url on the wire | precise, compact, versioned; opaque to server |
| D5 | `messages.content` | Repurposed as the opaque envelope (no schema churn) | RLS/trigger/Realtime/reporting untouched |
| D6 | Prekey storage on server | Public keys in 3 new tables, consumed via SECURITY DEFINER RPC | R1 §4.7 rate limits; I-31 pattern |
| D7 | MAX_SKIP | 2000 | R2 §8.4 "~1000" suggestion ×2 margin; message_cap=1000 bounds real gaps |
| D8 | Group chat | Same envelope, per-recipient fan-out (post-MVP) | no protocol change |
| D9 | Media | NOT E2EE at MVP (explicit) | scoped; reserved type 0x04 |
| D10 | Metadata | Accepted exposure, Signal stance | documented, no anonymity claims |
| D11 | Simultaneous init | Last-processed-wins | MVP single-device; Sesame convergence equivalent |
| D12 | Header encryption | post-MVP, version 0x02 | R2 §4; framing reserved |

---

## 14. Verification Notes (D-07)

- Every repo path referenced above was verified to exist in the working tree on 2026-08-09 **and re-verified 2026-08-13**: `docs/security/SECURITY.md`, `docs/specs/steps/phase-07-chat/*`, `supabase/migrations/20260510000001_full_schema.sql` (chats/messages RLS + policies at :742-753), `20260510000002_cron.sql:19`, `20260724000001_fix_signup_tracker_rls.sql` (check_signup_email pattern), `lib/crypto/*` (10 modules, landed), `lib/core/services/chat_service.dart`, `lib/core/services/e2ee_*` (via `lib/crypto/e2ee_prekey_service.dart`), `lib/core/providers/auth_provider.dart`, `lib/core/router/app_router.dart` (ChatScreen live at :414-420), `pubspec.yaml:17`.
- Agent IDs referenced (I-25, I-28, I-30, I-31, I-37, I-38, I-52, I-56, I-77, S-02, S-07, S-11, S-18, S-20, V-06, M-27, D-07) all exist in `docs/process/FILE-OWNERSHIP.md`.
- Sources fetched 2026-08-09: R1, R2, R3, R8, R10 (pub.dev + GitHub), R12, R13 (see §0 URLs).
- D-07 is the spec consumed by I-37/I-38; implementation status and deviations are recorded in §0.

*Samay E2EE Architecture — v1.1 (D-07) · 2026-08-13 refresh · Next review: S-07 crypto audit (post-I-37) + S-10 prekey rate limit, before release.*
