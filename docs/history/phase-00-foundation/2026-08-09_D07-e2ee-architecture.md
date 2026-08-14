# D-07 — E2EE Chat Architecture (docs/security/E2EE-ARCHITECTURE.md)

## Date: 2026-08-09

## Role
Documentation agent D-07 (Phase 4.1) — authoritative design for end-to-end-encrypted chat
"as secure as Signal" (X3DH + Double Ratchet + Sesame session management), consumed by I-37
(crypto core, `lib/crypto/**`) and I-38 (chat integration + prekey server migration).

## What was built

`docs/security/E2EE-ARCHITECTURE.md` (new, 730 lines) — the design spec that lets a Dart
developer implement without further design decisions:

1. **Threat model for chat** — 6 assets, 7 adversary rows (server compromise passive/active,
   network, device theft locked/unlocked, identity-key and ratchet-state compromise), and 6
   distilled requirements (confidentiality, integrity, forward secrecy, post-compromise
   security, out-of-order resilience, no key reuse). Cross-references `docs/security/SECURITY.md` §1.
2. **Cryptographic primitives (FINAL)** — X25519 (RFC 7748) for agreement, Ed25519 prekey
   signature, HKDF-SHA256 (RFC 5869) with strictly distinct `info` strings, HMAC-SHA256 KDF
   chains, AES-256-GCM with a nonce derived from the message key (R2 §7.2 option), MAX_SKIP=2000.
   Documented identity-key deviation: X25519 DH identity + Ed25519 signing identity pair, both
   bound in AD (XEdDSA not available in `cryptography` package; SECURITY.md §3.1 pre-authorizes
   "Ed25519 (or XEdDSA)"); migration path to strict XEdDSA = envelope version 0x02.
3. **Message envelope + payload format (FINAL)** — binary, big-endian: magic "SME2" + version +
   type framing; type 0x01 X3DH-init envelope (186-byte fixed header: identity keys, ek_a,
   spk_id, opk_id, ratchet header dh_pub/pn/n, ct_len) and type 0x02 ratchet envelope
   (114-byte header — the spec's §6.4 "112 bytes" is an arithmetic typo; the
   implementation in `lib/crypto/envelope.dart` is authoritative, see I-37 MISTAKE-1).
   AEAD ciphertext = ct‖tag; AD = 128-byte AD_base (identity binding) ‖ 40-byte header
   bytes. Parse rules (length checks before crypto, drop on mismatch). base64url on the wire into
   `messages.content` (opaque blob, zero schema churn). Reserved versions 0x02/0x03 and type 0x04.
4. **Session lifecycle** — creation (initiator/responder X3DH), per-chat storage in
   flutter_secure_storage, resumption after restart, out-of-order handling via MKSKIPPED
   (TrySkippedMessageKeys/SkipMessageKeys pseudocode), simultaneous-initiation last-processed-wins,
   re-key on device reinstall (Sesame conditional-update semantics), session wipe on account
   deletion (`auth_provider.dart:186-190` + `wipeAll()`), 90-day inactive-session expiry.
5. **Key storage** — exact flutter_secure_storage key namespaces (`samay.e2ee.*`), session
   serialization JSON shape, backup policy: NO plaintext backups, Android `allowBackup=false`,
   iOS first_unlock Keychain, no iCloud sync, Hive never stores keys/plaintext, ephemeral-key
   hygiene (memory only). Recommends bumping flutter_secure_storage to ^11.0.0.
