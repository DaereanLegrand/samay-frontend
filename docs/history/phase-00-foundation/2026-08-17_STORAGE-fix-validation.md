# Storage fixes — avatar upload + image rendering + error mapping (2026-08-17)

**Orchestrator:** ORCH-STORAGE · **Branch:** `fixes` (uncommitted working tree)
**Stack:** samay-testing compose (54382/54386/54384) · **HEAD:** 47944e4 + working tree

## What was fixed (three independent TDD agents)

| Agent | Fix | Files |
|---|---|---|
| AVATAR-PATH-FIX | Avatar upload path `avatars/<uid>/<ts>.png` → `<uid>/<ts>.png` (relative to the `avatars` bucket) — the redundant `avatars/` first segment violated `storage_objects_insert_own`'s first-segment rule (`storage.foldername(name))[1] = auth.jwt()->>'sub'`) → every avatar upload 42501 | `lib/core/services/media_service.dart`, `test/services/media_service_test.dart`, migration header comments ×2 stacks |
| IMG-APIKEY-FIX | `VNetworkImage` sends the public anon key as the `apikey` header on `/storage/v1/` URLs (Kong key-auth on `storage-v1` rejects bare public URLs with 401 → all stored covers/banners rendered as broken images) | `lib/shared/widgets/v_network_image.dart`, `test/widgets/v_network_image_test.dart` |
| ERR-MAP-FIX | `StorageException` mapped in `toAppError()`: 401→Unauthorized, 403/42501/AccessDenied/InvalidKey→Permission, 404→NotFound, else ServerError(message) — the generic "Error del servidor" masked the real 42501 | `lib/core/extensions/error_mapper.dart`, `test/core/error_mapper_test.dart` |

Daily logs: `docs/history/phase-02-flutter-foundation/2026-08-17_{AVATAR,IMG,ERR}*.md`.

## Root cause chain (for future devs)

1. `uploadUserAvatar` wrote object key `avatars/<uid>/<ts>.png` (bucket-relative path with the bucket name repeated as first segment). The M-08 RLS policy requires the first segment to be the caller's `sub`. Live logs proved the 42501: `POST /object/avatars/avatars/<uuid>/…png` → `AccessDenied 42501 new row violates row-level security policy` (both Android and iOS, 2026-08-18T01:50/01:55Z).
2. The generic message: `StorageException` was unmapped in `error_mapper.dart` → `ServerError('')` → "Error del servidor. Intenta de nuevo."
3. Even successful uploads rendered as broken images: Kong `storage-v1` requires `apikey` (key-auth) on ALL `/storage/v1/*` routes, so the bare `getPublicUrl` URL fetched by `CachedNetworkImage` (no headers) → 401 → `broken_image_outlined`.

## Verification (live, against the running stack)

`bash /tmp/avatar_e2e.sh` (scratch script, tester@tester.com / tester123 login, 1×1 PNG):

```
1) upload  avatars/<uid>/<ts>.png        → 200   (was 400/403)
2) upload  avatars/avatars/<uid>/<ts>.png → 400   (regression guard — old path still denied)
3) GET public URL, no apikey             → 401   (the broken-image cause)
   GET public URL, +apikey               → 200
4) storage.objects row: name=<uid>/<ts>.png, owner_id=<uid>  ✅ (first-segment rule satisfied)
5) object delete                         → 200   (cleanup; tester user kept)
```

## Gates

| Gate | Result |
|---|---|
| `flutter test` (full) | **2467/2467 pass, 0 failures** (baseline 2455 + 12 new: 7 error-mapper + 5 VNetworkImage) |
| `dart analyze` | 0 errors / 10 warnings / 22 infos — **all pre-existing** (VAurora commit `47944e4` drift; 0 new from this change set) |
| `go test ./...` | 188 pass / 5 packages (unaffected) |
| Migration parity | `supabase/` vs `supabase-testing/` byte-identical (comment-only diff, both files + whole dirs) |
| `make secrets-check` | PASS |
| `tools/check_ports.sh --strict` | STRICT PASS (19 mappings / 227 refs / 0 violations) |
| RLS posture | `storage_objects_insert_own` untouched — defense-in-depth preserved (verified by security agent) |

## Decisions

- **Code-side fix, no migration:** the RLS policy encodes the documented intent (`<userId>/…` first segment); the client path was wrong.
- **apikey header in `VNetworkImage`** (app-side) instead of a key-auth-free Kong public-objects route: single seam, zero infra/parity churn; the anon key is public by design (SECURITY.md §2.8, DEPLOYMENT-PLACEHOLDER.md §2.1 "✅ yes").
- Header only for URLs containing `/storage/v1/` and only when the key is non-empty (`EnvConfig.supabaseAnonKeyRaw`) — hermetic widget tests unchanged.

## MISTAKE

- The avatar bug shipped and survived for weeks because every test mocks `uploadBinary`/`uploadUserAvatar`, and the I-36/M-08 docs encoded the wrong path (`avatars/<userId>/…`) — the same wrong shape as the code, so doc↔code "verified". No test exercised the real RLS first-segment rule. Lesson: storage path/RLS contracts must be tested against the policy shape (unit-test the object-key shape AND live-verify once per stack change).
- Self-hosted "public bucket" URLs are NOT loadable bare: Kong key-auth applies to `/storage/v1/` even for `object/public/`. The design docs assumed public-bucket URLs render directly.

## Follow-ups (out of scope, reported)

- Stray untracked `flutter_01.png` in the repo root (remove/gitignore before the next commit).
- `dart analyze` baseline drift: 32 pre-existing issues from the VAurora removal commit — docs claim "0 issues" (2026-08-16); recommend a cleanup pass + baseline re-verification.
- Previously stored group `cover_url`s need no DB change — they render once the apikey-header fix ships in a build.

## Commands (reproducibility)

```bash
flutter test test/services/media_service_test.dart        # 18/18 (RED 3 fails pre-fix)
flutter test test/features/profile/avatar_flow_test.dart  # 6/6
flutter test test/widgets/v_network_image_test.dart       # 16/16 (RED compile fails pre-fix)
flutter test test/widgets/v_network_image_disk_cache_test.dart  # 1/1
flutter test test/core/error_mapper_test.dart             # 50/50 (RED 7 fails pre-fix)
flutter test                                             # 2467/2467
dart analyze                                             # 0 errors (32 pre-existing infos/warnings)
go test ./...                                            # 188 / 5 pkgs
make secrets-check                                       # PASS
tools/check_ports.sh --strict                            # STRICT PASS
# live e2e: bash /tmp/avatar_e2e.sh
```
