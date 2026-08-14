# U-19 — Responsive layout + safe areas: the §7.3/UI-09 text-scaling pass (2026-08-11)

**Agent:** U-19 | **Phase:** 04-ui (4.4) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §4.1 (`AppSpacing.scale`) +
§7.3 (text scaling, safe areas) read in full; `docs/process/DEVELOPMENT-WORKFLOW.md` +
`docs/process/FILE-OWNERSHIP.md` + `docs/process/DEVELOPMENT-WORKFLOW.md` +
`docs/process/DEVELOPMENT-WORKFLOW.md` read in full; all 18 U-series daily
logs + the handoffs (U-07 auth Columns, U-09 groups box 120 + balance card,
U-11 group-detail rows, U-12 coming-soon, U-16 flow rows); finding UI-09
(`docs/to-fix/categories/07-UI-DESIGN.md`) + L-20 (`docs/to-fix/TODO.md`);
AGENTS.md. Research: Flutter SDK source (read-only, 3.44.1) —
`MediaQuery.textScalerOf`, `RenderIntrinsicHeight`, `RenderSliverFillRemaining`,
`RenderFlex` flex layout; Flutter text-scaling guidance
(https://api.flutter.dev/flutter/widgets/MediaQuery/textScalerOf.html).
Baseline before edits: `dart analyze` 0 issues; full `flutter test` **1935/0**
(U-18 checkpoint).

## The audit table (every screen at 1.5× text scale on 320×568 logical px)

Method: `test/features/responsive_test.dart` pumps each screen inside
`MediaQuery(textScaler: TextScaler.linear(1.5))` on a 320×568 @ dpr 1.0
viewport with the real Samay theme + es l10n + provider stubs mirroring the
real data shapes, then asserts `tester.takeException() == null`. The Ahem
test font (every glyph 1em wide) is *harsher* than any real font, so the
pass over-approximates device risk. 18 screens audited; **10 overflowed**.

| # | Screen | Risk driver (found by the RED smoke) | Verdict | Fix |
|---|--------|--------------------------------------|---------|-----|
| 1 | welcome | 2×`Spacer` fixed column; 96px wordmark at 1.5× | PASS 1.5× (fits) — brittle | scroll-safe body (pattern A) |
| 2 | login | fixed Column (2 VInputs + 2 CTAs) | PASS 1.5× (fits) — brittle | scroll-safe body (pattern A) |
| 3 | signup | fixed Column + Spacer | **FAIL −316px bottom** | scroll-safe body (pattern A) |
| 4 | OTP | — (U-07 already fixed) | PASS | none (regression-pinned) |
| 5 | age_gate | fixed Column + Spacer | **FAIL −359px bottom** | scroll-safe body (pattern A) |
| 6 | privacy_terms | fixed Column + Spacer; long checkbox subtitles | **FAIL −989px bottom** | scroll-safe body (**pattern B** — see MISTAKE 1) |
| 7 | profile_setup | fixed Column + Spacer | PASS 1.5× (fits) — brittle | scroll-safe body (pattern A) |
| 8 | banned | centered Column; long ban reason | **FAIL −49px bottom** | scroll-safe body (pattern A) + 200 CTA → full-width |
| 9 | forgot_password | — (U-14 already scroll-safe) | PASS | none (regression-pinned) |
| 10 | profile | `_BalanceCard` Row (shards column natural width); groups box `SizedBox(height: 120)` | **FAIL −56px right** | `Expanded` column; box → inline `_GroupTile` rows |
| 11 | settings | ListView (scrolls) | PASS | none |
| 12 | delete_account | fixed Column + Spacer | **FAIL −665px bottom** | scroll-safe body (pattern A) |
| 13 | my_groups | Amigos/Solicitudes TextButton Row (−177 right); tile subtitle Row (VBadge+shard+count+RankBadge, −284 right) | **FAIL ×2** | both Rows → `Wrap` |
| 14 | group_detail | hero badges Row (−75 right); shards Row (−168 right); header column taller than the body (−59 bottom) | **FAIL ×3** | badges → `Wrap`; shards → `Flexible`; **bounded-scroll header** (`bodyHeight − 120` min tab area) |
| 15 | friends_list | Column + Expanded list (scrolls) | PASS | none |
| 16 | chat | Column + Expanded list + composer | PASS | none |
| 17 | feed | featured carousel `height: 264` clipped the card text (−28 bottom); chip row `height: 36` | **FAIL** | both heights → `AppSpacing.scale(context, …)` (the §4.1/UI-09 helper, first real consumer) |
| 18 | coming_soon | centered Column (icon 48 + Playfair 32 + desc + 200 CTA) | **FAIL −27px bottom** | scroll-safe body (pattern A) + 200 CTA → full-width |

Also audited (not pumped — out of the mission's list, all
ListView/SingleChildScrollView-based, no fixed non-scroll bodies):
group_members, create_group, invite, leaderboard, donate, search, requests,
blocked_users, public_profile, edit_profile, events screens, notifications,
party_finder, subscriptions, cosmetics, minigames, shards, photos, qr
screens. The nine `width: 200` CTA sites (banned, v_coming_soon, VEmptyView,
error_view, route_error_screen, qr_scanner ×2, attendance_qr,
photo_gallery) were all fixed to the full-width
`ConstrainedBox(maxWidth: 320)` form regardless.

SafeArea audit: the shell's bottom nav + the tab screens' AppBars already
resolve the top/bottom insets (AppBar = status bar, BottomNavigationBar =
home indicator, welcome/banned/coming-soon/feed already had SafeArea); the
auth screens' AppBar'd bodies sit above the bottom inset with the 24/32px
body padding — no safe-area gaps found, no changes needed beyond the scroll
patterns.

## What was built

1. **`test/features/responsive_test.dart` (NEW, 18 tests)** — the smoke:
   the full mission screen list (welcome, login, signup, OTP, age_gate,
   privacy_terms, profile_setup, feed, profile, settings, my_groups,
   group_detail, friends_list, chat, coming-soon) + banned,
   delete_account, forgot_password. Fixtures mirror the real Supabase data
   shapes (AGENT-RULES §0.6): group maps with `my_role`/`rank_bracket`,
   event rows with featured + upcoming, chat envelopes, a long ban reason.
   RED-proven: 10/18 failed with RenderFlex overflows before any fix.
2. **Pattern A (the OTP template) applied to 9 screens:** login, signup,
   age_gate, profile_setup, delete_account, banned, welcome, coming-soon
   (+ OTP/forgot-password already had it). `LayoutBuilder →
   SingleChildScrollView → ConstrainedBox(minHeight) → IntrinsicHeight →
   Column(Spacer)` — pins the CTA when the content fits, scrolls when it
   doesn't (U-07's §7.3 template).
