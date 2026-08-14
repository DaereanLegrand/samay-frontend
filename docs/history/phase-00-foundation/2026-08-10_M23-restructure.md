# 2026-08-10 — M-23: ARC-01/H-13 feature-directory restructure (flat → screens/ providers/ widgets/ logic/)

**Agent:** M-23 (Phase 4.3 — code-structure track; sole agent this run)
**Role:** move every file in `lib/features/**` into per-feature subdirectories
(`screens/` `providers/` `widgets/` `logic/`), rewriting ALL imports in `lib/`,
`test/`, `integration_test/`, keeping the 1624-test suite green. Highest-risk
change of the campaign: mechanical `git mv` + import rewrites only, no content
changes; `dart analyze` must stay 0 issues after EVERY feature; full
`flutter test` (1624/0) at the end.
**Campaign:** Samay 180-agent orchestration; Juega untouched (read-only), NO
commits, NO docker, NO network ops.

---

## PLAN — mapping table (written FIRST, before any code)

### Target layout convention

Per feature dir `lib/features/<f>/`, files move by PRIMARY ROLE:

| Role | Target subdir | Matching rule |
|---|---|---|
| Full screen/page | `screens/` | `*_screen.dart` |
| State/logic provider | `providers/` | `*_provider(s).dart` |
| Presentation widget (incl. route-wrapper widgets) | `widgets/` | contains a `Widget` class, not a full screen |
| Pure domain logic (policies, formatters, enums, value objects, catalogs) | `logic/` | no widgets, no providers, no full screens |

Cross-cutting code stays where the campaign already settled it (documented in
this table so every move is accounted for):

| Layer | Location | Decision source |
|---|---|---|
| Feature services | `lib/core/services/` | I-11 (2026-08-09) — do NOT move |
| Models | `lib/core/models/` (freezed) | I-10 — do NOT move |
| Cross-cutting providers | `lib/core/providers/` | auth, config, user, theme, connectivity, realtime, paged, service_providers — keep (cross-cutting) |

### Per-feature mapping (58 files, 15 features)

| Feature | File | → Target | Count |
|---|---|---|---|
| **auth** | welcome, login, signup_contact, otp_verification, age_gate, privacy_terms, profile_setup, banned — `*_screen.dart` | `auth/screens/` | 8 |
| **auth** | age_policy.dart, password_policy.dart | `auth/logic/` | 2 |
| **chat** | chat_screen.dart · chat_providers.dart | `chat/screens/` · `chat/providers/` | 2 |
| **cosmetics** | cosmetics_shop_screen.dart · cosmetics_providers.dart | `cosmetics/screens/` · `cosmetics/providers/` | 2 |
| **events** | create_event, event_detail, event_edit — `*_screen.dart` | `events/screens/` | 3 |
| **events** | events_providers.dart | `events/providers/` | 1 |
| **events** | event_invite_route.dart (route-wrapper ConsumerWidget) | `events/widgets/` | 1 |
| **events** | event_form_data.dart, event_formatters.dart | `events/logic/` | 2 |
| **feed** | feed_screen.dart · feed_providers.dart | `feed/screens/` · `feed/providers/` | 2 |
| **friends** | friends_list, search, requests, blocked_users — `*_screen.dart` | `friends/screens/` | 4 |
| **friends** | friends_providers.dart | `friends/providers/` | 1 |
| **groups** | my_groups, create_group, group_detail, group_members, invite, leaderboard, donate_shards — `*_screen.dart` | `groups/screens/` | 7 |
| **groups** | groups_providers.dart | `groups/providers/` | 1 |
| **minigames** | minigames_screen.dart · minigames_providers.dart | `minigames/screens/` · `minigames/providers/` | 2 |
| **notifications** | notification_center_screen.dart · notifications_providers.dart | `notifications/screens/` · `notifications/providers/` | 2 |
| **party_finder** | party_finder_screen.dart · party_finder_providers.dart | `party_finder/screens/` · `party_finder/providers/` | 2 |
| **photos** | photo_gallery_screen.dart · photos_providers.dart | `photos/screens/` · `photos/providers/` | 2 |
| **profile** | profile, edit_profile, public_profile, settings, delete_account — `*_screen.dart` | `profile/screens/` | 5 |
| **profile** | profile_providers.dart | `profile/providers/` | 1 |
| **profile** | interests.dart (mixed: `UserInterests` value object + `InterestTagPicker` widget; widget-first) | `profile/widgets/` | 1 |
| **qr** | attendance_qr, qr_scanner — `*_screen.dart` | `qr/screens/` | 2 |
| **qr** | qr_providers.dart | `qr/providers/` | 1 |
| **shards** | shard_ledger_screen.dart · shard_ledger_providers.dart | `shards/screens/` · `shards/providers/` | 2 |
| **shards** | shard_ledger_formatters.dart | `shards/logic/` | 1 |
| **subscriptions** | paywall_screen.dart (single-file feature → `screens/` minimum) | `subscriptions/screens/` | 1 |

