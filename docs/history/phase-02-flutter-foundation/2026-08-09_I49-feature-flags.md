# 2026-08-09 — I-49: Feature flags + release gating provider

**Agent:** I-49-feature-flags · **Role:** feature-flag system (FILE-OWNERSHIP.md:
`lib/core/feature_flags/**` + feature-flag provider)
**Deps:** I-36 (minimal `AppFeatureFlags.showCosmeticsSection` stub, consumed by
`profile_screen`) ✅ · I-38 (E2EE chat live) ✅ · I-53 (notification center live —
landed concurrently mid-session, see §3) · **Downstream:** I-69 (route gating
uses this provider), I-71 (remote-config driving the provider)

---

## 1. What was built

1. **`lib/core/feature_flags.dart` rebuilt** into the release-gating system:
   - **`AppFeatureFlag` enum** (12 flags): `cosmeticsSection`, `events`,
     `chat`, `qr`, `feed`, `notifications`, `subscriptions`, `partyFinder`,
     `minigames`, `photoUpload`, `e2ee`, `themePersistence`.
   - **`AppFeatureFlags`** immutable const class with one bool getter per
     flag + `isEnabled(flag)` switch + value `==`/`hashCode` (test-friendly).
     Defaults: **LIVE features `true`** — `chat` (I-38), `notifications`
     (I-53, see §3 deviation), `e2ee` (always-on kill-switch) — everything
     else **dark** (`false`).
   - **`featureFlagsProvider`** (`Provider<AppFeatureFlags>`) — the **single
     seam**: overridable in tests (`overrideWithValue`) and at app startup
     (`ProviderScope` overrides in `main()`). Documented remote-config seam:
     `_flagsFromConfig()` can read `app_config` later (I-71) — no
     `app.*feature.*` keys seeded yet, so every deployment ships const
     defaults until then. `SamayApp`/`main.dart` NOT touched (I-05 owns
     main.dart) — the seam is documented in the provider doc comment.
   - **`FlagGate`** — const-constructible `ConsumerWidget`:
     `FlagGate(flag: AppFeatureFlag.events, child: const EventsScreen())`.
     Renders `child` when the flag is on; otherwise `fallback` (default: a
     **localized `VComingSoonScreen`** per flag — events/notifications/
     subscriptions/partyFinder/qr map to their existing ARB coming-soon keys;
     unmapped flags get the generic shell).
   - **`isEnabled` helpers via ref**: `extension AppFeatureFlagsRefX on
     WidgetRef` (`ref.isEnabled(flag)` — widget layer) and
     `extension AppFeatureFlagsRef on Ref` (`Ref` layer — exactly what I-69's
     `routerProvider` gating needs).
2. **profile_screen wired to the new system**: I-36's
   `AppFeatureFlags.showCosmeticsSection` (compile-time const) → runtime
   `ref.watch(featureFlagsProvider).cosmeticsSection`. Zero visual diff while
   off (I-36's off-state test still passes unchanged).
3. **Route gating (trivially-correct subset)**: `app_router.dart` now gates
   `mainEvents`, `mainNotifications`, `subscriptions`, `partyFinder` with
   `FlagGate`. mainNotifications' child is I-53's `NotificationCenterScreen`
   (renders because the flag is live). Child of the other three stays the
   localized `VComingSoonScreen` placeholder (real screens land with I-54/
   I-55/I-61/I-60 behind the flag).
4. **Tests**: `test/core/feature_flags_test.dart` (18 tests) + a cosmetics-on
   test in `test/features/profile_screens_test.dart`.

## 2. Tests (results)

| Command | Result |
|---|---|
| `flutter test test/core/feature_flags_test.dart` | **18/18 pass** — defaults table (every flag vs documented state), getter/isEnabled parity, custom-instance override, `==`/`hashCode`, provider default + `ProviderContainer` override, `Ref.isEnabled` (on + off), FlagGate const-constructibility, child-when-enabled, fallback-when-disabled (VComingSoonScreen + 'Próximamente'), localized per-flag fallback titles, explicit-fallback override, live-flag-renders-child, kill-switch (live→dark restores coming-soon), WidgetRef `isEnabled` (on + off) |
| `flutter test test/features/profile_screens_test.dart` | **17/17 pass** (incl. new: cosmetics section renders when flag enabled via provider override) |
| `flutter test test/router/app_router_test.dart` | **62/62 pass** with my FlagGate gating (verified BEFORE I-55 landed `EventDetailScreen`/`EventEditScreen` on `/event/:id`; the file now fails to compile due to I-55's in-flight l10n gap — see §4, not mine) |
| `dart analyze` (my files) | **No issues found** |
| `dart analyze` (whole repo) | 38 errors, ALL in `lib/features/events/**` + `test/features/events/**` + `test/router/app_router_test.dart` (transitive) — I-54/I-55 in-flight code under their held locks (see §4) |

## 3. MISTAKE blocks (searchable)

- **MISTAKE (stale defaults — notifications):** my mission brief said
  `notifications: false` (it predates I-53). I-53 landed `NotificationCenterScreen`
  on `mainNotifications` **mid-session** while holding the router + router-test
  locks, and their updated tests assert the real screen renders. Shipping the
  literal brief default would have regressed I-53's live feature and broken
  their tests. Resolution: `notifications: true` (matches the mission's own
  rule "only the flags for LIVE features true" — notifications IS live now);
  the flag stays as the kill-switch/remote-config knob. Documented in the enum
  + defaults-table test. **Lesson: re-check concurrent agents' landed state
  before finalizing defaults, not just at acquire time.**
- **MISTAKE (widget-test provider reuse):** two pumps in ONE `testWidgets`
  with a changed `ProviderScope.overrides` — Riverpod reuses the element's
  container and silently IGNORES the new overrides (no re-init in initState).
  The second pump rendered the old flags. Fix: split into two `testWidgets`.
- **MISTAKE (static vs instance):** `_defaultFallback` was initially `static`
  but reads the instance `flag` — compile error caught immediately by the
  failing test load. Fixed to an instance method.
- **MISTAKE (lint):** `sort_child_properties_last` info in the new test file —
  `child:` must be last in widget constructor args. Fixed.

## 4. Issues found / coordination notes (not mine to fix — reported)

1. **`test/router/app_router_test.dart` + whole-suite compile break — OWNER
   I-55 (locked):** I-55's in-flight `event_detail_screen.dart`/
   `event_edit_screen.dart` reference `event*` `AppLocalizations` getters
   (`eventDetailTitle`, `eventCancelDialogTitle`, `eventPoolLockedNotice`, …)
   that don't exist in the generated `app_localizations.dart` yet (ARB + gen
   held by I-53). Every test file that transitively imports the router now
   fails to load (`app_router_test`, `l10n_test`, `widget_test`,
   `list_view_builder_test`, …). I verified my gating passes 62/62 before
   I-55's router edit; the current break is entirely theirs. Fix: I-53 to add
   the `event*` keys to ARB + run `flutter gen-l10n` (or I-55 to self-serve
   l10n on their locked ARB set).
2. **`test/features/events/create_event_test.dart` compile error
   (`Method not found: 'base'`, line 274) — OWNER I-54 (locked):** in-flight
   test code; not mine.
3. **`/event/:inviteToken` shadowing (pre-existing, now visible):** the
   `eventInviteToken` route (`/event/:token`) is declared AFTER
   `eventDetail` (`/event/:eventId`) — go_router matches in order, so the
   token route was always shadowed (flagged by D-12, `app_router.dart`).
   I-55's real `EventDetailScreen` made it visible (the coherence test now
   finds `EventDetailScreen` instead of `VComingSoonScreen`). I-55 added a
   NOTE comment acknowledging `/event/create` ordering; the token route needs
   a distinct path (e.g. `/invite/:token`) — flag for I-55/I-66 (deep links).