3. **Pattern B for privacy_terms:** `CustomScrollView →
   SliverFillRemaining(hasScrollBody: false)` + the same pinned Column.
   `CheckboxListTile` replaced by a custom `_ConsentRow` (checkbox +
   title/subtitle Column, the same theme roles) — see MISTAKE 1 for why.
4. **profile_screen:** `_BalanceCard` shards Column `Spacer` → `Expanded`;
   the `SizedBox(height: 120)` nested groups list → inline `_GroupTile`
   const sub-widgets (hairline dividers preserved, PERF-08 style).
5. **my_groups:** the two-button row and the tile subtitle row → `Wrap`.
6. **group_detail:** badges row → `Wrap`; shards text → `Flexible`; hero
   header → bounded `SingleChildScrollView` (`maxHeight = bodyHeight −
   _minTabArea(120)`), byte-identical at 1.0× (natural height, no scroll).
7. **feed:** carousel `height: 264` and chip-row `height: 36` →
   `AppSpacing.scale(context, …)`.
8. **The 200px CTA family (9 sites):** → `ConstrainedBox(maxWidth: 320)`
   full-width.

## Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire <path> --owner U-19` (acquired
11:32Z, held through the edits, released after — see the commands section):

| File | Action | Lock |
|---|---|---|
| `lib/features/auth/screens/login_screen.dart` | modified (pattern A) | f1468d4e9f1350f6d3001b95 |
| `lib/features/auth/screens/signup_contact_screen.dart` | modified (pattern A) | 80229d247be74dcbc03a4f56 |
| `lib/features/auth/screens/age_gate_screen.dart` | modified (pattern A) | 9eb326f703086e98f1ff65f6 |
| `lib/features/auth/screens/privacy_terms_screen.dart` | modified (pattern B + `_ConsentRow`) | 3624869c4b495235178a546a |
| `lib/features/auth/screens/profile_setup_screen.dart` | modified (pattern A) | d4fd09c102dfd82c55c4c517 |
| `lib/features/auth/screens/banned_screen.dart` | modified (pattern A + CTA) | 2e6b140103d15652dadd9199 |
| `lib/features/auth/screens/welcome_screen.dart` | modified (pattern A) | 483d0366061be2e48d856e7f |
| `lib/features/profile/screens/delete_account_screen.dart` | modified (pattern A) | 2e2337bca9f99cbe2a579915 |
| `lib/features/profile/screens/profile_screen.dart` | modified (Expanded + inline tiles) | 2ceaa479553376b48f7290ca |
| `lib/features/feed/screens/feed_screen.dart` | modified (scale-aware heights) | b19d2bd2379d00ae1c95ae15 |
| `lib/features/groups/screens/my_groups_screen.dart` | modified (2× Wrap) | 291c1445f19a8eb29a632ce3-set |
| `lib/features/groups/screens/group_detail_screen.dart` | modified (Wrap/Flexible/bounded header) | 291c1445f19a8eb29a632ce3-set |
| `lib/shared/widgets/v_coming_soon.dart` | modified (pattern A + CTA) | 6a4a71094adc35e05dc469b6 |
| `lib/shared/widgets/state_views.dart` | modified (CTA) | 64b94a48ad7fc8eb03b96398 |
| `lib/shared/widgets/error_view.dart` | modified (CTA) | f7e08c07ae26ea9ac7f3b1fc |
| `lib/shared/widgets/route_error_screen.dart` | modified (CTA) | aaa77ebf8c818083d7fd18a7 |
| `lib/features/photos/screens/photo_gallery_screen.dart` | modified (CTA) | 5566ccbb65b64c7cc8d1ad57 |
| `lib/features/qr/screens/qr_scanner_screen.dart` | modified (CTA ×2) | 6729adce35720babb3d7f538 |
| `lib/features/qr/screens/attendance_qr_screen.dart` | modified (CTA) | 7553d39b98edf5109c7c4422 |
| `test/features/responsive_test.dart` | **created** (18 tests) | new file (free per FILE-OWNERSHIP) |
| `docs/to-fix/TODO.md` | modified (U-19 block + L-20 ✅) | b802f899fb97030c6d655fd5 |
| `docs/to-fix/categories/07-UI-DESIGN.md` | modified (UI-09 ✅) | 291c1445f19a8eb29a632ce3 |
| `docs/history/phase-04-ui/2026-08-11_U19-responsive.md` | **created** (this log) | new file |

