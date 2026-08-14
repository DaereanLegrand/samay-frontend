# Phase 07 — Chat · PLAN

> Compiled by D-12 (2026-08-09) from `docs/specs/steps/phase-07-chat/*` and
> `docs/specs/steps/cross-references.md`. Read-only planning aid for I-49..I-78.

## Summary

Build the real-time chat system on Supabase Realtime (`messages` table
subscriptions). Three chat types: **group** (auto-created with the group),
**event** (auto-created with the event), **direct** (DM pair created on first
message). Includes the rolling message cap (DB trigger) and message reporting for
UGC compliance (App Store requirement).

Key mechanics (from specs):
- Load last 50 messages on open; scroll-up pagination for older history.
- Realtime INSERTS append at bottom; "Nuevo mensaje" chip if user is scrolled up.
- Message cap: `chat.message_cap` (1000) rolling window enforced by
  `message_cap_trigger` (already in schema, TRIG ✅).
- Media messages: upload to Storage `chats/{chat_id}/media/`, URL in `media_url`.
- Long-press → Report → `reports` row + `messages.reported = true` (visible until
  admin action).
- **Backend service layer is already complete (C-02):** `loadMessages`,
  `sendMessage`, `subscribeToMessages`, media upload helpers exist in
  `lib/core/services/supabase_service.dart`. Only screens + client logic missing.
- E2EE (X3DH + Double Ratchet) is a planned enhancement via I-37 (`lib/crypto/**`)
  then I-38 (chat E2EE integration) — ciphertext-only server.

## Steps & dependency status (cross-references.md, verified 2026-08-09; I-38 update)

| Step | Direct deps | Dep status | Step status |
|------|-------------|------------|-------------|
| `CHAT` | `AUTH`⚠️, `SBAS`✅, `DSNG`✅ | 2/3 green | 🔄 E2EE chat shipped by I-38 (2026-08-09): `/chat/:chatId` = real `ChatScreen` (was `VComingSoonScreen`), send/load/realtime E2EE-wired. **I-56 (2026-08-09): message-history pagination shipped** — last-50 on open + "Cargar anteriores" page loading (offset += 50, dedupe, `hasMore`), `chat.message_cap` (1000) cap awareness, E2EE service-only invariant pinned by `verifyNever` tests; pagination tests at `test/features/chat/chat_pagination_test.dart` + screen button/loader widget tests. Remaining CHAT gaps: chat list screen, media attachments, direct-chat creation, sender avatar/username rows, "Nuevo mensaje" chip (per `CHAT-chat-system-core.md`) |
| `CHPT` | `CHAT`❌, `DATA`✅, `SECU`✅ | 2/3 green | ❌ No code |
| `CHMC` | `CHAT`❌, `DATA`✅, `TRIG`✅ | 2/3 green | 🔄 Trigger exists; client cap awareness landed with I-56 (provider never pages past 1000); report flow absent |

**E2EE status (I-38, 2026-08-09):** crypto core (I-37) + chat integration shipped and
tested (116 crypto + 10 chat tests green). Migration `20260809000003_e2ee_tables.sql`
(e2ee_identity_keys + fetch_prekey_bundle RPC) + pgTAP Section 41 in both
`schema_test.sql` (plan 233). Follow-ups: auth lifecycle hooks (publish at profile
creation, `wipeAll()` on sign-out — §12.2 step 4), group fan-out (§9.6), S-07 audit
before chat ships (SECURITY.md §5.2).

## Orchestration agents starting here

