# 2026-08-09 — I-36: PRFL Profile Gaps Foundation (avatar upload, interest tags, cosmetics display)

**Agent:** I-36 (profile feature gaps foundation)
**Status:** DONE
**Scope:** PRFL spec gaps that Phase 03 deferred: (1) REAL avatar upload in
`edit_profile_screen.dart`, (2) interest-tags foundation module, (3) flag-gated
cosmetics display placeholder on `profile_screen.dart`. Full polish is U-09's
domain; these pieces are deliberately small, typed, tested and refactorable.

---

## 1. What was built

### Avatar upload (REAL, functional)

- **`lib/core/services/media_service.dart`** — `MediaService.uploadUserAvatar(String userId, Uint8List bytes)`:
  compresses via `ImageProcessor.compressBytes` (I-22), uploads to storage bucket
  `avatars` at `avatars/<userId>/<millis>.png`, returns the public URL —
  mirrors `uploadGroupCover` 1:1.
- **`lib/core/services/user_service.dart`** — `UserService.updateAvatarUrl(String userId, String avatarUrl)`:
  `users.update({'avatar_url': …}).eq('id', userId)` (guarded by the existing
  `users_update_own` RLS policy — verified in
  `20260510000001_full_schema.sql:611`).
- **`lib/features/profile/edit_profile_screen.dart`** — avatar button wired:
  `PermissionService.photos` (I-28, with localized rationale/settings UX) →
  `ImagePicker` gallery → `mediaServiceProvider.uploadUserAvatar` →
  `userServiceProvider.updateAvatarUrl` → `ref.invalidate(myProfileProvider)`.
  - In-button progress state: `CircularProgressIndicator` replaces the camera
    icon while the upload is in flight (button disabled).
  - Avatar display: `VNetworkImage` (I-19) in a `ClipOval` when
    `avatar_url` is set (prefilled from `myProfileProvider`), person icon
    otherwise.
  - Injectable seams for tests: `permissions` (`PermissionService?`) and
    `galleryPicker` (`GalleryPicker` typedef — `image_picker` is a plugin that
    cannot run in widget tests; thin-wrapper pattern from I-28).
  - User id read from `authStateProvider` (awaiting its future — see MISTAKE).

### Interest tags foundation (NO persistence yet)

- **`lib/features/profile/interests.dart`** (new):
  - `kInterestTagIds` — const curated catalog: `musica, fiestas, deportes,
    gaming, cine, arte, viajes, comida` (es labels: Música, Fiestas, Deportes,
    Gaming, Cine, Arte, Viajes, Comida).
  - `interestTagLabel(AppLocalizations, tagId)` — typed ARB label resolution,
    `ArgumentError` on unknown ids. Labels live in ARB (the l10n extraction
    guard forbids accented literals in `lib/features/**`).
  - `UserInterests` — immutable value object over `Set<String>`:
    `fromDb(Object?)` accepts the PostgREST list form AND a JSON-encoded array
    string; `toDb()` emits the sorted JSON array literal PostgREST accepts for
    `text[]` columns; copy-on-write `withTag/without/toggle`; set-based
    `==`/`hashCode`.
  - `InterestTagPicker` — const-constructible stateless widget, `Wrap` of
    `VChip` (disco `FilterChip`) rendering the whole catalog; `onChanged`
    receives the new selection set. Parent owns the state.
- **NOT wired into the edit screen** (deliberate): no persistence column exists
  yet, so rendering the picker would lie to the user. Needs
  `ALTER TABLE users ADD COLUMN interest_tags text[]` — a migration owned by
  **I-31/I-32** (migration agents; I did NOT touch `supabase/migrations/**`).
  **FLAG for S-03/orchestrator:** storage contract pinned by the
  `UserInterests.fromDb/toDb` tests so the migration consumes it cleanly.

### Cosmetics display foundation

- **`lib/core/feature_flags.dart`** (new) — minimal `AppFeatureFlags` const
  class with `showCosmeticsSection = false`. **I-49 owns growing this into the
  provider-backed feature-flag system** (`lib/core/feature_flags/**`); this
  file is the single seam today.
- **`lib/features/profile/profile_screen.dart`** — "Cosméticos" header +
  empty-state line below the groups section, rendered ONLY when
  `AppFeatureFlags.showCosmeticsSection` is true → **zero visual diff** with
  the flag off (covered by test). L10n keys `profileCosmetics` /
  `profileNoCosmeticsYet` were pre-added by **I-35** during its session (same
  keys I needed — see MISTAKE about ARB duplicates); I kept I-35's strings.

### l10n

- ARB keys used (es+en, all pre-existing from I-35 where noted): the `interest*`
  octet (I-35), `profileAvatarChange`, `profileAvatarUpdatedSnack`,
  `profileCosmetics`, `profileNoCosmeticsYet` (I-35), plus existing
  `permissionsPhotoRationale`/`permissionsSettings*`/`commonCancel` (I-28).
- No net-new keys from I-36 after the dedup pass (see MISTAKE).

## 2. Tests (all green)

| File | Tests | Covers |
|---|---|---|
| `test/features/profile/interests_test.dart` (new) | 16 | catalog integrity (unique ASCII slugs), label resolution incl. ArgumentError, `UserInterests` roundtrip/fromDb/toDb/equality/copy-on-write, picker render + controlled-toggle + const-constructible |
| `test/features/profile/avatar_flow_test.dart` (new) | 6 | full flow (permission→picker→upload→persist→invalidate→snackbar), denied-permission rationale, cancelled picker, upload failure (no persist/invalidate), in-button spinner via Completer, avatar prefill render |
| `test/services/user_service_test.dart` (new) | 2 | `updateAvatarUrl` payload + `eq('id', …)` filter (recorded via real `eq` override), failure propagation |
| `test/services/media_service_test.dart` | +4 | `uploadUserAvatar`: compression of full-res payloads, small-payload passthrough, public URL, per-user path namespacing |
| `test/features/profile_screens_test.dart` | +1 | cosmetics section renders nothing while the flag is off |

