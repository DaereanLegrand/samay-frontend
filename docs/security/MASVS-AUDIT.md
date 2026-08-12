# Samay — OWASP MASVS v2.0 Audit (S-01)

**Agent:** S-01 (Phase 4.5 — Security) · **Date:** 2026-08-11 · **Branch:** `fixes`
**Method:** static audit of `lib/`, `android/`, `ios/`, `supabase/` against
OWASP MASVS v2.0 control groups (https://mas.owasp.org/MASVS/) · MASVS v2.0
(mobileAppSecVerificationStandard) · MASTG references where relevant.
**Verdict legend:** ✅ pass · ⚠️ partial · ❌ fail · 🔲 n/a (feature absent)

---

## MASVS-STORAGE (S1: secure storage)

| Control | Verdict | Evidence |
|---|---|---|
| S1.1 — Credentials/tokens in secure storage | ✅ | Sessions + PKCE verifier in `flutter_secure_storage` (iOS Keychain / Android Keystore): `lib/main.dart:108` wiring, `SecureSessionStorage`/`SecurePkceStorage` (I-25/I-30); Hive AES-256 key at `samay.hive.key` in secure storage (I-26) |
| S1.2 — E2EE key material in secure storage | ✅ | `SecureE2eeKeyStore` (`lib/crypto/e2ee_key_store.dart`) — X25519 identity + ratchet keys, `flutter_secure_storage` namespaces (`lib/crypto/interfaces.dart:61-66`); never in Hive/logs (E2EE-ARCHITECTURE §8) |
| S1.3 — No sensitive data in shared storage/logs | ⚠️ | `AppLogger` (I-05) is the only logger; no sensitive-field logging seen in audit. ⚠️ Chat `messages.content` plaintext in Postgres until E2EE ships client-wide (E2EE-ARCHITECTURE; server-side ciphertext once I-38 flow is the only writer) |
| S1.4 — Backups exclude secrets | ✅ | Android `allowBackup="false"` (`android/app/src/main/AndroidManifest.xml:21`, M-27 — Keystore-wrapped material can't be adb-exfiltrated); iOS: Keychain items excluded from backup by default (kSecAttrAccessible default); E2EE keys never in Hive (backup surface) |
| S1.5 — Keyboard/screenshot clipboard leakage | ⚠️ | No screenshot protection (`FLAG_SECURE`/iOS snapshot policy) implemented; no clipboard sanitization on OTP paste. Mobile-scanner camera preview is a natural screenshot surface |
| S1.6 — App sandbox not disabled | ✅ | No device-root/jailbreak bypass, no debugger-attach backdoors, no `android:debuggable` in release manifest (M-27) |
| S1.7 — Uninstall/purge removes data | ✅ | E2EE `wipeAll()` on account delete (`lib/crypto/session.dart:170` — §7.6); Hive boxes + secure-storage keys purged in `deleteAccount` path |

## MASVS-CRYPTO (S2: cryptography)

| Control | Verdict | Evidence |
|---|---|---|
| S2.1 — Approved algorithms only | ✅ | Crypto policy (`docs/security/SECURITY.md` §3.1): X25519, Ed25519, AES-256-GCM, HKDF-SHA256, SHA-256/512 — no MD5/SHA-1/ECB/RC4/DES/3DES in `lib/crypto/` (I-37, 106 unit tests) |
| S2.2 — Keys generated with CSPRNG | ✅ | `Random.secure()` / `SecureRandom` in the crypto core; no `Random()` key material (I-37 tests assert non-determinism) |
| S2.3 — Nonces unique per key | ✅ | AES-256-GCM 96-bit random nonce per message; nonce reuse guarded by the ratchet chain state (E2EE-ARCHITECTURE §4/§6; S-07 re-verifies) |
| S2.4 — No hardcoded keys | ✅ | Zero key material in code (secrets-check enforces); placeholders only |
| S2.5 — Key derivation domain separation | ✅ | HKDF `info` strings distinct per use (E2EE-ARCHITECTURE §3.1) |
| S2.6 — Hive-at-rest encryption | ✅ | `HiveAesCipher` AES-256 on all 4 boxes, key in secure storage, `crashRecovery: false` (I-26; SEC-10/M-32 closed) |
| S2.7 — TLS ≥1.2, valid certs | ✅ | Platform defaults (ATS untouched on iOS, cleartext blocked by default); self-hosted dev HTTP is localhost-only. ⚠️ no certificate pinning (see S5) |

## MASVS-AUTH (S3: authentication)

| Control | Verdict | Evidence |
|---|---|---|
| S3.1 — AuthN per user | ✅ | GoTrue email+password+OTP; PKCE pinned (`AuthFlowType.pkce`, I-30); refresh-token rotation + 10 s reuse interval (config.toml:57-59) |
| S3.2 — Session lifecycle | ✅ | Access JWT 1 h; explicit refresh failure → unauthenticated transition (I-30); session + verifier persisted in secure storage |
| S3.3 — Biometric where claimed | 🔲 | Not implemented (not claimed) |
| S3.4 — Password policy | ⚠️ | `minimum_password_length = 6` (config.toml:62) — below NIST SP 800-63B §5.1.1 (≥8). **Finding S3.4-1** |
| S3.5 — App-specific password reuse checks | 🔲 | n/a (no such feature) |
| S3.6 — Concurrent session control | ⚠️ | No device-session revocation UI; refresh rotation limits token replay window only |
| S3.7 — Session termination | ✅ | `signOut()` clears session + secure storage; ban enforcement flips auth state (I-35) |
| S3.8 — Account deletion | ✅ | Soft delete + hard-delete cron; E2EE wipe (DELE) |
| S3.9 — Session tokens via secure channel | ✅ | All auth calls over HTTPS in prod (Kong 54443); localhost dev HTTP |

## MASVS-NETWORK (S4: network communication)

| Control | Verdict | Evidence |
|---|---|---|
| S4.1 — TLS for all endpoints | ✅ | Supabase client defaults; ATS default (no `NSAllowsArbitraryLoads`); Android `usesCleartextTraffic` not enabled |
| S4.2 — Pin validation | ⚠️ | No certificate pinning (documented gap, S-05/M-27 handoff) |
| S4.3 — Mutual TLS | 🔲 | n/a (bearer model) |
| S4.4 — Network security config | ⚠️ | No custom `network_security_config.xml` on Android (base-config cleartext default is fine; pinning would live here) |
| S4.5 — Sensitive data over WSS/TLS | ✅ | Realtime WS rides the same TLS-terminated Kong route |

## MASVS-PLATFORM (S5: platform interaction)

| Control | Verdict | Evidence |
|---|---|---|
| S5.1 — App permissions minimal | ✅ | `permission_handler` seam (I-28); manifest declares camera (mobile_scanner) + media (image_picker) only; no broad storage/contacts/location |
| S5.2 — WebView hardening | 🔲 | No WebViews used |
| S5.3 — Deep-link handling | ⚠️ | `DeepLinkHandler` (I-66) validates `samay://event/<token>` shapes; ⚠️ invite-token validation vs `/event/:eventId` route shadowing (pre-existing NAV issue, Phase 05) — S-12 deep audit follows |
| S5.4 — IPC exposure | ⚠️ | Android `exported=true` on the launcher activity only (M-27); no custom ContentProviders/Services exported; ⚠️ no intent-filter allowlist review committed to this audit — S-18 |
| S5.5 — Tapjacking | 🔲 | Not assessed (no overlay permission used by the app) |

## MASVS-DATA (S6: data privacy / PII)

| Control | Verdict | Evidence |
|---|---|---|
| S6.1 — Data minimization | ⚠️ | Collects email, DoB (age gate), username, bio, photos — all in product spec; interest tags opt-in (`discovery_opt_in` default false) |
| S6.2 — Privacy policy/ToS consent | ✅ | Mandatory non-prechecked checkboxes at signup (privacy_terms_screen, L29733 §4.1) |
| S6.3 — User data control (delete/export) | ⚠️ | Delete-account flow complete (DELE); ❌ no data-export feature (not in MVP spec — note for App Store/Play) |
| S6.4 — PII protection in transit/at rest | ✅ | TLS everywhere; RLS primary layer; chat E2EE roadmap; DoB retained only for the age gate |
| S6.5 — Analytics opt-out | ⚠️ | Telemetry is a stub (no PostHog key shipped); `discovery_opt_in` default off; no global opt-out UI yet (I-68 foundation) |

## MASVS-CODE (S7: code quality / backend hardening)

| Control | Verdict | Evidence |
|---|---|---|
| S7.1 — Injection-free queries | ✅ | No `.or()` string interpolation in Dart (SEC-02, C-04, 0 hits); Go query builder parameterized (I-40); S-04 re-audits |
| S7.2 — Backend authN/AuthZ (RLS) | ✅ | FORCE RLS on all 31 tables (I-31); **20260811000001 closed the image-default-privilege anon-EXECUTE hole on all 17 SECURITY DEFINER functions** (verified live, S-01 cross-check: `anon_exec=f` on 15, 2 intended) |
| S7.3 — Error handling without leakage | ✅ | `AppError` hierarchy maps PostgREST codes → user-safe messages (I-08; error_mapper_test 82 cases) |
| S7.4 — Secure logging | ⚠️ | `AppLogger` only; no PII/session logging found; ⚠️ server logs (Kong/PostgREST) retain request bodies at `warn` level — review before prod |
| S7.5 — Server config hardening | ✅ | Search-path-hardened SECURITY DEFINERs (I-31 + 20260811000001 donate); Kong key-auth + ACL consumer model |
| S7.6 — Rate limiting | ⚠️ | GoTrue limits configured (email_sent=2 etc.); ❌ no Kong rate-limit plugin; app_config thresholds unenforced (FLMT blocked on Edge Functions) — S-10 |
| S7.7 — Dependency hygiene | ⚠️ | Lockfiles committed (pubspec.lock, go.sum, Gemfile.lock); compose images pinned (M-01..M-10) — **S-02 CVE scan is the evidence step** |
| S7.8 — Secrets in builds/CI | ✅ | `secrets-check` gate (M-13); `.env` NOT a Flutter asset (I-34); CI/workflow files carry placeholders only (M-20..M-22); Makefile never prints env values |

---

## Findings (ranked)

| # | Severity | Finding | Control | Status |
|---|---|---|---|---|
| S3.4-1 | LOW | `minimum_password_length = 6` — raise to ≥ 8 (NIST SP 800-63B §5.1.1) | S3.4 | open (config.toml; ops change) |
| S1.5-1 | MEDIUM | No screenshot-protection on sensitive screens (OTP, QR) | S1.5 | open (S-18 scope) |
| S4.2-1 | MEDIUM | No certificate pinning; no Android network-security-config | S4.2/S4.4 | open (S-05 follow-up) |
| S3.6-1 | LOW | No session-revocation UI (all-sessions sign-out) | S3.6 | open (product decision) |
| S7.5-1 | INFO | pgTAP test harness functions live in `public` schema (anon-executable, test-only) — relocate/drop after CI runs | S7.5 | open (S-03) |
| S6.3-1 | LOW | No data-export feature (store-review risk) | S6.3 | open (product decision) |

**Previous criticals closed by this campaign's Step-0 work (cross-checked here):**
- anon EXECUTE on all 17 SECURITY DEFINER functions (incl. shard minting, PII-deletion cron, E2EE bundle exfiltration) — **FIXED** (migration 20260811000001, verified `anon_exec=f`).
- NULL-unsafe `auth.uid()` guard in `donate_shards_to_group` — **FIXED** (throws_ok + live denial).
- Dead `groups_read_member`/`groups_update_promotor` RLS policies (unqualified `id`) — **FIXED**.
- Table-grant-beaten column REVOKEs on groups/events — **FIXED** via `assert_safe_group_update`/`assert_safe_event_update` triggers (users trigger existed).

**Sources:** MASVS v2.0 (mas.owasp.org/MASVS/) · MASTG (mas.owasp.org/MASTG/) ·
NIST SP 800-63B (pages.nist.gov/800-63-3/sp800-63b.html) · SECURITY.md (D-06) ·
E2EE-ARCHITECTURE.md (D-07) · verified against the working tree + live DB
(2026-08-11, commit `a44bd64`).

*Samay MASVS Audit — S-01 · 2026-08-11 · next review after S-03/S-05/S-18 land*
