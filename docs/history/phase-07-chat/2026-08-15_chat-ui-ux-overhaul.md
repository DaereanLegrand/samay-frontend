# 2026-08-15 — Chat UI/UX overhaul: white voice, WhatsApp statuses, ordering fix

User request (2026-08-15): chat UI/UX overhaul — fix message disorder at the
start of threads, show time + date per message, implement sent/received/read
status ticks (WhatsApp-style) with a read-receipts privacy toggle, replace the
orange (peach) with WHITE on buttons and bubbles, and show the PEER USERNAME
in the chat AppBar (not "Chat").

E2EE was just made to work live and is explicitly out of bounds: this pass is
UI/UX + the minimal read-receipt backend. All E2EE paths (envelope format,
insert payload, decrypt flow, session/ratchet, `_decryptTail` serialization,
outbox) are untouched.

## What was built

### 1. Message ordering fix (root causes)
- `ChatService.loadMessages` had no secondary sort key → same-`created_at`
  rows (both sims supply client clocks) came back in non-deterministic order.
  Added `.order('id', ascending: false)` tie-break. This ALSO makes the E2EE
  decrypt order deterministic across loads (strictly safer for the ratchet).
- `ChatMessagesNotifier.addMessage` APPENDED realtime rows regardless of
  timestamp → a late-delivered older row stuck at the tail forever. Replaced
  with a sorted insert by `(created_at, id)` in `ChatMessagesState`
  (`insertMessage`, `compareRows`, `sortRows`; `fromPaged` re-sorts merged
  pages). Pending-row lifecycle: a peer's row never touches local pendings;
  the server row of the SAME sender drops its pending twin.
- Optimistic send: the outgoing bubble appears immediately with a single grey
  check (WhatsApp "sent") and is replaced by the committed row on refresh.

### 2. Time + date in bubbles
- Every bubble footer shows `HH:mm` (intl, local tz). Decorative → wrapped in
  `ExcludeSemantics` so the bubble announces exactly its content (the a11y
  4.1.2 contract for the undecryptable placeholder).
- Date separator chips between day groups: "Hoy"/"Ayer"/`dd/MM/yyyy`
  (new l10n keys `commonToday`/`commonYesterday`, es + en).

### 3. Sent / received / read (backend read receipts)
- Migration `20260815000005_chat_read_receipts.sql` (mirrored in
  `supabase-testing/migrations`, pgTAP extended 401→413):
  - `messages.read_at timestamptz NULL` — per-message receipt, INSERT path
    untouched (E2EE-inert).
  - `mark_messages_read(p_chat_id)` — SECURITY DEFINER, self-only participant
    guard, `search_path=''`, stamps `read_at` only on `sender_id <> me`.
  - `users.read_receipts_enabled boolean NOT NULL DEFAULT true` — the privacy
    switch (written via the existing `users_update_own` RLS).
- ChatService: selects `read_at`; `markMessagesRead`; `getReadReceiptsEnabled`/
  `setReadReceiptsEnabled` (mirrors the `getDiscoveryOptIn` pattern);
  `subscribeToMessageReads` (realtime UPDATE channel — the UI merges ONLY
  `read_at`, never decrypts the envelope).
- Status ticks (own bubbles): ✓ grey = sent (pending row) · ✓✓ grey =
  received/delivered (committed, `read_at` NULL) · ✓✓ BLUE = read
  (peer's device stamped it; flips live via realtime). New palette tokens
  `statusGrey` #757575 (4.6:1 on white) and `statusRead` #007AFF (4.0:1 on
  white) — added to `AppColors.all` + the palette-completeness test.
- Mark-read gating: the chat screen stamps receipts on open + on every
  realtime insert while open, ONLY when `read_receipts_enabled` is ON —
  when off, nothing is ever stamped (the peer never sees blue checks).

