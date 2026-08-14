# M-08 — Storage buckets + storage.objects RLS (S-09/M-track gap closure)

## Date: 2026-08-10

## Role
Modification agent M-08 (storage track, Phase 4.3) — close the bucket-creation
gap: no `storage.buckets` migration existed anywhere; `events`/`groups`/
`avatars` were provisioned out-of-band (dashboard/CLI), so `event_photos`
INSERT + `uploadBinary` failed with 404/PGRST until the bucket existed (flagged
by I-36, I-59, TODO.md:893-894, SECURITY.md §2.5/G-12, EF-03). STATIC
verification only — no docker, no live stack, no commits, Juega untouched
(AGENT-RULES §0.2-0.4). Sole agent running; all locks acquired instantly.

## Mandatory repo read (AGENT-RULES §0.1, no shortcuts)

- All 24 migrations (20260510000001 → 20260809000006) — verified NO
  `storage.*` references anywhere (grep: only config.toml `[storage.*]`
  sections matched).
- `seed.sql` + `seed-dev.sql`; `supabase-testing/` full tree (migrations
  byte-identical, seed files byte-identical, scripts parity per M-10).
- `lib/core/services/media_service.dart` (all 3 buckets + signed URLs),
  `lib/features/photos/` (SignedUrlCache, gallery, upload pipeline).
- `test/opt-007-compose-static.sh` (810 lines — storage/pgTAP untouched by
  design: the mission keeps the gate = pgTAP plan recount + mirror cmp +
  policy-name grep, NOT a compose-test edit).
- docs: AGENTS.md, AGENT-RULES.md, FILE-OWNERSHIP.md, ORCHESTRATION refs,
  SELFHOSTING.md (storage §2 + §3.2 pgTAP), SECURITY.md (§2.5 + G-12),
  TODO.md (I-36/I-59 handoff blocks), SECU-rls-policies.md §Storage Bucket
  Policies, development logs I-36, I-59, I-77 (plan-recount method), D-04,
  M-07 (services), cross-references refs.

## Research (verified, cited in the migration header)