6. **Server model** — 4 new tables (user_devices, signed_prekeys, one_time_prekeys,
   prekey_fetch_log) holding public keys only; SECURITY DEFINER RPCs `fetch_prekey_bundle`
   (rate-limited 10/h, `FOR UPDATE SKIP LOCKED` OPK consumption) and `publish_prekeys`, FORCE RLS,
   `REPLICA IDENTITY FULL` + realtime publication; Realtime channel design (existing
   `messages:$chatId` pattern with `chat_id=eq.` filter); metadata exposure documented as
   accepted (Signal's stance — contents protected, graph visible); media explicitly NOT E2EE at
   MVP (reserved type 0x04); group-chat fan-out reuses the same envelope.
7. **Double Ratchet decision** — custom implementation on `cryptography` package (Apache-2.0)
   over `libsignal_protocol_dart` (GPL-3.0, Signal-server-shaped wire format) and Rust libsignal
   via FFI (no Flutter bindings). Rationale + full `lib/crypto/` file map + API sketch.
8. **Migration/refactorability** — 4 abstract interfaces (E2eeKeyStore, E2eeSessionStore,
   E2eeMessageCipher, E2eePrekeyService) so the ratchet can be swapped to libsignal later without
   touching chat UI (V-06 verifies).
9. **Test matrix** — 16 unit tests (KDF chains, X3DH known-answer vector, DH ratchet symmetry,
   skip-keys, out-of-order, tamper/atomicity, envelope parse, session restore, identity change,
   fingerprint) + 6 integration scenarios (two-party through fake server, reorder queue, reinstall
   re-key, server tamper, opt-003 curl backend proof, account deletion) + acceptance gate.
10. **I-37/I-38 implementation plan** — step tables with acceptance criteria per step, plus
    ownership/dependencies (I-01, I-25, I-30, I-31, I-52, I-56, I-77, S-07) and 12 resolved
    design decisions (D1–D12).

## Decisions made and why

- **Custom ratchet over libsignal_protocol_dart** (D1): GPL-3.0 is viral for a commercial app;
  the library's wire format is Signal-server-shaped, so a custom server shim is needed anyway;
  the repo's own refactorability requirement (swappable core) favors interfaces + own code.
- **X25519-DH + Ed25519-signing identity pair** (D2): XEdDSA isn't in `cryptography`; SECURITY.md
  §3.1 pre-authorizes Ed25519; both keys bound into AD preserves the spec's security arguments.
- **Nonce derived from message key** (D3): eliminates the nonce-reuse class entirely (R2 §7.2).
- **Reuse `messages.content` as the opaque envelope** (D5): RLS, message_cap trigger, Realtime,
  and reporting stay untouched — the server sees only ciphertext with zero schema churn.
- **MAX_SKIP = 2000** (D7): server message_cap=1000 bounds realistic gaps; 2× margin per R2 §8.4.
- **Metadata exposure documented, not hidden** (D10): matches Signal's published stance; no
  anonymity claims anywhere (user directive: anonymity is NOT a feature).
- **Doc kept self-contained for I-37/I-38** — every KDF, byte layout, key name, and pseudocode
  branch is specified; implementers make no protocol decisions.

## Sources consulted (webfetch, 2026-08-09)

- R1 X3DH: https://signal.org/docs/specifications/x3dh/ (full §2-§4 read)
- R2 Double Ratchet: https://signal.org/docs/specifications/doubleratchet/ (full §2-§8 read, incl.
  §7.2 recommended algorithms and §8 security considerations)
- R3 Sesame: https://signal.org/docs/specifications/sesame/ (full read — session lifecycle basis)
- R8 cryptography package: https://pub.dev/packages/cryptography (API: X25519, Ed25519, AesGcm,
  Hkdf, Hmac, Sha256, Random.secure, SecretBox)
- R10 libsignal_protocol_dart: https://pub.dev/packages/libsignal_protocol_dart +
  https://github.com/MixinNetwork/libsignal_protocol_dart (GPL-3.0; SessionBuilder/SessionCipher/
  stores API; activity level)
- R12 flutter_secure_storage: https://pub.dev/packages/flutter_secure_storage (v11: Android
  RSA-OAEP+AES-GCM, migrateWithBackup, accessibility, allowBackup requirement)
- R13 Supabase Realtime: https://supabase.com/docs/guides/realtime/postgres-changes
  (PostgresChangeFilter eq form, REPLICA IDENTITY, publication)
