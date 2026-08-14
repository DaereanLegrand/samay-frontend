# I-67 — Connectivity layer: service, provider, global offline banner

**Agent:** I-67-connectivity · **Date:** 2026-08-09/10 · **Phase:** 02 (flutter foundation) / C-07 connectivity + offline UX
**Spec inputs:** `docs/specs/steps/cross-references.md` (I-49..I-78 row), `docs/to-fix/TODO.md` (H-06 family: network failures surface only as errors), `STOR-local-storage-setup.md` (offline cache groundwork), 08-SECURITY/10-PERFORMANCE categories (connectivity+offline UX, NOT M-32 — encryption was I-26).

---

## What was built

### 1. Dependency: `connectivity_plus ^7.3.1` (researched, current)

- **Version decision:** 7.3.1 (published 2026-07, Flutter Favorite, verified publisher `fluttercommunity.dev`; requirements Flutter ≥3.19 / Dart ≥3.3 — repo is on Flutter 3.44.1 / Dart 3.12.1). Added to `pubspec.yaml` after `permission_handler` with a comment documenting the injectable seam. `flutter pub get` — only the new package + its 2 transitive deps (`connectivity_plus_platform_interface 2.1.0`, `nm 0.5.0`) were added to the lockfile; minimal diff.
- **API notes (7.x):** `checkConnectivity()` returns `Future<List<ConnectivityResult>>`; `onConnectivityChanged` is `Stream<List<ConnectivityResult>>` (already `.distinct` internally — no double events from iOS NWPathMonitor). `none` is only ever the sole element when offline. The plugin measures *interface* availability, not internet reachability (captive portals report wifi) — documented in the service, banner is an UX hint not a gate.
- **Dev dependency:** `connectivity_plus_platform_interface ^2.1.0` added to `dev_dependencies` so tests can substitute a fake `ConnectivityPlatform` (the platform-interface seam) and exercise the **real default implementation** of the service end-to-end without a device or MethodChannel. Mirrors the transitive version.

### 2. `lib/core/services/connectivity_service.dart` (new)

