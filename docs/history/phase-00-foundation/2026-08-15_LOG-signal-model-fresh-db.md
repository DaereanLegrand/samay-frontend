# Signal model: identity survives sign-out + stale-bundle heal + fresh DB (2026-08-15)

**Branch:** `fixes` · **Worktree:** post-`af52ebf` (uncommitted by user directive)

## Symptom (user report, waydroid + emulator logs)

After sign-out/in, the fresh-init heal fired correctly (`e2ee unacknowledged
init … re-initiating with a fresh init envelope`, `type=init(0x01)`) — but the
**receiver dropped the init silently** (`chat decrypt failed … undecryptable
(null decrypt or throw; see above)` with no preceding log). The sender's init
carried an identity the receiving device couldn't honor.

## Root cause (verified by decoding the live envelope)

- The failed init's `senderIkDh` ≠ the sender's **published** identity
  (DB row), and its `recipientIkDh` matched the recipient's **published**
  identity — but the recipient's **local** key material no longer matched its
  own row.
- **Why stale:** there are only three publish paths, and none fires after a
  sign-out/in:
  1. `createProfile` → `publishAll` (signup only);
  2. `handleMissingSession` — checked only "does a row exist?" (it did → skip);
  3. `sendMessage` → `publishAll` — guarded by `!_sessions.containsKey(chatId)`,
     and **opening the chat caches the session first** (the waydroid logs:
     `chat resolvePeer` at 08:53:56 → `chat sendMessage` at 08:54:52 with the
     publish skipped).
- `signOut` wiped the local identity (§7.6 old design) → next start
  regenerated it → the server row kept advertising the OLD identity → peers
  initiate against material the device no longer holds → silent drop at
  `_handleInitEnvelope` (recipient-binding / SPK / OPK checks — all unlogged).

## What was built

1. **Signal model (§7.6 rewrite, option B chosen by user):**
   - `signOut` NO LONGER wipes — the identity/prekeys/sessions are bound to
     the ACCOUNT (like Signal's protocol store). Same-account re-sign-in
     decrypts old chats without re-key.
   - **Account-switch ownership guard:** `E2eeKeyStore.ownerUid()` /
     `setOwnerUid()` (`samay.e2ee.owner_uid`); `_ensureE2eeKeysPublished`
     wipes both stores when a DIFFERENT account signs in, before the heal
     publishes. `deleteAccount` still wipes everything.
2. **Stale-bundle heal:** `handleMissingSession` republishes when the
   published `identity_key` ≠ the local identity — the server mirror always
   matches device material (Signal's model: no "row exists → skip").
3. **Init-drop logging:** `_handleInitEnvelope` now logs every silent drop
   (recipient-binding / missing X3DH fields / own-echo / replay / unknown
   SPK/OPK) — the "see above" paths the emulator hit.
4. **Fresh DB (user request):** `make supabase-testing-reset` path executed
   (`reset.sh`: down → wipe db-data/minio volumes → up → all migrations →
   seed). Live backend == this stack, so prod is fresh too. pgTAP **401/401**
   on the fresh DB (pgtap extension re-created), opt suite **8/8**, tester
   accounts recreated (tester2/tester3 @tester.com / tester123).

## MISTAKE blocks

- **MISTAKE (ownership guard + widget tests):** the ownership block reads the
  secure store during the auth restore; `FlutterSecureStorage` platform calls
  never complete under `testWidgets`' FakeAsync → the avatar upload tests hung
  on `await authStateProvider.future`. Fix: profile harness overrides the
  E2EE stores with memory twins (test isolation — E2EE is not under test
  there). Kept the ownership code unchanged (real devices complete fine).
- **MISTAKE (flush test):** the new auth_scope_reset chat-service flush test
  initially failed — `ref.invalidate` from the widget listener only takes
  effect after the provider has seen a prior transition; mirroring the
  friends test's intermediate same-uid `auth.set` fixed it (same rhythm,
  same pass).
- **MISTAKE (bisecting):** first diagnosis blamed the heal; the bisect showed
  the heal is fine in widget tests and the ownership block was the hang.

## Validation

- `dart analyze` 0 · `flutter test` **2266/2266** (was 2259; +7: signOut-keeps,
  account-switch wipe, heal-republish, expired-session rework, flush test).
- `go test ./...` green · pgTAP **401/401** fresh DB · opt suite **8/8**.
- Fresh DB: 0 messages / 0 identity rows / 0 chats; tester accounts verified
  (sign-in + `get_chat_inbox` = []).

## Device instructions (user)

- Uninstall the app on BOTH devices (Waydroid + emulator), then `make dev`
  — the app starts with a clean slate against the fresh DB.
- Sign in with tester2 on one device and tester3 on the other (or register
  new accounts). First send shows `type=init(0x01)`; the peer decrypts; the
  reply acknowledges; ratchet resumes.
- Sign-out/in no longer rotates the identity — same-account re-sign-in keeps
  the keys and old chats stay decryptable.

## Follow-up (same day): REALTIME tenant fix — root cause + resolution

**Symptom:** friends/chat/inbox needed a hot restart to show updates — no live
realtime delivery on any screen.

**Root cause (agent investigation, supabase/realtime v2.102.3):** Kong's
`realtime-v1` route forwards the websocket to `http://samay-testing-realtime:4000`
without `preserve_host` → the upstream host becomes the `Host` header, and
realtime derives the tenant id from the Host's first label
(`RealtimeWeb.UserSocket.connect` → `Database.get_external_id(host)`). The
seeded tenant was `realtime-dev` (seed default) → every join →
`TenantNotFound: samay-testing-realtime`. Nothing ever exercised live realtime
before the two-device test, so it was broken from the start.

**Fix:**
1. `_realtime.tenants.external_id` → `samay-testing-realtime` (FK re-added with
   `ON UPDATE CASCADE`).
2. `supabase-testing/docker-compose.yml` realtime service:
   `SELF_HOST_TENANT_NAME: "samay-testing-realtime"` — the startup seed
   re-creates the row keyed by that env, so it survives restarts.

**Verification:** raw-websocket probe (`dart:io`) — `phx_join` on
`realtime:postgres_changes` → `phx_reply ok`, then a live `messages` INSERT
event received. Local + remote URL. After `docker compose up -d realtime` and
`docker restart` — still one consistent row, 0 TenantNotFound. opt suite 8/8
(incl. opt-007 compose static gate). Report: docs/audit/2026-08-15_DEBUG-REPORT.md.
