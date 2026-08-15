# "No se pudo enviar el mensaje" — REAL root cause: chats_read_participant SQL typo (2026-08-15)

**Branch:** `fixes` · **Worktree:** post-`af52ebf` (uncommitted by user directive)

## Symptom (user report)

Sending a chat message takes a long time, then fails with `chatSendError`
("No se pudo enviar el mensaje"). The chat thread appears empty.

## FIRST diagnosis was WRONG (MISTAKE block)

The first pass blamed the E2EE prekey-bundle gap (peers without published
keys → `fetch_prekey_bundle` NULL). That gap WAS real (tester/tester3 had no
`e2ee_identity_keys` rows) and the §12.2 step 4 auth hooks were indeed never
wired — the hooks fix shipped (publish on `createProfile` + heal on restore,
see 2026-08-15_LOG-e2ee-auth-hooks.md) — **but it did not fix the reported
bug.** The user was right: "YOU HAVE NOT SOLVED SHIT."

**MISTAKE:** diagnosed from server-side *state* instead of reproducing the
failure and reading the actual error. The send path swallowed it
(`catch (_)` in `chat_screen.dart`), so nothing ever logged it.

## Investigation (second pass — user directive: "ADD LOGS TO IDENTIFY THE ERROR")

1. Instrumented the whole send path with `AppLogger` (step logs + durations +
   PostgrestException code/message/details; no content/keys/envelopes):
   `chat_screen.dart` (`_send`/`_loadOlder` — the swallow sites now log the
   real exception + stack), `chat_providers.dart` (send/loadOlder),
   `chat_service.dart` (publishAll/encrypt/INSERT with raw PostgrestException
   detail), `e2ee_prekey_service.dart` (fetchBundle null-vs-bundle-vs-RPC
   error; publish top-up + upsert error), `session.dart` (`_ensureSessionReady`
   restore-vs-init + null-bundle throw), `auth_provider.dart` (hook publish
   timing). Full suite stayed 2238/2238.
2. Reproduced live with a temporary harness mirroring `ChatService.sendMessage`
   step-for-step against the real backend with tester2/tester3 (real crypto,
   real RPCs). **The error printed itself:**

   ```
   *** step INSERT FAILED ms=2290
       PostgrestException: new row violates row-level security policy for
       table "messages", code: 42501, details: Forbidden
   ```

   Publish, bundle fetch, X3DH, encrypt: ALL OK. The **messages INSERT was
   rejected by RLS**.

## REAL root cause (found via the harness + pg_policies)

`chats_read_participant` (`supabase/migrations/20260510000001_full_schema.sql:732`,
present since the ORIGINAL schema) used an **unqualified `id`** in the direct
branch:

```sql
(type = 'direct' AND EXISTS (SELECT 1 FROM chat_participants
    WHERE chat_id = id AND user_id = auth.uid()))
```

Inside the subquery, `id` resolves to `chat_participants.id` (the row's own
PK shadows the outer `chats.id`) → PostgreSQL evaluated
`chat_participants.chat_id = chat_participants.id`, true for NO row. So:

- every **direct chat was invisible to its own participants**
  (`chats` SELECT → `[]` even for members — the empty thread);
- every **`messages` INSERT violated `messages_insert_participant`**
  (its `chats` subquery passes through this policy) → **42501 → send fails**;
- after the failure, `refresh()` reloads the thread → still empty → the
  failure reads as "message never sent".

`messages_read_participant` (:744) used the qualified `chat_id = chats.id` —
correct — which is why every existing test passed: pgTAP asserts only policy
NAMES; opt-003 tested group/event chats (no shadowing column in those
branches); the Flutter chat tests run against a fake server. **A direct-chat
insert was never exercised against real RLS until the live repro.**

## The fix

- **Migration `20260815000003_fix_chats_read_participant.sql`** (both stacks,
  byte-identical): drops + recreates the policy with `chat_id = chats.id`,
  fully-qualified (20260809000002 convention). A full policy-expression sweep
  (same shadowing pattern `X.col = X.id`) found a SECOND instance —
  `chats_insert_related`'s direct branch (`chat_id = id` → dead branch, latent
  since client-side direct inserts go through the RPC) — fixed in the same
  migration.
- **pgTAP +2 (plan 388)** in both `schema_test.sql` mirrors: asserts the
  policy expressions contain `chat_participants.chat_id = chats.id` and NOT
  the shadowed form (`pg_get_expr` — catches this whole class of bug) for
  BOTH `chats_read_participant` (qual) and `chats_insert_related`
  (with_check).
- **opt-003 TEST F** (new, 6 checks): authenticated `create_direct_chat` RPC →
  participant reads the chat row → INSERTs an envelope message (http 201) →
  reads it back byte-for-byte → outsider C cannot see the chat. Third user C
  added to the opt-003 setup/cleanup.
- **Live DB fixed**: probing revealed `samay-api.qallariy.lat` serves THIS
  machine's testing-stack DB (marker write via local psql visible through the
  remote API) — the migration apply landed the fix in production.

## Validation

- `dart analyze` 0 · `flutter test` 2238/2238 · `go test ./...` green.
- pgTAP 388/388 on the live DB (psql fallback; `supabase db test` hangs on
  the pg_prove image pull — known).
- `bash test/run_all_backend.sh` → **8/8** (opt-003 now 19 checks incl. TEST F).
- Live end-to-end (harness, both directions, real crypto): publish OK →
  bundle OK → encrypt OK → **INSERT OK → readback OK** (was 42501).
- Diagnostic rows injected into the tester2↔tester3 chat during the repro
  were deleted.
- Policy sweep for the shadowing class (`= same_table.id`) over ALL policies:
  only the two `chats` policies matched — both now fixed.

## MISTAKE blocks

- **MISTAKE-1 (diagnosis):** blamed the prekey-bundle gap without reproducing.
  The bundle gap was real but NOT the reported failure. Reproduce first; the
  error was invisible only because `catch (_)` swallowed it.
- **MISTAKE-2 (SQL, 20260510):** unqualified `id` in a policy subquery —
  shadowed by `chat_participants.id`. Lesson: correlate OUTER tables by
  explicit name in every policy; pgTAP must assert policy EXPRESSIONS (not
  just names) — now done for this policy.
- **MISTAKE-3 (harness):** jsonb RPC responses format `"chatId": "..."` with a
  space after the colon — the first `grep -o '"chatId":"…"'` missed it.
- **MISTAKE-4 (opt-003 TEST F draft):** used user B as the "outsider" for the
  A↔B direct chat — B is a participant. Third user C added.

## Follow-ups

- The E2EE auth-hooks work (previous session) stands as a separate genuine
  fix (documented in 2026-08-15_LOG-e2ee-auth-hooks.md); both ships together.
- The shadowing sweep is done (only the two `chats` policies matched, both
  fixed); future policy reviews should assert EXPRESSIONS, not just names.
