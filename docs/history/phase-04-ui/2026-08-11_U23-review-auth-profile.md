# U-23 — UI review pass: auth → profile (DISCO §2/§3/§5/§6/§7 conformance checklist + fixes + flags) (2026-08-11)

**Agent:** U-23 | **Phase:** 04-ui (4.4) — review passes (U-23..U-25) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §2/§3/§5/§6/§7 (read in full — THE
CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md` +
`docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/DEVELOPMENT-WORKFLOW.md` (read in
full), the U-07/U-09/U-14/U-15/U-18/U-19/U-21/U-22 daily logs + their handoff
tables (U-22's remaining `VLoadingView` sites in profile/edit_profile/
public_profile; U-18's §6.2 "auth headers" breathing gap on signup/age_gate/
privacy_terms; U-19's pattern-A/B lesson; U-21's state-widget sweep + the
U-09/U-15 section-header voice), AGENTS.md, `docs/to-fix/TODO.md`. Baseline
before edits: `dart analyze` **0 issues**; full `flutter test` **1981/0**
(U-22 checkpoint).

## The per-screen checklist (fresh-eyes walk, doc §2/§3/§5/§6/§7)

Method: every screen in scope read against the doc — colors/tokens (no raw
hues, §2), typography roles (§3.2/§3.3), spacing/radius/elevation (§4), glow
discipline (≤1 breathing element, ≤1 glow CTA, accent budget §2.5), state
views (§5.8/§5.9), reduced motion (§6.2/§7.5), responsive/scroll-safety (§7.3).

| # | Screen | Checklist verdict | Notes |
|---|--------|-------------------|-------|
| A1 | `welcome_screen` | **PASS** | wordmark VIVE displayLarge Playfair+glow, **breathing** (§6.2); glowAccent-filled primary + outlined secondary + `VDiscoDivider` (§5.1/§5.3); pattern-A scroll-safe; SafeArea |
| A2 | `login_screen` | **PASS** | no §3.2 header (AppBar title — doc lists none for login); glowAccent-filled primary; password `errorText` glowPink (§5.2); forgot-password → dedicated route (U-14 R3); pattern A |
| A3 | `signup_contact_screen` | **PASS** (1 flag) | header displayMedium + glow, **now breathing**; field `errorText`s + inline auth error glowPink; pattern A. **FLAG F1:** the primary CTA is `VButton.emphasized` (white) while welcome/login/OTP/forgot-password use the filled glowAccent — the account-creation act is the funnel's strongest brand moment; U-07's handoff list excluded it, so it is deliberate, but the family is now inconsistent → product call |
| A4 | `otp_verification_screen` | **PASS** | displayMedium **breathing**; `otpInputText` token; attempts counter mutedStrong→error at ≤1 (§2.4/§5.2); back-to-login (U-14 R1); pattern A |
| A5 | `age_gate_screen` | **PASS** | header displayMedium + glow, **now breathing**; underage message glowPink; date-picker theme-owned (U-04); pattern A |
| A6 | `privacy_terms_screen` | **PASS** | header displayMedium + glow, **now breathing**; `_ConsentRow` (U-19 pattern B); CTA disabled-until-accepted → `muted` per §5.1 |
| A7 | `profile_setup_screen` | **PASS** | avatar placeholder `border #333333` + camera affordance (§5.9 tone, U-07); username `errorText`; hint bodySmall mutedStrong (§2.4); pattern A. Note: placeholder is the plain CircleAvatar, not `ProfileAvatar` — deliberate (camera affordance lives inside); consistent size 96 |
| A8 | `banned_screen` | **PASS** | displayMedium **breathing**; white xxl icon; body mutedStrong; outlined full-width CTA (U-19); SafeArea + pattern A |
| A9 | `forgot_password_screen` | **PASS** | header displayMedium + glow, **now breathing** (form + success states); `errorText` (validation first, auth second); glowAccent-filled CTA; snackbar (F7); pattern A |
| P1 | `profile_screen` | **PASS** (1 flag) | `ProfileAvatar` ring (U-09); username Playfair headlineLarge glow-soft; `VCard` balance + gold shard lg (§5.3/§5.6); bio mutedStrong; hairline group tiles; `VEmptyView` empty voice (R9); R8 tap-to-edit; **skeleton loading now** (U-22 handoff). **FLAG F2:** the "Mis grupos" section label uses `labelLarge` sentence-case vs the R6 settings section-header voice (`labelSmall` uppercase mutedStrong) — two section-header patterns in the same feature |
| P2 | `edit_profile_screen` | **PASS** (1 flag) | `ProfileAvatar` + camera affordance (white/black P2 primitives, exempt); token VInput bio; **skeleton loading now**; save emphasized. **FLAG F4:** 'Cambiar contraseña' TextButton is a no-op (`onPressed: () {}`) — renders enabled, does nothing (pre-existing) |
| P3 | `settings_screen` | **PASS** (1 flag) | R6 grouping (labelSmall-uppercase headers + two VCards + transparent-Material rule); R7 sign-out confirm (danger pair, glowPink); SegmentedButton token-clean (§5.4); version footer mutedStrong outside cards (R10). **FLAG F4:** 'Notificaciones' + 'Privacidad' rows are no-op `onTap: () {}` (pre-existing placeholders) |
| P4 | `public_profile_screen` | **PASS** (1 flag) | header mirrors own-profile (avatar ring + Playfair + mutedStrong handle/bio); glowAccent-filled 'Agregar amigo'; shared-groups empty mutedStrong (§5.9); popup theme-owned; **skeleton loading now**. **FLAG F3:** the blocked/accepted/pending status buttons are `VButton.emphasized` with `onPressed: () {}` — they render enabled but do nothing; a disabled control should drop to `muted` (§5.1) — U-16-flow boundary, needs product input |
| P5 | `delete_account_screen` | **PASS** | glowAccent **outlined** danger CTA (U-09 decision); confirm dialog 'Eliminar' glowPink; email-match gate; pattern A |
| W1 | `profile_avatar.dart` | **PASS** | surfaceAlt fill + `border` ring + white w600 initials (size×0.25); `VNetworkImage` fallbacks (§5.8); the one circle geometry allowed (§4.2) |

**Cross-cutting (scope-wide):** colors — zero raw `Colors.*` (beyond the
exempt white/black/transparent P2 primitives) and zero ad-hoc hexes in scope;
typography — every Playfair site is a sanctioned §3.2 role, Inter elsewhere;
glow — exactly one breathing element and ≤1 glow CTA per screen after the
fixes; reduced motion — every ambient animation (VBreathingGlow/VShimmer)
gates on `MediaQuery.disableAnimationsOf`; responsive — all 14 screens are
pattern A/B or naturally scrolling, `test/features/responsive_test.dart` stays
green; state views — no bare spinner remains as a screen-level loading state
in scope (U-21 guard + the U-22 handoff below).

## Fixes applied (small + safe, TDD-pinned)

### FIX 1 — U-22's skeleton handoff: the last three `VLoadingView` sites in profile (3 screens)

Per U-22's handoff table ("profile → `VSkeletonProfile`, group_detail →
…, event_detail → …" — the profile row + the two profile-adjacent screens):
`profile_screen`, `edit_profile_screen`, `public_profile_screen` now render
`VSkeletonProfile()` (§5.8: surfaceAlt blocks, avatar-circle exception,
shimmer sweep, reduced-motion static) on first load instead of the bare
spinner. Refresh behavior unchanged (the screens' existing guards already
keep the content during refresh; only the nothing-on-screen first frame is
skeleton). No flow change; the avatar-upload 16px inline spinner (U-21
allowlist) untouched — its pin moved `:200 → :202` after my comment block
(guard RED-proven → fixed).

### FIX 2 — U-18's §6.2 breathing gap: the four remaining auth headers (4 screens)

The doc's §6.2 breathing scope names "display titles with glow-strong
(welcome wordmark, auth headers)". U-18 applied `VBreathingGlow` to
welcome/feed/coming-soon/OTP/banned and explicitly flagged
**signup_contact, age_gate, privacy_terms** as the remaining auth-header gap
("1-line-per-screen follow-up"; TODO.md handoff "§6.2 'auth headers'
breathing gap on the remaining auth screens"). `forgot_password_screen` was
born after U-18 (U-14 R3), so its header is the same gap. All four now render
the header through `VBreathingGlow` (glow-strong stack, α0.75→α1.0 alternate,
3000ms + idle-safe rest, reduced-motion → static full-α — the U-18 engine).
Exactly one breathing element per screen maintained; byte-identical rendering
at the α1.0 peak (the existing `_expectPlayfairHeader` pins stay green
unchanged).

## Flags (need product input — not fixed)

- **F1** — signup's primary CTA is `VButton.emphasized` (white fill) while the
  other four auth primaries (welcome/login/OTP/forgot) are filled glowAccent.
  Deliberate per U-07's handoff list, but the account-creation act is the
  funnel's strongest brand moment → decide: make it glowAccent-filled (1-line
  change, `_signup` CTA) or keep white as the funnel-middle voice.
- **F2** — two section-header voices in profile: `settings_screen` uses the R6
  pattern (uppercase `labelSmall` mutedStrong) while `profile_screen`'s "Mis
  grupos" and `public_profile_screen`'s "Grupos compartidos" use
  `labelLarge` sentence-case. Unifying = role swap + `toUpperCase` on 2
  headers (breaks the l10n text finders in flows); keeping = document the
  two-tier hierarchy (small section overlines vs large list-section titles).
- **F3** — public_profile status buttons (Bloqueado / Amigos / Pendiente /
  Aceptar solicitud) render `VButton.emphasized` enabled but with no-op
  handlers; per §5.1 a non-actionable control should read disabled (`muted`).
  U-16 flow boundary — the buttons are the friendship-state readout, not
  actions.
- **F4** — pre-existing no-op rows: settings 'Notificaciones' + 'Privacidad'
  (`onTap: () {}`), edit_profile 'Cambiar contraseña' (`onPressed: () {}`).
  Wire them or mark them disabled/coming-soon — currently they look tappable.
- **F5** — `welcome_screen` wordmark renders `welcomeVive` = "VIVE"; the doc
  §3.2 row notes the current literal. Copy decision (pre-existing,
  acknowledged by the doc) — flag only.

## Files modified (lock evidence — 13 locks, all U-23, all released)

| File | Change | Lock |
|---|---|---|
| `lib/features/profile/screens/profile_screen.dart` | FIX 1 (skeleton) | acquire 2ceaa479553376b48f7290ca → release |
| `lib/features/profile/screens/edit_profile_screen.dart` | FIX 1 (skeleton) | acquire f1cf0f586bb3ccdfbb40f25a → release |
| `lib/features/profile/screens/public_profile_screen.dart` | FIX 1 (skeleton) | acquire 0b26e4381837fce037d1384b → release |
| `lib/features/auth/screens/signup_contact_screen.dart` | FIX 2 (breathing header) | acquire 80229d247be74dcbc03a4f56 → release |
| `lib/features/auth/screens/age_gate_screen.dart` | FIX 2 (breathing header) | acquire 9eb326f703086e98f1ff65f6 → release |
| `lib/features/auth/screens/privacy_terms_screen.dart` | FIX 2 (breathing header) | acquire 3624869c4b495235178a546a → release |
| `lib/features/auth/screens/forgot_password_screen.dart` | FIX 2 (breathing header, form+success) | acquire d68531fe2083017329d00b14 → release |
| `test/features/profile_screens_test.dart` | loading pin VLoadingView → VSkeletonProfile (+skeleton-gone pin) | acquire 575e6990fb848854ba656266 → release |
| `test/features/profile/restyle_test.dart` | +3 skeleton first-frame pins; `pumpPublic` hoisted to main() scope | acquire 765fb6694340a1d079d9b51c → release |
| `test/features/auth/restyle_test.dart` | +4 breathing-header pins (§6.2 group) | acquire 101a4701741d0543e1fb5fe6 → release |
| `test/meta/conventions_test.dart` | U-21 spinner allowlist `edit_profile_screen.dart:200 → :202` (line drift from FIX 1's comment; I-48's file — lock-coordinated) | acquire → release |
| `docs/to-fix/TODO.md` | U-23 workstream block | acquire b802f899fb97030c6d655fd5 → release |
| `docs/history/phase-04-ui/2026-08-11_U23-review-auth-profile.md` | this log | created under its lock → release |

## Commands run (reproducibility)

```bash
export AGENT_NAME=U-23
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
flutter test test/features/auth/ test/features/profile/ \
  test/features/profile_screens_test.dart test/features/responsive_test.dart
                                                           # 153/153 baseline
tools/agent_lock.sh acquire <12 paths> --owner U-23        # all held (see table)
# RED: new pins written against the pre-fix tree — breathing pins failed
# (no VBreathingGlow on the 4 screens), skeleton pins failed (VLoadingView
# still present) → then GREEN with the 7 screen edits + the test updates
flutter test test/features/auth/restyle_test.dart \
  test/features/profile/restyle_test.dart \
  test/features/profile_screens_test.dart                  # 61/61 (54 + 7 new)
flutter test test/features/auth/ test/features/profile/ \
  test/features/profile_screens_test.dart test/features/responsive_test.dart
                                                           # 160/160
flutter test test/features/auth/auth_interactions_test.dart \
  test/features/auth/otp_ux_test.dart test/features/auth/banned_test.dart \
  test/features/profile/delete_account_flow_test.dart \
  test/features/profile/avatar_flow_test.dart \
  test/features/auth_screens_test.dart                     # 55/55 (neighbors)
dart analyze                                               # 0 issues
flutter test                                               # FULL SUITE 1988/0
#   (baseline 1981 → +7; the one regression — the U-21 spinner-allowlist
#   line drift — was caught by the conventions guard, fixed, suite re-run)
flutter test test/meta/conventions_test.dart               # 27/27
tools/agent_lock.sh release <path> --owner U-23            # all 13 released
```

## Test results

- `test/features/auth/restyle_test.dart` — **22/22** (18 pre-existing + 4 new
  §6.2 breathing pins).
- `test/features/profile/restyle_test.dart` — **18/18** (15 pre-existing +
  3 new skeleton first-frame pins).
- `test/features/profile_screens_test.dart` — loading pin updated to the
  skeleton (spinner + skeleton-gone assertions unchanged in spirit).
- Scope run (auth + profile + profile_screens + responsive) — **160/160**;
  neighbors (auth_screens/auth_interactions/otp_ux/banned/avatar_flow/
  delete_account_flow) — **55/55**.
- `test/features/responsive_test.dart` — **18/18** unchanged (the responsive
  suite must stay green — it did).
- `flutter test` (full) — **1988 pass / 0 failures** (U-22 baseline 1981,
  +7 = the new pins, zero regressions).
- `dart analyze` — **0 issues**.

## MISTAKE blocks

- **MISTAKE (self-caught, two test-edit slips):** (1) an edit that was meant
  to *insert* a new group before the DeleteAccountScreen group instead
  *replaced* the group's opening line, dropping the delete tests into the new
  group — caught by a group-scan, restored. (2) A similar oldString slip
  replaced the age-gate underage test with the new breathing group — restored
  verbatim from the pre-edit read. Both fixed before any test run; lesson:
  for test files, insert against a unique *trailing* anchor (the previous
  group's closing `});`) rather than the next group's opening line.
- **MISTAKE (scope creep, guarded):** `pumpPublic` was a local function
  inside the PublicProfileScreen group; the new skeleton group (sibling
  scope) couldn't call it — hoisted to `main()` level (no behavior change).
- **MISTAKE (line drift, caught by the campaign's own guard):** FIX 1's
  two-line comment above the profile loading branch shifted
  `edit_profile_screen.dart`'s allowlisted 16px avatar-upload spinner
  `:200 → :202` — the U-21 conventions guard RED-flagged it in the FULL
  suite (the guard proved its worth). Fixed the allowlist entry, re-ran.
- **MISTAKE (wrong test path):** the first neighbor run used
  `test/features/banned_test.dart` etc. — the M-23 restructure moved them
  under `test/features/auth/` and `test/features/profile/`; "Does not exist"
  load failures, corrected.

## Decisions made and why

- **Skeleton over spinner in profile = the U-22 handoff, honored as written.**
  The three screens have real hero geometry (`ProfileAvatar` + name lines) to
  mirror, so `VSkeletonProfile` is the correct §5.8 shape (not
  `VSkeletonList`/`VSkeletonDetail` — those are for row/card lists). The
  skeleton only stands in when nothing is on screen (the existing guards),
  exactly U-22's first-load contract.
- **Breathing on all auth headers now.** The doc §6.2 is the authority
  ("auth headers" are in the breathing scope) and U-18's TODO handoff names
  the gap explicitly; the mission's "fix the small ones" clause applies. The
  engine is idle-safe for tests (proven by welcome/OTP/banned) and
  reduced-motion-safe. One breathing element per screen preserved.
- **NOT fixed — the flags (F1..F5).** Each is either a product/hierarchy
  call (F1, F2), a flow-boundary state (F3), a pre-existing placeholder that
  needs product wiring (F4), or an acknowledged copy literal (F5). Changing
  any of them without product input would violate the review-pass discipline
  ("flag the big ones; fix the small ones").

## Issues found / handoffs

- **U-26 (a11y audit):** the new breathing sites use the identical §3.4 stack
  and amplitude floor (α0.75 → ≥4.75:1) as the U-18 sites — the audit can
  treat signup/age_gate/privacy_terms/forgot-password as already-audited;
  the skeleton sites are gray `surfaceAlt` blocks (no color contrast
  surface). The flagged no-op controls (F3/F4) ARE a11y-adjacent (a control
  that looks enabled but does nothing fails 2.1.1/4.1.2 semantics) — consider
  asserting disabled-state rendering in the audit.
- **U-27/U-28:** the new pins live in the existing restyle files
  (`test/features/auth/restyle_test.dart`, `test/features/profile/
  restyle_test.dart`) — extend there; the U-21 spinner allowlist now points
  at `edit_profile_screen.dart:202`.
- **U-30 (doc finalization):** (1) §6.2's breathing scope is now fully
  implemented on every auth screen — the "auth headers" wording can be made
  exhaustive; (2) `VSkeletonProfile` is now the canonical profile-loading
  state (consider a §5.8 line); (3) F1/F2 deserve a §5.1/§5.4-adjacent
  decision once product rules on them.
- **U-29 (integration smoke):** no new screens; the existing profile flow
  settles past the skeleton frame — no new assertions needed.
- **Pre-existing, reported (not touched):** `_getMemberLimit` '14' hardcode
  (I-46); friends-list `@username` double render (U-16); the F3/F4 no-op
  controls; F5 wordmark literal.

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §2/§3/§4/§5/§6/§7 (read in full — the
  contract).
- U-07/U-09/U-14/U-15/U-18/U-19/U-21/U-22 daily logs + handoff tables (the
  gaps this pass closed and the decisions it preserved).
- Flutter SDK (read-only, 3.44.1): `widgets/media_query.dart`
  (`disableAnimationsOf` — the reduced-motion gate every touched animation
  honors).
- WCAG 2.2 contrast pairs via the doc's §2 tables (all contrast decisions in
  this pass reuse already-verified ratios).

## Change log

| Date | Change |
|---|---|
| 2026-08-11 | v1.0 authored by U-23 (review pass auth→profile; 14-screen checklist; FIX 1 skeleton handoff + FIX 2 breathing gap; 5 product flags; 1988/1988 full suite). |
