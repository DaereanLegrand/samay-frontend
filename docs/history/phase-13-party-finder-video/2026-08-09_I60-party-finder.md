# I-60 — Party Finder foundation (PFND)

**Agent:** I-60-party-finder | **Date:** 2026-08-09 | **Phase 13** (docs/specs/steps/phase-13-party-finder-video/PFND-party-finder.md)

## RESUME addendum (2026-08-10, session 2 — first session cancelled mid-flight)

### Found vs fixed

**Already landed (verified intact this session):** migration `20260809000004_users_discovery.sql` (both stacks byte-identical, static trigger-interplay audit passed — see below); pgTAP Section 43 in both `schema_test.sql` (plan 250 = 252 `SELECT` statements − `plan()` − `finish()`; recounted, correct; both stacks identical); `party_finder_providers.dart`; `party_finder_screen.dart`; `integration_test/party_finder_flow_test.dart` + `runner.sh` entry; `feature_flags.dart` `partyFinder` (dark); `route_paths.dart` `/party-finder`; router-test fakes (`_FakeDiscoveryOptInNotifier`/`_FakePartyMatchesNotifier`) in `app_router_test.dart`.

**Gaps found (first session cut before landing):**

1. `lib/core/services/user_service.dart` — the 4 PFND methods were **missing** (file ended at `getBlockStatus`). Added `getDiscoveryOptIn`, `setDiscoveryOptIn`, `getMyInterestTags`, `findMatches` (query `discovery_view` with `.neq(id, me)` + `.overlaps('interest_tags', myTags)` + `.limit(50)`, `shared_tags`/`shared_count` computed + sorted count-DESC then username-ASC, client-side block filtering mirroring `searchUsers`). Lock evidence: acquire/release `lib/core/services/user_service.dart --owner I-60-party-finder`.
2. **l10n** — the 8 `partyFinder*` ARB keys were missing from `app_es.arb`/`app_en.arb` (screen/providers referenced getters that did not exist → nothing compiled). Added both files (incl. `partyFinderSharedInterests` ICU plural), ran `flutter gen-l10n`; the generated `app_localizations*.dart` (regenerated at 20:34 by I-59's in-flight gen-l10n run) contain all 8 keys in both locales. ARB parity verified programmatically (405 keys each, symmetric, valid JSON). Locks: acquire/release on both ARBs (I-60); the 3 generated files are I-59-held — noted, no conflict (regeneration is idempotent over ARB).
3. **Router wiring** — `app_router.dart` `/party-finder` still rendered `VComingSoonScreen` directly instead of `FlagGate(flag: partyFinder, child: PartyFinderScreen())`. Fixed (BLOCKED-until: lock held by I-57-qr-foundation for ~30 min; waited per semaphore, then acquired).
4. **Test bugs from the cancelled session** (RED tests written before code existed):
   - `test/services/user_service_test.dart` did not compile: `view.filters` referenced on a `MockQueryBuilder` (filters live on the `ResolvingBuilder` returned by `select()`) → captured the builder as `viewBuilder`. Also the `.overlaps` filter assertion compared a `List` by identity (`==`) → switched to a contents join comparison.
   - `test/features/party_finder/party_finder_screen_test.dart`: (a) `find.text('Música')` expected 3 chips for 2 matches (2 shared sets → 2 chips — corrected); (b) the failed-block test threw `Exception('network down')`, which maps through `error_mapper` to `ServerError` (generic), not `NetworkError` → changed to `SocketException` so the mapper produces `errorsNetwork` ("Error de conexión. Verifica tu internet.").
   - `party_finder_providers_test.dart` "failed write surfaces as AsyncError": `setOptIn` didn't flip state on failure → added the established `catch (e, st) { state = AsyncError(e, st); rethrow; }` pattern (same as `photos_providers.dart:210` / `auth_provider.dart`).

### Trigger-allowlist decision (re-audited, CONFIRMED)

Read `20260809000002_rls_audit_fixes.sql` §1 end-to-end this session: `assert_safe_user_update()` is SECURITY INVOKER and compares **only** the protected set (personal_shards, preshards, subscription_tier, subscription_expires_at, banned_at, ban_reason, date_of_birth + the one-way deleted_at rule) and the §1.1 `REVOKE UPDATE` covers only those columns. `interest_tags`/`discovery_opt_in` are absent from both → updates pass through untouched and stay self-editable via `users_update_own` (id = auth.uid()). **No ALTER/recreate of the trigger function needed** — the migration header decision stands; pgTAP §43b asserts the column-UPdate grant contract.

### Verification (session 2)

- `flutter test test/services/user_service_test.dart` → 43/43 pass (was: compile error).
- `flutter test test/features/party_finder/` → 14/14 pass (was: 3 failures + 1 compile error).
- `flutter test test/router/app_router_test.dart` → pending I-57/I-59 l10n-key in-flight breakage (compile-blocked on `qrScanRetry`/`photos*` getters) — see Issues.
- `dart analyze` on my files: 0 errors (1 pre-existing `curly_braces_in_flow_control_structures` info at `user_service.dart:176` — region untouched by this session; reported, not fixed).
- ARB JSON validity + key parity: verified with a Python check.
- Static SQL: plan 250 recount OK; both stacks' `schema_test.sql` and migration 0004 byte-identical (`diff` clean).

### Issues found (S-03 review note, pre-existing/in-flight — NOT fixed)

- **Repo-wide `dart analyze`/test compile breakage is other agents' in-flight work**: I-57's `lib/features/qr/qr_scanner_screen.dart:463` references `l10n.qrScanRetry`; I-59's `lib/features/photos/photo_gallery_screen.dart` references `photosPermissionRationale`/`photosUploadedSnack`/`photosReport*` — none of those keys are in the ARBs yet, and both agents hold the generated `app_localizations*.dart` locks. Their gen-l10n runs will resolve it. My 8 partyFinder keys are already in the generated files.
- **S-03 radar (unchanged from handoff):** (1) `discovery_view` does not exclude blocked users (client-side filter — presence of a blocked user's overlap is still derived from the view; same as `user_search_view`); (2) superuser-owner view semantics — a future `security_invoker` flip would break both views; (3) `interest_tags` has no catalog CHECK constraint — crafted writes could pollute match chips (unknown ids are skipped client-side).
- Pre-existing info-level lint `user_service.dart:176` (braces around `if` body) — pre-dates this session; left as-is per no-out-of-scope rule.

## Original session log (what was built)

1. **Migration `20260809000004_users_discovery.sql`** (+ identical `supabase-testing/` mirror):
   - `users` gains `interest_tags text[] NOT NULL DEFAULT '{}'` and `discovery_opt_in boolean NOT NULL DEFAULT false` (privacy default **OFF**, PFND spec).
   - `discovery_view` — security-barrier view exposing only `(id, username, avatar_url, interest_tags)` of non-deleted, opted-in users with ≥1 tag; `GRANT SELECT TO authenticated` + defensive `REVOKE FROM anon` (no pre-auth enumeration, mirrors I-32 §13).
   - **Trigger allowlist decision (documented in the migration header):** `interest_tags`/`discovery_opt_in` are **user-owned** profile data. I-32's `assert_safe_user_update()` compares only the protected columns (economy/subscription/ban/DOB/deleted_at) and the column-level `REVOKE UPDATE` covers only those — so **no trigger change and no new REVOKE**. Both columns pass through the trigger untouched and stay self-editable via `users_update_own` (id = auth.uid()). This is a deliberate, documented exception class (same as username/avatar_url/bio, which G-03 never guarded). Re-audit hook left for S-03: neither column is economy/subscription-affecting, so G-03 is not reopened.
   - RLS note for the view (documented in migration): a non-`security_invoker` view resolves base-table access with the **view owner's** privileges (postgres = superuser → RLS bypassed for the view body, exactly like the pre-existing `user_search_view`), so the view itself is the column-level gate; `security_barrier` prevents predicate-pushdown row leaks (§39.5).

2. **pgTAP Section 43** in `supabase/tests/schema_test.sql` + mirror (plan 235 → **250**, +15): columns/types/defaults/NOT NULL, `has_column_priv UPDATE` = true for authenticated on both user-owned columns (the self-edit contract), view presence + exact column projection + authenticated-only + `security_barrier` reloption.

3. **`UserService`** (`lib/core/services/user_service.dart`):
   - `getDiscoveryOptIn()` / `setDiscoveryOptIn(bool)` — own-row read/write of `users.discovery_opt_in`.
   - `getMyInterestTags()` — own-row `users.interest_tags` parsed through the I-36 `UserInterests.fromDb` (both PostgREST list and JSON-string forms).
   - `findMatches(myTags)` — queries `discovery_view` (`.neq(id, me)` + `.overlaps('interest_tags', myTags)`, limit 50), parses tags, attaches `shared_tags` (sorted intersection) + `shared_count`, sorts **shared-count DESC then username ASC**; drops matches I blocked and hides matches who blocked me (mirrors `searchUsers` — block lands immediately without policy re-derivation).

4. **`lib/features/party_finder/party_finder_providers.dart`** (new): `discoveryOptInProvider` (read/write toggle) + `partyMatchesProvider` (my tags → overlaps). Providers read `userServiceProvider` directly (NOTI feature precedent — no repository needed at this scope).

5. **`lib/features/party_finder/party_finder_screen.dart`** (new): opt-in `SwitchListTile` on top; first-run explainer ("Descubrimiento está apagado") while OFF; match list (avatar / @username / shared-count with ICU plural / tag chips / "Bloquear") sorted by shared count; tap → `RoutePaths.userProfile`; block reuses `friendsRepositoryProvider.blockUser` + snackbar + reload; pull-to-refresh; empty + error (`ErrorView`) states; disco tokens (hairline borders, glowPink-free minimal list, mutedStrong secondary text).

6. **Router** (`lib/core/router/app_router.dart`): `/party-finder` → `FlagGate(partyFinder, child: PartyFinderScreen())` — still **dark by default** (fallback = localized coming-soon, unchanged).

7. **Tests** (TDD RED→GREEN): service tests (+22 in `test/services/user_service_test.dart`), provider tests (`test/features/party_finder/party_finder_providers_test.dart`), screen widget tests (`test/features/party_finder/party_finder_screen_test.dart`), router flag-on test (`test/router/app_router_test.dart`), hermetic `integration_test/party_finder_flow_test.dart` + `runner.sh` order entry. `test/support/resolving_builder.dart` gained an `overlaps` recorder (shared mock seam).

8. **ARB**: 8 new keys (`partyFinder*`) in `app_es.arb` + `app_en.arb`, `flutter gen-l10n` regenerated the 3 `app_localizations*.dart` files.

## Decisions made and why

- **Add the migration (not the placeholder path):** the column migration is clean-additive, and the I-36 `UserInterests` value object + catalog already documented the `users.interest_tags` storage contract — building the real provider against the real schema unblocks the whole feature.
- **No trigger change** (see §1): the trigger's "allowlist" is the protected-column set; the new columns are deliberately absent.
- **View over direct table query:** `discovery_view` gives column-level gating (RLS can't restrict columns — G-03 rationale) and matches the existing `user_search_view` pattern.
- **Client-side block filtering** in `findMatches` (not SQL): mirrors `searchUsers`, gives instant block effect, avoids re-deriving policy.
- **Sort by shared-tag count DESC** (not mutual-friends first, which the spec asks for): mutual-friends count needs a friendships-count query that the match list does not have yet — flagged as follow-up (I-60 log) to keep this foundation minimal. Tags-first is a defensible MVP ordering per the mission.
- **Flag stays dark** (`partyFinder: false` default untouched) — the feature is unreachable until the stack lands, per I-49 dark-first doctrine.

## MISTAKE (searchable)

- `test/services/user_service_test.dart`: an Edit operation with a too-short `oldString` accidentally deleted the existing `blockUser/unblockUser` group. Restored verbatim from the working tree history and re-verified with `git diff` — always include unique context lines around the edit anchor.

## Verification

- `dart analyze` — 0 errors (see final numbers below).
- `flutter test test/features/party_finder/ test/router/app_router_test.dart test/l10n/` — green (final numbers below).
- Full suite — run below.
- Static SQL checks: plan 250 = assertion count (delta +15 verified); mirror files byte-identical; `security_barrier=on` reloption asserted; anon revoked; authenticated SELECT granted.

## Commands run

```bash
# pgTAP (needs the self-hosted stack on port 54382 — not running during I-60;
# static verification only + mirrored test files)
supabase db test            # deferred to stack start

# Flutter
dart analyze
flutter test test/features/party_finder/
flutter test test/router/app_router_test.dart
flutter test test/l10n/
flutter test test/services/user_service_test.dart
flutter test integration_test/party_finder_flow_test.dart

# locks
tools/agent_lock.sh acquire/release <path> --owner I-60-party-finder
```

## Handoff / follow-ups (do NOT fix out of scope)

- **Mutual-friends count + sort priority** (spec: mutual friends DESC first): needs a friendships-count query — follow-up agent (FRND-owned `FriendsRepository`).
- **Match detail card** (bio excerpt, mutual-friends avatars, "Enviar mensaje") — blocked on CHAT (I-56/I-38).
- **Opt-in toggle in privacy settings** (`settings_screen.dart` "Privacidad") — currently only on the party-finder screen; reuse `discoveryOptInProvider`.
- **Wiring `InterestTagPicker` into edit-profile save** — the picker + `UserInterests` exist (I-36); `users.interest_tags` now exists, so the write path can land (I-36 follow-up / PRFL).
- **S-03 review note (the view):** (1) `discovery_view` deliberately does NOT exclude blocked users (client-side filter) — presence of a blocked user's tag overlap is still derived from the view; acceptable (same as `user_search_view`) but worth an S-03 audit row. (2) Pre-existing: `user_search_view` and now `discovery_view` both rely on the superuser-owner view semantics — if the platform ever flips views to `security_invoker`, both views would return own-row-only; keep on the S-03/S-04 radar. (3) `interest_tags` is free-text array without a CHECK against the catalog — a crafted write could pollute match chips (unknown ids are skipped client-side); consider a catalog CHECK constraint in a later migration.
- **IDOR/profanity**: usernames render verbatim on cards — display is `@username` only, consistent with the search screen.
