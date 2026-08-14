# I-72 — Reusable pagination utilities (PagedState + PageLoader + PagedProvider) (2026-08-10)

**Agent:** I-72-pagination | **Phase:** 02-flutter-foundation | **Status:** DONE

## What was built

Extracted I-56's chat pagination pattern into a generic, provider-agnostic
paged-state utility so future features (events list, leaderboard,
notifications history) get infinite-scroll pagination for free.

1. **`lib/core/utils/pagination.dart`** (new) — pure Dart, **zero Riverpod
   imports** (unit-testable in isolation):
   - `PagedState<T>` — immutable page-window state: `items`, `hasMore`,
     `loadingMore`, `pageSize`, `nextOffset`; `copyWith`, `append`
     (dedupes by `idOf`, existing rows win), `prepend` (same dedupe, older
     first), `reset()` (fresh first-page state, pageSize + idOf preserved).
     `idOf` (`String? Function(T)?`) is the optional dedupe key extractor;
     rows whose key is null are never deduped (always kept) — mirrors I-56's
     "rows without a string id pass through" contract.
   - `PageLoader<T>` — plain paging engine: `fetch(offset, limit)` seam +
     `idOf` + `pageSize` + `maxItems` cap. `loadFirst()` fetches (0, pageSize)
     and sets `hasMore = full page && below cap`; `loadMore(current)` fetches
     at `current.nextOffset`, prepends (deduped), advances the offset by the
     **returned** page length, and flips `hasMore` false on short pages, at
     the cap, or when the accumulated list reaches `maxItems` — the CHMC/TRIG
     "never paginate past the 1000-message rolling window" semantics moved
     verbatim from `ChatMessagesNotifier`. Guards: no-op (same state) when
     `!hasMore` or `loadingMore`; refuses to fetch at/past the cap even
     against a stale `hasMore`. Fetch failures propagate unchanged.
2. **`lib/core/providers/paged_provider.dart`** (new) — `PagedProvider<T>`, the
   Riverpod seam: `AsyncNotifier<PagedState<T>>` base class where `build()`
   calls `createLoader().loadFirst()`, `loadOlder()` is guarded
   (loadingMore/hasMore/cap) with previous-state preservation + rethrow on
   failure, and `refresh()` = `ref.invalidateSelf()` (SM-09). Feature
   notifiers implement only `createLoader()`.
3. **`lib/features/chat/chat_providers.dart`** — refactored to the utility.
   Public API byte-identical: `ChatMessagesState { messages, hasMore,
   loadingOlder }` (now a thin view over `PagedState<Map<String, dynamic>>`
   with the same constructor/copyWith/fromPaged factory),
   `chatMessagesProvider` family type unchanged, `loadOlder`/`send`/
   `addMessage`/`refresh` unchanged. The notifier's hand-rolled
   `_offset`/`_hasMore`/`_loadingOlder` fields, `_loadPage` and `_fullPage`
   are gone — a fresh `PageLoader` per `build()` does all paging arithmetic.
   E2EE invariant untouched (still reads only `chatE2eeRepositoryProvider`).
4. **Tests** — `test/utils/pagination_test.dart` (18) + `test/providers/
   paged_provider_test.dart` (11), TDD (RED = compile errors for the missing
   utilities, then GREEN). All 25 I-56 chat tests re-ran green **unmodified**;
   the provider-delegation test in `feature_providers_test.dart` untouched.

## Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire/release <path> --owner I-72-pagination`
(checked `tools/agent_lock.sh list` first — zero locks held; I was the only agent):

| File | Action |
|---|---|
| `lib/core/utils/pagination.dart` | created |
| `lib/core/providers/paged_provider.dart` | created |
| `lib/features/chat/chat_providers.dart` | modified (locked) |
| `test/utils/pagination_test.dart` | created |
| `test/providers/paged_provider_test.dart` | created |
| `docs/to-fix/TODO.md` | modified (workstream note) |
| `docs/history/phase-02-flutter-foundation/2026-08-09_I72-pagination.md` | created (this log) |

`test/features/chat/*` were **not** modified (ran green as-is — the point of
the public-API-preserving refactor).

## Tests added + results (TDD: RED → GREEN)

RED proof: both new test files failed to load with exactly the expected
compile errors (`pagination.dart`/`paged_provider.dart` undefined; `refresh`
undefined on the notifier).

```bash
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
flutter test test/utils/pagination_test.dart test/providers/paged_provider_test.dart
  # RED: +0 -2 (compile) → GREEN: 29/29
flutter test test/features/chat/ test/providers/feature_providers_test.dart   # 49/49
flutter test                                 # FULL SUITE: 1576/1576, 0 failures
dart analyze                                 # 0 errors (2 pre-existing non-errors:
                                             # qr_flow_test unused import [I-57],
                                             # user_service curly_braces [I-60])
```

Coverage map:

- **PagedState** (8): constructor defaults + immutability; copyWith
  field-preservation; append dedupe (existing wins, order kept); append keeps
  null-key rows; append without idOf concatenates raw; prepend dedupe
  (existing wins, older first); prepend keeps null-key rows; reset preserves
  pageSize + idOf.
