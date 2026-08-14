# 2026-08-09 — I-56 · Chat pagination + message-history paging (CHAT spec)

**Agent:** I-56 · **Role:** `lib/features/chat/chat_screen.dart` (message list
foundation) — pagination + chat-list foundation for the CHAT step (the chat
*list* screen itself is I-76/phase-07 future; this agent focused on message
history paging + E2EE safety).
**Contract:** `docs/specs/steps/phase-07-chat/CHAT-chat-system-core.md`
("load last 50 on open; scroll up → paginate older messages") + PLAN.md.
**Deps:** I-38 (E2EE chat screen + `ChatService.loadMessages(limit, offset)`),
I-50 (`ChatRepository` — E2EE invariant pin), I-44 (mocktail conventions).

## What was built

1. **`chat_providers.dart` — paginated `chatMessagesProvider` (family chatId).**
   - New `ChatMessagesState { messages, hasMore, loadingOlder }` — the provider
     value changed from `List<Map>` to this state (screen + tests updated).
   - `build`: loads the FIRST page (`loadMessages(limit: 50, offset: 0)`), the
     last 50 messages; `hasMore` = full page returned.
   - `loadOlder()`: fetches `offset += 50`, PREPENDS the older page,
     **dedupes by `id`** (realtime rows can overlap page boundaries), recomputes
     `hasMore`, exposes `loadingOlder` while in flight, serializes concurrent
     taps (L-07 guard), rethrows on failure (state untouched; the screen shows
     a snackbar).
   - **Message cap awareness (CHMC/TRIG):** `chatMessageCap = 1000` mirrors the
     DB `app_config 'chat.message_cap'` enforced by `enforce_message_cap`
     (migration 20260809000001:124). Pagination flips `hasMore` false at the
     cap (accumulated-length guard + `_offset >= cap` guard), so the client
     never requests past the rolling window.
   - E2EE invariant preserved: the provider reads ONLY
     `chatE2eeRepositoryProvider` (→ `ChatService`); no raw `client.from`
     path (pinned by a `verifyNever` test).
   - E2EE decryption ordering note (documented in the provider): the service
     serializes per-chat decryption in each page's own chronological order;
     history older than the session's first-decrypted message may render as the
     `decryptFailed` placeholder — E2EE §12.2 step 6, by design.
2. **`chat_screen.dart` — older-history header row.**
   - "Cargar anteriores" button at the top of the list, shown only when
     `hasMore`; replaced by a small 20×20 loader row while `loadingOlder`
     (**button chosen over scroll-to-top for testability**, documented in
     code); empty-chat / short-history states unchanged.
   - `_loadOlder()` surfaces failures via the existing `chatLoadError` snackbar.
3. **l10n** — `chatLoadOlder` ("Cargar anteriores" / "Load older messages") in
   both ARBs + regenerated accessors.
4. **Tests** (`test/features/chat/chat_pagination_test.dart`, 10 new; 5 new
   widget tests in `chat_screen_test.dart`; 1 fixed provider-delegation test in
   `test/providers/feature_providers_test.dart`):
   - first page = last 50 via `loadMessages(chatId, limit: 50, offset: 0)`;
   - `loadOlder` prepends + dedupes by id (page-boundary duplicate dropped);
   - `hasMore` flips false on a short (<50) page; empty chat → hasMore false;
   - **cap test:** 20 pages × 50 = 1000 → hasMore false, the 1001st request
     never fires (offsets captured, all < 1000);
   - `loadingOlder` in-flight flag (Completer-gated page);
   - concurrent `loadOlder` calls serialized (no double fetch);
   - realtime `addMessage` still appends + dedupes on the paged state;
   - **E2EE invariant:** `verifyNever(client.from(any()))` +
     `verifyNever(realtime.subscribeToMessages(...))` — the service is the only
     data source;
   - **real stack:** real `ChatService` (plaintext) + real `ChatRepository` +
     real provider over a window-resolving PostgREST builder — asserts the true
     offset math `range(offset, offset+49)` + DESC/reverse ordering end to end
     (150-row server, 4 window requests `(0,49),(50,99),(100,149),(150,199)`).
   - Widget: button visible iff `hasMore`; tap → `loadOlder()`; loader row
     replaces the button while `loadingOlder`; list stays visible.

## Decisions

- **Button over scroll-to-top:** deterministic, testable, works with the
  current oldest-first list; a `ScrollController` listener remains a trivial
  follow-up once the chat list screen (I-76) lands.
- **State object over parallel providers:** `hasMore`/`loadingOlder` are
  derived from the same fetch lifecycle as `messages` — one AsyncValue keeps
  them consistent (no torn updates between providers).
- **`_offset` bookkeeping:** offset advances by the *returned* page length
  (short page ⇒ hasMore false ⇒ offset irrelevant); the cap guards make
  "never beyond 1000" hold even against a misbehaving server.
- **`loadOlder()` takes no chatId** — the family notifier's `arg` is the
  chat id (same class of API as `addMessage`).

## Test results

