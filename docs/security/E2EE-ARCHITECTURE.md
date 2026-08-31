# Samay — E2EE Chat Architecture (X3DH + Double Ratchet)

**Status:** authoritative design spec for the shipped E2EE chat stack
(`lib/crypto/**`, 1:1 + group sender-key). Keep this document aligned with
code in the same commit that changes either; deviations are summarized in §0.

> Companion docs: `docs/security/SECURITY.md` (threat model, crypto policy).
> Server-side schema lives in `supabase/migrations/` (`080_chat/*`, mirrored
> byte-identical in `supabase-testing/migrations/`).

---

## 0. Implementation status

`lib/crypto/` ships 10 modules (codec, constants, x3dh, double_ratchet,
envelope, session, e2ee_key_store, e2ee_primitives, e2ee_prekey_service,
interfaces) plus `group_cipher.dart` (Signal sender keys). Chat is live with
E2EE; the server stores ciphertext only. The sections below remain
authoritative for the design; where the implementation went further or
differed, it is listed here.

### 0.1 Implemented beyond the original spec (now part of the design)

| Feature | Where | Notes |
|---|---|---|
| **Init-envelope replay protection** | `e2ee_primitives.dart`, `session.dart` — HKDF marker over `sender_ik_dh ‖ ekA ‖ spk_id ‖ opk_id`; identical replayed init dropped without re-decrypting | X3DH §4.2 leaves replay mitigation open |
| **Session convergence (≤ 2 inactive)** | `constants.dart`, `session.dart` — on init, match inactive sessions first, activate, demote old active (Sesame §3.4) | bounds inactive-session storage |
| **Failed-init restore** | `session.dart` — snapshot before init/decrypt; auth failure restores prior session | atomicity beyond §4.5 |
| **Persisted `last_init_marker`** | serialized in the session JSON (§8.3 extension) | survives restart |
| **Server-side SPK expiry** | `e2ee_identity_keys.signed_prekey_expires_at`, enforced client-side by `e2ee_prekey_service.dart` | gives §5.2 rotation a hard deadline |
| **In-app key wipe on ban/delete** | sessions/replay markers wiped on ban; full wipe on account delete | — |
| **Unacknowledged-init heal** | Signal `unacknowledgedPreKeyMessage` semantics: until the peer acknowledges the init, every outbound message re-initiates with a FRESH init envelope; INSERT failure rolls the session back | fixes invisible-message when the peer never received the init |
| **Group chat E2EE — Signal sender keys** | `group_cipher.dart`, envelope type 0x03 (62-byte header), group send/distribution/rekey in `chat_service.dart`, migrations under `080_chat/` | one 0x03 row per group message + pairwise-X3DH distribution bundles addressed by `messages.recipient_id` (§9.6) |
| **Rekey epochs** | `processSenderKeyBundle` accepts higher-epoch bundles as genuine rekeys and ignores stale same/lower epoch; `wipeGroupKeys` bumps the persisted epoch but never deletes the registry | prevents message drops on rekeyed chains |
| **Reinstall heal + bundle-identity binding** | an identity-changed bundle (reinstall/device change) is accepted regardless of epoch, authenticated by the pairwise session's bound peer identity (`boundPeerIkDh`); per-chat send mutex prevents AEAD key/nonce reuse on concurrent sends | §7.5 semantics applied to the sender-key path |
| **Receiver-initiated key-request retry** | throttled (1/min per chat+sender) `samay.group_key_request` riding the pairwise session; chain owner un-marks + immediately re-distributes | heals members who missed/stale-processed a distribution without waiting for a roster-change rekey |

### 0.2 Known deviations from the original design

| Original claim | Actual |
|---|---|
| `prekey_fetch_log` table + fetch-rate RPC | Not built — bundle fetch is a plain RLS read of `e2ee_identity_keys` (server-side rate limiting remains an open item, see SECURITY.md §6 O1) |
| Three-table prekey model (`user_devices` / `signed_prekeys` / `one_time_prekeys`) | Merged into ONE table `e2ee_identity_keys` (`080_chat/02_e2ee_keys.sql`) |
| `flutter_secure_storage ^11` | Still `^9.2.4` |

### 0.3 Verification posture

Crypto behavior is pinned by the backend contract (`test/opt-003-chat.sh`,
`test/opt-010-groups-chat.sh` + pgTAP) — the Flutter unit suites in
`test/crypto/` were deleted with the Dart test trees (directive 2026-08-31).
No plaintext persists client-side — only envelope bytes reach
`messages.content`.

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



- 1:1 direct chats and group/event chats share the same wire format family. 1:1 sessions use the X3DH + Double Ratchet envelopes (types 0x01/0x02); **group chat is E2EE with Signal sender keys** (type 0x03, §9.6) — implemented, not a later step.

- Text messages E2EE. CHAT media (images/videos in Supabase Storage) is **NOT** E2EE at MVP — explicit limitation (§9.7); minigame image answers ARE client-side-encrypted in Storage since 2026-08-31 (§9.8).

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

