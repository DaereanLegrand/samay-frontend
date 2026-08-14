# 2026-08-09 — EF-04: Integration-suite & image-test stability (flake elimination)

**Agent:** EF-04-stability · **Role:** flake/robustness engineer — integration suite
**Phase:** 02-flutter-foundation (campaign sub-phase 4.2, post-STOP-50 fixes)
**Status:** DONE

## Assignment

1. Fix the `test/widgets/v_network_image_test.dart` disk-cache flake under full-suite load.
2. Make `integration_test/runner.sh` robust to the macOS "Failed to foreground app; open returned 1"
   environmental failure (retry once + detect/skip-with-warning when the platform cannot foreground).
3. Add `integration_test/ban_flow_test.dart` (hermetic ban flow) and register it in `runner.sh`.
4. Verify every integration flow file runs green standalone (hermetic, no live server).
5. Fix any OTHER flaky tests found during the 3 consecutive full-suite runs.

---

## What was built

### 1. VNetworkImage disk-cache flake — split + deterministic waiting (fixes I-24 flag)

`test/widgets/v_network_image_test.dart` contained 12 tests sharing one isolate; the success-path
test ("renders the decoded image on success (disk-cached flow)") does REAL engine work (HTTP fetch →
disk-cache pipeline → image decode) that competes for the UI thread and used FIXED
`Future.delayed(400ms)` sleeps — a load-dependent race (passes isolated, flakes in full-suite runs).

- **`test/support/test_network_image_http.dart` (new)** — the HTTP/file-system harness extracted from
  the test (per-URL `HttpClient` mocks, in-memory `FileSystem`, `inTestNetworkZone()`), so both test
  files share it instead of duplicating ~160 lines.
- **`test/widgets/v_network_image_disk_cache_test.dart` (new)** — the decode test now runs in its OWN
  isolate, waits with a POLL loop (`pumpUntil`: 50 ms real-time step + 100 ms fake-clock pump until
  the decoded `RawImage` is present AND the placeholder is gone — the fade-in keeps both mounted
  mid-transition), and clears the global `imageCache` in setUp + disposes its cache manager in
  tearDown. Fresh per-test `CacheManager` with unique keys (no shared cache state).
- `test/widgets/v_network_image_test.dart` — 11 remaining tests, uses the shared harness, clears the
  global `ImageCache` in `setUp` (per-isolate hygiene).

### 2. `integration_test/runner.sh` — foreground-failure robustness (fixes I-08 flag)

- **Retry once:** any run whose output contains `Failed to foreground app` is retried after 2 s.
- **Detect + skip with warning:** if the retry still cannot launch (foreground error present AND no
  test-run result marker — `All tests passed`/`Some tests failed`), the flow is counted as
  environment-SKIPPED (not a failure), listed in the summary, and the runner still exits 0.
- Genuine test failures are never masked (fail → exit 1 as before).
- **Fixed a real bug:** `mktemp "${TMPDIR:-/tmp}/samay-int-XXXXXX.log"` — macOS (BSD) `mktemp`
  requires the `XXXXXX` run at the END of the template; the `.log` suffix made it create a literal
  filename, which then collided on the second flow ("File exists") and broke the whole run.
- Documented in `integration_test/README.md` (§"Foreground-failure handling (runner.sh, EF-04)").
- Verified with simulated foreground failures (fake `flutter` shim): retry-pass path, all-skip path
  (exit 0 + warnings), and genuine-failure path (exit 1).

### 3. `integration_test/ban_flow_test.dart` (new, hermetic) — I-35 gap

- 3 tests through the real app (real router/guard/theme): banned user lands on `/banned`
  (`BannedScreen`, "Cuenta suspendida", stored reason "Motivo: Spam", "Cerrar sesión"); banned user is
  redirected from EVERY route (authenticated `/main/feed` AND public `/`); "Cerrar sesión" calls
  `AuthService.signOut()` (mocktail fake) and leaves the ban screen for the login route.
- Registered in `runner.sh` `ORDERED_FLOWS` right after `auth_flow_test.dart`.

### 4. OTHER flaky test found and fixed: `test/services/storage_service_test.dart` hang

During verification run 1 of the full suite, the "lost key (fresh install after backup restore)"
test timed out at 30 s. Reproduced it deterministically-ish (~50% under parallel-file load, 3/8 runs).

