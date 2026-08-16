# 2026-08-16 — K1 security re-audit close (deleted_messages RLS, group bundle identity binding, 1:1 send serialization pin)

Agent: `K1-audit-close` (track: Security re-audit close).

## What was built

Three findings from the security re-audit were closed:

### Finding 1 (SEV HIGH) — `deleted_messages` had NO RLS

`supabase/migrations/20260815000006_message_delete.sql` created the deletion
audit trail WITHOUT `ENABLE/FORCE ROW LEVEL SECURITY` and without policies —
any anon/authenticated client could read/insert/delete the trail (violates
E2EE §9.3 "all new tables ENABLE + FORCE RLS", weakens §7.5a
non-repudiation).

- **New migration** `supabase/migrations/20260817000005_deleted_messages_rls.sql`
  (+ byte-identical `supabase-testing/migrations/` mirror):
  `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` + policy
  `deleted_messages_no_access FOR ALL USING (false) WITH CHECK (false)`
  (mirrors the admin_audit_log no-access pattern, full_schema.sql:785).
- **pgTAP:** Section 56e added to BOTH `schema_test.sql` files
  (byte-identical): `relrowsecurity` + `relforcerowsecurity` `ok()` asserts
  + `policies_are` for the no_access policy. Plan bumped 473 → **476**.
- **SECURITY.md ledger:** 33 → 34 RLS-enabled/FORCE tables (rows 56, 71, 85,
  87, G-01 table, §"re-verified" ledger at line ~350). Line refs verified
  against the migration file (ALTERs are at lines 30-31).
- **SECURITY DEFINER RPCs verified unchanged** (they run as the `postgres`
  superuser definer, who bypasses RLS even under FORCE — superusers are
  exempt): `delete_message_for_everyone` and
  `delete_undecryptable_messages` both wrote `deleted_messages` audit rows on
  the live DB after the migration (functional psql test, simulated JWT via
  `set_config('request.jwt.claim.sub', ...)`).
- **Client blocking verified:** `SET ROLE authenticated` → SELECT returns 0
  rows, INSERT raises 42501 (insufficient_privilege).

### Finding 2 (SEV LOW) — group bundle `sender_ik_dh` self-attestation

`processSenderKeyBundle` trusted the bundle's self-attested `sender_ik_dh`
(M can mint `sender_user_id = M` + `sender_ik_dh = S's published key`).

- `E2eeMessageCipher.boundPeerIkDh()` added to `lib/crypto/interfaces.dart`
  (+ docs); implemented in `E2eeSession` (`lib/crypto/session.dart:159`) —
  returns the peer X25519 identity key bound to the session (in-memory
  `_peerIkDh`, restored from the stored session JSON `peer_ik_dh` when the
  cipher was just created; null when no session).
- `processSenderKeyBundle` gains optional `expectedSenderIkDh` (base64url):
  when non-null, the bundle is accepted ONLY if its `sender_ik_dh`
  constant-time-equals it — checked on EVERY acceptance path (fresh record,
  identity change, epoch rekey, gap heal); mismatch → IGNORED. Null keeps
  best-effort (documented).
- `ChatService._decryptGroupRow` (`lib/core/services/chat_service.dart:1091`)
  obtains the pairwise session's bound key and passes it through
  (`base64UrlNoPadEncode`; codec import added).
- RED→GREEN tests: 4 new crypto tests (mismatch ignored/no record; matching
  accepted/reinstall-heal; spoof ignored against an EXISTING record; malformed
  expected key ignored) + 2 new service tests (spoofed-ik_dh bundle rejected
  end-to-end through the real pairwise+group stack; genuine bundle accepted —
  proves the bound key is actually passed).

### Finding 3 (SEV LOW) — no 1:1 send-serialization pin

`_sendTail` covers both paths but only the group path was tested.