| Agent | Scope (per ORCHESTRATION.md / FILE-OWNERSHIP.md) |
|-------|--------------------------------------------------|
| I-56 | `lib/features/chat/chat_screen.dart` (message list foundation) — ✅ pagination shipped (2026-08-09, daily log `2026-08-09_I56-chat-pagination.md`) |
| I-37 | `lib/crypto/**` (X25519, Double Ratchet, envelope) — E2EE pre-req |
| I-38 | `lib/features/chat/**` E2EE integration + `chat_service` |
| I-49/I-50/I-51 | Feature flags / repositories / typed REST client foundations |
| I-52 | Realtime lifecycle (chat is the heaviest Realtime consumer) |
| I-76 | `test/opt-003-chat.sh` (backend opt-test: message cap, insert, report) |
| I-77 | pgTAP expansion (messages/reports/chats invariants) |
| I-78 | Full-matrix sweep |

## Acceptance checklist (from the step specs)

**CHAT (`CHAT-chat-system-core.md`):**
- [x] E2EE chat screen (I-38): message list, composer, send/load/realtime through the E2EE stack (functional; visual polish → U-12)
- [x] E2EE: X3DH + Double Ratchet wiring in `chat_service` (encrypt-on-send, decrypt-on-load/realtime, `decryptFailed` placeholder) — I-38
- [x] Last-50 load on open + pagination for older history (I-56: `chatMessagesProvider` family — `loadOlder()` offset += 50, prepend + dedupe by id, `hasMore`, `loadingOlder`, `chat.message_cap` 1000 cap awareness; UI = "Cargar anteriores" button / loader row at the list top — button chosen over scroll-to-top for testability, documented in `chat_screen.dart`)
- [ ] Chat list screen: name, last-message preview, unread count, timestamp, most-recent-first (I-76/phase-07 future)
- [ ] Reversed list polish: sender avatar + username + media thumbnail → fullscreen (history paging itself is done)
- [ ] Input bar: attachment (image → Storage → `media_url`)
- [ ] "Nuevo mensaje" chip when scrolled up
- [ ] Direct chat creation: first-message → `chats` (type=direct) + 2 `chat_participants` rows + message

**CHPT (`CHPT-chat-participation-access-rules.md`):**
- [ ] Participation models: group chat = all `group_members`; event chat = group members (if group-scoped) or accepted invitees (if public); direct = the two `chat_participants`
- [ ] RLS for chats/messages per model (SECU layer — verify existing policies cover all three before shipping)
- [ ] Client access check before opening a chat; UI for non-participants ("No tienes acceso a este chat..."), blocked-user messaging ("No puedes enviar mensajes a este usuario.")

**CHMC (`CHMC-message-cap-reporting.md`):**
- [ ] Message cap verified end-to-end (insert #cap+1 deletes oldest; newest 1000 retained; client unaware)
- [ ] Long-press → "Reportar" → reason required → submit (updates `messages.reported`, inserts `reports` row) → "Gracias. Revisaremos este mensaje."
- [ ] Admin moderation path via `RPTS` (remove → DB + Storage cleanup; warn → in-app notification)

## Phase exit gate

All 3 steps green in cross-references.md; `/chat/:chatId` + group chat tab real;
opt-003-chat + pgTAP green; E2EE either shipped (I-37/I-38) or explicitly flagged
deferred; full matrix green.

## E2EE shipped (I-37 + I-38, 2026-08-09)

- `lib/crypto/**`: X3DH + Double Ratchet + envelope + key/session stores (I-37).
- `lib/features/chat/**` + `chat_service` + migration `20260809000003` + pgTAP §41 (I-38).
- Daily log: `docs/history/phase-07-chat/2026-08-09_I38-chat-e2ee.md`.

## Pagination shipped (I-56, 2026-08-09)

- `chatMessagesProvider` (family) paginates message history: last-50 first page,
  `loadOlder()` offset += 50 with prepend + id-dedupe, `hasMore`/`loadingOlder`
  flags, `chat.message_cap` (1000) cap awareness; UI: "Cargar anteriores" button
  + loader row at the list top.
- E2EE invariant pinned: the provider/repository path only ever reads through
  `ChatService` (`verifyNever` on raw client + realtime in
  `test/features/chat/chat_pagination_test.dart`).
- Daily log: `docs/history/phase-07-chat/2026-08-09_I56-chat-pagination.md`.