1. **Storage schema** — `storage.buckets`/`storage.objects` come from the
   storage-api tenant migrations baked into the pinned supabase/postgres image
   (storage-api **v1.60.4**): 0002 creates both tables + enables
   `storage.objects` RLS; 0007 enables `storage.buckets` RLS; 0008 adds
   `buckets.public boolean default false`; 0018 adds **`owner_id` (text)** and
   deprecates `owner` (uuid); 0015 adds `can_insert_object` (upload
   pre-check). All present at `supabase/storage` tag `v1.60.4` (verified via
   the tag's migrations/tenant tree).
2. **Signed-URL issuance does NOT bypass RLS** (mission claim verified FALSE):
   `src/storage/object.ts` `signObjectUrl` first runs
   `await this.findObject(objectName)` through the caller's RLS-scoped DB
   session (`routes/object/index.ts` registers signing under the
   `registerJwtAuth` + `db` group). A zero-policy events bucket → `createSignedUrl`
   fails "object not found" even for authorized users. Fix: the events SELECT
   policy below.
3. **Signed-URL retrieval DOES bypass RLS** (claim verified TRUE):
   `src/http/routes/object/getSignedObject.ts` requires NO JWT — the signed
   token IS the authorization (verifyJWT + `url === path`), and the object
   read runs `request.storage.asSuperUser()` (BYPASSRLS).
4. **uploadBinary**: `can_insert_object` (0015) probes the INSERT policy with
   a dummy row whose owner is the JWT sub → own-row INSERT policy must pass
   for the uploader.
5. **Official policy patterns** (supabase.com/docs/guides/storage/security/
   access-control): own-row `(select auth.jwt()->>'sub') = owner_id`;
   bucket scoping `bucket_id = 'avatars'`; public-bucket note: reads via
   public URLs need no objects policy (getPublicObject runs super-user), but a
   SELECT policy is what enables listing/signing/getInfo — added for
   avatars/groups to match the public-read model.

## What was built

1. **`supabase/migrations/20260810000007_storage_buckets.sql`** (Migration 24
   of 24) + byte-identical `supabase-testing/` mirror:
   - **Buckets** (idempotent, `ON CONFLICT (id) DO NOTHING`): `avatars`
     public=true, `groups` public=true, `events` public=false (private — PHUP
     signed-URL retrieval only). Explicit `file_size_limit`/`allowed_mime_types`
     NULLs for schema-shape stability.
   - **`ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY`** — defensive
     no-op (0002 already enables it).
   - **5 policies** (`DROP POLICY IF EXISTS` + `CREATE` = idempotent, repo
     pattern from 20260512000008):
     | Policy | Command/roles | Predicate |
     |---|---|---|
     | `storage_objects_public_read_avatars_groups` | SELECT, all roles | `bucket_id IN ('avatars','groups')` |
     | `storage_objects_events_select_access` | SELECT, authenticated | `bucket_id='events' AND EXISTS (event_photos ep WHERE ep.storage_path = objects.name)` — event access transitively via eph_read_access (FORCE-RLS applies in subqueries) |
     | `storage_objects_insert_own` | INSERT, authenticated | 3 buckets + `owner_id = auth.jwt()->>'sub'` + avatars path prefix `(storage.foldername(name))[1] = sub` (SECU spec) |
     | `storage_objects_update_own` | UPDATE, authenticated | own row + bucket scope, WITH CHECK re-asserts |
     | `storage_objects_delete_own` | DELETE, authenticated | own row + bucket scope |
   - **SECURITY NOTES header** covering signed-URL issuance/retrieval,
     uploadBinary paths, owner_id column verification, event-cover warning.
2. **pgTAP Section 47** in BOTH `schema_test.sql` files (byte-identical):
   header "24 → 25 migrations", `plan(304)` → **`plan(312)`**:
   - 47a `has_table('storage','buckets'/'objects')` (2)
   - 47b `results_eq` bucket ids + `ok()` public-flag ×3 (avatars/groups true,
     events false) (4)
   - 47c objects `relrowsecurity` + `policies_are` with the 5 exact policy
     names (2)
   - **Recount exact**: 318 `^\s*SELECT ` lines − 1 plan − 1 finish − 4
     nested (l.422/801/1008/1017 — the Section-47 subqueries are parenthesized
     inline and do NOT start with SELECT) = **312 = plan(312)**.
     MISTAKE (caught before mirroring): first draft planned 308
     (310+8−2) — arithmetic error; the storage subqueries don't match the
     `^\s*SELECT ` pattern, so the true delta is +8 tests / +0 counted nested.
3. **Docs**:
   - `docs/to-fix/TODO.md` — "Storage bucket workstream (M-08)" blockquote at
     the top of the tracking list; S-09 gap row context updated.
   - `<private-ops-repo>/SELFHOSTING.md` — storage §: bucket+policies bullet under
     "Storage: S3 vs local file backend"; §3.2 pgTAP stale counts (129 → 312
     assertions / "Ran 312 tests").
   - `docs/security/SECURITY.md` — §2.5 table rows rewritten (bucket rows +
     policies ✅ M-08; signed-URL/RLS interplay verified + handoff stays S-09;
     event-cover finding); G-12 row 🟠 → ✅ with remaining S-09/S-10 items.
   - This daily log.

## Files modified (lock evidence — `--owner M-08-storage`)

| File | Change | Lock |
|---|---|---|
| `supabase/migrations/20260810000007_storage_buckets.sql` | new (buckets + 5 policies + SECURITY NOTES) | `16433474e90168ef24a3eb18` |
| `supabase-testing/migrations/20260810000007_storage_buckets.sql` | new (byte-identical mirror) | `0c9536fe0c02b2bc0200bb34` |
| `supabase/tests/schema_test.sql` | Section 47, header, plan 304→312 | `a43b237c31f9fc558029d8b6` |
| `supabase-testing/tests/schema_test.sql` | byte-identical mirror | `c713b08b989954b6ea3afb3f` |
| `docs/to-fix/TODO.md` | M-08 workstream blockquote | `b802f899fb97030c6d655fd5` |
| `<private-ops-repo>/SELFHOSTING.md` | storage bullet + pgTAP counts | `a00c2a0c357f5decd7b07b6d` |
| `docs/security/SECURITY.md` | §2.5 rows + G-12 status | `f1c906c818995fb9795f08f7` |
| `docs/history/phase-00-foundation/2026-08-10_M08-storage-buckets.md` | this log | `162a25dfa8d8c95951eadd12` |

All 8 acquired instantly (sole agent), all released by owner after edits.

## Commands run (static verification, no docker)

```bash
export AGENT_NAME=M-08-storage
tools/agent_lock.sh acquire <8 files> --owner $AGENT_NAME --timeout 60   # all instant
cp supabase/migrations/20260810000007_storage_buckets.sql supabase-testing/migrations/ && cmp  # BYTE-IDENTICAL
cp supabase/tests/schema_test.sql supabase-testing/tests/schema_test.sql && cmp               # BYTE-IDENTICAL
rg -c '^\s*SELECT ' supabase/tests/schema_test.sql   # 318 → 318−1−1−4 = 312 == plan(312)
rg -n 'storage_objects_(public_read_avatars_groups|events_select_access|insert_own|update_own|delete_own)' \
    supabase/migrations/20260810000007_storage_buckets.sql   # 5 CREATE POLICY + 5 DROP POLICY hits
rg -n "('avatars', 'groups', 'events'|avatars|groups|events)" supabase/migrations/20260810000007_storage_buckets.sql
tools/agent_lock.sh release <8 files> --owner $AGENT_NAME
```

## Static verification results

- [x] **Recount exact BEFORE and AFTER** (310→318 lines; 4 nested unchanged;
      318−1−1−4 = **312 = plan(312)**) in both schema_test files.
- [x] **Both schema_test.sql byte-identical** (`cmp`) and **both new
      migrations byte-identical** (`cmp`).
- [x] **Policy/bucket names grep-verified** vs the migration text: 5 ×
      `CREATE POLICY` names match the `policies_are` array exactly;
      `storage.buckets` INSERT carries the 3 ids + public flags (2×true, 1×false).
- [x] **owner_id column verified against storage-api v1.60.4 source**: tenant
      migration `0018-add_owner_id_column_deprecate_owner.sql` (present in the
      v1.60.4 tag) adds `storage.objects.owner_id text`; `owner` deprecated.
      Policies use `owner_id` = `auth.jwt()->>'sub'` (official docs pattern).
- [x] **Signed-URL claim verified (and corrected)** against v1.60.4 source:
      issuance RLS-scoped (`object.ts signObjectUrl` → `findObject`),
      retrieval super-user (`getSignedObject.ts` `asSuperUser()`).
- [x] Locks: 8 acquired + released by owner (evidence above).
- [x] No docker started; no commits; Juega untouched; no Juega ports touched.

## Decisions made and why

- **Events SELECT policy exists (mission deviation, evidence-driven).** The
  mission brief said "NO policy for events bucket reads… signed URLs are
  issued server-side by storage-api, which uses service-role and bypasses RLS
  for URL signing — verify this claim". Verification disproved the mechanism:
  `signObjectUrl` (v1.60.4 `src/storage/object.ts`) calls
  `await this.findObject(objectName)` under the caller's RLS session, so with
  zero SELECT policy the app's `MediaService.getSignedPhotoUrl` (createSignedUrl)
  would fail for every photo. `storage_objects_events_select_access` is the
  minimal fix: it is NOT public (authenticated only) and NOT broad (gated on
  the `event_photos` row being visible under `eph_read_access`, which already
  encodes the canonical event-access predicate — public event / group member /
  invitee / promotor). RLS applies inside policy subqueries, so the policy
  reuses eph_read_access without duplicating it; recursion-safe (terminal
  checks + is_group_member SECURITY DEFINER; nothing re-enters storage.objects).
- **`owner_id` over `owner`**: verified column reality (0018) rather than the
  mission's guessed "owner_id = auth.uid()" — and text-to-text
  (`auth.jwt()->>'sub'`) rather than uuid cast, matching how storage-api
  writes the column and the official docs example.
- **Avatars path-prefix INSERT rule**: SECU-rls-policies.md requires "path
  must contain user ID"; the app writes `avatars/<userId>/…`. Folded into the
  INSERT policy (`bucket_id <> 'avatars' OR foldername[1] = sub`).
- **No `storage.buckets` RLS policies**: buckets RLS is enabled (0007) with
  no policies; the app never queries storage.buckets via PostgREST; adding
  policies would be gold-plating.
- **No opt-007 / opt-005 edits** (mission decision): the gate is pgTAP plan
  recount + mirror cmp + policy-name grep — compose tests are not storage
  tests.
- **No seed changes**: buckets are schema, not seed data (SUP-04: seeds hold
  admin_users + app_config only).

## MISTAKE / gotcha

- **Plan-count arithmetic error (caught before mirroring):** first plan value
  was 308 (I applied I-77's "+8 tests" but forgot their nested subqueries do
  NOT start with `SELECT`, so the +4 nested guess was wrong both ways — the
  real delta is 8 top-level lines, 0 counted nested; plan must be 312, i.e.
  318−1−1−4). The mirror `cmp` + recount step caught it. Verify the plan by
  recounting AFTER writing, never by delta arithmetic alone.
- **Gotcha (storage-api semantics):** `getPublicObject` (public-URL reads)
  runs in the super-user route group → for a `public=true` bucket, objects are
  downloadable WITHOUT any objects policy; for `public=false` (events) the
  public URL serves nothing even to authorized users — that is exactly the
  model the mission wants, and exactly why `uploadEventCover`'s `getPublicUrl`
  return value is a bug (reported, not fixed).

## Deferred / handoffs

1. **S-09 — event-cover serving (real, app-breaking if ECRT covers ship):**
   `MediaService.uploadEventCover` (media_service.dart:45-51) uploads into the
   PRIVATE `events` bucket and returns `getPublicUrl` — non-servable for
   public=false. Fix options: move covers to the `groups` bucket, or serve via
   `createSignedUrl` (needs cover_url consumers to resolve a URL before
   render). ECRT follow-up.
2. **S-09 — server-side signing stays absent:** the app still calls
   `createSignedUrl` client-side (works now: authenticated + events SELECT
   policy). If the product wants signing gated server-side (Edge Function /
   RPC with service_role), that requires EEDG (blocked) + an app change.
3. **S-09/S-10 — signed-URL generation rate limiting** (SECURITY.md plan item;
   SECU spec): unchanged, open.
4. **S-03 — `eph_insert_own` upload-window check** (I-59 issue #3): unchanged,
   still a candidate; the events INSERT storage policy mirrors only
   own-row-ness (window enforcement would need a policy on `events.ends_at` —
   storage.objects policies cannot join that today without an objects-side
   denormalization).
5. **Chats/cosmetics buckets** (SECU-rls-policies.md lists them as future
   buckets): NOT created — the app has no chat-media/cosmetics upload paths
   yet; they get migrations when the features land.

## Sources consulted

- supabase/storage @ v1.60.4 migrations/tenant — 0002-storage-schema.sql
  (objects/buckets DDL + objects RLS), 0007-add-rls-to-buckets.sql,
  0008-add-public-to-buckets.sql, 0015-add-can-insert-object-function.sql,
  0017-drop-owner-foreign-key.sql, 0018-add_owner_id_column_deprecate_owner.sql
  (`owner_id` text): https://github.com/supabase/storage/tree/v1.60.4/migrations/tenant
- storage-api v1.60.4 routes — `src/http/routes/object/index.ts` (signing =
  authenticated+db group; signed GET = dbSuperUser group),
  `getSignedURL.ts`, `getSignedObject.ts` (asSuperUser + token auth),
  `src/storage/object.ts` (`signObjectUrl` → `findObject`), `src/storage/storage.ts`.
- Supabase Storage access-control docs (policy examples, own-row owner_id,
  public-bucket note): https://supabase.com/docs/guides/storage/security/access-control
- pgTAP docs (has_table schema form, results_eq, policies_are):
  https://pgtap.org/documentation.html
- Repo docs: SECU-rls-policies.md §Storage Bucket Policies, SELFHOSTING.md §2/§3,
  I-36/I-59/I-77 daily logs, TODO.md:893-894, SECURITY.md §2.5/G-12.