4. **BLOCKED on `docs/to-fix/TODO.md`:** held by I-52 (took over from I-53)
   — my acquire timed out twice (600s each). Feature-flag workstream note
   queued in this log (§6) for the orchestrator/next holder to append.
5. **`lib/core/feature_flags.dart` now imports `shared/widgets/`** — layer
   direction core→shared. Precedent exists (`app_router.dart` imports
   `v_coming_soon.dart`); flagged for M-23/M-24 restructure to judge.
6. **Integration suite:** not extended with a flag-gating flow — the mission
   scoped verification to unit/widget suites, and `integration_test/runner.sh`
   + `support/test_app.dart` are held by I-01/I-53. A `flag_gating_flow_test`
   (pump `RoutePaths.mainEvents` → VComingSoonScreen; override provider →
   child) is a good I-69 addition when route gating expands.

## 5. Lock evidence

Acquired + released by `I-49-feature-flags`:

| Path | Status |
|---|---|
| `lib/core/feature_flags.dart` | acquire + release (this session) |
| `lib/features/profile/profile_screen.dart` | acquire + release |
| `lib/core/router/app_router.dart` | acquire (waited on I-53), edit, **released before I-55 re-acquired** (my FlagGate blocks remain in the working tree, verified via `git diff`) |
| `test/core/feature_flags_test.dart` (new) | acquire + release |
| `test/features/profile_screens_test.dart` | acquire + release |
| `docs/to-fix/TODO.md` | **BLOCKED** (I-52) — not modified |
| `docs/history/phase-02-flutter-foundation/2026-08-09_I49-feature-flags.md` | acquire (held) — this log |

## 6. Pending workstream note (for TODO.md, queued while I-52 holds the lock)

```
> **Feature-flag workstream (I-49, 2026-08-09):** `lib/core/feature_flags.dart`
> rebuilt into the release-gating system — `AppFeatureFlag` enum (12 flags),
> const `AppFeatureFlags` defaults (LIVE: chat, notifications, e2ee; rest
> dark), `featureFlagsProvider` (single overridable seam — tests + app-startup
> ProviderScope; future remote-config via app_config, documented), `FlagGate`
> (const-constructible, default fallback = localized VComingSoonScreen),
> `ref.isEnabled(flag)` helpers (WidgetRef + Ref). profile_screen cosmetics
> section + mainEvents/mainNotifications/subscriptions/partyFinder routes
> gated. 18 tests at test/core/feature_flags_test.dart + cosmetics-on profile
> test. Downstream: I-69 route gating, I-71 remote-config wiring.
```

## 7. Commands run (reproducibility)

```bash
export AGENT_NAME=I-49-feature-flags
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME"   # per file
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
flutter test test/core/feature_flags_test.dart             # RED first: fails (undefined API), then 18/18
flutter test test/features/profile_screens_test.dart       # 17/17
flutter test test/router/app_router_test.dart              # 62/62 (pre-I-55; see §4)
dart analyze lib/core/feature_flags.dart lib/features/profile/profile_screen.dart test/core/feature_flags_test.dart test/features/profile_screens_test.dart  # No issues found
flutter test                                               # full suite: only I-54/I-55 in-flight breaks (see §4)
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"
```

*Sources: Riverpod overrides docs (pub.dev/packages/riverpod), go_router route
matching order (pub.dev/packages/go_router), existing repo conventions
(provider seams in service_providers.dart, AppFeatureFlags consumption in
profile_screen.dart).*