## Commands run (reproducibility)

```bash
export AGENT_NAME="U-19"
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
flutter test test/features/responsive_test.dart            # RED: 10/18 fail
#   (overflow sites identified via debugDumpRenderTree + the "relevant
#   error-causing widget" diagnostics per failing screen)
tools/agent_lock.sh acquire <21 files> --owner U-19        # all held
# GREEN: the 19 source edits (patterns A/B, Wraps, Flexible, scale, CTAs)
flutter test test/features/responsive_test.dart            # 18/18
dart analyze                                               # 0 issues
flutter test test/features/auth/ test/features/auth_screens_test.dart \
  test/features/profile/ test/features/groups/ test/features/friends/ \
  test/features/feed/                                       # 222/222
flutter test test/widgets/ test/design_tokens/ test/meta/ test/theme/  # 316/316
flutter test                                               # 1953/1953
tools/agent_lock.sh release <path> --owner U-19            # all released
```

## Test results

- `flutter test test/features/responsive_test.dart` — **18/18** (RED-proven
  10/18 → GREEN).
- Flagged neighbors — auth (incl. `auth_screens_test`) + profile + groups +
  friends + feed — **222/222**.
- Widgets + design_tokens + meta + theme — **316/316**.
- `flutter test` (full) — **1953 pass / 0 failures** (U-18 baseline 1935/0,
  +18 = the responsive smoke, zero regressions).
- `dart analyze` — **0 issues**.

## MISTAKE blocks

