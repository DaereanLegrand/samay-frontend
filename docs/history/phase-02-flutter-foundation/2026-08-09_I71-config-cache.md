# I-71 — Config refresh + encrypted Hive cache wiring (H-09 + STOR) (2026-08-10)

**Agent:** I-71-config-cache | **Phase:** 02-flutter-foundation | **Status:** DONE

## What was built

Closing **H-09** (`appConfigProvider` is a stateless `FutureProvider` — cannot be
refreshed from UI) and the **STOR** offline-cache groundwork (I-67 handoff):
the app config is now an `AsyncNotifier` that refreshes, persists every
successful fetch to the encrypted Hive `config_cache`, and serves the cache
when offline:

1. **`lib/core/providers/config_provider.dart`** — `appConfigProvider` migrated
   from `FutureProvider` to `AsyncNotifierProvider<AppConfigNotifier,
   Map<String, String>>`:
   - `refresh()` seam — `ref.invalidateSelf()` (repo convention: `auth_provider.dart:82`,
     `minigames_providers.dart:23`). External `ref.invalidate(appConfigProvider)`
     (the paywall retry) still works unchanged.
   - `build()` **watches `connectivityProvider`** (the I-67 handoff): every
     online/offline transition re-runs the build — going offline swaps in the
     cache, coming back online re-fetches. Loading/error connectivity states
     are treated as **online** (`valueOrNull == false` is the only "offline"
     signal) — I-67's fail-open philosophy: the cache never masks a server
     error while connectivity is unknown.
   - **Cache write-through:** on success, `cacheConfig` is fired
     `unawaited` — write failures are logged (`AppLogger.warn`), never
     thrown (a cache failure must not fail the fetch the provider already
     succeeded on).
   - **Offline fallback:** on fetch failure with `offline == true`, serve
     `getCachedConfig()` when non-empty. Empty cache / unreadable cache
     (uninitialized or key-loss re-created Hive — I-26 degradation, wrapped +
     logged) → the **original error** propagates as `AsyncError`
     (`Error.throwWithStackTrace(e, st)` preserves the stack).

