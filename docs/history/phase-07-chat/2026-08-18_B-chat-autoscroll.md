# 2026-08-18 — B-chat-autoscroll: chat thread auto-scroll UX

**Agent:** B-chat-autoscroll · **Scope:** `lib/features/chat/widgets/
chat_thread_view.dart` + `test/features/chat/chat_screen_test.dart` (scroll
behavior only — the docked-bar composer / circular send-button work that was
already uncommitted in the file was preserved exactly, not restyled).

## What was built

Auto-scroll for the NON-reversed message thread (oldest-first, "Cargar
anteriores" header at index 0):

- **First successful load → open at the newest message.** The first
  `loading → data` transition schedules an unconditional scroll to the bottom.
- **New tail message while the user is AT the bottom → auto-scroll** so the
  new bubble comes into view. This covers realtime arrivals AND the send path
  (the optimistic pending row and the post-confirm refresh both hit the same
  "new tail" branch).
- **Scrolled up → never yanked.** A scroll listener tracks `_isAtBottom`
  (`pixels >= maxScrollExtent - 60px`); a new tail message only auto-scrolls
  inside that trigger zone.
- Reduced motion: `MediaQuery.disableAnimationsOf(context)` → `jumpTo`
  instead of `animateTo` (repo ANIM-OFF convention). Duration/curve come from
  the `SamayDurations` tokens (`fast` 150 ms + `defaultCurve` easeOutCubic).

Implementation notes:

- `ScrollController _scrollController` is a `State` member, wired to the
  `ListView.builder`, disposed in `dispose()` (the Flutter API-docs pattern,
  see Sources).
- Scroll triggers run in a **post-frame callback** so the newly arrived item
  is laid out before `maxScrollExtent` is read.
- **Corrective loop** (`_animateToNewest`): a lazy `ListView.builder`
  (no `itemExtent`) reports `maxScrollExtent` as an *estimate* that refines
  as bottom items build during the scroll — a single `animateTo` stopped ~26px
  short of the true bottom in the first test run. The loop re-checks after
  each frame and repeats until `pixels` actually reaches the extent.
- **Coalescing guard** (`_scrollingToBottom`): the send confirm path
  (`refresh()`) briefly drops the list to the loading view then rebuilds it,
  which can start a second scroll chain while the first is mid-flight. Two
  concurrent chains each `animateTo` — each cancels the other before it ticks,
  and the position never moved (the `pumpAndSettle` timeout in the RED run).
  A single in-flight loop absorbs arrivals (each step re-targets the newest
  extent), so concurrent chains can never ping-pong.

## Tests (TDD — RED → GREEN)

Added a `thread auto-scroll (B-chat-autoscroll)` group to
`test/features/chat/chat_screen_test.dart` using the existing in-memory
harness (`_pump`, `_FakeChatMessagesNotifier`, real notifier + mocked repo
for the send case):

1. **first successful load scrolls to the NEWEST message** — failed RED
   (offset stayed 0), now asserts `pixels ≈ maxScrollExtent`.
2. **arrival while at the bottom auto-scrolls to it** — failed RED, now
   asserts offset reaches the new max AND the new bubble is on screen.
3. **arrival while scrolled up leaves the viewport untouched** — guards the
   no-yank behavior (offset unchanged, still >60px from the bottom).
4. **sending while at the bottom keeps the newest message in view** — real
   `ChatMessagesNotifier` + mocked repo; exercises the optimistic pending row
   and the confirm refresh path (this is the test that caught the ping-pong).

## Validation

```bash
flutter test test/features/chat/chat_screen_test.dart   # 38/38 pass
dart analyze                                            # No issues found
```

Full `flutter test` suite intentionally NOT run (out of scope — other agents).

## MISTAKE

The first auto-scroll implementation did a single `animateTo(maxScrollExtent)`.
Two real problems, both caught by the widget tests before anything shipped:

1. **Single scroll lands short.** `maxScrollExtent` on a lazy
   `ListView.builder` is an estimate, not the true content extent — it is
   refined as items near the bottom get laid out *during* the scroll. A single
   `animateTo` stopped ~26px short (the newest bubble stayed clipped). Fix:
   iterate after each frame until `pixels >= maxScrollExtent`.
2. **Two concurrent scroll chains ping-pong forever.** The send confirm
   (`refresh()`) rebuilds the provider, dropping the list to the loading view
   and back, so a second scroll chain started while the first was still
   animating. Each `animateTo` cancels the other before it can tick → pixels
   never moved → `pumpAndSettle` timed out. Fix: coalesce onto one in-flight
   loop (`_scrollingToBottom` guard).

## Commands run (reproducibility)

```bash
tools/agent_lock.sh acquire lib/features/chat/widgets/chat_thread_view.dart --owner B-chat-autoscroll
tools/agent_lock.sh acquire test/features/chat/chat_screen_test.dart --owner B-chat-autoscroll
flutter test test/features/chat/chat_screen_test.dart      # RED: 35 pass / 3 fail (right reason)
# …implement… 
flutter test test/features/chat/chat_screen_test.dart      # 38/38 pass
dart analyze                                              # No issues found
tools/agent_lock.sh acquire docs/history/phase-07-chat/2026-08-18_B-chat-autoscroll.md --owner B-chat-autoscroll
# …write this log…
tools/agent_lock.sh release <each path> --owner B-chat-autoscroll
```

## Sources

- Flutter API docs — ScrollController class (controllers as `State` members,
  `hasClients`, `position`, `animateTo(offset, duration, curve)`, `jumpTo`,
  `dispose`): https://api.flutter.dev/flutter/widgets/ScrollController-class.html
- Flutter API docs — ScrollMetrics `maxScrollExtent` (estimate for lazy
  scrollables, refined as content lays out):
  https://api.flutter.dev/flutter/rendering/ScrollMetrics-class.html

## Pre-existing issues found (not fixed — out of scope)

- `tools/agent_lock.sh list` showed no held locks; no blockers.
- Nothing else observed in the touched files beyond the already-uncommitted
  composer work (2026-08-18 user override), which was preserved as-is.