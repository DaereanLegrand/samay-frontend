# U-09 — Profile screens restyle: the §5/§3.2/§5.6 profile pass + avatar widget (2026-08-11)

**Agent:** U-09 | **Phase:** 04-ui (4.4) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §2.1/§2.4/§2.5/§3.2/§3.3/§5.1/
§5.2/§5.3/§5.6/§5.9/§7.2 (read in full — THE CONTRACT),
`docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md` +
`docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/DEVELOPMENT-WORKFLOW.md` (read
in full), U-01..U-08 daily logs + the U-05/U-06/U-02/U-04 handoffs (profile
header → avatar treatment + Playfair username + VCard balance card; danger →
`AppColors.error`; `VButton.glowAccent` ready; `VInput.errorText` seam;
`VDiscoDivider` available), the I-13/I-36/I-65 logs (profile provider,
avatar upload, theme persistence), AGENTS.md. Baseline before edits:
`dart analyze` 0 issues; full `flutter test` **1783/0** (U-08 checkpoint).

## What was built

The 5 profile screens' disco restyle, screen-by-screen, exactly per the §5
handoffs. **The flow is byte-identical**: every route, provider, l10n string,
tap target, upload pipeline and dialog action is untouched — this pass
changes *rendering* only. A new shared `ProfileAvatar` widget
(`lib/features/profile/widgets/profile_avatar.dart`) carries the header
avatar treatment so all three avatar slots (own profile, public profile,
edit profile) render identically. TDD: `test/features/profile/restyle_test.dart`
(15 tests) written first, RED against the pre-restyle tree (14/15 failed —
the 1 green pins the U-05 VInput token treatment already in place), then
GREEN.

### The visual-change ledger (screen → §5 ref → change → test update)

