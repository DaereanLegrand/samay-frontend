# U-07 — Auth screens restyle: the §5/§3.2/§5.1/§5.2 visual-change ledger (2026-08-11)

**Agent:** U-07 | **Phase:** 04-ui (4.4) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §3.2/§3.3/§5.1/§5.2 (read in
full — THE CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` +
`docs/process/FILE-OWNERSHIP.md` + `docs/process/DEVELOPMENT-WORKFLOW.md` +
`docs/process/DEVELOPMENT-WORKFLOW.md` (read in full), U-01..U-06 daily logs +
the U-05/U-02 handoffs (auth headers → `displayMedium`; OTP field →
`AppTypography.otpInputText`; raw `Colors.red` → `AppColors.error`;
`VButton.glowAccent` for welcome/login/OTP CTAs; `VDiscoDivider` between the
welcome CTAs; `VInput.errorText` wiring), AGENTS.md. Baseline before edits:
`dart analyze` 0 issues; full `flutter test` **1758/0** (U-06 checkpoint).

## What was built

The auth screens' disco restyle, screen-by-screen, exactly per the handoffs.
**The flow is byte-identical**: every route, button label, l10n string,
validation rule, timer and dialog is untouched — this pass changes *rendering*
only. TDD: `test/features/auth/restyle_test.dart` (14 tests) written first,
RED against the pre-restyle tree (12/14 failed — the 2 green ones pin the
unchanged bits: outlined secondary CTA + Playfair wordmark), then GREEN.

### The visual-change ledger (screen → handoff → change → test update)

| Screen | Handoff | Change (visual) | Test update |
|---|---|---|---|
| `welcome_screen.dart` | (5) + (6) | Primary CTA `VButton.emphasized` (white fill) → **`VButton.glowAccent(filled: true)`** (pink fill + black text, 6.00:1 — §5.1 brand moment); `VDiscoDivider` inserted between the two CTAs (hairline + 48px glowPink segment, U-06) | `restyle_test` +4 (glowAccent fill/text, outlined secondary, divider present, wordmark unchanged) |
| `login_screen.dart` | (3) + (4) + (5) | The `Colors.red` inline error Text **moved into the password `VInput.errorText`** (glowPink via §5.2 errorStyle) — the auth error now rides the offending field; primary CTA `emphasized` → **`glowAccent(filled: true)`** | `restyle_test` +1 (errorText + glowPink style); existing error-flow test unchanged (message still findable) |
| `signup_contact_screen.dart` | (1) + (3) + (4) | Header `headlineMedium` → **`displayMedium`** (Playfair italic 40 + glow-strong); the single `_validationError` split into `_passwordError`/`_confirmError` → **`VInput.errorText`** on the password (policy message) and confirm (mismatch) fields; the `auth.hasError` inline text `Colors.red` → **`AppColors.error`** | `restyle_test` +3 (Playfair header, policy/mismatch errorTexts); existing mismatch/weak-password tests unchanged (messages render once in the field) |
| `otp_verification_screen.dart` | (1) + (2) + (3) + (5) | Header → **`displayMedium`**; OTP field inline `TextStyle(fontSize: 32, letterSpacing: 12)` → **`AppTypography.otpInputText`** (30/w800/ls8/1.5) + white; both `Colors.red` texts → **`AppColors.error`**; primary CTA → **`glowAccent(filled: true)`**; body wrapped in the pinned-bottom/scroll-when-needed pattern (§7.3 — see Decisions) | `restyle_test` +2 (Playfair header, otpInputText style); `otp_ux_test` + `auth_screens_test` harnesses → phone-sized surface (see Decisions) |
| `age_gate_screen.dart` | (1) + (3) | Header → **`displayMedium`**; underage message `Colors.red` → **`AppColors.error`** | `restyle_test` +2 (Playfair header; underage message glowPink — driven through the real M3 date picker in text-entry mode) |
| `privacy_terms_screen.dart` | (1) | Header → **`displayMedium`** | `restyle_test` +1 (Playfair header) |
| `profile_setup_screen.dart` | (3) + (4) | Avatar `Colors.grey[800]` → **`AppColors.border`** (§5.9 placeholder tone); camera icon 32 → `AppIconSizes.xl`; hint `TextStyle(fontSize: 12, color: grey[500])` → **`AppTypography.bodySmall` + `AppColors.mutedStrong`** (§2.4 AA); `Colors.red` inline error → **username `VInput.errorText`** | `restyle_test` +1 (username errorText + glowPink) |
| `banned_screen.dart` | (3 — none present) | Already fully tokenized (displayMedium, white icon, mutedStrong body) — **zero changes** | none (locked, verified) |

**Zero-change contract:** all l10n strings, all routes/CTAs' labels, the OTP
auto-submit + cooldown + 5-attempt logic, the age-gate picker flow, the
privacy checkboxes and the profile-setup sanitizer flow are byte-identical.
U-14 owns flow alignment — nothing here alters flow.

## Files created / modified (lock evidence)

All 14 locks via `tools/agent_lock.sh acquire <path> --owner U-07` (acquired
04:23Z, held for the whole edit, released after — see the release transcript
in the commands section):

| File | Action | Lock evidence |
|---|---|---|
| `lib/features/auth/screens/welcome_screen.dart` | modified (glowAccent CTA + divider) | acquire 483d0366061be2e48d856e7f → release |
| `lib/features/auth/screens/login_screen.dart` | modified (errorText + glowAccent) | acquire f1468d4e9f1350f6d3001b95 → release |
| `lib/features/auth/screens/signup_contact_screen.dart` | modified (header + split errorTexts) | acquire 80229d247be74dcbc03a4f56 → release |
| `lib/features/auth/screens/otp_verification_screen.dart` | modified (header, otpInputText, errors, glowAccent, scroll) | acquire fbbb96cb7a00e717338f3593 → release |
| `lib/features/auth/screens/age_gate_screen.dart` | modified (header + error color) | acquire 9eb326f703086e98f1ff65f6 → release |
| `lib/features/auth/screens/privacy_terms_screen.dart` | modified (header) | acquire 3624869c4b495235178a546a → release |
| `lib/features/auth/screens/profile_setup_screen.dart` | modified (tokens + errorText) | acquire d4fd09c102dfd82c55c4c517 → release |
| `lib/features/auth/screens/banned_screen.dart` | locked, **unmodified** (verification only) | acquire 2e6b140103d15652dadd9199 → release |
| `test/features/auth/restyle_test.dart` | **created** (14 tests) | created under the auth-test lock set |
| `test/features/auth/otp_ux_test.dart` | modified (phone-surface harness) | acquire 5a1471ef9992ee58ccf5f3d0 → release |
| `test/features/auth/auth_interactions_test.dart` | locked, **unmodified** (verification only — all assertions stayed green) | acquire 07294416877a9084953e9675 → release |
| `test/features/auth/banned_test.dart` | locked, **unmodified** (verification only) | acquire f065dace11ba56f5b702db1a → release |
| `test/features/auth_screens_test.dart` | modified (phone-surface helper, 3 OTP-pumping tests) | acquire f096e0b8650a9d707a8d76cd → release |
| `docs/to-fix/TODO.md` | modified (U-07 workstream block) | acquire b802f899fb97030c6d655fd5 → release |
| `docs/history/phase-04-ui/2026-08-11_U07-auth-restyle.md` | created (this log) | acquire → release |

## Commands run (reproducibility)

```bash
export AGENT_NAME="U-07"
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
flutter test test/features/auth/ test/features/auth_screens_test.dart  # 58/58
tools/agent_lock.sh acquire <13 files> --owner U-07        # all held (see table)
# RED: test/features/auth/restyle_test.dart (14 tests against the pre-restyle tree)
flutter test test/features/auth/restyle_test.dart          # 2 pass / 12 fail = RED
#   (age-gate test iterated: es okButtonLabel is "ACEPTAR", not "Aceptar")
# GREEN: the 7 screen edits
flutter test test/features/auth/restyle_test.dart          # 14/14
flutter test test/features/auth/ test/features/auth_screens_test.dart
#   → 3 OTP tests fail: RenderFlex overflow (Ahem-font harness, 800×600)
#   → fix: OTP body scroll-when-needed + phone-sized test surfaces
flutter test test/features/auth/ test/features/auth_screens_test.dart  # 72/72
rm test/probe_layout_tmp_test.dart                         # transient probe, DELETED
dart analyze                                               # 1 warning (unused import) → fixed
dart analyze                                               # 0 issues
# full-suite iteration: l10n guard failure from formatting the AppLogger line
flutter test                                               # 1772/0 (baseline 1758 → +14)
tools/agent_lock.sh release <path> --owner U-07            # all 14 released
```

## Test results

- `test/features/auth/restyle_test.dart` — **14/14** (new; RED-proven).
- `flutter test test/features/auth/ test/features/auth_screens_test.dart`
  — **72/72** (58 pre-existing, all assertions unchanged + the 14 new).
- `flutter test` (full) — **1772 pass / 0 failures** (U-06 baseline 1758/0,
  +14 = the new ledger tests; the 3 harness-fix edits kept every existing
  assertion green).
- `dart analyze` — **0 issues**.

## Decisions made and why

- **glowAccent is FILLED on welcome/login/OTP:** §5.1 offers border-or-fill;
  a *border-only* pink CTA would read lighter than the white outlined
  secondary it replaced on welcome (hierarchy flip). Pink fill + black text
  (6.00:1) is the unmistakable brand moment; the pressed state
  (`glowPinkDeep` + white, 5.87:1) is §5.1-exact. Exactly ≤ 1 glow CTA per
  screen — the secondary CTAs stay outlined white (§2.5 rule 3).
- **Error texts moved INTO the fields (`VInput.errorText`) where the error
  belongs to a field** (login password, signup password/confirm,
  profile_setup username — handoff 4): the message position changes
  (field-attached instead of standalone inline Text) — ledgered as a visual
  change; server-level errors (`auth.hasError` on signup) stay inline but in
  `AppColors.error`. The OTP/age-gate messages are not field errors, so they
  stay inline — only recolored.
- **OTP body = pinned-bottom / scroll-when-needed (§7.3):** the displayMedium
  header + otpInputText field grew the column ~105px; at the 800×600 test
  surface (and, in production, at larger text scales / small phones) the
  fixed `Column` + `Spacer` overflowed. The `LayoutBuilder →
  SingleChildScrollView → ConstrainedBox(minHeight) → IntrinsicHeight →
  Column(Spacer)` pattern pins the CTA when the content fits and scrolls when
  it doesn't — exactly §7.3 ("buttons/inputs grow; never clip").
- **Phone-sized test surfaces in the OTP harnesses:** the 800×600 test
  default is smaller than any real phone and the Ahem test font renders
  every glyph 1em wide, so the 45px bare-theme header wraps to 3 lines.
  `tester.view.physicalSize = 1170×2532 @ dpr 3` (390×844 logical) in
  `otp_ux_test._pumpScreen` + a `_usePhoneSurface` helper on the 3
  OTP-pumping tests of `auth_screens_test`. No production behavior changed.
- **`auth_screens_test`/`otp_ux_test`/`banned_test`/`auth_interactions_test`
  keep the repo's committed formatting:** the tree was formatted with a
  pre-tall-style formatter; the current SDK reflows those files wholesale on
  `dart format`. Only the semantically-needed lines were edited
  (format-drift hunks were restored to HEAD — pure churn is not a restyle).

## MISTAKE

- **`dart format` re-wrapped the OTP `AppLogger.instance.warn(...)` call and
  broke the I-15 l10n guard:** the guard skips hardcoded-literal scans per
  line via `line.contains('AppLogger.instance')`; a formatted multi-line call
  puts the message literal on its own line → the scan flagged "verification"
  (stopword 'verifica' substring). Caught by the full suite. Fixed by keeping
  the statement single-line with a comment explaining why. **Handoff:
  U-28/I-15** — the line-based AppLogger skip is fragile; a multiline-aware
  skip (or scoping the scan to widget-building statements) would fix it.
- **The age-gate test's confirm label:** the M3 es `okButtonLabel` is
  uppercase "ACEPTAR" (material_es.arb), not "Aceptar" — the first run
  failed to find the button. Fixed, and the M3 date-picker text-entry toggle
  (`Icons.edit_outlined`) + `warnIfMissed: false` work reliably (verified
  green in 3 full-suite runs).
- **Format-drift churn (self-inflicted, fixed):** a blanket
  `dart format test/features/auth/` reflowed 4 tests with zero semantic
  change. Restored them to HEAD (verified each diff was formatting-only
  before restoring; files were clean at session start).

## Issues found / handoffs

- **U-14 (flow-alignment):** nothing to align — the restyle touched
  rendering only; every route/label/validation/timer is byte-identical to
  the pre-restyle tree (pinned by the unchanged `auth_interactions_test` /
  `otp_ux_test` / `auth_screens_test` assertions).
- **U-19/U-26:** the other auth screens (login/signup/age_gate/
  privacy_terms/profile_setup) still use fixed `Column` bodies — they fit the
  test surfaces and typical phones today, but at ≥1.5× text scaling on small
  phones they would overflow like the OTP screen did. The OTP pattern
  (`LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight) +
  IntrinsicHeight`) is the template to apply repo-wide in the responsive pass.
- **I-15/U-28:** the l10n guard's `AppLogger.instance` skip is line-based —
  any multi-line logger call in the UI scope leaks into the literal scan
  (see MISTAKE).
- **U-27:** the auth restyle assertions live in
  `test/features/auth/restyle_test.dart` (grouped by § section) — extend
  there when U-14/U-23 touch auth again.
- **U-30 (doc finalization):** §5.1's "Pink 1px border OR pink fill" is now
  concretized: brand-moment CTAs use `filled: true`. Consider wording the
  spec so the filled form is the canonical primary CTA on black.
- **Pre-existing, not touched:** none beyond the U-05/U-06 handoff chain
  (all now landed for auth).

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §2.5/§3.2/§3.3/§3.4/§5.1/§5.2/§7.3
  (read in full — the contract).
- Flutter SDK source (read-only, 3.44.1): `material/date_picker.dart`
  (`Icons.edit_outlined` input-toggle, `okButtonLabel` action);
  `flutter_localizations/src/l10n/material_es.arb` (okButtonLabel =
  "ACEPTAR"); `theme_data.dart` M3 displayMedium metrics (45px Roboto in the
  bare theme — the harness overflow driver).
- U-01..U-06 daily logs + handoff tables (the exact token/widget surface this
  pass consumed).
- WCAG 2.2 contrast pairs (via the doc's §2 tables: pink fill + black text
  6.00:1; `glowPinkDeep` + white 5.87:1).