`ConnectivityService` with two injectable seams (the `PermissionService` pattern, SEC-07/I-28):
- `typedef ConnectivityStream = Stream<bool> Function()` — `onConnectivityChanged` getter
- `typedef ConnectivityCheck = Future<bool> Function()` — `isConnected()`
- Defaults wrap `connectivity_plus`; mapping is the pure, unit-tested `hasNetworkConnection(List<ConnectivityResult>)` → `none → false, else true` (fail-safe on empty).
- `connectivityServiceProvider` defined here (per mission; keeps `service_providers.dart` — I-11's — untouched).

### 3. `lib/core/providers/connectivity_provider.dart` (new)

`connectivityProvider` = `StreamProvider.autoDispose<bool>` watching the service. **Initial optimistic** (AsyncLoading → consumers use `valueOrNull ?? true`); stream errors → AsyncError → same `?? true` fallback (fail-open — the banner is a hint, never a gate).

### 4. `lib/shared/widgets/connectivity_banner.dart` (new)

`ConnectivityBanner` — const-constructible `ConsumerWidget`:
- Hidden (`SizedBox.shrink`) while connected, loading, or erroring (optimistic).
- Offline: slim full-width bar — `AppColors.discoBlack` background, red `wifi_off` icon (`Theme.of(context).colorScheme.error` — M3 dark red, no ad-hoc palette value; new palette colors are U-01's track), localized copy, `bodySmall` text, single-line ellipsis.

### 5. `lib/app.dart` — wiring (chosen: inside `MaterialApp.router`'s `builder`)

- The mission's "Column above MaterialApp" option was evaluated and **rejected**: a widget above `MaterialApp` has no `Directionality`/`MediaQuery`/`Localizations` (the mission itself flagged this). The cleanest spot is the existing `builder:` (I-66's precedent — `DeepLinkListener` mounts there) → below Localizations/Theme/MediaQuery, above the Navigator → **every route** gets the banner (auth flow included), copy resolves, tests keep pumping `SamayApp` as-is.
- `builder: (context, child) => Column([const ConnectivityBanner(), Expanded(child: Stack([?child, const DeepLinkListener()]))])` — banner *displaces* content (no overlay covering UI).

### 6. Test-harness wiring (the plugin cannot be listened to in tests)

`receiveBroadcastStream` on a missing platform channel calls `FlutterError.reportError` → the flutter_test binding **fails the test**. So every `SamayApp` pump must inject an inert connectivity seam. Updated the 4 sites: `test/widget_test.dart`, `test/l10n/l10n_test.dart`, `test/theme/theme_persistence_test.dart`, `integration_test/support/test_app.dart` (`newTestContainer` defaults — all hermetic flows get it for free). Inert value: `ConnectivityService(onConnectivityChanged: () => Stream<bool>.multi((_) {}))` — never emits, multi-subscription-safe, banner stays hidden on the optimistic state.

### 7. l10n

One ARB key ×2 (gen-l10n once, drift-free):
- es: `connectivityOfflineBanner` = "Sin conexión — los datos podrían no estar actualizados"
- en: "No connection — data might not be up to date"

### 8. Out of scope (as instructed)

- `appConfigProvider` (I-71) — untouched.
- `refreshConfigFromCache` helper on HiveService — **not** added (trivial but belongs to I-71's config fallback; the offline-cache consumption point is I-71's decision, the provider here is the signal it keys off). See the I-71 handoff note in TODO.md.
- Screen-level offline hints — U-agents.

---

## Tests (TDD: RED → GREEN)

Written first (all failed: compile errors), then implemented.

| File | Cases |
|---|---|
| `test/services/connectivity_service_test.dart` | 9 — real default impl against `_FakeConnectivityPlatform` (none→false; every non-none interface→true; stream false/true; transition sequence true→false→true) + seam (stream delegation, check delegation, unmapped pass-through) |
| `test/providers/connectivity_provider_test.dart` | 6 — initial AsyncLoading (optimistic), true/false emission, sequence, error→AsyncError, autoDispose release+re-create contract |
| `test/widgets/connectivity_banner_test.dart` | 6 — hidden online, es copy, en copy, drop→show→recover, hidden while loading, hidden on stream error |

**MISTAKE 1 (test-harness):** initial provider tests used `container.listen(provider, (state) {...})` with `sub.cancel()` — Riverpod 2.6's `ProviderSubscription` has `close()` and the listener takes `(previous, next)` (see `auth_provider_test.dart` pattern). Fixed to the repo's two-arg + `addTearDown(sub.close)` convention.

**MISTAKE 2 (stream timing):** service tests called `emit()` before `.first` subscribed — broadcast events are dropped with no listener; fixed by subscribing first, then emitting. Banner sequence test used single `tester.pump()`; the event→provider→rebuild chain needs `pumpAndSettle()`.

**GOTCHA (Riverpod internals — documented, not fought):** asserting "subscription cancelled on dispose" via `StreamController.hasListener` FAILS with Riverpod 2.6.1: `handleStream` wraps the stream with `asBroadcastStream` + `lastCancelable`, whose internal listener outlives the provider's own subscription; `hasListener` stays true even after `container.dispose()`. The meaningful autoDispose contract — release + re-create with a fresh subscription on re-watch — is asserted instead (proven: service stream function called twice).

---

## Verification (validation gate)

```bash
flutter test test/services/connectivity_service_test.dart \
  test/providers/connectivity_provider_test.dart \
  test/widgets/connectivity_banner_test.dart \
  test/widget_test.dart test/l10n/          # 33/33 green
flutter test integration_test/theme_flow_test.dart   # 2/2 (hermetic app boot)
flutter test integration_test/auth_flow_test.dart    # 3/3
flutter test integration_test/feed_flow_test.dart    # 1/1
flutter test                                        # FULL SUITE 1482/1482
dart analyze                                        # 0 errors
```

`dart analyze`: 0 errors, 0 new warnings/infos from I-67 (remaining 1 warning `qr_flow_test.dart` unused import + 1 info `user_service.dart` curly-braces are pre-existing).

---

## Files created/modified (locks held/released)

- `pubspec.yaml` + `pubspec.lock` — acquire/release by `I-67-connectivity` (owner recorded in `repo-locks/`)
- `lib/app.dart`
- `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_localizations*.dart` (gen-l10n output)
- `lib/core/services/connectivity_service.dart` (new), `lib/core/providers/connectivity_provider.dart` (new), `lib/shared/widgets/connectivity_banner.dart` (new)
- `test/services/connectivity_service_test.dart`, `test/providers/connectivity_provider_test.dart`, `test/widgets/connectivity_banner_test.dart` (new)
- `test/widget_test.dart`, `test/l10n/l10n_test.dart`, `test/theme/theme_persistence_test.dart`, `integration_test/support/test_app.dart` (inert connectivity override)
- `docs/to-fix/TODO.md` (I-67 workstream + I-71 handoff note)
- `docs/history/phase-02-flutter-foundation/2026-08-09_I67-connectivity.md` (this log)

## Sources consulted

- https://pub.dev/packages/connectivity_plus (7.3.1 API: List<ConnectivityResult>, hasConnectivity, distinct stream, captive-portal caveat)
- https://pub.dev/packages/connectivity_plus_platform_interface (2.1.0 — ConnectivityPlatform seam, verifyToken pattern)
- Flutter SDK `platform_channel.dart` (`receiveBroadcastStream` → `FlutterError.reportError` on missing plugin — why tests must inject the seam)
- Riverpod 2.6.1 `stream_provider/base.dart` + `async_notifier/base.dart` (handleStream/lastCancelable subscription semantics)
