# I-53 — Notification Center (NOTI)

**Date:** 2026-08-09
**Agent:** I-53 (Phase 4.2, feature foundations)
**Owned files:** `lib/features/notifications/notification_center_screen.dart` (per FILE-OWNERSHIP.md) + feature providers, router wiring, tests, integration flow, docs.

## Summary

Built the real in-app notification center for the `notifications` tab
(`RoutePaths.mainNotifications`), replacing the `VComingSoonScreen` placeholder
(NOTI spec: `docs/specs/steps/phase-09-notifications-push/NOTI-notification-center.md`).

### What was built

- **`lib/features/notifications/notifications_providers.dart`** (new)
  - `NotificationsNotifier` (AsyncNotifier): `build()` maps
    `NotificationService.getNotifications()` rows → `NotificationItem` (I-10's
    freezed model); `refresh()`, `markRead(id)` (server + local flip, skips
    already-read), `markAllRead()` (NOTI "mark all read"), `addNotification(row)`
    (realtime live-insert, dedupe by id, prepend newest-first).
  - `notificationsProvider` + `unreadCountProvider` (derived Provider, select-style).
  - Pure helpers (unit-testable): `notificationTimeSpan` (now/min/h/d buckets),
    `notificationDeepLink(type, data)` (NOTI deep-link table: explicit `deepLink`
    wins, else type-aware `event_id`/`group_id`/`chat_id`/`user_id` resolution;
    `friend_request` maps to the registered `/user/{id}` since the spec's
    `/user/{id}/friend` route doesn't exist), `isRegisteredRoutePath(path)`
    (segment-exact route-existence guard).
- **`lib/features/notifications/notification_center_screen.dart`** (new)
  - Black minimalist per DISCO-DESIGN-SYSTEM §1 (P1/P2): black bg, white core
    text, hairline `#1A1A1A` separators, unread = `surface #0A0A0A` tile + bold
    title + `glowPink` 8px dot (never color-only, §2.5 rule 5 — bold is the
    second signal).
  - `ListView.separated` (PERF-01/H-27 compliant) + `RefreshIndicator`
    (pull-to-refresh), empty state (`notificationsEmpty`), error state via the
    shared `ErrorView` with retry, `AppBar` "Marcar todo como leído" action
    (visible only when unread > 0).
  - Realtime live-insert: screen-level subscription via
    `notificationServiceProvider.subscribeToNotifications` (the chat-screen
    pattern), dispose-safe channel unsubscribe, `mounted` guard, best-effort
    failure (history + pull-to-refresh still work).
  - Tap contract: `markRead` first, then fire-and-forget `context.push` only
    when the deep link is a registered route; otherwise just mark read.
  - Icon per type (`notificationIconForType`, all 16 NOTI types + fallback).
- **Service change (I-11's files, locks held, coordinated):**
  `RealtimeService.subscribeToNotifications` and
  `NotificationService.subscribeToNotifications` now return the
  `RealtimeChannel` (previously `void`/dropped handle) so the screen can
  unsubscribe on dispose — mirrors the existing `subscribeToMessages` contract.
  Existing I-44 service tests unchanged and still green.
- **Router wiring** (`lib/core/router/app_router.dart`): the ShellRoute child
  for `RoutePaths.mainNotifications` now builds `NotificationCenterScreen`;
  bottom nav untouched (I-04's MainShell owns the shell).
- **l10n:** 10 new keys in `app_es.arb`/`app_en.arb` (title, empty + body,
  mark-all-read, load error, 4 relative-time keys — 3 with int placeholders);
  `flutter gen-l10n` regenerated the Dart localizations.
- **Tests**
  - `test/features/notifications/notification_center_test.dart` (new, 27
    tests): provider list/refresh/markRead/markAllRead/addNotification/error,
    unread count, time-span buckets, deep-link table, route guard, and widget
    tests (render, empty, unread dot, tap-mark-read, tap-navigates, realtime
    insert, mark-all-read) with the fake `NotificationService` injected via
    `notificationServiceProvider.overrideWithValue` + `ProviderContainer`.
  - `test/router/app_router_test.dart` updated: `mainNotifications` now asserts
    `NotificationCenterScreen` + `BottomNavigationBar` (was
    `VComingSoonScreen` + coming-soon body text); coherence table row swapped.
  - `test/l10n/l10n_extraction_test.dart`: added `'create-event'` to the data
    allowlist (route path segment in `isRegisteredRoutePath`, not UI text).
  - `integration_test/notifications_flow_test.dart` (new, hermetic) + registered
    in `runner.sh` ORDERED_FLOWS + README listing.

### Realtime provider coordination (I-52)

`lib/shared/providers/realtime_provider.dart` (I-52's file) was NOT locked by
anyone at my start. Decision: **the notification center uses the
service-based pattern** (`notification_service.subscribeToNotifications`,
chat-screen precedent) instead of the I-52 `realtimeProvider` stream factory,
because (a) it is user-scoped (`notifications:{userId}` channel), (b) it is the
pattern already proven in production chat code, (c) it keeps the screen
testable via `notificationServiceProvider` override, and (d) the generic
`realtimeProvider` is mid-flight at I-52. Documented here for I-52/registry.

### Decisions

1. Deep links only navigate when `isRegisteredRoutePath` — segment-exact guard,
   so `/user/{id}/friend` (no route) and `/event` (no id) never push.
2. `markRead` runs before `push`; `context.push` is unawaited — awaiting it
   would block the mark-read until the pushed route pops.
3. Relative time is coarse (now/min/h/d) via pure `notificationTimeSpan` +
   ARB placeholders (no intl pluralization needed for MVP).
4. `comingSoonNotificationsTitle/Body` ARB keys left in place (now unused —
   U-12/I-78 can remove); removing them would churn the ARB diff for no gain.

### MISTAKE block

- **MISTAKE (fixed):** First `isRegisteredRoutePath` used prefix matching
  (`startsWith('/user/')`), which accepted `/user/{id}/friend` — a path with no
  route. Reworked to segment-exact matching (rejects trailing segments beyond
  known route shapes). Caught by my own test before the suite ran.
- **MISTAKE (fixed):** Initial tap handler did `await context.push(link)` then
  `markRead` — `push`'s future completes only when the route pops, so
  `markRead` never ran while the pushed screen was open (caught by the
  navigate-and-mark-read widget test: `markedRead` was empty).
- **MISTAKE (avoided):** l10n guard — `'create-event'` route segment is a data
  literal, not UI text; added to the extraction allowlist instead of
  localizing a route path.

### Pre-existing issues found (NOT mine, do not fix out of scope)

- **I-54 in-flight draft breaks `dart analyze` and 3 tests:** untracked
  `lib/features/events/create_event_screen.dart` + `event_detail_screen.dart`
  reference l10n getters (`eventsJoinModeOpenDescription`, `eventsPreshardsLabel`,
  …) that do not exist in any ARB → 40+ analyzer errors; `test/features/events/*`
  fail to load (compile error); `test/perf/list_view_builder_test.dart` flags the
  same two files for `ListView(children:)`. Full suite: **1057 pass / 3 fail —
  all 3 attributable to I-54's draft.** Baseline per AGENT-RULES was 23
  documented pre-existing failures; this draft landed in the shared tree before
  my run.
- `l10n.yaml` emits a deprecation warning (`synthetic-package` no longer has
  effect) — M-26/U-14 cleanup candidate.

### Commands run (reproducibility)

```bash
tools/agent_lock.sh acquire <17 files> --owner "I-53-notification-center"
flutter gen-l10n
dart analyze   # 0 issues in my files; pre-existing I-54 errors elsewhere
flutter test test/features/notifications/ test/router/app_router_test.dart test/l10n/  # 103/103 pass
flutter test test/features/notifications/notification_center_test.dart  # 27/27
flutter test test/router/app_router_test.dart                           # pass
flutter test test/l10n/                                                 # pass
flutter test                                                            # 1057 pass / 3 fail (all I-54 draft)
flutter test integration_test/notifications_flow_test.dart              # pass (hermetic)
tools/agent_lock.sh list / release <...>
```

### Validation gate

- [x] `dart analyze` clean for all files I touched (0 issues)
- [x] Targeted suites green: `test/features/notifications/`, `test/router/app_router_test.dart`, `test/l10n/`
- [x] Full suite: 1057 pass, 3 fail — all 3 pre-existing (I-54 untracked draft)
- [x] Integration flow green (hermetic)
- [x] NOTI acceptance checklist (PLAN.md) updated
- [x] Cross-references NOTI row left for D-02/orchestrator (not my file)