- New service test mirrors the group concurrency test on the REAL 1:1
  pairwise encrypt path: `_GatedSessionStore` (Completer-gated
  `saveSession` — the final step of `E2eeSession.encrypt`) detects overlap;
  asserts strict serialization (`maxActive == 1`, trace
  `0-start/0-end/1-start/1-end`) + both messages inserted as DISTINCT
  envelopes. Harness gained `service({sessionStore})` + a swappable
  `cipher` field (real `GroupE2eeCipher` bound to the party's keys/sessions
  for the K1 tests).

## Decisions made and why

- **Expected-key check placed BEFORE the record-load guard** in
  `processSenderKeyBundle`: the check must apply to the fresh-record path
  too (no existing record → pre-fix "accepted"); placing it after the
  format/own-echo checks gives uniform behavior.
- **First-arrival gap documented:** the very FIRST distribution envelope of
  a pairwise session (the X3DH init that *creates* the session) decrypts
  with no bound identity yet → `expectedSenderIkDh = null` → best-effort.
  Every subsequent bundle is checked. The attack requires a later custom
  envelope, so the identity binding holds for all post-session deliveries.
- **`_GroupParty` harness:** the K1 service tests REUSE the setUp `bob`
  (whose prekey bundle is published on the fake server) and swap in a real
  cipher — a fresh party would carry a NEW identity that cannot decrypt
  envelopes addressed to the published bundle (delivery binding §6.5).
- **SECURITY.md adjusted** only where the count was a plain tally (33 → 34);
  no other prose touched.
- Session restore for `boundPeerIkDh` mirrors `peerIdentityChanged` (load
  from store on first access) — no session probe burns an OPK (fetchBundle
  never called).

## MISTAKE / gotchas

- **MISTAKE:** first service-test version built a fresh `_GroupParty` for
  bob with `realGroupCipher` — its fresh keyStore identity did not match the
  published bundle, so the init envelope was dropped at the delivery-binding
  check and the pairwise session never formed (RED test failed for the wrong
  reason). Fixed by swapping the cipher on the setUp party (whose identity
  IS published).
- **MISTAKE:** a no-op edit on `schema_test.sql` accidentally merged a
  comment line with the next `SELECT lives_ok(...)` (syntax break) — caught
  and reverted immediately by the failing pgTAP parse.
- `rg "FORCE ROW LEVEL SECURITY"` counts include COMMENT mentions (e.g.
  20260809000001 has 34 matches = 31 ALTERs + 3 header comments) — the real
  statement tally is 31+1+1+1 = **34**, matching the ledger.

## Commands run (reproducibility)

```bash
# RED: pgTAP against the live DB BEFORE the migration (3 not ok of 476)
psql "postgres://postgres:postgres@localhost:54382/postgres" -f supabase/tests/schema_test.sql
# RED: compile (expectedSenderIkDh undefined — 4 errors)
flutter analyze test/crypto/group_cipher_test.dart test/services/chat_service_test.dart
# GREEN: apply + verify
psql "postgres://postgres:postgres@localhost:54382/postgres" -v ON_ERROR_STOP=1 -f supabase/migrations/20260817000005_deleted_messages_rls.sql
psql "postgres://postgres:postgres@localhost:54382/postgres" -f supabase/tests/schema_test.sql   # 476 ok / 0 not ok
dart analyze lib/crypto lib/core/services test/crypto test/services                            # 0 issues
flutter test test/crypto/group_cipher_test.dart test/services/chat_service_test.dart           # 75/75
flutter test test/crypto                                                                        # 179/179 (regression)
bash test/opt-010-groups-chat.sh                                                                 # 29/29
# RPC functional check (SECURITY DEFINER still writes the trail under FORCE RLS)
# SET ROLE authenticated → SELECT 0 rows / INSERT 42501
```

## Results

- pgTAP plan: **476** (was 473; +3 assertions in 56e) — 476 ok / 0 not ok.
- Flutter: crypto 39/39 (incl. 4 new), services 36/36 (incl. 3 new) — 75/75.
- `dart analyze` 0 issues; opt-010 29/29.
