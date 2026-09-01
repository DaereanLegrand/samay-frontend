# 2026-09-01 — Dare image: preview + storage insert-policy column-shadow 403

## What was built

- **Dare image preview** (`truth_dare_screen.dart`): the picked image now
  renders via `Image.file(File(path))` inside a `ClipRRect` card — previously
  only the filename showed. Matches the app-wide picked-image convention
  (create_group_screen / create_event_screen). The remove (×) control and the
  submit path (reads the `XFile` bytes) are unchanged.
- **Storage insert-policy fix** (`950_storage/storage_buckets_privileged.sql`
  + byte-identical supabase-testing mirror): `storage_objects_minigame_images_insert`
  previously referenced the UNQUALIFIED `name` in its session-exists subquery.
  Inside the subquery that `name` resolved to the correlated
  `minigame_sessions.name` column (the partida-name column — NULL/empty for
  most sessions) instead of `storage.objects.name` (the object path).
  `storage.foldername('')` → `{""}` → `''::uuid` cast fails → policy false →
  **every dare-with-image upload 403'd** ("new row violates row-level security
  policy"). Now qualified to `storage.foldername(storage.objects.name)`.
- **pgTAP** (`schema_test.sql` + mirror): new assertion (plan 880 → 881) pins
  the qualification — reads `with_check` (INSERT policies store the predicate
  in `with_check`, not `qual`) and regex-matches the deparsed
  `storage.foldername((storage\.)?objects\.name)` (Postgres deparses
  `storage.objects.name` to `objects.name`). All 881 pass against the reset
  testing stack.

## Decisions

- Per user directive: **modify the migrations and run `make supabase-testing-reset`**
  to deploy — the reset rebuilds the testing stack and re-applies the
  privileged tier via `docker exec supabase_admin` (the only role that can
  attach storage.objects policies). Verified the deployed policy in the live
  testing DB reads `storage.foldername(objects.name)`.
- Preview follows the existing `Image.file` convention — no new dependency
  (`dart:io` was the only added import).

## MISTAKE blocks

**MISTAKE: column shadowing in a policy subquery.** `minigame_sessions.name`
(shadowed) vs `storage.objects.name` (intended). The SELECT policy was fine
because it used the qualified `a.image_storage_path = storage.objects.name`;
the INSERT policy dropped the qualification. Lesson: ALWAYS fully qualify the
object-path column inside storage.objects policy subqueries — the subquery's
tables correlate and shadow the outer table's columns.

**MISTAKE: writing the pgTAP assertion against `qual`, not `with_check`.**
For an INSERT policy the predicate lives in `with_check`; `qual` is NULL, so
the first assertion returned NULL and failed. Also, Postgres deparses
`storage.objects.name` as `objects.name`, so a literal `LIKE '%storage.objects.name%'`
pattern never matches — the regex `storage\.foldername\((storage\.)?objects\.name\)`
accepts both forms.

## Pre-existing (report-only, not fixed)

- **`SUPABASE_SERVICE_ROLE_KEY=` is empty in the root `.env`** (line 6). The
  Makefile `load-env` sources root `.env`, so kong starts with
  `SERVICE_ROLE_KEY=` empty → the service-role JWT is Unauthorized → every
  opt-test that uses SERVICE_KEY cascades into "invalid input syntax for type
  uuid: ''" (empty session ids). opt-007 flags this exact mismatch. The pgTAP
  suite runs as `postgres` directly and is unaffected. To fix: populate
  `SUPABASE_SERVICE_ROLE_KEY` in `.env` (or load it before
  `supabase-testing-reset`) and re-run the reset. NOT part of this change.

## Commands

```bash
make supabase-testing-reset          # rebuild + apply migrations (41 files), seed
# deployed policy now reads storage.foldername(objects.name)
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS pgtap SCHEMA public;"
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql  # 881/881
dart analyze                         # clean
flutter build apk --debug            # builds
bash test/opt-005-seeds-static.sh    # PASS (45)
bash test/opt-007-compose-static.sh  # pre-existing SERVICE_KEY mismatch (env)
```

On-device verification still to run: pick a dare image → it previews; submit →
no 403, answer streams, other device decrypts the image.