2. **`lib/core/providers/service_providers.dart`** — `hiveServiceProvider`
   **promoted** from `theme_provider.dart` (I-65's logged handoff) so every
   cache consumer — theme persistence and the config fallback — shares one
   wiring point. Import of `storage_service.dart` added; no import cycle
   (storage_service imports only `app_logger` + plugins; theme/config providers
   import service_providers, never the reverse).

3. **`lib/core/providers/theme_provider.dart`** — `hiveServiceProvider`
   definition removed; imports it from `service_providers.dart`. Behavior
   unchanged (all 13 theme tests untouched in behavior).

4. **`test/support/fake_config_provider.dart`** (new, shared) —
   `FakeAppConfigNotifier` / `FailingAppConfigNotifier` replace the legacy
   `appConfigProvider.overrideWith((ref) async => …)` syntax (which no longer
   exists on `AsyncNotifierProvider`). All 6 call sites migrated:
   `test/router/app_router_test.dart`, `test/features/feed/feed_test.dart` (×2),
   `test/features/subscriptions/paywall_test.dart` (×2, incl. the error-state
   variant), `test/features/photos/photo_gallery_test.dart`,
   `integration_test/subscriptions_flow_test.dart`.

5. **Tests** — `test/providers/config_provider_test.dart` extended 3 → 10:
   fetched→AsyncData; online failure→AsyncError; `refresh()` re-fetches
   (called ×2); external invalidate re-fetches; success writes cache
   (fake-hive contents asserted); cache-write failure logged-not-thrown
   (state stays AsyncData); offline failure → cached served (connectivity
   flips false mid-test); offline + empty cache → AsyncError; provider
   resolution (hiveServiceProvider resolves a real `HiveService` in a bare
   container and is overridable).

## Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire/release <path> --owner I-71-config-cache`
(checked `tools/agent_lock.sh list` first — zero locks held; I was the only agent):

| File | Action |
|---|---|
| `lib/core/providers/config_provider.dart` | modified (locked `adae7ff0…`) |
| `lib/core/providers/service_providers.dart` | modified (locked `0c59a81b…`) |
| `lib/core/providers/theme_provider.dart` | modified (locked `cf8aec39…`) |
| `test/support/fake_config_provider.dart` | created (locked `db41cf47…`) |
| `test/providers/config_provider_test.dart` | rewritten (locked `5f4cada6…`) |
| `test/providers/theme_provider_test.dart` | modified — import (locked `1e9e0a7d…`) |
| `test/theme/theme_persistence_test.dart` | modified — import (locked `213042af…`) |
| `test/router/app_router_test.dart` | modified — override syntax (locked `b8475ef7…`) |
| `test/features/feed/feed_test.dart` | modified — override syntax ×2 (locked `72c70e18…`) |
| `test/features/subscriptions/paywall_test.dart` | modified — override syntax ×2 (locked `e080145a…`) |
| `test/features/photos/photo_gallery_test.dart` | modified — override syntax (locked `2b540bad…`) |
| `integration_test/theme_flow_test.dart` | modified — import (locked `a7f0ed32…`) |
| `integration_test/subscriptions_flow_test.dart` | modified — override syntax (locked `5866d341…`) |
| `docs/to-fix/TODO.md` | modified (locked `b802f899…`, H-09 ✅ + workstream block) |
| `docs/history/phase-02-flutter-foundation/2026-08-09_I71-config-cache.md` | created (locked `1793b849…`, this log) |

All released after the final full-suite run (see Validation below).

## Tests added + results (TDD: RED → GREEN)

RED proof: new test file failed to compile with exactly the two expected
errors (`hiveServiceProvider` undefined; `.notifier` not on `FutureProvider`).

```bash
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
flutter test test/providers/config_provider_test.dart        # RED: compile errors → GREEN: 10/10
dart analyze                                                 # 0 errors (2 pre-existing non-errors)
flutter test test/providers/ test/theme/ test/router/app_router_test.dart \
  test/features/feed/feed_test.dart test/features/subscriptions/paywall_test.dart \
  test/features/photos/photo_gallery_test.dart               # 250/250
flutter test integration_test/theme_flow_test.dart -d macos  # 2/2
flutter test integration_test/subscriptions_flow_test.dart -d macos  # 2/2
flutter test test/providers/ test/services/storage_service_test.dart   # 90/90
flutter test                                                 # FULL SUITE 1547/1547
```

`config_provider_test.dart` ran 3× consecutively — 10/10 each (the offline
tests are timing-stable, see MISTAKE below). Full suite green on first
complete run.

## Decisions made and why

- **AsyncNotifierProvider over FutureProvider** — the mission's requirement +
  H-09's exact complaint (no refresh method). `refresh()` = `ref.invalidateSelf()`
  matching the repo's existing notifier convention.
- **Watch connectivity, don't read it** — the I-67 handoff says "watch
  connectivityProvider; when false → serve getCachedConfig". Watching also
  gives the recovery property for free: the error state self-heals when the
  device comes back online (build re-runs → fetch succeeds).
- **`valueOrNull == false` as the only offline signal** — I-67's optimistic
  first state (`AsyncLoading`) and stream errors must NOT be treated as
  offline, or a flaky connectivity plugin would mask real server errors
  with stale cache. Fail-open, matching the banner's `valueOrNull ?? true`.
- **Fire-and-forget cache write** — `unawaited(_cacheConfig(config))`; the
  write path catches + logs. The provider must never fail a successful fetch
  because the cache write failed.
- **`Error.throwWithStackTrace(e, st)`** — preserves the original error +
  stack so the AsyncError surfaced to consumers (ErrorView retry, etc.) is the
  real server error, not a re-wrapped one.
- **Shared fake notifier in `test/support/`** — 6 call sites needed the new
  override shape; a single shared file (importable from `integration_test/`,
  precedent: `realtime_flow_test.dart` → `../test/support/resolving_builder.dart`)
  avoids 6 inline copies. Named fakes (`FakeAppConfigNotifier`) stay greppable
  and each screen suite keeps its exact config values.
- **No circular imports** — verified: `storage_service.dart` imports only
  `app_logger` + plugins; `theme_provider.dart` → `service_providers.dart` →
  `storage_service.dart` is a one-way chain. `dart analyze` clean.
- **Integration tests run with `-d macos`** — the iOS Simulator path fails
  pod install in this environment (see Issues); macOS target is the repo's
  workable hermetic harness here.

## MISTAKE

- **First attempt used `invalidateSelf()` bare on the notifier** — that method
  lives on `Ref`, not `AsyncNotifier` (riverpod 2.6.1). Compile error caught
  it in the first GREEN run; fixed to `ref.invalidateSelf()` (repo convention).
- **Offline-test timing flake (the long one):** the connectivity-flip →
  rebuild chain spans (a) the broadcast controller's async event delivery,
  (b) the StreamProvider's state update, (c) riverpod's internal
  `TaskScheduler` rebuild, (d) the notifier build future completion — four
  independent scheduling layers. Fixed flushes (`pumpEventQueue()` +
  `container.pump()`) raced this chain: the same test passed in isolation and
  failed in a shared process. Diagnosis: `container.pump()` only awaits the
  scheduler's `pendingFuture`; if the event delivery hasn't reached the
  scheduler yet, pump() returns before the rebuild even starts. Fix: bounded
  poll `pumpUntilSettled()` (pumpEventQueue + pump until the state leaves
  `AsyncLoading`, max 100 rounds) — deterministic, and the behavioral
  assertions are unchanged. Verified stable ×3.
- **Integration-test false alarm:** `flutter test integration_test/…` (no
  device) failed on the iOS pod path — diagnosed as the pre-existing
  CocoaPods/purchases_flutter environment conflict (see Issues), NOT my
  changes; re-ran with `-d macos` → green. `pod repo update` was run once to
  move past the "specs out of date" failure (no repo files changed).

## Issues found (out of scope, reported)

- **CocoaPods iOS pod-install is broken in this environment**: `flutter test
  integration_test/…` on the iOS simulator fails with a
  `PurchasesHybridCommon` constraint conflict ("run `pod update
  PurchasesHybridCommon`") in `purchases_flutter` — pre-existing (working tree
  was clean at start; nothing here touches pods). M-track/M-28 territory;
  integration tests were validated on the macOS target instead.
- **TODO.md H-09 row's second half was stale**: it listed `currentUserProvider`
  as still a `FutureProvider`, but that provider no longer exists post-I-09/
  decomposition (only `authServiceProvider.auth.currentUser` SDK access
  remains). Corrected in the row while flipping it ✅.
- I-65's "Issues" note (promote `hiveServiceProvider` to `service_providers.dart`)
  — the exact handoff this agent closed.

## Sources consulted

- Riverpod 2.6.1 `AsyncNotifier`/`AsyncNotifierProvider` docs (build/refresh,
  `ref.invalidateSelf`): https://riverpod.dev/docs/providers/notifier_provider
- Riverpod 2.6.1 source (`~/.pub-cache/hosted/pub.dev/riverpod-2.6.1/`):
  `async_notifier/base.dart` (`handleFuture`, `_onLoading` semantics),
  `framework/container.dart` (`pump()` awaits the scheduler's `pendingFuture` —
  why fixed flushes race the connectivity→rebuild chain)
- I-67 handoff (watch `connectivityProvider`, `false` = serve cache):
  `docs/history/phase-02-flutter-foundation/2026-08-09_I67-connectivity.md`
- I-26 cache API (`cacheConfig`/`getCachedConfig`, key-loss degradation):
  `docs/history/phase-02-flutter-foundation/2026-08-09_I26-hive-encryption.md`
- I-65 theme persistence (hiveServiceProvider promotion handoff):
  `docs/history/phase-02-flutter-foundation/2026-08-09_I65-theme-persistence.md`
- flutter_test `pumpEventQueue` semantics: https://api.flutter.dev/flutter/flutter_test/pumpEventQueue.html