| Screen | §5 ref | Change (visual) | Test update |
|---|---|---|---|
| `profile_screen.dart` | §2.1/§4.2/§3.2 | Avatar `CircleAvatar(grey[800])` → **`ProfileAvatar`** (surfaceAlt fill + `border #333333` 1px ring + white w600 initials — the §2.1 avatar-ring token; mission's "border hairline" resolved to the doc's avatar-ring token, see Decisions) | `restyle_test` +1 (ring decoration: shape/color/border; initials white/24) |
| `profile_screen.dart` | §3.2 | Username `headlineMedium` (Inter 24) → **`headlineLarge`** (Playfair Display italic 28 + glow-soft baked into the theme role — the doc's fancy moment; username is the brand-ish header element) | `restyle_test` +1 (family/italic/28/shadows == `fancyTitle(headlineLarge, soft:true)`) |
| `profile_screen.dart` | §5.3/§5.6 | Balance card `Container(grey[800] border)` → **`VCard`** (surface fill + hairline borders, §5.3) with **`VShardIcon(size: lg 24)`** gold diamond (§5.6 balance-card size); text stays `bodyLarge`/`bodyMedium` tokens; ledger chevron survives | `restyle_test` +1 (VCard present; shard gold + lg; texts; chevron) |
| `profile_screen.dart` | §2.4 | Bio `bodyMedium` (white) → **`bodyMedium` + `mutedStrong`** (7.37:1 AA) | `restyle_test` +1 (bio color) |
| `profile_screen.dart` | §5 ListTiles | Group tiles `ListView.builder` → **`ListView.separated`** with 1px **hairline** `Divider` separators (the U-04 dividerTheme paints them) | `restyle_test` +1 (separator count + `dividerTheme.color` hairline — M3 Divider reads dividerTheme, not `ThemeData.dividerColor`, see MISTAKE) |
| `profile_screen.dart` | §5 (verify-only) | Cosmetics section **unchanged** (already token-clean, flag-gated) | none (existing flag tests stay green) |
| `edit_profile_screen.dart` | §2.1/§4.2/§5.8 | Avatar placeholder `ClipOval+ColoredBox(grey[800])` + `Icons.person 48` → **`ProfileAvatar(initials:, imageUrl:)`** — initials placeholder (matches the header treatment; the person icon is gone — deliberate, see Decisions) | `restyle_test` +1 (ProfileAvatar ring + camera affordance survives) |
| `edit_profile_screen.dart` | §5.2 (verify-only) | Bio `VInput` already token-clean (mutedStrong label — U-05); `VInput.errorText` seam ready | `restyle_test` +1 (label mutedStrong — the one GREEN-against-pre-restyle pin) |
| `settings_screen.dart` | §5.4/§2.4 | Theme `SegmentedButton` default M3 (secondaryContainer selected) → **token-clean `SegmentedButton.styleFrom`**: transparent + white unselected, **white fill + black text selected**, white side, sharp (the §5.4 chip treatment; labels already resolve the theme `labelLarge`) | `restyle_test` +1 (style resolution per state: white/black/transparent/white side/sharp) |
| `settings_screen.dart` | §5.2/danger | Destructive 'Eliminar mi cuenta' row `Colors.red` icon+label → **`AppColors.error`** (glowPink 6.00:1 — the *semantic*; `AppColors.danger`/glowPinkDeep is AA-large-only and banned as sole text color by §2.5 rule 6, see Decisions) | `restyle_test` +1 (label + icon color error) |
| `settings_screen.dart` | §2.4 | Version footer `bodyMedium` (white) → **`bodyMedium` + `mutedStrong`** (mission's "muted" resolved to mutedStrong — `muted` fails 1.4.3 at 14px, see Decisions) | `restyle_test` +1 (version color) |
| `settings_screen.dart` | §5 (verify-only) | ListTiles hairline **already done** — the `Divider()`s resolve the U-04 dividerTheme (`hairline #1A1A1A`) | none (pinned by the theme tests) |
| `public_profile_screen.dart` | §5.1 | Primary action `VButton.emphasized` → **`VButton.glowAccent(filled: true)`** for 'Agregar amigo' (pink fill + black text 6.00:1, `glowPinkDeep` pressed — U-07's canonical brand-moment CTA; exactly ≤1 glow per screen; the pending/accept/blocked status buttons stay emphasized white) | `restyle_test` +1 (VButton variant glow + filled) |
| `public_profile_screen.dart` | §3.2/§2.4 | Header mirrors the own-profile treatment: avatar → **`ProfileAvatar`**; username → **`headlineLarge`** Playfair; `@handle` + bio → **`mutedStrong`** | `restyle_test` +1 (ring, Playfair, handle/bio colors) |
| `public_profile_screen.dart` | §5.9 | Shared-groups empty placeholder → **`bodyMedium` + `mutedStrong`** (the §5.9 empty-state voice); the block IS the mutual-friends placeholder (no separate element exists — l10n has no mutual-friends key; see Decisions) | `restyle_test` +1 (empty text color) |
| `public_profile_screen.dart` | §5 (verify-only) | Blocked/report `PopupMenuButton` **already theme-owned** (U-04 popupMenuTheme: black surface, white text/icons, sharp) | none (pinned by theme tests) |
| `delete_account_screen.dart` | §5.1 | Danger CTA `VButton.emphasized` (white fill) → **`VButton.glowAccent` outlined** (pink 1px border + pink label — the §5.9-mission "glowPink outlined" call; danger is a function, not a brand moment, so no pink fill; disabled → `muted` per VButton) | `restyle_test` +1 (variant glow, filled false) |
| `delete_account_screen.dart` | §5.2 | Confirm dialog 'Eliminar' `Colors.red` → **`AppColors.error`** (glowPink, never raw red on black); the dialog chrome itself is already U-04's black dialogTheme | `restyle_test` +1 (confirm color; dialog opens through the real seeded-session flow) |

**Zero-change contract:** all l10n strings, all routes (settings → edit →
delete-account chain, public profile load/block/report/send-accept-decline
actions, the shard-ledger balance-card tap, cosmetics flag row), the avatar
upload pipeline (permission → picker → upload → persist → invalidate →
snackbar) and the delete-account email-match gate are byte-identical —
pinned by the untouched `profile_screens_test`, `avatar_flow_test`,
`delete_account_flow_test` and `profile_providers_test` assertions. U-15
owns flow alignment — nothing here alters flow.

## Files created / modified (lock evidence)

All 10 locks via `tools/agent_lock.sh acquire <path> --owner U-09`
(acquired 06:31Z, held for the whole edit, released after):

| File | Action | Lock evidence |
|---|---|---|
| `lib/features/profile/screens/profile_screen.dart` | modified (avatar/username/balance-card/bio/groups) | acquire 2ceaa479553376b48f7290ca → release |
| `lib/features/profile/screens/edit_profile_screen.dart` | modified (ProfileAvatar placeholder + initials state) | acquire f1cf0f586bb3ccdfbb40f25a → release |
| `lib/features/profile/screens/settings_screen.dart` | modified (danger rows, SegmentedButton, version footer) | acquire d9d3ab78043f510d09c3163f → release |
| `lib/features/profile/screens/public_profile_screen.dart` | modified (action/avatar/username/handle/bio/empty state) | acquire 0b26e4381837fce037d1384b → release |
| `lib/features/profile/screens/delete_account_screen.dart` | modified (glowAccent CTA + dialog error color) | acquire 2e2337bca9f99cbe2a579915 → release |
| `lib/features/profile/widgets/profile_avatar.dart` | **created** (the §2.1/§4.2 avatar treatment) | acquire 3d7e1092cd2da8109b9ec91a → release |
| `test/features/profile/restyle_test.dart` | **created** (15 ledger tests) | acquire 765fb6694340a1d079d9b51c → release |
| `test/features/profile_screens_test.dart` | locked, **unmodified** (verification only — every existing assertion stayed green) | acquire 575e6990fb848854ba656266 → release |
| `docs/to-fix/TODO.md` | modified (U-09 workstream block) | acquire b802f899fb97030c6d655fd5 → release |
| `docs/history/phase-04-ui/2026-08-11_U09-profile-restyle.md` | created (this log) | acquire 906513b25f1158b31d62aecb → release |

## Commands run (reproducibility)

```bash
export AGENT_NAME="U-09"
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
flutter test test/features/profile/ test/features/profile_screens_test.dart \
  test/providers/profile_providers_test.dart              # baseline 43/43
tools/agent_lock.sh acquire <10 files> --owner U-09        # all held (see table)
# RED: restyle_test.dart (15 tests against the pre-restyle tree)
flutter test test/features/profile/restyle_test.dart       # 1 pass / 14 fail = RED
#   (2 harness fixes before RED was readable: SegmentedButton.style is
#    ButtonStyle (styleFrom folds selected/unselected colors into the
#    backgroundColor/foregroundColor properties); ProfileAvatar pre-restyle
#    port so the RED is behavioral, not a missing-file compile error)
# GREEN: the 5 screen edits + the ProfileAvatar token treatment
flutter test test/features/profile/restyle_test.dart       # 15/15
#   (5 test-side fixes: settings rows are lazily built below the 600px
#    viewport → scrollUntilVisible; settings label is 'Eliminar mi cuenta',
#    not 'Eliminar cuenta'; '@dana' matches AppBar title + handle → scoped
#    to the ListView; Divider color asserted via dividerTheme (M3 reads
#    dividerTheme, ThemeData.dividerColor is the M2 fallback = white);
#    delete-screen tap targeted via widgetWithText(TextButton, ...) because
#    find.text('Eliminar cuenta').last resolves to the AppBar title)
dart analyze                                               # 4 infos → fixed (const/null-aware/import)
dart analyze                                               # 0 issues
flutter test test/features/profile/ test/features/profile_screens_test.dart \
  test/providers/profile_providers_test.dart              # 58/58 (43 prior + 15 new)
flutter test                                               # FULL 1798/0 (baseline 1783 → +15)
flutter test integration_test/profile_flow_test.dart       # 2/2 (unchanged)
git diff -w --numstat <5 screens>                         # verified: the only
#   whitespace-sensitive line is the balance-card `onTap` reindent (6→8sp,
#   parent moved from `return InkWell(` to `child: InkWell(` — legitimate)
tools/agent_lock.sh release <path> --owner U-09            # all 10 released
```

## Test results

- `test/features/profile/restyle_test.dart` — **15/15** (new; RED-proven:
  the 14 failing assertions were exactly the missing treatments; the 1 green
  pins the pre-existing U-05 VInput token state).
- `flutter test test/features/profile/ test/features/profile_screens_test.dart
  test/providers/profile_providers_test.dart` — **58/58** (43 pre-existing
  assertions unchanged + 15 new).
- `flutter test integration_test/profile_flow_test.dart` — **2/2**
  (unchanged — flow byte-identical).
- `flutter test` (full) — **1798 pass / 0 failures** (U-08 baseline 1783/0,
  +15 = the ledger tests; zero regressions).
- `dart analyze` — **0 issues**.

## Decisions made and why

- **Avatar ring = `border #333333`, not `hairline #1A1A1A` (doc wins over
  the mission's "border hairline"):** the doc's §2.1 table explicitly
  assigns `border #333333` to "Interactive outlines (unselected chips,
  avatar rings)" — the avatar-ring token. The mission's phrase is read as
  "a hairline-*thin* 1px border" (same resolution U-08 used for the
  featured-card border). The initials (21:1) carry the text contrast, so
  the 1.66:1 ring is never the only signal (§7.2). U-07's profile_setup
  avatar placeholder used the same token — campaign-consistent.
- **Username = `headlineLarge` (28), not `displayMedium` (40):** the
  handoff offered either; 40px is the auth-screen header size (§3.2), 28px
  is the "event titles, podium, group hero" size — the profile username is
  a hero-name, not a page wordmark. The theme role already bakes the
  glow-soft stack (`fancyTitle(headlineLarge, soft: true)`), so the fancy
  moment is zero extra code and byte-identical to `VGlowText` output
  (U-06 parity contract).
- **Danger *text* = `AppColors.error` (glowPink), NOT `AppColors.danger`
  (glowPinkDeep):** the mission's "(AppColors.error vs a danger alias —
  use the semantic)" is resolved by the doc: `glowPinkDeep` is 3.58:1 —
  AA-large only — and §2.5 rule 6 bans it as the sole text color at normal
  size. `AppColors.error` (glowPink, 6.00:1) IS the semantic alias for
  error/danger *text*. The `danger` alias stays for fills (pressed states,
  error chips). Flagged for U-30: the alias table could carry a
  text-vs-fill usage note.
- **Version footer = `mutedStrong`, not `muted`:** the mission's "version
  footer muted" — §2.4 hard rule: informational text below 24px must be
  `mutedStrong` (7.37:1); `muted` (3.66:1) is legal only for placeholders,
  disabled controls or ≥24px text. A version string is informational
  14px text → mutedStrong. Same resolution U-07 applied to the
  profile_setup hint. Flagged for U-26/U-30.
- **Delete CTA = glowAccent *outline*, not filled:** §5.1 offers border-or-
  fill; the mission calls the "glowPink outlined" form for the danger CTA.
  The delete action is a destructive *function*, not a brand moment —
  the filled pink treatment is reserved for positive brand CTAs (auth,
  add-friend). Disabled (empty email) drops to `muted` per the VButton
  disabled state. The confirm dialog's 'Eliminar' is the second danger
  text — both glowPink.
- **Edit-profile placeholder now shows initials, not the person icon:**
  the mission says "keep ALL behavior/flow/text identical" — a person icon
  vs initials is pure rendering; showing the same initials treatment as
  the header keeps the three avatar slots consistent and lets one
  `ProfileAvatar` serve all three (less code, one test target). The camera
  affordance (white circle + black icon, P2 primitives) is untouched.
- **Public-profile primary = `glowAccent(filled: true)` only for
  'Agregar amigo':** the mission names that one action. 'Aceptar solicitud'
  stays emphasized-white (it renders beside the outlined 'Rechazar' — a
  balanced pair; adding pink there would invert the pair's hierarchy).
  Flagged for U-15/U-23: if flow alignment wants the pink accept, it is a
  one-line change in `_buildActionButton`.
- **No mutual-friends placeholder exists as content:** the mission lists
  "mutual-friends placeholder, shared-groups section" — the l10n has no
  mutual-friends key; the shared-groups block ("Grupos compartidos" /
  "Sin grupos en común") IS the mutual-friends placeholder. Restyled its
  text to the §5.9 empty-state voice and pinned it; adding a new section
  would violate the zero-change contract (U-15/U-16 flow scope).
- **`ListView.separated` over per-tile dividers:** the hairline separators
  appear *between* tiles only (no leading/trailing rule), which is the
  §5 ListTile treatment; `Divider(height: 1)` consumes the U-04
  dividerTheme color — no inline color anywhere.

## MISTAKE

- **`SegmentedButton.style` is `ButtonStyle?`, and `styleFrom` folds the
  selected/unselected colors into `backgroundColor`/`foregroundColor`
  WidgetStateProperties** — my first test asserted non-existent
  `selectedBackgroundColor` fields on ButtonStyle (compile error) and then
  asserted the wrong resolution set. Fixed by reading the SDK source:
  `styleFrom` → `TextButton.styleFrom().copyWith(backgroundColor:
  _defaultColor(enabled, disabled, selected))` — resolve with
  `{WidgetState.selected}` for the selected treatment, `{}` for the
  unselected. Lesson: assert the *resolved* property per state, not a
  param name from the docs.
- **`find.text('Eliminar cuenta').last` resolves to the AppBar title, not
  the CTA** (Scaffold traversal order puts the AppBar subtree last in the
  delete screen's element order — the tap at `Offset(151, 28)` was a
  no-op, and the dialog never opened). Probed the tap position and
  switched to `find.widgetWithText(TextButton, 'Eliminar cuenta')` — the
  same pattern `delete_account_flow_test` already uses. (Side observation:
  the pre-existing `profile_screens_test` 'empty email' taps also hit the
  AppBar title — harmless there, they assert a dialog does NOT open.)
- **M3 Divider ignores `ThemeData.dividerColor`:** the divider-test first
  asserted `Theme.of(context).dividerColor == hairline` and got WHITE —
  in M3 the Divider resolves `widget.color ?? dividerTheme.color ??
  colorScheme.outlineVariant`; `ThemeData.dividerColor` is the M2
  fallback. Asserted `dividerTheme.color` (the real source) instead.
- **Settings rows are lazily built below the 600px test viewport:** the
  destructive row and version footer are not in the element tree until
  scrolled — `scrollUntilVisible` needed. Also: the settings row label is
  `profileDeleteMyAccount` = **'Eliminar mi cuenta'** (distinct from the
  delete screen's 'Eliminar cuenta') — the first finder matched nothing.
- **`@dana` renders twice on the public profile** (AppBar title + body
  handle) — `find.text` matched 2 ("Too many elements"); scoped to the
  ListView body.
- **RED harness fix (self-caught):** the first RED run was a compile error
  (missing `ProfileAvatar`) — a wrong-reason failure per
  DEVELOPMENT-WORKFLOW §1.3. Fixed by porting the pre-restyle avatar into
  `ProfileAvatar` first so the RED run was behavioral (14 failed for the
  missing treatments). Also: `const` on the BoxDecoration was illegal
  (`AppColors.border` is a `Border.all` — non-const), and `_initFakeSupabase`
  would have double-initialized Supabase against
  `initSupabaseHarness` — the file seeds once via the harness.

## Issues found / handoffs

- **U-30 (doc finalization):** (1) §2.1's avatar-ring role (`border
  #333333`) vs the U-09 mission's "border hairline" wording — worth
  spelling out that avatar rings are `border`, not `hairline`; (2) the
  semantic-alias table should note `danger` is a *fill* alias (glowPinkDeep
  is AA-large-only as text; `error` is the text alias) — both were used
  correctly here; (3) §5.1's glowAccent "border OR fill" is now concretized
  in three places: filled for brand CTAs (auth, add-friend), outline for
  the danger CTA — the filled form is the canonical primary.
- **U-15/U-23 (flow alignment + review):** nothing to align — rendering
  only; every route/label/provider/tap is byte-identical (pinned by the
  unchanged `profile_screens_test`/`avatar_flow_test`/
  `delete_account_flow_test`/`profile_providers_test` and
  `integration_test/profile_flow_test.dart`). If the Juega study wants the
  pink 'Aceptar solicitud', it is a one-line change in
  `public_profile_screen._buildActionButton`.
- **U-19/U-26 (responsive + a11y):** the fixed-height groups box
  (`SizedBox(height: 120)`) predates this pass; with many groups it scrolls
  internally (fine) but the OTP `LayoutBuilder` pattern is the repo-wide
  template. Contrast recap for the audit: initials 21:1, Playfair glow
  halo legal (§7.4), mutedStrong 7.37:1, glowPink danger 6.00:1, gold
  shard 13.71:1 (non-text), hairline dividers decorative (§7.2 — tile
  text carries the boundary).
- **U-27 (theme tests):** the settings SegmentedButton is now explicitly
  styled in-screen (U-04's file was NOT touched — `app_theme.dart` has no
  segmentedButtonTheme; a future U-27 pass could promote it to the theme).
- **U-29 (integration smoke):** consider asserting the profile header
  treatment (avatar ring + Playfair username) in the UI smoke pass.
- **I-15/U-28:** no new hardcoded strings — every label is a pre-existing
  ARB key; no `AppLogger` calls added.
- **Pre-existing, not touched:** none beyond the noted M3-Divider and
  Scaffold-traversal curiosities; the `profile_screens_test` empty-email
  tap hitting the AppBar title is pre-existing and harmless (reported for
  completeness).

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §2.1/§2.4/§2.5/§3.2/§3.3/§3.4/§4.2/
  §5.1/§5.2/§5.3/§5.6/§5.9/§7.2/§7.4 (read in full — the contract).
- Flutter SDK source (read-only, 3.44.1): `material/segmented_button.dart`
  (`styleFrom` → `_defaultColor` state folding; `_SegmentedButtonDefaultsM3`
  selected-state resolution), `material/divider.dart` (M3 color precedence:
  widget → dividerTheme → colorScheme.outlineVariant; `ThemeData.dividerColor`
  is the M2 path), `material/scaffold.dart` (AppBar/body traversal order —
  the `.last` tap trap).
- U-01..U-08 daily logs (tokens, theme, widget restyle, auth/feed restyle
  precedents incl. the format-churn MISTAKE — no blanket `dart format`),
  I-13 (profile provider), I-36 (avatar upload + edit screen), I-65
  (theme persistence / SegmentedButton).
- WCAG 2.2 contrast pairs via the doc's §2 tables (muted vs mutedStrong
  for the footer/bio decisions; glowPinkDeep AA-large-only rule).