### 4. White voice + header
- Own bubbles: SOLID WHITE fill, black text, radius 16, no gradient/glow/
  hairline. Peer bubbles: unchanged white-only glass. Send button: flat
  `VButton.emphasized` (white fill, black label) — the peach gradient is gone
  from every chat control; the composer's thinking dots stay black-on-white.
- AppBar title = the peer's username from `chatInboxProvider` (fallback
  "Chat" only until the inbox resolves; the list is the normal entry so it is
  warm).

### 5. Settings
- New CHAT section in Settings with the read-receipts switch (optimistic,
  rolls back + snackbar on failure; `chatReadReceiptsSaveError` l10n).
  `readReceiptsEnabledProvider` (chat feature, autoDispose).

## Files
- lib/core/services/chat_service.dart, lib/core/repositories/chat_repository.dart
- lib/features/chat/providers/chat_providers.dart
- lib/features/chat/screens/chat_screen.dart
- lib/features/profile/screens/settings_screen.dart
- lib/core/design_tokens/app_colors.dart
- lib/l10n/*.arb + generated (commonToday/commonYesterday, chatReadReceipts*,
  chatSent/chatReceived/chatRead, settingsSectionChat)
- supabase(+testing)/migrations/20260815000005_chat_read_receipts.sql
- supabase(+testing)/tests/schema_test.sql
- test/: chat_screen_test.dart (rewritten for the new UI), chat_state_test.dart
  (new — ordering/pending/read-merge), chat_pagination_test.dart (fixtures get
  realistic timestamps; sorted-insert assertion), restyle_test (3rd settings
  card), a11y (new repo stubs), responsive (subscribeToMessageReads stub),
  app_colors_test (2 new tokens)

## Testing
- `flutter test` 2281 pass, `dart analyze` clean, `go test ./...` pass.
- pgTAP 413/413 against the local testing stack (applied the migration +
  re-applied the `supabase_admin` default-privilege hardening — see MISTAKE).
- Both simulators rebuilt (`make build TESTING=true TARGET=simulator`) and
  relaunched with the new UI. Manual E2E is with the user (my UI-driving
  harness was unreliable; dropped it).

## Decisions
- Three states map to real signals: pending row = sent; committed = received;
  `read_at` set = read. No fake timers, no heuristics.
- The reader's OWN device decides whether receipts are SENT (privacy switch);
  the sender always shows blue when `read_at` is set — correct by construction
  because the reader only stamps when enabled.
- `addMessage` drops a pending row only when the incoming row's sender matches
  (a peer's row must never remove the user's in-flight bubble).
- Keep the peach aurora at α0.04 + peach unread badge on the list (micro-
  accents only); the directive covered buttons and bubbles.

## MISTAKE
- `flutter drive` UI automation: three failed approaches (dart-defines not
  forwarded in a backgrounded shell; a fresh make-minted Kong key that never
  matched the key passed to the app; the app booting to the crash-recovery
  dialog + welcome/login states). The reliable path was `xcrun simctl`
  screenshots + macOS Vision OCR (swift one-liner) — used to identify the
  screens; final visual QA left to the user.
- The local testing stack had drifted: `pg_default_acl` for `supabase_admin`
  still granted anon EXECUTE on functions (pgTAP #351 failed BEFORE this
  change). Fixed on the stack only (as `supabase_admin`): re-applied the
  REVOKE EXECUTE default-privilege hardening from 20260811000001. Not
  committed (DB state, not code).
- Two l10n arb edits initially corrupted the JSON (a duplicated description
  fragment after an edit); `flutter gen-l10n` caught it with a clear
  FormatException — fixed by hand before regenerating.

## Commands (reproducibility)
- make migrate-check (fails on untracked migration by design — commit first)
- psql ... -f supabase-testing/migrations/20260815000005_chat_read_receipts.sql
- PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres \
    -f supabase-testing/tests/schema_test.sql
- flutter gen-l10n; dart analyze; flutter test; go test ./...
- make build TESTING=true TARGET=simulator
- xcrun simctl install/launch <udid> com.qallariy.samay