- **PageLoader** (10): loadFirst fetch(0, pageSize) + hasMore full/short/
  empty; loadMore fetch-at-nextOffset + prepend + offset advance; boundary
  dedupe; short-page → hasMore false + later no-op (same instance, no fetch);
  cap (page 6 never requested); stale-hasMore defense at the cap; loadingMore
  no-op; fetch failure propagates from loadFirst and loadMore.
- **PagedProvider** (11): build first page (full/short/error→AsyncError);
  loadOlder prepend + offset; short page → hasMore false + no-op; cap never
  exceeded; in-flight loadingMore (Completer-gated); concurrent loadOlder
  serialized; failure keeps previous state + rethrows; refresh re-runs build
  from offset 0.

## Decisions

1. **`ChatMessagesState` wraps `PagedState` (composition) instead of
   subclassing.** I-56's tests construct `ChatMessagesState(messages:, hasMore:,
   loadingOlder:)` and read `state.messages`/`state.hasMore`/`state.loadingOlder`
   — the state type is pinned by the public API. Composition keeps the
   constructor/getters/copyWith signature exactly as I-56 shipped them and
   lets `PageLoader` produce plain `PagedState<T>` results (no covariant
   override machinery on `copyWith`/`append`/`prepend` needed).
2. **`PagedState<Map<String, dynamic>>` for chat, not `PagedState<ChatMessage>`**
   (mission wording "PagedState<ChatMessage>-driven"): chat rows carry the
   E2EE `decryptFailed` flag and no `chat_id` (service contract,
   `chat_repository.dart`), so the freezed `ChatMessage` model cannot represent
   them. Map rows are the documented I-12 stopgap; the generic engine is
   type-agnostic and works for typed models in future features.
3. **Dedupe only against accumulated rows, never within one incoming batch**
   — mirrors I-56 (`existing` set from the current messages only). The reset
   test initially asserted intra-batch dedupe and failed — that is *not* the
   contract (see MISTAKE-1).
4. **`loadingMore` in-state instead of a notifier field.** I-56 used a
   private `_loadingOlder` + mirror field in state. Because `loadOlder` marks
   the state (`copyWith(loadingMore: true)`) synchronously before the first
   await, a concurrent second call reads the marked state and no-ops — the
   L-07 serialization test passes without a notifier-local flag.
5. **`PageLoader` takes the `PagedState` as its source of truth** for
   `loadMore` (offset/hasMore from the state, not internal bookkeeping), so
   the loader is effectively stateless and safe to share; `build()` creates a
   fresh loader to restart at page 1 (I-56's build-reset semantics).
6. **`maxItems` guard in `PageLoader`** (`loadFirst` + `loadMore`): the
   accumulated-length cap `merged.items.length < maxItems → hasMore=false` was
   ported 1:1 from I-56's `if (merged.length >= chatMessageCap)`.

## MISTAKE blocks (searchable)

- **MISTAKE-1 (test expectation):** the reset test asserted
  `reset.append([a, a2])` dedupes within the batch. Dedupe is only against
  *accumulated* rows (I-56 semantics) — fixed the test to seed then append a
  duplicate.
- **MISTAKE-2 (const):** initially kept `const ChatMessagesState(...)` with a
  `PagedState(...)` initializer referencing constructor parameters. Dart const
  constructors cannot reference parameters in initializer expressions
  (`invalid_constant`) — dropped `const` (nothing requires it; verified via
  scratch repro in /tmp).
- **MISTAKE-3 (test compile):** `const PagedState(...)` in a test where the
  constructor was non-const, and `_gate.complete()` on a top-level
  `Completer<void>?` (top-level vars don't promote) — fixed with
  non-const invocation / `_gate!`.
- **MISTAKE-4 (private member ref):** the notifier referenced the state's
  private static `_messageIdOf` unqualified — same-library access requires
  `ChatMessagesState._messageIdOf`; fixed.

## Issues found (reported, not mine — do NOT fix)

- **Integration-test environment:** `flutter test integration_test/<any>.dart`
  currently fails at LOAD with `Error running pod install — CocoaPods's specs
  repository is too out-of-date` (verified identical for the untouched
  `auth_flow_test.dart`; `chat_flow_test.dart` never reached test code). Pure
  environment (needs `pod repo update` on this machine) — pre-existing, not
  caused by this change (no pubspec/plugin changes).
- **Pre-existing analyze non-errors** (unchanged): `integration_test/
  qr_flow_test.dart:1` unused import (I-57), `lib/core/services/user_service.dart:176`
  curly-brace lint (I-60).
- **`docs/specs/steps/cross-references.md` CHAT row still stale** (pre-
  I-38/I-56 "❌ No chat screens") — D-02 territory, re-reported by I-56/I-38.

## Commands run (reproducibility)

```bash
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
export AGENT_NAME="I-72-pagination"
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME"   # 7 files, all acquired
flutter test test/utils/pagination_test.dart test/providers/paged_provider_test.dart   # RED→GREEN 29/29
flutter test test/features/chat/ test/providers/feature_providers_test.dart            # 49/49
dart analyze                                                                           # 0 errors
flutter test                                                                            # 1576/1576
flutter test integration_test/chat_flow_test.dart                                      # env-blocked (pod install, see Issues)
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"
```

*Sources: Dart language (const-constructor initializer restriction — verified
by scratch repro), Riverpod 2.6 `AsyncNotifier` API, I-56 daily log
(behavioral contract ported from), I-44/I-71 test-file conventions.*