Totals: **38 screens · 13 providers · 2 widgets · 5 logic = 58 files, 15 features.**
Subdirs created only where non-empty (all 4 subdir kinds exist somewhere; every
feature gets at least `screens/`).

### Execution order (per-feature, guardrail after each)

```
auth → profile → friends → groups → events → chat → qr → feed → photos →
notifications → minigames → party_finder → cosmetics → shards → subscriptions
```

After EVERY feature: `dart analyze` (must stay "No issues found") + that
feature's tests. Any move I cannot fix in 10 minutes → REVERT that feature's
move + document why (never leave the tree broken).

### Import-rewrite mechanics

- All imports are `package:samay/features/<f>/<file>.dart` (verified: zero
  relative imports, zero `part`/`part of` in features) → mechanical string
  replacement of the exact old path with the new path.
- Rewrite EVERY importer in `lib/` + `test/` + `integration_test/` (83 files
  import `package:samay/features/` today) — inside the moved files themselves
  (cross-feature imports) and in every test/integration file.
- Locks: acquire the TARGET path before each `git mv` (lock hashes paths);
  acquire every file being import-edited before editing. Release all after.

### Test/guard updates

- `test/structure_test.dart` (EF-01's file — locked): does NOT assert the old
  flat layout (verified: only dir-existence + dynamic no-empty-dir invariant).
  STRENGTHEN: add a feature-sublayers group — every `lib/features/<f>/` must
  contain a `screens/` subdir with ≥1 `.dart` file (documents the new layout,
  keeps the dynamic invariant intact).
- `test/meta/conventions_test.dart` (I-48's guard — locked): guard (c) is
  recursive (`_screen`/`_provider` regex over all files under the feature) →
  still passes post-move. STRENGTHEN: add ARC-01 invariant — no `.dart` file
  directly in a feature dir ROOT (every feature file lives in a subdir).
- `docs/process/FILE-OWNERSHIP.md` (locked): update the M-23 row + the phase-4.2
  path table entries that name `lib/features/<f>/<file>.dart` → new paths.
- `docs/process/DEVELOPMENT-WORKFLOW.md` §5 refactorability table (locked):
  "Feature-first dirs" row — "later M-23 splits" → landed layout.
- `docs/to-fix/TODO.md` (locked): add the M-23 workstream block (M-21/M-22
  precedent). ARC-01 status flip in `docs/to-fix/categories/00-ARCHITECTURE.md`
  stays D-03's (M-18/M-20/M-21 precedent).

### Not moved / not touched (documented decisions)

- `lib/core/providers/` keeps auth, config, user, theme, connectivity,
  realtime, paged, service_providers — cross-cutting by design.
- Feature services stay in `lib/core/services/` (I-11 decision).
- `lib/features/**/widgets` may stay empty in most features (create only if
  non-empty).
- SQL migration comments referencing `lib/features/...` paths stay untouched
  (historical records applied to DBs; noted as handoff).

---

## Commands run (reproducibility)

```bash
export AGENT_NAME="M-23-restructure"
tools/agent_lock.sh acquire <target-path> --owner "$AGENT_NAME" --timeout 300
git mv lib/features/<f>/<file>.dart lib/features/<f>/<subdir>/<file>.dart
# import rewrite under per-file locks (all importers in lib/ test/ integration_test/)
dart analyze
flutter test test/features/<f>/ test/features/<f>_screens_test.dart ...
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"
```

(Execution log + final mapping summary + reverts appended below after the run.)

---

## EXECUTION LOG (all 15 features, guardrail after each)

| # | Feature | Moved | Importers rewritten | `dart analyze` | Feature tests |
|---|---|---|---|---|---|
| 1 | auth | 8 screens + 2 logic | 14 | 0 issues | 130 pass (auth + app_router) |
| 2 | profile | 5 screens + 1 providers + 1 widgets | 23 | 0 issues | 43 pass (profile + profile_providers) |
| 3 | friends | 4 screens + 1 providers | 10 | 0 issues | 48 pass |
| 4 | groups | 7 screens + 1 providers | 13 | 0 issues | 109 pass |
| 5 | events | 3 screens + 1 providers + 1 widgets + 2 logic | 20 | 0 issues | 119 pass |
| 6 | chat | 1 screens + 1 providers | 7 | 0 issues | — (batched below) |
| 7 | qr | 2 screens + 1 providers | 7 | 0 issues | — (batched below) |
| 8 | feed | 1 screens + 1 providers | 7 | 0 issues | — (batched below) |
| 9 | photos | 1 screens + 1 providers | 5 | 0 issues | 170 pass / 2 pre-existing (chat+qr+feed+photos+events) |
| 10 | notifications | 1 screens + 1 providers | 5 | 0 issues | — (batched below) |
| 11 | minigames | 1 screens + 1 providers | 6 | 0 issues | — (batched below) |
| 12 | party_finder | 1 screens + 1 providers | 6 | 0 issues | — (batched below) |
| 13 | cosmetics | 1 screens + 1 providers | 6 | 0 issues | — (batched below) |
| 14 | shards | 1 screens + 1 providers + 1 logic | 6 | 0 issues | — (batched below) |
| 15 | subscriptions | 1 screens | 4 | 0 issues | 143 pass / 2 pre-existing (remaining features) |

Total: **58 files moved, 15 features; every `dart analyze` after each feature = 0 issues.**

### Fixes required during the run (none were reverts)

- **`test/perf/list_view_builder_test.dart` (PERF-01/H-27 allowlist):** its
  `_justifiedFixedLists` map hardcoded the 9 old flat feature paths → the guard
  flagged all 9 moved screens as "unjustified" and its stale-entry check would
  have flagged the old keys. Fixed by updating the 9 keys to the new
  `screens/` paths (justifications unchanged — content untouched).
- **Empty subdirs:** the move script pre-creates `screens/ providers/ widgets/
  logic/` per feature; after all moves, 27 empty subdirs were deleted so only
  non-empty subdirs exist (mission rule).

### Guard/doc updates (all locked, all green)

| File | Change | Owner | Result |
|---|---|---|---|
| `test/structure_test.dart` | new group `feature sublayers (ARC-01, M-23)`: every `lib/features/<f>/` has a `screens/` subdir with ≥1 `.dart` | EF-01's (locked) | 30/30 guard tests pass |
| `test/meta/conventions_test.dart` | new test `ARC-01: no .dart files directly in a feature dir root` | I-48's (locked) | included above |
| `test/perf/list_view_builder_test.dart` | 9 allowlist keys → new subdir paths | (guard fix, own) | 2/2 pass |
| `docs/process/FILE-OWNERSHIP.md` | M-23 row → DONE + new convention; 14 I-agent path rows → subdir paths | orchestrator-owned (locked per mission) | — |
| `docs/process/DEVELOPMENT-WORKFLOW.md` | §5 feature-first-dirs row → landed subdir layout | D-09's (locked per mission) | — |
| `docs/to-fix/TODO.md` | M-23 workstream block (ARC-01 ✅, layout, guards, pre-existing-failure handoff) | (M-21/M-22 precedent) | — |

Not changed (documented decisions): `lib/core/providers/` keeps the 8
cross-cutting providers; feature services stay in `lib/core/services/`
(I-11); models stay in `lib/core/models/` (I-10); ARC-01 status flip in
`docs/to-fix/categories/00-ARCHITECTURE.md` left to D-03 (M-18/M-20/M-21
precedent); SQL migration comments referencing old feature paths left
untouched (historical, applied to DBs — reported as handoff).

## FINAL VERIFICATION (gate)

- [x] `dart analyze` — **No issues found** (0 errors, 0 warnings, 0 infos) —
      run after EVERY feature and at the end.
- [x] Full `flutter test` — **1622 pass / 4 fail**. The 4 failures are the
      two SQL-plan-consistency tests ×2 suites (`qr_rpc_migration_test.dart`,
      `minigame_rpc_migration_test.dart`) — **proven pre-existing** in the
      shared working tree (see Issues below), NOT caused by this restructure:
      both test files are untouched by M-23 (`git status` clean) and parse
      only the two `schema_test.sql` files (mtime 2026-08-10 16:24 — M-08's
      uncommitted session, before M-23 started ~22:40). Suite total went
      1624 → **1626** (+2 new guard tests). Zero failures attributable to
      M-23; on the committed baseline this restructure is 1626/0.
- [x] `go test ./...` — unaffected, all packages ok (cached/clean).
- [x] Hermetic integration flow spot-check: `flutter test
      integration_test/auth_flow_test.dart` — 3/3 pass (all 15 flow files
      import-rewritten; `dart analyze` proves they compile).
- [x] `git status` — **58 renames** (pure `R` or `RM`) + import-only
      modifications; diff-checks of `event_detail_screen.dart`,
      `groups_screens_test.dart`, `user_service.dart`, `app_router.dart`
      show ONLY import-path changes (mechanical).
- [x] `tools/agent_lock.sh list` at session end — no locks held.
- [x] No commits; no `git add`; Juega untouched (read-only); no docker; no
      network ops.

## Lock evidence

Owner `M-23-restructure`. Every moved file: lock acquired on the NEW path
before `git mv`, released after (58×). Every import-rewritten file: lock
acquired before `sed`, released after (139 importer-lock pairs across the 15
features — the `m23_move.sh` log printed each ACQUIRED/RELEASED pair;
guard/doc files: structure_test, conventions_test, list_view_builder_test,
FILE-OWNERSHIP.md, DEVELOPMENT-WORKFLOW.md, TODO.md — all acquire→edit→release,
verified via `tools/agent_lock.sh list` = empty at end).

## MISTAKE blocks

- **MISTAKE (script, low impact):** the first `sed` sweep for FILE-OWNERSHIP.md
  used a Python dict whose duplicate prefix keys silently deduped → two
  assertions failed before any write (file untouched); fixed with an ordered
  pair list + row-level replacements for the two rows with bare second
  filenames. No file was ever left half-written.
- **Gotcha (expected, handled):** `test/perf/list_view_builder_test.dart` is a
  path-keyed allowlist guard — any feature restructure MUST update it in
  lockstep (its stale-entry assertion would have failed on the old keys).
- **MISTAKE (pre-existing, NOT mine — surfaced by the full run):** the 4
  SQL-plan failures (see Issues) initially looked like a regression; proven
  otherwise via mtime + git status + diff before touching anything.

## Issues found / handoffs (M-24 and others)

1. **M-08/D-04 handoff (pre-existing failures in the shared tree):** M-08's
   UNCOMMITTED `supabase/tests/schema_test.sql` + `supabase-testing/tests/schema_test.sql`
   edits bump `plan(304)→plan(312)` (+8) but add **9** SELECT assertions
   (Section 47, storage buckets) → declared plan ≠ actual count → the 2
   plan-consistency tests ×2 suites fail (4 failures). Fix: sync the plan
   count in both SQL files (M-08 or D-04; do NOT do it in M-23's run — the
   file belongs to their uncommitted work).
2. **M-24 handoff:** `lib/core/**` restructure is next (constants/
   design_tokens/errors/extensions) — `lib/core/providers/` keeps the 8
   cross-cutting providers; the convention doc in FILE-OWNERSHIP.md M-23 row
   is the reference. Note: `lib/core/feature_flags.dart` is a single file at
   `lib/core/` root (sits next to the `config/` dir) — M-24 may want it
   under `lib/core/feature_flags/` (I-49 created it as a file).
3. **D-03/V-02 handoff:** flip ARC-01 in `docs/to-fix/categories/00-ARCHITECTURE.md`
   to ✅ DONE with the M-23 ref (precedent: M-18/M-20/M-21/M-22 left category
   flips to D-03).
4. **Cosmetic (reported, not fixed):** SQL migration comments referencing old
   `lib/features/...` paths (e.g. `20260724000001_fix_signup_tracker_rls.sql:13`,
   `20260809000004_users_discovery.sql:7-10`, `20260809000005_qr_validate_rpc.sql:12`,
   `20260809000002_rls_audit_fixes.sql:416`) are historical records — left
   untouched; future migration writers should use the new paths.
5. **Post-move convention (for future agents):** feature files go to
   `screens/ providers/ widgets/ logic/` (see FILE-OWNERSHIP.md M-23 row);
   `test/perf/list_view_builder_test.dart` allowlist keys must be updated in
   lockstep with any future feature-file move.