- Migration path to strict XEdDSA (or a single Ed25519 identity with X25519 conversion) is confined to `lib/crypto/e2ee_primitives.dart`; envelope `version = 0x02` is reserved for it.



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



`fetch_prekey_bundle` is a `SECURITY DEFINER` RPC with `SET search_path = ''` (pattern: `check_signup_email`, migration the chat migrations (080_chat/*)) enforcing **10 fetches/hour per caller** (server-trust requirement R1 §4.7: prevent OPK draining). Counter lives in `prekey_fetch_log` (user_id, fetched_at); window prune on insert.



> **ERRATA (2026-08-13): NOT SHIPPED.** There is no `fetch_prekey_bundle` RPC and no

> `prekey_fetch_log`; bundle fetch is a plain RLS-scoped read of `e2ee_identity_keys`

> (`080_chat/02_e2ee_keys.sql`). Rate limiting deferred to S-10 (see §0.2 / SECURITY.md G-25).



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

| type | 1 B | `0x01` init (X3DH) · `0x02` ratchet · `0x03` sender-key (group chat, ISSUE 4 — §9.6) |

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

> ratchet envelope fails AEAD (verified empirically when the framing shipped).



### 6.5 Parse rules



- Length validation BEFORE any crypto: `ct_len` must equal `envelope.length - header_size`; mismatch → drop.

- Unknown magic/version/type → drop (future versions rejected cleanly).

- `recipient_ik_dh` mismatch (type 0x01) → drop.

- Type 0x02 whose `sender_ik_dh` has no session → drop (no auto-session creation from ratchet messages; only init messages create sessions, per Sesame R3 §3.4).



### 6.6 Wire storage



The full envelope (magic…ciphertext) is **base64url-encoded (no padding)** and stored in `messages.content`. Server treats it as an opaque blob. (base64url-text chosen over `bytea` for PostgREST/Realtime ergonomics; the blob is still ciphertext from the server's perspective.)



### 6.7 Reserved upgrade paths



- `version = 0x02`: XEdDSA identity unification and/or header encryption (R2 §4). Header encryption turns `header_bytes` into `HENCRYPT(...)` output and adds `HKs/NHKs` state; `AD_msg` changes accordingly.

- **`type 0x03` is taken by the group sender-key envelope** (ISSUE 4, §9.6 — fixed 62-byte header, no `sender_ik_sig`, no ratchet header). A future ratchet-with-encrypted-header needs a new type (e.g. `0x04`; `0x04` is also reserved for media-key transfer, §9.7).

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



- Reinstall ⇒ new identity keypairs ⇒ the `e2ee_identity_keys` row is replaced on the next heal (auth-restore `handleMissingSession` republishes on identity mismatch — 2026-08-15) **and the one-time-prekey pool is REPLACED with a fresh batch** (2026-08-16: the stale row's OPKs belong to the old identity — their private keys are gone, so any peer initiating with them can never be decrypted; see §9.3).

- **Reinstall history = silently absent (Signal semantics, 2026-08-16).** Rows that fail decryption with NO local session are the pre-reinstall class — permanently undecryptable by anyone (the keys are gone). The client HIDES them (the thread starts fresh — Signal shows no history after a fresh install, and its server holds none) and **deletes them server-side** (`delete_undecryptable_messages`, migration the chat migrations (080_chat/*) — participant-gated, audited in `deleted_messages`): the server never stores bytes nobody can ever read again (offload). The "Mensaje no descifrable" bubble survives ONLY for failures against an EXISTING session (tamper / skip-gap — the case Signal itself error-bubbles).

- **Peer behavior** (Sesame conditional update, R3 §3.2/§6.1): on bundle fetch, if `IK_dh` differs from the value bound to the stored session → **retire that session** (keep it for decrypting in-flight ciphertext up to 30 days, then delete) and create a fresh session for the new identity. Detection is wired at chat open (`E2eeSession.peerIdentityChanged` restores the session from the store first — 2026-08-16) and surfaces **once per peer**: "El otro usuario reinstaló la app o cambió de dispositivo" (flag persisted in the Hive config box). Informational — the conversation heals automatically on this device's next send (unacknowledged-init semantics, §7.8/§0.2). Fingerprint re-verification UI is post-MVP (S-07/S-20 gate item).

- **Platform nuance:** on iOS the Keychain survives an app uninstall, so a reinstall keeps the identity + sessions and old history stays decryptable; on Android (Keystore wiped) the Signal semantics above apply. Updates never touch key material (secure storage survives updates on both platforms).



### 7.5a Message deletion (2026-08-16, migration the chat migrations (080_chat/*))



WhatsApp-style two-option long-press deletion, plus the automatic cleanup above:



- **"Eliminar para todos"** — sender-only, within a **5-minute window anchored on the SERVER clock** (`messages.sent_at`, default `now()` at insert; existing rows backfilled from `created_at`). `delete_message_for_everyone` enforces sender + age inside Postgres — the client can never extend the window by lying (client `created_at` is untrusted for this). Verdicts surface as `MESSAGE_TOO_OLD` / `NOT_THE_SENDER` / `MESSAGE_NOT_FOUND` → l10n. Rows are hard-deleted + audited in `deleted_messages`; the peer's open thread removes them **live** via the realtime DELETE channel (REPLICA IDENTITY FULL, the chat migrations (080_chat/*)).

- **"Eliminar para mí"** — any participant, any age: client-local tombstone only; server rows stay (the peer keeps them). MVP tombstone is in-memory.

- Realtime DELETE events (PostgresChangeEvent.delete) deliver hard deletes to open threads.

- Trust surface (documented): the server cannot verify "undecryptable" (no keys), so `delete_undecryptable_messages` is participant-gated and every deletion lands in `deleted_messages` (audit; a prune cron can trim old rows).



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

  (`supabase/migrations/the chat migrations (080_chat/*).sql:19`).

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



> **ERRATA (2026-08-16 — Signal plaintext store):** the pre-2026-08-16

> "plaintext is memory-only" rule was a design contradiction: the server

> stores only E2EE envelopes and the Double Ratchet is stateful and

> irreversible, so an already-consumed message can NEVER be re-decrypted

> after the chain advanced — meaning readable history after an app restart /

> update was impossible (the live "Mensaje no descifrable" bug). Signal

> solves this by persisting DECRYPTED plaintext locally (SQLCipher). Samay

> now does the same: the Hive `message_cache` box

> (`message_plaintext_store.dart`, Hive-backed, opened at startup) stores decrypted history,

> AES-256-encrypted at rest with the key in the platform

> Keystore/Keychain (`samay.hive.key`, §8.2 namespace) — the SQLCipher

> equivalent. The envelope remains the ONLY content that ever reaches

> Postgres; the plaintext store is device-local, keyed per

> `(chatId, messageId)`, bounded at `chat.message_cap` (1000) per chat,

> wiped together with the key material on account deletion/switch (§7.6),

> and its key-loss degradation re-creates it empty (SEC-10 — the thread

> then re-decrypts fresh, or hides rows per §12.2 step 6). Server-side

> invariants in §9.2 are unchanged: the server never sees plaintext.

> The protocol companion fixes landed with it (2026-08-16):

> unacknowledged inits RE-WRAP the same baseKey instead of re-running fresh

> X3DH (`SessionCipher.encrypt` getPreKeyMessage), the recipient reuses a

> session bound to a baseKey instead of re-processing an init

> (`SessionBuilder.processV3` hasSessionState), and protocol-level drops

> are SILENT (Signal DuplicateMessageException) — only genuine tampering

> bubbles.



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

| `e2ee_identity_keys` (NEW — **single-table model**, single-table model, `080_chat/02_e2ee_keys.sql`) | user_id PK, ik_dh, ik_sig, registration_id, spk_id, spk_public, spk_signature, **signed_prekey_expires_at**, opk_batch (jsonb), created_at, updated_at | public keys + Ed25519 SPK sig + expiry; OPK batch consumed in a transaction |



> **ERRATA (2026-08-13):** the three-table model below (`user_devices`,

> `signed_prekeys`, `one_time_prekeys` + `prekey_fetch_log`) was **merged into the

> single `e2ee_identity_keys` table** into `080_chat/02_e2ee_keys.sql` (deviation

> documented in its header). No `prekey_fetch_log` exists (§0.2). All three tables

> were specified pre-I-37; the RLS/RPC design in §9.3 applies to the single table.



### 9.2 What the server must NOT store



- ❌ Private keys of any kind (never uploaded).

- ❌ Message plaintext (never in `content`, never in logs, never in Realtime payloads beyond the envelope).

- ❌ Device lists beyond the single MVP device row (multi-device fan-out adds `device_id` — the design reserves the column, does not add it now).



### 9.3 RLS + RPC design (I-38 server step)



- **ERRATA (2026-08-13):** implemented as RLS on the single `e2ee_identity_keys` table —

  SELECT/INSERT/UPDATE/DELETE own-row policies + `FORCE ROW LEVEL SECURITY`

  (`080_chat/02_e2ee_keys.sql`); no SECURITY DEFINER RPCs (no rate limiting — §0.2).

- (Design as originally specified, for the three-table model:) `user_devices`:

  SELECT to `authenticated` (bundle fetch), INSERT/UPDATE own row (`user_id = auth.uid()`), FORCE RLS (per I-31 pattern).

- `signed_prekeys`: SELECT to `authenticated`, INSERT/DELETE own.

- `one_time_prekeys`: INSERT own, SELECT **denied** (direct reads would let clients drain the pool — consumption happens inside the RPC with `FOR UPDATE`).

- `fetch_prekey_bundle(p_peer_id uuid)` — `SECURITY DEFINER`, `SET search_path = ''`, REVOKE/GRANT to `authenticated` (pattern: migration the chat migrations (080_chat/*) `check_signup_email`):

  1. rate-limit check (§5.5)

  2. `SELECT ... FROM user_devices WHERE user_id = p_peer_id`

  3. current `signed_prekeys` row

  4. `SELECT ... FROM one_time_prekeys WHERE user_id = p_peer_id AND used_at IS NULL ORDER BY opk_id LIMIT 1 FOR UPDATE SKIP LOCKED` → mark `used_at = now()`

  5. return JSON bundle (§5.3)

- `publish_prekeys(p_ik_dh, p_ik_sig, p_registration_id, p_spk_id, p_spk_pub, p_spk_sig, p_opks jsonb)` — upserts own device row + prekeys in one transaction.

- **OPK pool replacement on identity change (2026-08-16):** `publishIdentityBundle` compares the row's `identity_key` with the local identity; when they differ (reinstall, account switch) the one-time-prekey pool is REPLACED with a fresh batch and `consumed_one_time_prekeys` resets — the old identity's OPKs are dead (private keys gone) and must never be served to peers. Same-identity republish (SPK rotation / top-up) keeps the merge behavior.

- **Message deletion RPCs (2026-08-16, deletion RPCs in `080_chat/03_messaging.sql`):**

  - `delete_message_for_everyone(p_message_id uuid)` — SECURITY DEFINER, sender-only, `now() - sent_at <= 5 minutes` (server clock; `messages.sent_at` defaults `now()` — backdated client `created_at` can never extend the window). Errors: `MESSAGE_TOO_OLD` / `NOT_THE_SENDER` / `MESSAGE_NOT_FOUND`.

  - `delete_undecryptable_messages(p_chat_id uuid, p_message_ids uuid[])` — SECURITY DEFINER, participant-gated (the `messages_read_participant` set: direct/group/event); deletes the given ids in that chat, returns the deleted count.

  - `deleted_messages` — audit table (message_id, chat_id, deleted_by, reason ∈ delete_for_everyone | undecryptable_cleanup, deleted_at).

- All new tables: `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` (I-31 pattern).

- `ALTER TABLE messages REPLICA IDENTITY FULL;` + `ALTER PUBLICATION supabase_realtime ADD TABLE messages;` (Realtime full-row delivery, R13).



### 9.4 Realtime delivery design



- Keep the existing per-chat channel pattern (`lib/core/providers/realtime_provider.dart` + `realtime_service.dart`; the I-52 lifecycle provider refactor carries it): channel `messages:$chatId`, `onPostgresChanges(insert, table: messages, filter: chat_id=eq.<chatId>)` — the filter form is supported (R13).

- RLS governs membership (existing `messages_read_participant`).

- The client receives the **envelope blob** and decrypts locally. Realtime is a delivery channel for opaque blobs — it carries ciphertext only.

- No new presence/channel-join metadata beyond what exists today (S-11 audits channel abuse).



### 9.5 Metadata exposure — accepted (Signal's stance)



The server knows: who talks to whom (chat_participants + sender_id/chat_id on every message), timestamps, message sizes, message counts, envelope public keys. Signal's own servers see equivalent delivery metadata (R3 §6.3; Signal's published metadata-minimization stance) — Signal protects *contents*, not *graph*, and so does Samay. Sealed Sender (hiding the sender from the server) is post-MVP. This is a **documented, accepted** exposure — no anonymity claims.



### 9.6 Group/event chat — Signal sender-key E2EE (IMPLEMENTED, ISSUE 4)



> **ERRATA (2026-08-15..17, ISSUE 4):** the original §9.6 ("Group/event chat fan-out,

> later step, same wire format" — per-recipient fan-out) is replaced by this section.

> **Group chat shipped with the Signal sender-key model instead.** Event chats (type

> `event`) still have no E2EE path at MVP (§9.7 caveat applies to the whole group/event

> family).



The group chat E2EE model follows Signal's sender-key ("sender-key message")

architecture (`lib/crypto/group_cipher.dart`, `GroupE2eeCipher`):



**Wire format — envelope type `0x03`** (ISSUE 4; `lib/crypto/envelope.dart`).

Fixed 62-byte header: `magic(4) ‖ version(1) ‖ type(1) ‖ sender_ik_dh(32) ‖

group_id(16) ‖ chain_index(4) ‖ ct_len(4)`, then `ciphertext ‖ tag`. The

`sender_ik_dh` (the sender's X25519 identity public key) is the per-sender

routing key; `group_id` is the group UUID as 16 raw bytes — the crypto group

the chain binds to. There is **no** `sender_ik_sig` on 0x03 and no ratchet

header (§6.2 family; `senderKeyHeaderSize` in code).



**One row per message.** Each group message is encrypted ONCE with a key

derived from the sender's chain and stored as **one** `messages` row (a

base64url type-0x03 envelope in `content`, `recipient_id` NULL) — every member

holding that sender's chain decrypts it. This is the fan-out economy of sender

keys vs. the per-recipient fan-out: one row, N decryptions, no protocol change

per member.



**Sender-key distribution.** Each member mints a random 32-byte chain ROOT for

the group and distributes it to every active member as a JSON

`senderKeyBundleJson` bundle (`samay.group_sender_key` marker: `group_id`,

`chat_id`, `sender_user_id`, `sender_ik_dh`, `chain_root`,

`chain_index = last_sent_n` — the position of the LAST message the receiver

has seen, so the stored invariant `root == C_{lastSeenN+1}` holds on both

sides; the bundle must NOT carry a hardcoded 0 — see the 2026-08-17 F2

hardening). Bundles

travel as the PLAINTEXT of ordinary pairwise Double Ratchet envelopes

(types 0x01/0x02, X3DH — the distributor is the initiator, the target the

responder) stored in the group's `messages` rows, **addressed to exactly one

member via `messages.recipient_id`** (column added by the chat messaging migration, `080_chat/03_messaging.sql`;

2026-08-17, no RLS change). Receivers route inbound rows by envelope type

before the pairwise path:

  - `recipient_id = <me>` → decrypt with the pairwise session bound to the

    row's `sender_id`, detect the bundle (`isSenderKeyBundle`), persist it

    (`processSenderKeyBundle`), hide the row — never a bubble;

  - `recipient_id = <other>` → **silent skip** (no decrypt attempt, no bubble;

    the envelope + client-side skip, not RLS, provide distribution privacy);

  - `recipient_id` NULL + type 0x03 → a real group message.



**Chain semantics** (Signal sender-key chain, §4.1 `KDF_CK` analogue —

`deriveMessageKey(ck) → (ck′, mk)`, HKDF-SHA256):

  - the sender advances its chain per send and discards the old chain key

    (forward secrecy: consumed keys are zeroed in memory before persisting the

    next chain key);

  - AEAD is AES-256-GCM with associated data `utf8(chatId) ‖ groupId(16 raw

    bytes)` — the group binding is in BOTH the envelope header and the AAD, so

    a header tamper (incl. cross-group replay) fails authentication;

  - receivers hold the distributed root and derive forward per message;

    `chainIndex <= lastSeenN` is a replay/duplicate/out-of-order and is

    **dropped**; gaps derive through and discard the skipped message keys

    **up to a bounded cap** (`e2eeSenderKeyMaxSkip = 2000`, mirroring the 1:1

    ratchet's MAX_SKIP — a gap beyond the cap is **dropped without deriving**,

    so a forged `chainIndex = 0xFFFFFFFF` cannot drive an unbounded CPU walk

    on any member's device; the F1 DoS hardening, 2026-08-17); distribution

    bundle acceptance is **epoch-aware** (F2c + the H1 rekey-epoch guard,

    2026-08-17): `bundle.epoch > record.epoch` is **accepted** — a GENUINE

    rekey (the roster-change wipe minted a fresh chain whose index restarts

    at 0), which overrides the `chain_index <= lastSeenN` no-regress guard;

    `bundle.epoch < record.epoch` is ignored (a stale bundle from an old

    epoch replaying after the rekey); same epoch + `chain_index <= lastSeenN`

    is ignored (the F2c stale/duplicate); same epoch + higher `chain_index`

    is accepted (gap heal — the receiver is behind on the same chain). The

    stored record takes the bundle's epoch and `lastSeenN = chain_index - 1`

    (the invariant `root == C_{lastSeenN+1}` holds unchanged); decrypt does

    NOT check epochs — the record IS the epoch. The chain is one-way — not

    even the sender can re-decrypt its own consumed history (own sent

    messages render from the outbox);

  - identity binding: the envelope's `sender_ik_dh` must equal the stored

    bundle's `ik_dh` (reinstall / identity-change protection — the Signal

    session-reset analogue); a mismatch is a protocol drop;

  - **bundle-identity binding (K1 hardening, 2026-08-17):** `processSenderKeyBundle`

    additionally takes `expectedSenderIkDh` — the pairwise session's BOUND peer

    identity (`E2eeMessageCipher.boundPeerIkDh()`, restored from the stored

    session JSON `peer_ik_dh`, never burns an OPK) — and constant-time-verifies

    the bundle's claimed `sender_ik_dh` against it BEFORE the record-load

    guard, on every acceptance path (fresh record, identity-change heal, epoch

    rekey, gap heal). Mismatch → the bundle is IGNORED: a member cannot

    self-attest another member's key into a record. The documented residual is

    the VERY FIRST distribution envelope of a pairwise session (no bound key

    yet → best-effort, no expected key); every subsequent bundle is checked.

    The reinstall heal still works — when the pairwise session bound the

    sender's NEW identity, the new-identity bundle matches and supersedes the

    old record;

  - chat binding: `GroupSenderKeyRecord` stores the `chat_id` the chain was

    created under; decrypt rejects a record whose `chat_id` differs from the

    chat the row arrived in (a G2-chain row posted into chat G1 is a protocol

    drop — the F4 hardening, 2026-08-17).



**Storage** (E2EE §8.2 namespace family, via `E2eeSessionStore` — effective

secure-storage prefix `samay.e2ee.session.`):

  - `group_sender_key:<groupId>:<senderUserId>` — `GroupSenderKeyRecord` JSON

    (schema **v3**: chain root, `last_sent_n`, `last_seen_n`, sender `ik_dh`,

    `chat_id`, `epoch`), one per (group, sender) per device;

  - `group_sender_key_registry:<chatId>` — `{version: 3, group_id, epoch,

    senders[], distributed_to{}}` bridging the chat layer's `chat_id` to the

    crypto `group_id` and enumerating records for rekey (the store has no

    key-listing method); it also OWNS the group-level `epoch` counter.

    Written AFTER every record save, so a crash in between leaves an orphan

    record that is simply re-distributed — never a member stranded without a

    chain;

  - **schema v3 is the migration** (H1, 2026-08-17): `epoch` was added to

    both JSON schemas; a v1/v2 record or registry fails `fromJson` and is

    treated as ABSENT — decrypt drops (NoSession semantics), the sender

    re-distributes once, and v3 state replaces the old — no manual

    migration step.



**Roster / rekey.** The active roster is fetched from `chat_participants` (the

trigger-maintained mirror of ACTIVE `group_members` — migration

participant-sync triggers + RLS in `080_chat/01_tables.sql`) and compared to the

cached roster before every group send:

  - **any membership change** (member added OR removed) → `wipeGroupKeys`

    (H1, 2026-08-17) deletes EVERY sender-key record of the group (own and

    received chains, enumerated through the registry) so the next send mints

    a FRESH chain root and re-distributes it to every remaining active member

    (hard rekey — a removed member's chain copies are useless going forward).

    The registry is **NEVER deleted**: `wipeGroupKeys` clears its `senders`

    and `distributed_to` sets and bumps the PERSISTED group `epoch` (creating

    the registry at epoch 1 when absent). Records minted afterwards stamp the

    CURRENT registry epoch, so receivers holding an old-epoch record ACCEPT

    the fresh distribution bundle. This path is **never limited** (no cap on

    rekeys);

  - no change → lazy heal: `membersMissingSenderKey` (a PURE computation —

    active roster minus the sender minus the persisted `distributed_to`

    targets; it NEVER persists) drives distribution to exactly the members

    still missing the sender's chain; the mesh heals as bundles arrive.



**Distribution contract** (H1, 2026-08-17 — split in `chat_service.dart`

`_sendGroupMessage`): the chat layer sends each missing member's bundle in

its own try/catch — a member whose pairwise session cannot be established

(no published prekey bundle) or whose distribution-row insert fails is

SKIPPED, never fatal. `markSenderKeyDistributed` persists the member into

the sender's `distributed_to` set ONLY AFTER that member's distribution-row

insert succeeds, so a failed member stays missing and is retried on the next

send. The single type-0x03 message row is inserted OUTSIDE the per-member

loop — a distribution failure must never block the message.



**Documented Signal limitation.** Sender keys authenticate possession of the

chain, not the user: there are no per-message sender signatures, so any member

holding a chain root can send as that member (impersonation within a chain is

inherent to the sender-key model — Signal accepts the same). The server sees

only ciphertext; confidentiality matches the 1:1 path. The write surface is

additionally gated by the active-only RLS policy (`080_chat/01_tables.sql`,

D1e): only ACTIVE members may read or insert group-chat rows.



**Server side.** The chat/group migrations under `080_chat/`: realtime publication for `group_members` joins (

`supabase_realtime` publication, REPLICA IDENTITY FULL — the client's

`GroupMembershipsRealtimeListener`), `01_tables.sql` (participant-sync

triggers D1a–D1c, inbox group branch D1d, active-only RLS D1e, publication

guard D1f), `03_messaging.sql` adds `messages.recipient_id`). The

`messages.sender_id`/`chat_id` schema, message_cap trigger and Realtime

publication are untouched — distribution rows are transparent to all of them.

Integration: `test/opt-010-groups-chat.sh` (DB-layer contract); UI: group rows in

the inbox + `ChatThreadView` in the group-detail Chat tab (D4).



### 9.7 Media (non-E2EE at MVP — explicit limitation)



**CHAT media** (`media_url` in Storage) is NOT encrypted at MVP (E2EE applies to message contents). Documented in SECURITY.md §2.5 (bucket policies are S-09/I-59 scope). A future media-encryption step encrypts blobs with a session-derived key before upload — the envelope reserves `type 0x04` for media-key transfer messages. **Server sees no chat text, ever; server MAY see chat media bytes at MVP.** Note the minigame exception below (§9.8): minigame image answers ARE client-side-encrypted in Storage since 2026-08-31.



### 9.8 Minigame answers: non-ratcheted round-key envelopes + encrypted media in Storage (2026-08-31)



Minigame answers (Verdad o Reto play engine v2, `202_minigame_play_v2`) are E2EE via a **per-round group key `K_r`** — a deliberate non-ratcheted design chosen so a late joiner can read full history (Signal sender keys / Matrix Megolm one-way chains destroy past keys; requirement 2 of TODO.md §3.1/§3.2).

- **Per-round key model.** Each round's answer (text + image) is AES-256-GCM-encrypted with `K_r` (a fresh `Random.secure()` 32-byte value); AAD binds session + round. The server stores only ciphertext (`minigame_answers.answer_ciphertext` / the game-state payload) and the storage path of an encrypted image blob. **Keys are additive, never wiped**: a player who accepts at round N receives the FULL history `K_1..K_N`, so every previous answer decrypts. No epoch/rekey/`wipeGroupKeys` machinery — device-scoped `wipe()` for account/device cleanup is the only deletion.
- **Host = key custodian.** The creator (participant[0]) mints the round keys and the accept/kick bundles. The creator cannot remove itself (`remove_minigame_participant` is `not_creator` for self) and there is no leave RPC, so the host is present for the session's lifetime.
- **Pairwise delivery.** Keys travel only inside pairwise-encrypted `E2eeSession` envelopes (X3DH + Double Ratchet) written to `minigame_e2ee_bundles` (namespace `g:minigame:<sessionId>:<peerId>`). `mgs_bundles_insert_own` is participant-only (sender AND recipient in `s.participants`); recipients read only their own-addressed rows. **Late-joiner full-history reads are achieved by delivery** — `distributeHistoryKeys` on accept, `ensureRoundKey` self-heal for a host on a fresh device, and the roster-change safety net for missed accepts.
- **Forward-rotation revoke on kick.** On kick the host mints `K_{r+1}` and delivers it ONLY to the remaining participants; the kicked player's RLS blocks reading others' bundles, so they never learn `K_{r+1}+`. Additive keys are kept (no wipe).
- **One cryptographic impossibility (explicit product decision).** A kicked user keeps decrypting rounds they **already participated in** because they hold those `K_r`. No mechanism on the internet can retroactively un-read content a device already decrypted — Signal, Matrix, and MLS all accept this. Future rounds are fully revoked; the already-seen rounds are not. This is an accepted product decision, not a bug (TODO.md §3.3 / Finding F).
- **Server-blindness posture.** Answer text is ciphertext in `minigame_answers.answer_ciphertext` / the game-state payload. Answer IMAGES are AEAD ciphertext BYTES in the PRIVATE `minigame_images` Storage bucket at `<sessionId>/<round>/<uuid>.bin`; the DB stores only `image_storage_path`. Reads are participant-gated via storage RLS (`storage_objects_minigame_images_select` participant-gated SELECT, `storage_objects_minigame_images_insert` participant-only INSERT) + signed URL / authenticated `download()`. The server never sees plaintext and never holds a raw key — this is the documented media-E2EE deviation from the §9.7 MVP limitation: the minigame media path IS encrypted client-side, unlike chat media.
- **Backend hardening (2026-08-31, TODO §3.7 findings A–E).** `gm.status='active'` + not-deleted in every group-member RLS SELECT and play/lobby RPC gate; by-turns/async WRITER RPCs participant-only (`auth.uid() = ANY (v_participants)`); `_minigame_advance_round` ACL revoked from PUBLIC; `init_minigame_game_state` preserves `round_target`/`prize_positions`; distinct-voter `{list,count}` reaction counts.

Coverage: `lib/features/minigames/logic/minigame_cipher.dart` (the Flutter `test/features/minigames/logic/minigame_cipher_test.dart` regression suite was deleted 2026-08-31 — backend-only testing), `test/opt-021-minigame-play-v2.sh` TEST H, pgTAP Sections 49k/49l.



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

  constants.dart          // magic, version, info strings, MAX_SKIP, limits

  codec.dart              // u32/u8 framing, base64url helpers

  e2ee_primitives.dart    // X25519/Ed25519 wrappers, HKDF-SHA256, generateIdentityKeys()

  x3dh.dart               // X3dhState, initiateX3dh(), respondX3dh()

  double_ratchet.dart     // RatchetState, RatchetInitAlice/Bob, RatchetEncrypt/Decrypt

  envelope.dart           // SamayEnvelope encode/parse (types 0x01/0x02/0x03 group)

  interfaces.dart         // E2eeKeyStore / E2eeSessionStore contracts (§7.3, §8)

  e2ee_key_store.dart     // E2eeKeyStore impl (flutter_secure_storage, §8)

  session.dart            // E2eeSession orchestration: x3dh + ratchet + envelope (cipher role)

  e2ee_prekey_service.dart // E2eePrekeyService (publish/fetch via Supabase RPCs)

  group_cipher.dart       // GroupE2eeCipher — Signal sender keys, envelope type 0x03

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



### 11.1 Crypto unit tests (I-37 — deleted with the Dart test trees, 2026-08-31)



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



### 11.2 Integration tests — `test/opt-003-chat.sh` (I-38)



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



- `dart analyze` clean; `go test ./...` green; `test/opt-003-chat.sh` green against the stack; S-07 crypto audit before chat ships (SECURITY.md §5.2). (The Flutter `test/crypto/` suite was deleted with the Dart test trees — directive 2026-08-31; crypto behavior is pinned by opt-003 + pgTAP.)

- Negative proof: `rg` over `lib/crypto/ lib/core/services/chat_service.dart` shows zero plaintext writes to any persistence layer (only envelope bytes to Postgres, only keys to flutter_secure_storage).



---



## 12. I-37 / I-38 Implementation Plan



### 12.1 I-37 — Crypto core (`lib/crypto/**`, pubspec)



| Step | Deliverable | Acceptance |

|------|-------------|------------|

| 1 | pubspec: add `cryptography ^2.9.0`, `cryptography_flutter ^2.3.4`; bump `flutter_secure_storage` to `^11.0.0` (→ **deferred, still ^9.2.4** — §0.2) | `flutter pub get` clean; S-02 CVE scan re-run |

| 2 | `constants.dart`, `codec.dart`, `e2ee_primitives.dart` (HKDF + key wrappers) | U2–U4, U15 green |

| 3 | `x3dh.dart` | U1 green |

| 4 | `double_ratchet.dart` | U5–U9 green |

| 5 | `envelope.dart` | U10, U11 green |

| 6 | `e2ee_key_store.dart` (+ `interfaces.dart` contracts) | U12–U14 green; keys under §8.2 namespaces; no plaintext anywhere |

| 7 | `session.dart` (x3dh+ratchet+envelope orchestration), `e2ee_prekey_service.dart` | I1 (unit-level, fake server) green |

| 8 | crypto behavior pinned by `test/opt-003-chat.sh` + pgTAP (the `test/crypto/*` Flutter matrix was deleted 2026-08-31) | opt-003 green; `dart analyze` clean |



**I-37 done =** all 16 unit tests green, interfaces in §10.4 exported, zero plaintext persistence, no chat-UI imports.



### 12.2 I-38 — Chat integration (`lib/features/chat/**`, `chat_service`, server migration)



| Step | Deliverable | Acceptance |

|------|-------------|------------|

| 1 | Server-side prekey storage (landed as **`080_chat/02_e2ee_keys.sql`, single `e2ee_identity_keys` table** — §9.1 errata): prekey tables + RLS + FORCE RLS + REPLICA IDENTITY FULL + realtime publication | pgTAP cases added (I-77 pattern) |

| 2 | `E2eePrekeyService` wired to the two RPCs; publish on profile creation; rotate SPK on foreground when >7d | opt-003 asserts bundle round-trip + rate limit |

| 3 | `lib/core/services/chat_service.dart` = `E2eeMessageCipher` + `messages` table ops: `sendMessage` encrypts → stores envelope; `loadMessages` decrypts; `subscribeToMessages` decrypts Realtime envelope | I1–I4 green (fake + real stack) |

| 4 | Key lifecycle hooks in auth: publish on `createProfile`, wipe on account switch/`deleteAccount` (**landed 2026-08-15** — `AuthNotifier._ensureE2eeKeysPublished`: `createProfile` → `publishAll()`; session restore / `signedIn` → ownership guard (wipe on account switch) + `handleMissingSession()` heal that also republishes on identity mismatch; `signOut` KEEPS material per §7.6 Signal model; `_wipeE2eeMaterial` wipes on switch/delete) | I6 green |

| 5 | `test/opt-003-chat.sh` (the `integration_test/e2ee_flow_test.dart` flow was deleted 2026-08-31 — backend-only testing) | I5 green |

| 6 | Wire `RoutePaths.chat` to the real chat screen (**landed** — ChatScreen live at app_router.dart:414-420, replaces `VComingSoonScreen`) with decrypt path | chat UI shows decrypted text; session-present failures → "Mensaje no descifrable"; no-session failures (reinstall history) are hidden + auto-deleted (§7.5, 2026-08-16) |



**I-38 done =** two clients exchange E2EE messages end-to-end through the stack; server DB dump of `messages` contains only envelopes; opt-003 + integration test green; S-07 audit opened.



### 12.3 Code map

- Crypto core: `lib/crypto/**`. Chat integration: `lib/features/chat/**`,
  `lib/core/services/chat_service.dart`. Server schema:
  `supabase/migrations/080_chat/*` (mirrored byte-identical in
  `supabase-testing/migrations/`).



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

| D8 | Group chat | **Signal sender keys — envelope type 0x03 (IMPLEMENTED, ISSUE 4)** | one message row + N decryptions beats per-recipient fan-out; per-pairwise X3DH distribution bundles addressed by `messages.recipient_id`; hard rekey on roster change (§9.6) |

| D9 | Media | CHAT media NOT E2EE at MVP (explicit); **minigame image answers E2EE in Storage since 2026-08-31 (§9.8)** | chat scoped; reserved type 0x04 |

| D10 | Metadata | Accepted exposure, Signal stance | documented, no anonymity claims |

| D11 | Simultaneous init | Last-processed-wins | MVP single-device; Sesame convergence equivalent |

| D12 | Header encryption | post-MVP, version 0x02 | R2 §4; framing reserved |



---



## 14. Verification

- Crypto behavior is pinned by the backend assertions in
  `test/opt-003-chat.sh`, `test/opt-010-groups-chat.sh` and the pgTAP suite
  (`supabase/tests/schema_test.sql`). The Flutter unit/integration suites
  (`test/crypto/`, `integration_test/`) were deleted with the Dart test trees
  (directive 2026-08-31).
- Implementation status and deviations are recorded in §0; update both in the
  same commit as any crypto change.
