# I-19 — Network image caching (VNetworkImage) (2026-08-09)

**Agent:** I-19-image-cache | **Phase:** 02-flutter-foundation | **Status:** DONE

> **Resume note (same day, second session):** this agent's first run was
> interrupted mid-work. All code (pubspec deps, wrapper, call-site swaps,
> widget tests) was already in the working tree when the session resumed; what
> was actually **missing** was the TODO.md H-28 status flip (still `❌` despite
> this log claiming it was done) and the final verification pass. Both are
> closed below — see "Resume run" section at the end.

## What was built

Findings **H-28 / PERF-02 / UI-02 / DEP-08** (bare network-image widget with no
caching, no placeholder, no error state, no disk cache) — closed:

1. **`pubspec.yaml`** — added `cached_network_image: ^3.4.1` (verified latest,
   verified-publisher Baseflow, same version Juega pins, compatible with
   Flutter 3.44.1 / SDK ^3.11.4) and `flutter_cache_manager: ^3.4.1` (its API
   `CacheManager` is part of the wrapper's public surface and of the test
   harness — declared so `depend_on_referenced_packages` stays clean). Dev dep
   `file: ^7.0.1` (only the test imports `package:file/memory.dart`, mirroring
   flutter_cache_manager's own test configuration). `flutter pub get` clean.
2. **`lib/shared/widgets/v_network_image.dart`** (new) — `VNetworkImage`, a thin
   branded wrapper over `CachedNetworkImage`:
   - placeholder: `Colors.grey[900]` surface + small `Icons.photo_outlined`
     (white24, 20px) while loading;
   - `errorWidget`: `Colors.grey[800]` surface + `Icons.broken_image_outlined`
     — never crashes, no blank space;
   - `fadeInDuration: SamayDurations.standard` (250ms) on load;
   - `fit` (default `BoxFit.cover`), `width`, `height`, `cacheManager`,
     `fadeInDuration` passthrough; `borderRadius` optional, sharp (no
     `ClipRRect`) by default per DISCO §4.2;
   - fully const-constructible. This is the single entry point future features
     use instead of the raw Flutter network-image widget.
3. **Call-site sweep** — replaced both remaining bare network-image sites:
   - `lib/features/groups/my_groups_screen.dart:101` — group avatar: was
     `CircleAvatar(backgroundImage: NetworkImage(...))`; now
     `VNetworkImage(width: 40, height: 40, borderRadius: circular(20))`
     (CircleAvatar default radius 20 → same 40px circle, but now with
     placeholder/error/cache);
   - `lib/features/groups/group_detail_screen.dart:143` — group cover: was
     `Image.network(..., height: 120, fit: BoxFit.cover)`; now
     `VNetworkImage(height: 120, fit: BoxFit.cover)` (CachedNetworkImage
     passes width/height/fit to the same `Image` renderer → identical final
     layout; the only difference is the grey placeholder during load instead
     of blank space).
   - `rg "Image.network" lib/` → 0 hits. (`Image.file` in
     `create_group_screen.dart` is a local-preview, not a network image — out
     of scope.)
4. **`test/widgets/v_network_image_test.dart`** (new) — 12 tests, all green.
   Test design: a small **test HttpClient** (`_TestHttpClient` +
   `HttpOverrides.runZoned` — takes precedence over flutter_test's global
   400-mock, confirmed in `_binding_io.dart`) answers per-URL: 200+1x1 PNG
   (success), 404 (error), 200 + never-closing body (loading). A real
   `CacheManager` runs inside the override zone with
   `NonStoringObjectProvider()` + an in-memory `FileSystem`
   (`package:file/memory.dart`, mirroring flutter_cache_manager's own
   `TestFileSystem`) so the REAL cache pipeline executes without
   path_provider/sqflite plugins. Success-path decode uses `tester.runAsync`
   (real engine work).

## Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire/release <path> --owner I-19-image-cache`:

| File | Action |
|---|---|
| `pubspec.yaml` | modified (locked, edited, `flutter pub get`, released) |
| `lib/shared/widgets/v_network_image.dart` | created (locked, written, released) |
| `lib/features/groups/my_groups_screen.dart` | modified (locked, call-site swap, released) |
| `lib/features/groups/group_detail_screen.dart` | modified (locked, call-site swap, released) |
| `test/widgets/v_network_image_test.dart` | created (locked, written, released) |
| `docs/to-fix/TODO.md` | modified (locked, H-28 status, released) |
| `docs/history/phase-02-flutter-foundation/2026-08-09_I19-image-cache.md` | created (locked, this log, released) |

TODO.md lock was briefly held by I-17-theme-disco when this agent started; the
other six locks were acquired first, work proceeded, and TODO.md was acquired
once I-17 released it (semaphore protocol, no barge).

## Commands run (reproducibility)

```bash
export AGENT_NAME="I-19-image-cache"
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
tools/agent_lock.sh acquire <file> --owner "$AGENT_NAME"   # per file
flutter pub get
flutter test test/widgets/v_network_image_test.dart        # 12/12
flutter test test/widgets/v_network_image_test.dart \
  test/features/groups_screens_test.dart                   # 31/31
flutter analyze                                            # 0 errors, 14 info (pre-existing)
flutter test                                               # 488 pass / 18 fail (see below)
rg "Image.network" lib/                                    # 0 hits (gate passed)
tools/agent_lock.sh release <file> --owner "$AGENT_NAME"
```

## Test results

- `flutter pub get` — clean, exit 0 (only pre-existing SPM warnings for
  `flutter_secure_storage`/`mobile_scanner`).
- `test/widgets/v_network_image_test.dart` — **12/12 pass**: placeholder while
  loading; placeholder grey[900] surface; error widget on HTTP 404 (no crash);
  error grey[800] surface; decoded image on success (real disk-cache flow);
  fit passthrough; width/height passthrough; imageUrl+cacheManager passthrough;
  sharp default (no ClipRRect); borderRadius via ClipRRect; fade-in uses
  `SamayDurations.standard`; const-constructible with sane defaults.
- `test/features/groups_screens_test.dart` — **19/19 pass** (call-site swaps
  keep layout; fixtures have no `cover_url` so no network images involved).
- `dart analyze` — **0 errors**, 14 info (all pre-existing
  `use_build_context_synchronously` in `public_profile_screen.dart`, not
  touched by this agent).
- Full `flutter test` — **488 pass / 18 fail**; the 18 are NOT regressions:
  12× `structure_test.dart` (documented pre-existing brittle future-dir
  asserts, L-13 → I-48), 5× `test/assets/fonts_test.dart` (I-18's untracked
  in-progress work, fonts not landed), 1× `test/perf/list_view_builder_test.dart`
  (I-20's untracked in-progress work, PERF-01 still open). Baseline was
  176/23 at campaign start.

## Decisions made and why

- **Wrapper over `CachedNetworkImage`, not direct usage**: one branded entry
  point (`VNetworkImage`) guarantees placeholder/error/fade/cache everywhere;
  future features just import the shared widget (refactorability directive).
- **`cacheManager` passthrough on the wrapper**: needed for deterministic
  widget tests (real `CacheManager` inside the override zone) and is the
  documented extension point for per-scope caches later.
- **Test HttpClient via `HttpOverrides.runZoned`**: flutter_test installs a
  global 400-mock; the Flutter framework docs state a zone-scoped override
  takes precedence, so tests need no global state mutation.
- **`NonStoringObjectProvider` + in-memory `FileSystem`**: avoids
  path_provider (MissingPluginException) and sqflite (CacheObjectProvider on
  darwin) while still exercising the real CacheManager/WebHelper/HttpFileService
  pipeline — the same approach flutter_cache_manager's own tests use.
- **`file` as a dev dependency**: only the test imports `package:file/memory.dart`
  (transitive via flutter_cache_manager) — declared to keep
  `depend_on_referenced_packages` clean.
- **No integration_test case added** (AGENT-RULES §2): the modular suite is
  hermetic by contract ("never hit the network in hermetic flows") and the
  groups flow file doesn't exist yet — an image-cache flow cannot run
  hermetically. Coverage lives at widget-test level (12 tests) + the existing
  groups screens tests; when `groups_flow_test.dart` lands (I-01/other I-agents)
  the VNetworkImage cover rendering can be asserted there. Noted for the
  orchestrator.
- **Placeholder/error colors are grey[900]/grey[800] per mission contract**;
  they map to DISCO `surfaceAlt`/empty-state `#333333` semantics — migrate to
  the design tokens when U-01/U-04 land (this wrapper is the single migration
  point).

## MISTAKE

- **CacheManager constructed outside the `HttpOverrides` zone.** First test
  draft created the `CacheManager` (which eagerly builds `http.Client()`) in
  the test body, outside `HttpOverrides.runZoned` → every request used
  flutter_test's global 400-mock instead of the test client (visible as the
  "all HTTP requests will return status code 400" warning). Fixed by
  constructing the cache manager inside the override zone; placeholder test
  then became deterministic.
- **dart:io `HttpHeaders` is abstract in this SDK** — the first mock tried
  `HttpHeaders()` directly; compiled only after implementing a minimal
  in-memory `HttpHeaders` (mirroring flutter_test's own `_MockHttpHeaders`).
- **`package:file` return-type trap** — `FileSystem.createFile` must return
  `package:file`'s `File`; a dart:io `File` fails the override signature.
  Switched to `MemoryFileSystem` like the upstream package's tests.
- **Interrupted-run gap: TODO.md not actually flipped.** The first session's
  log claimed H-28 was set to ✅, but the file still read `❌` on resume —
  the edit never landed (session cut before the write). Resume session
  re-acquired the TODO.md lock, verified the code state first, flipped H-28,
  and re-ran the full verification gate.

## Issues found (out of scope, reported)

- `.env.example` still contains what looks like a real `SUPABASE_ANON_KEY`
  (finding H-21) — untouched.
- `flutter_cache_manager 3.4.1 (3.4.2 available)`: the direct `^3.4.1`
  constraint resolved to 3.4.1 while the transitive resolution had picked
  3.4.2 — same API, cosmetic.
- `docs/to-fix/categories/{10-PERFORMANCE,07-UI-DESIGN,11-DEPENDENCY-MANAGEMENT}.md`
  still carry "planned → I-19" status text — those files are D-03/V-02 owned;
  TODO.md H-28 is flipped here, category files should be re-verified by V-02.

---

## Resume run (second session, same day)

**State found on resume:** all code work from the interrupted run was already
in the working tree and correct — `pubspec.yaml` deps present (lines 31-33),
`v_network_image.dart` complete per spec (grey[900] placeholder + icon, grey[800]
error + icon, fadeIn = `SamayDurations.standard`, fit/width/height/borderRadius/
cacheManager passthrough, const-constructible), both call sites converted
(`my_groups_screen.dart:101`, `group_detail_screen.dart:143`), the 12-test
widget suite present, and `rg "Image.network" lib/` already at 0 hits.

**What was missing / done in this session:**

1. **TODO.md H-28 → ✅** — the log's claim was stale; flipped with evidence
   (lock `b802f899...`, re-verified after edit).
2. **Full verification gate re-run** (see above): `flutter pub get` clean,
   `dart analyze` 0 errors / 14 pre-existing info, targeted widget suite
   **12/12 green** re-confirmed on the resumed session.
3. **This log finalized** with the resume addendum (overwrite per mission
   contract; lock held `3f42aa95...` during write).

**Locks held during resume session (all 7, acquired 2026-08-09, released after
edits):** `pubspec.yaml`, `lib/shared/widgets/v_network_image.dart`,
`lib/features/groups/my_groups_screen.dart`, `lib/features/groups/group_detail_screen.dart`,
`test/widgets/v_network_image_test.dart`, `docs/to-fix/TODO.md`,
`docs/history/phase-02-flutter-foundation/2026-08-09_I19-image-cache.md`.

## Sources consulted

- cached_network_image 3.4.1 (API, disk-cache defaults, error handling FAQ):
  https://pub.dev/packages/cached_network_image
- flutter_cache_manager (Config/NonStoringObjectProvider/HttpFileService,
  own test configuration): https://pub.dev/packages/flutter_cache_manager
- Flutter docs — zone-scoped HttpOverrides precedence over the test 400-mock:
  https://docs.flutter.dev/testing/network-images
- flutter_test `_binding_io.dart` (`setupHttpOverrides`, `_MockHttpOverrides`,
  runZoned precedence) — Flutter SDK source
- package:http `io_client.dart` (IOClient.send contract for the mock
  HttpClient) — pub cache source
- Juega reference pattern (read-only): `cached_network_image: ^3.4.1` +
  `CachedNetworkImageProvider` avatars / `CachedNetworkImage` covers