- **MISTAKE 1 (the big one): the OTP `IntrinsicHeight + Spacer` pattern is
  NOT safe for every child.** privacy_terms kept overflowing by 132px even
  inside the scroll view. Root cause (SDK source, read-only): both the
  `RenderIntrinsicHeight` pass and `RenderSliverFillRemaining`'s no-scroll
  branch lay the child out at a TIGHT height derived from
  `getMaxIntrinsicHeight` — and `ListTile`'s intrinsic height is smaller
  than its laid-out height when the subtitle wraps (its internal
  title/subtitle Row measures differently in the intrinsic pass). The tight
  height then clips the real content → overflow. Fix: replace the
  `CheckboxListTile`s with plain `Checkbox + Text` rows (`_ConsentRow`) —
  plain Texts measure exactly — and use the `SliverFillRemaining` form for
  that screen. **Handoff U-26/U-30:** pattern A is fragile for any
  wrapped-text tile child; prefer pattern B for list-tile-like content.
  (Both variants were RED-proven before the fix; the lesson is documented
  in the screen's comment.)
- **MISTAKE 2 (analysis churn):** the first privacy_terms attempt used
  `SliverFillRemaining` while keeping `CheckboxListTile` — still RED (the
  intrinsic flaw above). The second attempt fixed it. The audit table's
  "−989px" was the fixed-Column measurement; the residual −132 was the
  intrinsic flaw.
- **MISTAKE 3 (test-harness churn):** debug instrumentation
  (`debugDumpRenderTree` on failure) was left in the test file during
  iteration and removed before the final run; the final file has the clean
  `takeException()` asserts only.
- **MISTAKE 4 (format discipline, per the U-07 precedent):** edits were made
  by hand without a blanket `dart format`; only touched regions were
  formatted. `dart analyze` 0 issues at the end.

## Decisions made and why

- **Two template variants, one contract.** Pattern A (IntrinsicHeight) stays
  for text/VInput-only columns (the U-07 repo template, green everywhere it
  is used); pattern B (SliverFillRemaining) is the variant for tile-like
  children. Both implement the same §7.3 contract: pin the CTA when the
  content fits, scroll when it doesn't.
- **`Wrap` over horizontal scrolling** for the my_groups/group_detail rows:
  the doc bans decorative chrome and the mission allows
  flexible/expanded/scrollable patterns; a Wrap keeps everything visible at
  1.5× with zero interaction cost (buttons stay tappable on the second
  line).
- **`AppSpacing.scale` for the feed's fixed heights** — the §4.1 helper
  exists precisely for this (finding UI-09); a scaled box tracks the scaled
  text exactly (the image block keeps 120px fixed, the rest scales).
- **Bounded-scroll hero on group_detail** instead of pushing the whole page
  into one scroll surface: the TabBarView must stay pinned (it holds the
  member/chat/events tabs); the header may scroll within
  `bodyHeight − _minTabArea(120)` so the tabs are never crushed.
- **The 200px CTA → `ConstrainedBox(maxWidth: 320)`** (full width, capped):
  the mission's "maxWidth-relative or full-width with margin"; 320 ≈ the
  content width of the smallest supported phone (390 − 2×24 − margin).
- **Inline profile groups instead of a scaled box:** §7.3 bans fixed-height
  text containers; the inline tiles make the page one scroll surface (the
  U-15 empty-state precedent already lives in the outer ListView).

## Issues found / handoffs

- **U-26/U-30 (a11y/doc):** (1) the IntrinsicHeight fragility + the
  SliverFillRemaining template — promote pattern B into §7.3 as the variant
  for tile-like children (both live in `privacy_terms_screen.dart` + OTP);
  (2) `_ConsentRow` is now the consent-row widget (ListTile-free); (3) the
  `AppSpacing.scale` usage sites + the `_minTabArea` convention could get
  §4.1/§7.3 mentions. All fixes are layout-only — zero contrast changes
  (U-26's WCAG pass unaffected).
- **U-29 (integration smoke):** the 18 pumps are widget-level; a device
  spot-check of welcome + privacy_terms + group_detail at 1.5× would
  complete the story (the Ahem font is harsher than real fonts, so device
  runs may show the layouts are roomier).
- **I-46 (report-only, unchanged):** `group_detail_screen._getMemberLimit`
  still hardcodes `'14'` (out of scope).
- **Pre-existing, not touched:** the friends-list `@username` double render
  (U-16); the feed's inline 13px metadata (U-08).

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §4.1/§7.3 (read in full — the
  contract), `docs/to-fix/categories/07-UI-DESIGN.md` (UI-09),
  `docs/to-fix/TODO.md` (L-20), U-01..U-18 daily logs + handoff tables.
- Flutter SDK source (read-only, 3.44.1): `widgets/media_query.dart`
  (`textScalerOf`), `rendering/flex.dart` (flex/unbounded layout),
  `rendering/intrinsic_dimensions.dart` (`RenderIntrinsicHeight`),
  `rendering/sliver_fill.dart` (`RenderSliverFillRemaining` no-scroll
  branch).
- Flutter text-scaling docs:
  https://api.flutter.dev/flutter/widgets/MediaQuery/textScalerOf.html
