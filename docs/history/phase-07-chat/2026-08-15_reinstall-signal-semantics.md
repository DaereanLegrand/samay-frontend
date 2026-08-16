# 2026-08-15 — Reinstall = Signal semantics + message deletion

**Step:** `reinstall-signal-semantics` — "Mensaje no descifrable" on app
reinstall (user-reported), E2EE audit, protocol fix + deletion feature set.

## What was built

1. **Dead-OPK replacement on identity regeneration** (`publishIdentityBundle`,
   `lib/crypto/e2ee_prekey_service.dart`): when the server row's
   `identity_key` differs from the local identity (reinstall / account
   switch), the one-time-prekey pool is REPLACED with a fresh batch and
   `consumed_one_time_prekeys` resets — the old identity's OPKs have no
   private keys on the device, so peers initiating with them could never be
   decrypted (the live failure class). Same-identity republish keeps the
   merge/top-up behavior. Tests: reinstall + account-switch simulations;
   same-identity top-up fixture corrected to a real matching identity.

2. **Migration `20260815000006_message_delete.sql`** (both stacks):
   - `messages.sent_at` — server-authoritative send timestamp (default
     `now()`; existing rows backfilled from `created_at` so old history is
     never window-open).
   - `deleted_messages` audit table.
   - `delete_message_for_everyone(p_message_id)` — SECURITY DEFINER,
     sender-only, `now() - sent_at <= 5 minutes` with the server clock.
     Error strings the client maps: `MESSAGE_TOO_OLD`, `NOT_THE_SENDER`,
     `MESSAGE_NOT_FOUND`.
   - `delete_undecryptable_messages(p_chat_id, p_message_ids[])` — SECURITY
     DEFINER, participant-gated (messages_read_participant set), returns the
     deleted count, audits via a CTE `RETURNING` (first draft tried to
     SELECT the ids AFTER the DELETE — found nothing; MISTAKE block below).
   - pgTAP: 15 new assertions (428/428). Behavior verified live via psql
     with `request.jwt.claims` simulation (fresh delete ok / too-old /
     not-sender / participant cleanup / audit rows).

3. **Client — Signal reinstall semantics (hide + offload):**
   - `chat_service.dart`: decrypt failure with NO session → `needsSession`
     (never the placeholder); `loadMessages`/`subscribeToMessages`/
     `decryptInboxRow` batch-delete those rows server-side (best-effort;
     missing RPC / RLS errors swallowed — the rows stay hidden, next load
     retries). The placeholder survives only for session-present failures.
   - `chat_providers.dart`: `ChatMessagesState.messages` filters
     `needsSession` rows (pagination counts RAW rows — a full page of hidden
     rows must not flip `hasMore`); inbox preview empty for the no-session
     class.

4. **Client — long-press deletion (both options):**
   - `deleteMessageForEveryone` maps the server verdicts to
     `MessageDeleteOutcome`; `deleteMessageForMe` is an in-memory tombstone
     (server rows stay); `subscribeToMessageDeletes` (realtime DELETE
     channel — REPLICA IDENTITY FULL delivers the old record).
   - Chat screen: long-press → bottom sheet ("Eliminar para todos" for OWN
     messages within 5 min, "Eliminar para mí" always); too-old → snackbar;
     deleted → bubble removed locally + peer thread drops it live.
   - l10n: `chatDeleteForEveryone/ForMe/TooOld/Failed` (en/es, generated).

5. **Client — peer reinstall notice (§7.5):** `peerIdentityChanged` restores
   the session from the store before comparing (first-chat-open detection on
   a fresh cipher instance) and returns early WITHOUT fetching the bundle
   when no session exists (avoids burning a peer OPK); `peerNeedsRekey`
   wired at chat open; notice once per peer (flag in the Hive config box).

6. **Seed:** the demo chat section was REMOVED from `seed-dev.sql` (chat +
   participants + messages + the dead chat-notification) — an E2EE app
   cannot seed decryptable chat content (keys live on devices), and
   plaintext demo rows would be hidden + deleted by the cleanup on first
   contact. opt-005 threshold `>40` → `>=40` (8 rows removed).

## Decisions made and why

- **Hide + delete, not placeholder:** the user directive "no fallbacks" —
  Signal shows NO history after a fresh reinstall (its server stores none);
  Samay's server stores the rows, so the client hides them (pure Signal
  look) AND deletes them server-side (offload — "none would be able to
  access the data").
- **Server-verified 5-minute window:** anchored on `sent_at` (server
  default), not the client `created_at` — a lying client can never extend
  the window. Chosen over clamping `created_at` (would break legit
  client-clock ordering / seeded data).
- **Delete-for-everyone is sender-only** (WhatsApp/Signal model); the peer
  sees the row vanish live via the realtime DELETE channel.
- **No outbox persistence** (own sent messages after a plain restart still
  render the placeholder — session exists → not the no-session class): the
  user rejected caching own plaintext (would amend §8.4's "no plaintext"
  policy). Remains a documented MVP limitation (DEBUG-REPORT §C).
- **Trust surface accepted:** `delete_undecryptable_messages` is
  participant-gated (server can't verify "undecryptable"); every deletion is
  audited in `deleted_messages`.

## Mistakes / gotchas

> **MISTAKE — audit-after-delete:** the first draft of
> `delete_undecryptable_messages` INSERTed audit rows by SELECTing the ids
> from `messages` AFTER the DELETE — the rows were gone, so the audit was
> empty. Fixed with a CTE `DELETE ... RETURNING id, chat_id` feeding the
> audit INSERT. Caught by the psql behavior check, not by pgTAP (schema-only).

> **MISTAKE — fake-server id reuse:** `chat_e2ee_test`'s fake assigned
> message ids as `msg-${rows.length}`; after the cleanup deleted rows the
> count shrank and a new row reused a deleted id — Alice's
> `_decryptedByMessage` cache then served the STALE plaintext for Bob's new
> message (a confusing test failure). Fixed with a monotonic counter.

> **MISTAKE — migration named 20260816…:** `tools/check_migrations.sh` rejects
> timestamps after today (UTC). Renamed to `20260815000006` (next free
> sequence) and sed'd all code references.

> **MISTAKE — `pumpAndSettle` vs SnackBar:** the peer-reinstall-notice
> widget test used the shared `_pump` (which pumpAndSettles); the settle
> advanced the fake clock past the snackbar's 4s dismissal timer, so the
> snackbar was never visible to the finder. Fixed with `settle: false` + an
> explicit 500ms pump.

> **GOTCHA — mock stub ordering:** `_pump`'s default `peerNeedsRekey → false`
> stub overrode the notice test's `→ true` stub (mocktail: last registration
> wins). Guarded the default stub behind `service == null`.

> **GOTCHA — PostgrestException.message is non-nullable:** `e.message ?? ''`
> triggered `dead_null_aware_expression`. Removed the `?? ''`.

## Commands run (reproducibility)

```bash
flutter test test/crypto/e2ee_prekey_service_test.dart   # Fix 1 RED→GREEN
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -f supabase/migrations/20260815000006_message_delete.sql
# behavior smoke tests via request.jwt.claims simulation (both RPCs)
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql   # 428/428
flutter gen-l10n
flutter test test/    # 2298/2298
dart analyze          # 0 issues
bash test/opt-005-seed-dev-static.sh && bash test/opt-008-makefile-static.sh
bash tools/check_migrations.sh   # fails only on the untracked-migration gate (pre-commit)
```
