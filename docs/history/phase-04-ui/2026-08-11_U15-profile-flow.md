# U-15 — Profile/settings FLOW alignment: settings grouping + sign-out confirm + header tap-to-edit + empty-state voice (2026-08-11)

**Agent:** U-15 | **Phase:** 04-ui (4.4) | **Status:** DONE

Contract: `docs/history/phase-04-ui/2026-08-11_U13-juega-flow-study.md` §5-U15 (the 5 recommendations with Juega evidence + Samay targets + test impact — THE CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` (read in full), the U-13 report's §7 disco guard rails, AGENTS.md. This is the **second attempt** (first stalled pre-work — verified zero partial edits, zero locks at start). Baseline before edits: full `flutter test` **1853 pass / 0 fail** (U-14's total); `dart analyze` **0 issues**.

**Scope discipline:** flow changes ONLY — no restyling beyond what the flow needs (the disco look is done, U-01..U-12), no data-layer/repository changes, no Juega code/infra touched. TDD: tests written first (RED proven), then the minimal implementation, full suite after each step.

## The ledger — 5/5 recommendations

| # | Rec | Juega evidence | Samay change | Test impact | Verdict |
|---|---|---|---|---|---|
| R6 | **Group the settings screen into sections with uppercase headers** (Apariencia / Cuenta) — flat sharp rows, hairline dividers, no glass (N2) | ADAPTED — `settings_screen.dart:80-198` (headers `:201-211`, cards `:213-231`) | `settings_screen.dart`: `_SectionHeader` (uppercase `labelSmall` mutedStrong, §3.3/§2.4) + two `VCard` groups: **Apariencia** (theme picker) and **Cuenta** (suscripción, notificaciones, editar perfil, privacidad, bloqueados, then the R7 danger pair). Tiles got `contentPadding: EdgeInsets.zero` (the card carries the 16px padding — identical row metrics); the picker's horizontal padding moved to the card. Version footer stays outside (R10). 2 new l10n keys | `restyle_test` +2 (headers render uppercase labelSmall mutedStrong; two VCard sections + danger pair inside the account card + footer outside). All pre-existing text-based settings finders stayed green | ✅ 2/2 |
| R7 | **Sign-out confirm dialog** (danger pair at the bottom of the account section; cancel keeps the session, confirm signs out + returns to login) | ADAPTED — `settings_screen.dart:145-152` (Juega signs out with zero confirmation; Samay *improves* per the delete-flow dialog discipline, F8) | `settings_screen.dart`: `_confirmSignOut` — `AlertDialog` (title + body, Cancel / `Cerrar sesión` in `AppColors.error` — the delete-account precedent), then `signOut()` + `context.go(RoutePaths.login)` only when confirmed. Sign-out row now `destructive: true` (the danger pair is *both* rows in the error semantic — Juega's danger-colored row) | `profile_screens_test` +2 (cancel → signOutCalls 0, dialog gone, still on settings; confirm → signOutCalls 1 + login route) | ✅ 2/2 |
| R8 | **Header tap-to-edit** (avatar tap AND username tap → the edit screen) | ADAPTED — `profile_screen.dart:56-88,90-112` (Juega edits inline from the profile; Samay pushes its existing editor — the sharp-dialog spec bans an inline form of this size) | `profile_screen.dart`: avatar wrapped in `Tooltip('Editar perfil')` + `InkWell(customBorder: CircleBorder)` → `context.push(RoutePaths.profileEdit)`; username wrapped in `InkWell` → same push. **Avatar tap is the new affordance** (previously only reachable via the edit screen) | `profile_screens_test` +2 (avatar tap → EditProfileScreen; username tap → EditProfileScreen) via a new minimal go_router harness (`_flowRouter`) — the real screens push with `context.push`, which plain `MaterialApp(home:)` cannot exercise. Zero visual diff: the `Text`/`ProfileAvatar` widgets are untouched (U-09 style pins green unchanged) | ✅ 2/2 |
| R9 | **Profile empty groups box → the F2 icon+title+hint voice** | DIRECT — `profile_screen.dart:268-282` (Juega's per-section empty cards) | `profile_screen.dart`: the 60px bare `Text` → `VEmptyView(icon: group_outlined, title: profileNoGroupsYet, description: profileNoGroupsHint)`, still inside the ListView (stays pull-to-refreshable). 1 new l10n key | `restyle_test` +2 (VEmptyView + icon + title + hint render; no VEmptyView with groups). **Test fallout absorbed:** the taller empty state pushed the profile cosmetics row below the 600px test fold → `profile_screens_test` cosmetics-flag test + `cosmetics_navigation_test` (I-62's file, lock-coordinated) scroll before asserting — the flag-gated navigation contract is unchanged | ✅ 2/2 |
| R10 | **Version footer + theme picker stay as-is** (explicit keep — both already exceed Juega) | DIRECT (explicit keep) — `settings_screen.dart:86-94` (worse pattern) | **No behavior/visual change** — verified: `SegmentedButton` token styling byte-identical (the U-09 restyle pins green), version footer outside the cards, mutedStrong | `restyle_test` +1 pin (both theme options + version footer render after the grouping). The existing SegmentedButton-tokens and footer-color pins stayed green unchanged | ✅ pinned |

## Deviations from the report (each justified)

1. **R6 Legal section deferred:** the report's example shape was "VISUAL/ACCOUNT/LEGAL" but Samay has **no legal rows** (no terms/privacy screens exist in-app). Adding an empty `Legal` header would render dead chrome. Implemented Apariencia + Cuenta; a Legal section is one header + rows away when legal content lands (documented, not scaffolded).
2. **R6 VCard-per-section kept, with a framework fix:** the report said "VCard grouping" and the disco doc (§7.3) names "R6's section cards" as radius-0 hairline surfaces — VCard is exactly that, so the grouping is VCard-based as written. Flutter's framework asserts `ListTile` under a colored `DecoratedBox` ("ink splashes may be invisible") — fixed with a transparent `Material` between the card and the tiles (splash paints above the card surface; zero visual change). The report's test-impact estimate ("finders stay text-based → mostly green") held: only the two profile→cosmetics tests needed a scroll (R9 fallout, see deviation 5).
3. **R7 key count:** the report estimated "new l10n key" (singular); the dialog needs **2** (`profileSignOutQuestion` + `profileSignOutBody` — a confirm dialog has a title *and* a body; the action reuses the existing `profileSignOut`, cancel reuses `commonCancel`).
4. **R7 sign-out row became `destructive: true`:** the report calls the pair "a danger *pair*" and cites Juega's "danger-colored row" — the sign-out row now uses the error semantic like the delete row. Not a restyle whim; it is the flow alignment (the pair reads as one danger unit). The §5.2 pin (glowPink text/icon) is the same rule the delete row already followed.
5. **R9 test-impact fallout beyond the estimate:** the report predicted "restyle_test +1-2"; the empty-state growth also pushed `profile_screens_test`'s cosmetics-flag test and `test/features/cosmetics/cosmetics_navigation_test.dart` (I-62's file — lock-coordinated, acquired/released) below the fold. Both got a `scrollUntilVisible` before the existing assertions/taps — behavior contracts unchanged. A report miss, absorbed like U-14's deviation 2.
6. **R8 needs a router harness, not `avatar_flow_test`:** the report suggested `profile_screens_test` + `avatar_flow_test` for the two taps; the taps push routes, so the new flow harness (minimal `GoRouter`) lives in `profile_screens_test` where the go_router import is new. `avatar_flow_test` stays untouched — its scope is the upload pipeline, not navigation.
7. **l10n keys total:** 5 (2 section headers + 2 sign-out dialog + 1 empty-state hint) — within the report's "l10n keys" allowance for R6/R7/R9; one ARB edit per file + `flutter gen-l10n` once.

## MISTAKE blocks

- **MISTAKE (implementation bug caught by my own tests):** the first grouped-settings version wrapped the tiles in `VCard` directly — the Flutter framework throws "ListTile background color or ink splashes may be invisible" for ListTiles under a colored `DecoratedBox`. The existing U-09 settings tests (delete-row color, segmented-button tokens, footer) caught it as a suite-level RED. Fixed with the transparent-`Material` layer; documented in deviation 2.
- **MISTAKE (test-design bug at RED time):** my first R6 grouping test asserted `findsNWidgets(2)` VCard sections at the default 600px viewport — the lazily-built ListView disposed the top card once scrolled, making the count viewport-dependent. Fixed with an explicit tall viewport (`Size(800, 1600)`) for the settings/profile tests so the full tree is built deterministically.

## Files modified (lock evidence)

| File | Change | Lock |
|---|---|---|
| `lib/l10n/app_es.arb` + `app_en.arb` | 5 new keys (one edit per file) + `flutter gen-l10n` once (regenerates `app_localizations{,_es,_en}.dart` — tracked artifacts, same as U-14) | acquire+release, U-15 |
| `lib/features/profile/screens/settings_screen.dart` | R6 grouping (section headers + two VCard groups) + R7 `_confirmSignOut` dialog + danger pair | acquire+release, U-15 |
| `lib/features/profile/screens/profile_screen.dart` | R8 header tap-to-edit (avatar + username) + R9 VEmptyView empty voice | acquire+release, U-15 |
| `test/features/profile/restyle_test.dart` | +5 tests (R6×2, R9×2, R10 pin) | acquire+release, U-15 |
| `test/features/profile_screens_test.dart` | +4 tests (R7×2, R8×2) + `_flowRouter` go_router harness + `_SignOutAuthNotifier` + cosmetics-flag test scroll fix | acquire+release, U-15 |
| `test/features/cosmetics/cosmetics_navigation_test.dart` | scroll fix before the cosmetics-row assert/tap (R9 fallout; I-62's file — coordinated, lock was free) | acquire+release, U-15 |
| `docs/to-fix/TODO.md` | U-15 completion block | acquired, U-15 (released at end) |
| `docs/history/phase-04-ui/2026-08-11_U15-profile-flow.md` | **NEW** — this ledger | created by U-15 |

## Tests + results

- RED proofs: `restyle_test` + `profile_screens_test` → **7 failures** before implementation (R6×2, R7×2, R8×2, R9×1); the R10 keep-pin and the R9 negative pin were green at RED by design (they pin no-change/absence). Then GREEN after each file's implementation (per-step runs).
- `flutter test test/features/profile/ test/router/` → **177/177**.
- `flutter test test/features/cosmetics/cosmetics_navigation_test.dart` → **4/4** (scroll fix verified).
- FULL `flutter test` → **1862/1862** (U-14 baseline 1853 + 9 new, zero regressions).
- `dart analyze` → **0 issues**.
- Disco guard rails (U-13 §7): no new Playfair sites; ≤1 glow accent per screen (none added — the SegmentedButton stays token-clean); errors glowPink via `AppColors.error`; sharp radius-0 + hairline (VCard groups, N2 — no Juega glass); AA text via `mutedStrong`/white; no emoji.

## Issues found (reported, not touched)

1. The U-13 report's R6 test-impact note said "settings finders stay text-based → mostly green; +2-3 (section headers render)" — it did not flag that R9's taller empty state would push the profile cosmetics row below test folds (two cosmetic-scroll fixes, deviation 5). A report miss, absorbed.
2. Pre-existing (U-13 §8, still open): `group_detail_screen._getMemberLimit` hardcodes `'14'` (I-46) — out of scope.
3. Pre-existing (U-13 §8, still open): friends-list `@username` double render — U-16 decision point, out of scope.
4. Handoff to U-30: the settings section-header pattern (uppercase `labelSmall` mutedStrong + sharp VCard groups) and the "transparent Material under card ListTiles" framework rule are worth promoting into DISCO §5.3/§5.4 wording.

## Change log

| Date | Change |
|---|---|
| 2026-08-11 | v1.0 authored by U-15 (5/5 flow recommendations; 1862/1862 full suite). |
