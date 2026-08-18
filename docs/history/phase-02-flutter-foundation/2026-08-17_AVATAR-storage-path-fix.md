# AVATAR — avatar upload storage-path fix: RLS 42501 on every upload (2026-08-17)

Agent: `AVATAR-PATH-FIX` · Phase 02 (flutter foundation) · No commits (working tree only).

## What was built

Fixed the avatar-upload 42501 (`storage_objects_insert_own` RLS denial) by correcting the
storage object path built in `MediaService.uploadUserAvatar`.

- `lib/core/services/media_service.dart`: `uploadUserAvatar` now builds
  `'$userId/${DateTime.now().millisecondsSinceEpoch}.png'` (relative to the `avatars`
  bucket) instead of the redundant `'avatars/$userId/…png'`. Doc comment corrected to
  `<userId>/<timestamp>.png`, noting the RLS first-segment rule.
- `test/services/media_service_test.dart` (`MediaService.uploadUserAvatar` group): 5
  assertions updated to the correct contract — upload path must start `user-1/`/`user-A/`/
  `user-B/` (NOT `avatars/user-1/`…), returned URL must be `https://cdn.example/avatars/
  user-1/…`. Test-only change; no test logic altered.
- `supabase/migrations/20260810000007_storage_buckets.sql` + `supabase-testing/migrations/
  20260810000007_storage_buckets.sql`: comment only — the `storage_objects_insert_own`
  header now reads "(MediaService uploadUserAvatar writes `<userId>/…`)". Both files
  remain byte-identical (`diff` clean).

`uploadGroupCover` / `uploadEventCover` untouched — their `groups`-bucket paths
(`group_covers/…`, `event_covers/…`) are unrelated to the `avatars` first-segment rule.

## Root-cause chain

1. `uploadUserAvatar` wrote `avatars/<uid>/<ts>.png` via
   `client.storage.from('avatars').uploadBinary(path, …)`.
2. Storage API treats the path as **relative to the bucket**, so the object key became
   `avatars/<uid>/<ts>.png` — with a redundant `avatars/` first segment.
3. RLS INSERT policy `storage_objects_insert_own` (migration 20260810000007, both stacks)
   requires `(storage.foldername(name))[1] = auth.jwt()->>'sub'` for the `avatars` bucket.
   `storage.foldername('avatars/<uid>/<ts>.png')` = `{avatars, <uid>}` → `[1]` = `'avatars'`
   ≠ sub → **42501** on every avatar upload.
4. Live evidence: storage-api logs 2026-08-18T01:50/01:55Z, Android and iOS.
5. Intended layout (per SECURITY.md §2.5): `<userId>/<ts>.png` inside the `avatars` bucket.
6. Fix: drop the redundant segment. No migration needed — the RLS policy is correct.

## Decisions made and why

- **Client path, not the policy, is the fix** — the policy encodes the security requirement
  (first segment = caller sub; verified by the live denial); the client violated it.
- **Test contract encoded in assertions** — the test file's public-URL stub builds
  `'https://cdn.example/avatars/<path>'`, so a correct path yields
  `https://cdn.example/avatars/<uid>/…` — the assertions now pin exactly that.
- **Comment parity kept** — both migration copies got the identical comment edit so the
  byte-identical pair invariant (opt-007 gate) survives.

## MISTAKE — wrong avatar path shipped because tests mocked the seam + docs encoded it

The bug shipped because the upload-seam stub (`fileApi.uploadBinary`) returns the path
argument unchanged, so the group asserted the *wrong* shape (`avatars/user-1/…`) and went
green — the mock cannot tell the client the server's RLS would reject the object key. The
wrong shape was also written into the migration comment and the method doc (both claimed
`avatars/<userId>/…`), so the error was encoded in three places. Rule for future avatar /
RLS-segment-adjacent work: the FIRST path segment of any object written to the `avatars`
bucket must be the owner's id — mock-based tests cannot prove this; verify the expected key
shape against the policy (or a live stack) before shipping.

## Commands run

```bash
# RED — assertions updated first, then run to prove the path-shape failure
flutter test test/services/media_service_test.dart
#   → 3 FAILURES (5 assertion sites; each failing expect aborts its test):
#     Expected: a string starting with 'https://cdn.example/avatars/user-1/'
#       Actual: 'https://cdn.example/avatars/avatars/user-1/1787022921794.png'
#     Expected: a string starting with 'https://cdn.example/avatars/user-1/'   (line 214)
#       Actual: 'https://cdn.example/avatars/avatars/user-1/1787022921841.png'
#     Expected: a string starting with 'user-A/'
#       Actual: 'avatars/user-A/1787022921855.png'
#   (assertions 181/231 fail identically, not reached because the earlier expect throws)

# GREEN — path + doc fix
flutter test test/services/media_service_test.dart
#   → 18/18 pass

# REFACTOR — identical comment edit in both migration copies
diff -r supabase/migrations/20260810000007_storage_buckets.sql \
        supabase-testing/migrations/20260810000007_storage_buckets.sql
#   → clean (byte-identical)

# VALIDATE (focused only — full suite reserved for the orchestrator)
flutter test test/features/profile/avatar_flow_test.dart      # 6/6 pass (mocks uploadUserAvatar)
dart analyze lib/core/services/media_service.dart test/services/media_service_test.dart
#   → No issues found
```

Full suite deliberately NOT run (per assignment; concurrent agents).