**Results:**
```
dart analyze                                        # 0 errors; 2 pre-existing warnings (shards_service/secure_session_storage, both committed pre-campaign — not mine)
flutter test test/features/profile/ test/features/profile_screens_test.dart test/providers/profile_providers_test.dart   # 41/41
flutter test test/l10n/ test/services/              # 69/69 (incl. l10n extraction guard + YAML strictness)
flutter test                                        # 740 pass / 12 fail — ALL 12 = pre-existing structure_test.dart brittle paths (I-47/I-48)
```

## 3. MISTAKE blocks

- **MISTAKE (auth read):** `ref.read(authStateProvider).valueOrNull` returns
  **AsyncLoading on first read** — nothing watches the auth provider on the
  edit screen, so the avatar flow silently aborted with a null user. Fixed by
  `await ref.read(authStateProvider.future)`.
- **MISTAKE (ARB duplicates):** I added `profileAvatar*`/`profileCosmetics*`
  and the `interest*` keys without re-reading the ARB files I had locked — but
  **I-35-ban had already added the same keys** (held the ARB locks before me;
  identical es values). Result: duplicate YAML mapping keys that only
  `l10n_test.dart`'s strict YAML parse caught (gen-l10n silently last-wins).
  Fix: kept I-35's canonical block, deleted mine, aligned my test assertion to
  I-36-free string 'Tu armario de cosméticos aparecerá aquí.'. Lesson: when a
  lock is contested, RE-READ the file immediately before editing, not just at
  acquire time.
- **MISTAKE (mocktail fallback):** `verify(() => media.uploadUserAvatar(_userId, any()))`
  threw "registerFallbackValue was not previously called for Uint8List" — same
  fix as `media_service_test.dart`: `registerFallbackValue(Uint8List(0))` in
  setUpAll.
- **MISTAKE (stale null handling):** my `_load()` rewrite dropped the
  null-provider-value settle path (`AsyncData(null)` → no profile → the screen
  must still leave `_loading`); the 'renders edit form' test caught it.
  `_applyProfile(profile.value ?? const {})`.

## 4. Coordination notes

- **Locks:** all acquired before edit, released after (list in §6). No lock
  wait-timeouts hit in the end — I did non-conflicting work first while I-35
  (ARB) and I-37 (TODO.md) held their locks, then acquired after release.
- **I-35 concurrency:** ARB keys pre-added by I-35 — dedup'd (see MISTAKE).
- **I-49:** `lib/core/feature_flags.dart` foundation only; I-49 owns the
  provider-backed system.
- **I-31/I-32:** the `users.interest_tags text[]` migration is theirs. The
  `avatars` storage bucket must ALSO exist for uploads to work (no bucket
  creation exists in any migration today — the `groups`/`events` buckets have
  the same gap); flag for M-09/I-31.
- **U-09:** profile screens restyle (VChip already used for the picker; the
  avatar layout is a plain Stack/ClipOval).
- **Integration suite:** not extended — the avatar flow is plugin-bound
  (image_picker/permission_handler) and cannot run hermetic (same documented
  decision as I-28 for the permission UX).

## 5. Commands run (reproducibility)

```
export AGENT_NAME=I-36-profile-gaps
tools/agent_lock.sh acquire <file> --owner "$AGENT_NAME" --timeout 120   # 19 files
flutter gen-l10n
dart analyze
flutter test test/features/profile/ test/features/profile_screens_test.dart test/providers/profile_providers_test.dart
flutter test test/l10n/ test/services/
flutter test
tools/agent_lock.sh release <file> --owner "$AGENT_NAME"
```

## 6. Lock evidence

Acquired + released (all by `I-36-profile-gaps`):
`lib/core/services/media_service.dart` · `lib/core/services/user_service.dart` ·
`lib/features/profile/edit_profile_screen.dart` · `lib/features/profile/profile_screen.dart` ·
`lib/core/feature_flags.dart` (new) · `lib/features/profile/interests.dart` (new) ·
`lib/l10n/app_es.arb` · `lib/l10n/app_en.arb` ·
`lib/l10n/app_localizations_es.dart` · `lib/l10n/app_localizations_en.dart` ·
`lib/l10n/app_localizations.dart` (gen-l10n outputs) ·
`test/features/profile/interests_test.dart` (new) ·
`test/features/profile/avatar_flow_test.dart` (new) ·
`test/services/user_service_test.dart` (new) ·
`test/features/profile_screens_test.dart` · `test/services/media_service_test.dart` ·
`docs/to-fix/TODO.md` · `docs/history/phase-02-flutter-foundation/2026-08-09_I36-profile-gaps.md` (this log)

## 7. Issues found (out of scope, reported not fixed)

1. **`users.interest_tags text[]` migration needed** — owner: I-31/I-32 (with
   S-03 RLS review). App-layer contract ready (`UserInterests.fromDb/toDb`).
2. **`avatars` storage bucket missing from all migrations** (also `groups`/
   `events`) — buckets are created out-of-band today; needs an owner
   (M-09/I-31 or infra).
3. Pre-existing `dart analyze` warnings in `lib/core/services/shards_service.dart`
   (unused `app_logger` import) and `test/services/secure_session_storage_test.dart`
   (unused `supabase_flutter` import) — both committed before this campaign;
   not mine to fix.
4. 12 `structure_test.dart` brittle path assertions still failing — documented
   baseline, I-47/I-48's assignment.