| Command | Result |
|---|---|
| `flutter test test/features/chat/` | 25 pass (5 e2ee + 10 screen + 10 pagination) |
| `flutter test test/core/repositories/ test/providers/feature_providers_test.dart` | green (incl. I-50's `verifyNever` repository test, untouched) |
| scoped set (chat/ + repositories/ + feature_providers) | **90 pass, 0 fail** |
| `dart analyze` (lib/features/chat/, test/features/chat/, feature_providers_test) | No issues found |
| `dart analyze` (whole repo) | 0 errors — 1 pre-existing info: `test/features/feed/feed_test.dart:11` unused import (**I-58's in-flight file**) |
| `flutter test` (full suite) | **49 loading failures — ALL traced to I-58's mid-flight `lib/core/errors/app_error.dart:67` (`const NotConfiguredError` with a non-const super) + I-58/I-60 feed & party-finder test files. Zero failures in my scope; the scoped set was fully green before I-58's edit landed.** |

## Files (lock evidence)

| File | Lock | Status |
|---|---|---|
| `lib/features/chat/chat_providers.dart` | acquire+release I-56-chat-pagination | paginated state + loadOlder |
| `lib/features/chat/chat_screen.dart` | acquire+release I-56-chat-pagination | older-history header (button/loader) |
| `test/features/chat/chat_pagination_test.dart` | acquire+release I-56-chat-pagination | created (10 tests) |
| `test/features/chat/chat_screen_test.dart` | acquire+release I-56-chat-pagination | fake updated to the state type + 5 widget tests |
| `test/providers/feature_providers_test.dart` | acquire+release I-56-chat-pagination (⚙️ I-44/I-47 territory — lock was free) | delegation test updated to `state.messages` |
| `lib/l10n/app_es.arb`, `app_en.arb` | acquire+release I-56-chat-pagination (⚙️ I-14/I-15) | `chatLoadOlder` |
| `lib/l10n/app_localizations*.dart` | acquire+release I-56-chat-pagination | regenerated via `flutter gen-l10n` |
| `docs/history/phase-07-chat/2026-08-09_I56-chat-pagination.md` | acquire+release I-56-chat-pagination | this log |
| `docs/history/phase-07-chat/PLAN.md` | acquire+release I-56-chat-pagination | CHAT checklist + status update |
| `docs/to-fix/TODO.md` | acquire+release I-56-chat-pagination | workstream note |

## MISTAKES (searchable)

- **MISTAKE-1 (test):** the dedupe test's duplicated id (`m-50`) was not
  actually in the first page (which was `m-49..m-0`) — the duplicate was
  dropped vacuously. Fixed to duplicate `m-49`, which the page genuinely
  contains.
- **MISTAKE-2 (test):** `_WindowBuilder` reversed the server window AND the
  real `ChatService` reverses it again — double reversal made the history
  newest-first. The builder must return the raw DESC window; the service's
  `.reversed` is the single reversal point (that's the production semantics).
- **MISTAKE-3 (test):** `onValue(resolved as U)` — the override's `U` may not
  equal `PostgrestList`; cast to `PostgrestList` (the builder's `T`).
- **MISTAKE-4 (expectation):** asserted `last['id'] == 'm-1'` where the page
  generator produces `m-49..m-0` (last is `m-0`).

## Issues found (reported, not mine — do NOT fix)

- **I-58's in-flight `lib/core/errors/app_error.dart:67` breaks compilation of
  the ENTIRE test suite** (`const NotConfiguredError()` → non-const super).
  Every one of the 49 full-suite failures is this single error or I-58/I-60's
  own feed/party-finder test files. Self-heals when those agents finish.
- **`docs/specs/steps/cross-references.md` CHAT row is stale** (still
  "❌ No chat screens", pre-I-38) — D-02 territory; PLAN.md is authoritative
  for phase-07 status.
- **`comingSoonChatTitle`/`comingSoonChatBody` ARB keys unused** (I-15/I-78
  cleanup — re-reported by I-38; unchanged).
- **E2EE pagination limitation (design):** decrypting history older than the
  current Double Ratchet session position fails AEAD → renders as
  `decryptFailed` placeholder. Documented in the provider; a session-rewind
  strategy is S-07/§4.5 follow-up scope.

## Commands run (reproducibility)

```bash
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
export AGENT_NAME="I-56-chat-pagination"
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME"   # 13 files, all acquired
flutter gen-l10n
flutter test test/features/chat/
flutter test test/core/repositories/chat_repository_test.dart test/providers/feature_providers_test.dart
flutter test test/features/chat/ test/core/repositories/ test/providers/feature_providers_test.dart   # +90 all pass
dart analyze lib/features/chat/ test/features/chat/ test/providers/feature_providers_test.dart        # no issues
dart analyze                                                                # 0 errors (1 pre-existing I-58 info)
flutter test                                                                # 49 loading failures, all I-58/I-60 files
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"
```

*Sources: Supabase docs (PostgREST range/order), CHAT-chat-system-core.md,
CHMC-message-cap-reporting.md (message cap), E2EE-ARCHITECTURE.md §12.2 step 6
(decryptFailed semantics), riverpod 2.6 `AsyncNotifierProviderFamily.future`
(documented via source read in `~/.pub-cache`).*