**Root cause (hive 2.2.3 upstream bug, not the test's logic):** on a wrong-key open,
`HiveImpl._openBox`'s catch calls `newBox?.close()` WITHOUT awaiting it — the box's `lockRaf` flock
is released asynchronously. The service's re-creation path (`deleteBoxFromDisk` → immediate re-open)
races that deferred close: when hive's exists→delete check loses the race (or the delete throws
`PathNotFoundException`), the lock file survives and the re-open's `lockRaf.lock()` **blocks forever
on the leaked flock** → 30 s timeout (or a hang that outlives the test timeout).

**Fix (`lib/core/services/storage_service.dart`):** new `_recreateBox()` used by both `_openBox`
failure branches:
- `deleteBoxFromDisk` is wrapped so `FileSystemException` races are retried, never fatal;
- the re-open is bounded with a 2 s `.timeout()` — on contention the next attempt's delete unlinks
  the lock file (unlink of an open+locked file succeeds on macOS), so the new open locks a FRESH
  inode and cannot block; worst case is a bounded failure, never an unbounded hang.
- Regression test strengthened: explicit 20 s test timeout (a hang now fails fast and loud) + new
  assertion that the re-created box is USABLE (`cacheConfig` → `getCachedConfig` round-trip).
- Verified: 12/12 parallel-load runs green (was 3/8 failing).

---

## Files created / modified (lock evidence — all via `tools/agent_lock.sh`)

| File | Action | Lock |
|---|---|---|
| `test/support/test_network_image_http.dart` | created | acquired → released (EF-04-stability) |
| `test/widgets/v_network_image_disk_cache_test.dart` | created | acquired → released |
| `test/widgets/v_network_image_test.dart` | modified | acquired → released |
| `integration_test/ban_flow_test.dart` | created | acquired → released |
| `integration_test/runner.sh` | modified | acquired → released |
| `integration_test/README.md` | modified | acquired → released |
| `lib/core/services/storage_service.dart` | modified (hive re-create hardening) | acquired → released |
| `test/services/storage_service_test.dart` | modified (regression guard + usability assert) | acquired → released |
| `docs/history/phase-02-flutter-foundation/2026-08-09_EF04-integration-stability.md` | created (this log) | acquired → released |

`tools/agent_lock.sh list` after release: no locks held by this agent.

## Tests added + results

| Command | Result |
|---|---|
| `flutter test` × 3 consecutive | **759 / 759 pass each run** (0 failures) |
| `flutter test test/widgets/v_network_image_test.dart test/widgets/v_network_image_disk_cache_test.dart` | 12/12 pass |
| disk-cache test × 5 isolated + 12× under parallel-file load | all green |
| `flutter test test/widgets/` | 63/63 |
| `flutter test test/services/storage_service_test.dart` | 7/7 (incl. hardened lost-key test) |
| storage test under parallel-file load × 12 | all green (pre-fix: 3/8 failing) |
| `flutter test integration_test/{auth,ban,error,profile}_flow_test.dart` standalone | auth 3/3 · ban 3/3 · error 3/3 · profile 2/2 |
| `bash integration_test/runner.sh` | 4 flows found, 4 passed, exit 0 |
| runner simulated paths (fake flutter): retry→pass / all-skip→exit 0 / real-fail→exit 1 | all three verified |
| `flutter analyze` (repo) | No issues found |

## Sources consulted

- flutter_cache_manager 3.4.1 source (CacheStore/WebHelper/NonStoringObjectProvider): pub cache
- hive 2.2.3 source (`hive_impl.dart` unawaited `newBox?.close()`; `storage_backend_vm.dart`
  `lockRaf.lock()` / `_closeInternal`; `read_write_sync.dart`): pub cache
- macOS `flock`/`unlink` semantics for open files (unlink of open+locked file succeeds; flock is
  per-inode) — man 2 flock / unlink
- BSD `mktemp` template rules (XXXXXX must be trailing): man mktemp
- Flutter docs — zone-scoped HttpOverrides in tests: https://docs.flutter.dev/testing/network-images

## Issues found / reported (not fixed — out of scope or other agents')

- **EF-03 in-flight work**: full-suite verification run 1 saw 1 failure in
  `test/features/groups_screens_test.dart` ("EF-03 swap" test) — passes isolated and under
  parallel-file load (8/8); the failure occurred while EF-03 held the file lock (mid-edit transient).
  NOT touched (semaphore); reported for EF-03/orchestrator.
- **hive 2.2.3 upstream bug** (unawaited close on failed open) documented in the service's
  `_recreateBox` doc comment — a future hive upgrade may fix it; the service is now immune either way.
- `integration_test/README.md` dependency table still lists friends/groups/events/chat flows as
  "not written yet" — those files belong to other agents' phases; runner already skips them.