- Repo docs read in full per AGENT-RULES §0.1: all of lib/, test/, cmd/, internal/, supabase/,
  supabase-testing/, docs/ (planification, implementation, development, to-fix, agents, security),
  pubspec.yaml, go.mod, Makefile, AGENTS.md, README.md.

## Commands run (reproducibility)

```bash
find lib test cmd internal supabase supabase-testing docs tools -type f | sort
# full repo read pass (Read/Grep/Glob over every file)
tools/agent_lock.sh list                                   # confirmed my files free
tools/agent_lock.sh acquire docs/security/E2EE-ARCHITECTURE.md --owner D-07
tools/agent_lock.sh acquire docs/history/phase-00-foundation/2026-08-09_D07-e2ee-architecture.md --owner D-07
# wrote both files via heredoc (write-tool JSON error on 45KB content → bash << 'EOF')
rg -n "sendMessage|loadMessages|subscribeToMessages|class SecureStorageService" lib/core/services/
wc -l docs/security/E2EE-ARCHITECTURE.md    # 730
tools/agent_lock.sh release docs/security/E2EE-ARCHITECTURE.md --owner D-07
tools/agent_lock.sh release docs/history/phase-00-foundation/2026-08-09_D07-e2ee-architecture.md --owner D-07
```

## Lock evidence

- `docs/security/E2EE-ARCHITECTURE.md` — ACQUIRED by D-07 (`[lock] ACQUIRED 'docs/security/E2EE-ARCHITECTURE.md' by D-07`), RELEASED after write.
- `docs/history/phase-00-foundation/2026-08-09_D07-e2ee-architecture.md` — ACQUIRED by D-07, RELEASED after write.
- No conflicts: only D-12 held locks (phase PLAN.md files) during my run.

## MISTAKE

- **MISTAKE:** first write attempt used the Write tool with ~45KB content and failed with a JSON
  parse error ("Unterminated string") — likely a control character in the content. Fixed by
  writing via `cat > file << 'EOF'` heredocs in 4 parts (quoted EOF = no interpolation).
- **MISTAKE (caught in review):** early draft had `MAX_SKIP = 1000` copied from the old
  SECURITY.md summary; changed to 2000 after reading R2 §8.4 (which suggests ~1000 as a *floor*
  example) — documented rationale in D7.
- **MISTAKE (avoided):** initially considered storing `messages.content` as `bytea`; verified
  PostgREST/Realtime ergonomics favor base64url text — no schema change either way, documented.

## Issues found (reported, not fixed — out of scope)

1. `supabase/config.toml` + `docker-compose*.yml` still map DB to 5432 and Kong to 54321
   (G-16/DKR-03) — I-02/M-01..M-10 scope; I did not start any stack.
2. `flutter_secure_storage` is pinned `^9.2.4` while the E2EE design requires v11 features
   (`migrateWithBackup`, AndroidOptions) — I-37 step 1 bumps it.
3. No `messages` row-level REPLICA IDENTITY/Realtime publication migration exists yet — I-38
   step 1 owns it.
4. `.env.example:5` still carries a real anon key (SEC-03) — I-34 scope; untouched.
5. `go.mod:3` declares `go 1.26.2` (C-08 marked done but directive unchanged) — I-42/CLI owners.

## Validation

- Doc re-read end-to-end after write; every referenced repo path/agent ID verified to exist
  (see §14 of the doc): file:line references for loadMessages/sendMessage/subscribeToMessages/
  SecureStorageService/auth_provider deleteAccount/app_router chat route all grep-verified.
- All 16 agent IDs referenced (I-25, I-28, I-30, I-31, I-37, I-38, I-52, I-56, I-77, S-02, S-07,
  S-11, S-18, S-20, V-06, M-27, D-07) exist in AGENT-REGISTRY.md / FILE-OWNERSHIP.md.
- Sources listed in §0 of the doc; 8 URLs fetched during research (see above).
- No code changed; `dart analyze`/`flutter test`/`go test` untouched (docs-only agent).
