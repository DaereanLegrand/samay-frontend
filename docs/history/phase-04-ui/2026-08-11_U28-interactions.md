# U-28 — Interaction-test completion: the U-series behavior coverage audit + missing interaction tests (2026-08-11)

**Agent:** U-28 | **Phase:** 04-ui (4.4) — `test/features/**` UI interaction tests for the restyled screens (U-28) | **Status:** DONE

Contract: `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md` +
`docs/process/DEVELOPMENT-WORKFLOW.md` (read in full), the I-45 interaction-suite log
(`docs/history/phase-02-flutter-foundation/2026-08-09_I45-widget-interactions.md`)
+ its gaps, the U-series behavior-change logs (U-14 auth flow, U-15 profile
flow, U-16 friends/groups flow, U-17 shell flow, U-18 motion, U-26 a11y —
the behaviors whose interaction paths must be covered), U-23..U-25/U-27
review/test handoffs, AGENTS.md, `docs/to-fix/TODO.md`. Baseline before
edits: `dart analyze` **0 issues**; full `flutter test` **2009/0** (U-27
checkpoint). Method: hermetic widget tests only (ProviderContainer overrides +
mocktail — the campaign pattern); zero production-code changes.

## 1. The interaction-coverage audit (screen → interaction tests)

Every screen in `lib/features/` was mapped to its interaction coverage
(`tap`/`enterText`/`fling`/`drag`/`scrollUntilVisible`/`ensureVisible` in
`test/features/`). Verdict legend: ✅ full interaction coverage · 🟡 partial
(render + states, some interactions) · ❌ render-only.

| Screen | Interactions tested | File | Verdict |
|---|---|---|---|
| `login_screen` | enterText→signIn→feed nav, empty/whitespace guards, AsyncError inline+dialog, forgot-password nav | `auth_interactions_test` | ✅ |
| `signup_contact_screen` | mismatch/weak/valid → checkEmail+sendOtp → OTP nav, double-tap guard | `auth_interactions_test` | ✅ |
| `otp_verification_screen` | resend countdown, auto-submit 6th digit, manual verify, success→age gate, 5-failure block, **R1 back-link** (signOut+login), **R2 attempts counter** | `otp_ux_test` | ✅ |
| `forgot_password_screen` | login nav, empty/invalid guards, send→success+snackbar, back-to-login, error keeps form | `auth_interactions_test` | ✅ |
| `age_gate_screen` | **GAP → +2 (this pass):** date-picker interaction, underage error+disabled CTA, adult→privacy-terms push | `auth_interactions_test` | ✅ now |
| `privacy_terms_screen` | **GAP → +1 (this pass):** CTA disabled until both consents, tap disabled CTA no-op, both consents → profile-setup push | `auth_interactions_test` | ✅ now |
| `profile_setup_screen` | empty-username guard, save→createProfile→feed | `auth_interactions_test` | ✅ |
| `banned_screen` | ban-state render + redirect | `banned_test` | ✅ |
| `profile_screen` | **R7-adjacent:** avatar/username tap→edit, pull-to-refresh, cosmetics flag rows | `profile_screens_test` | ✅ |
| `settings_screen` | **R7 sign-out confirm** (cancel keeps session / confirm signs out → login), theme picker; **GAP → +1:** disabled Notificaciones/Privacidad rows tap→nothing | `profile_screens_test` | ✅ now |
| `edit_profile_screen` | prefills from provider; **GAP → +1:** disabled 'Cambiar contraseña' tap→nothing | `profile_screens_test` | ✅ now |
| `public_profile_screen` | **R15 mutual dialog** (search + public-profile accepted send); **GAP → +2:** disabled 'Bloqueado'/'Amigos' status taps→no dialog/no service call | `friends/flow_test` | ✅ now |
| `delete_account_screen` | empty/wrong-email guards, full delete flow → login, mismatch snackbar | `profile_screens_test` + `delete_account_flow_test` | ✅ |
| `friends_list_screen` | **R13 refresh** (list + 2 empties), error retry, rows | `friends/flow_test` + `friends_screens_test` | ✅ |
| `search_screen` | **R14 autofocus + min-chars hint + 2-char results, R15 mutual dialog**, debounce, error retry | `friends/flow_test` + `friends_screens_test` | ✅ |
| `requests_screen` | **R11 per-row spinners** (accept/decline/cancel/invite), **R12 tab badges**, **R13 refresh**, service calls + reloads; **GAP → +1:** badge count live update | `friends/flow_test` + `friends_screens_test` | ✅ now |
| `blocked_users_screen` | **R13 refresh** (list + empty), unblock render | `friends/flow_test` + `friends_screens_test` | ✅ |
| `my_groups_screen` | **R12 Solicitudes badge**, **R13 refresh** (list + empty) | `friends/flow_test` | ✅ |
| `group_detail_screen` | **R16 inline leave** full flow (row→dialog→service→pop), **R17 members-tab sheet**, donate nav, frozen menu | `groups/flow_test` + `groups_screens_test` | ✅ |
| `group_members_screen` | **R17 sheet:** open with role-fitting options, non-admin never opens, kick confirm→service→reload, promote→setMemberRole, **GAP → +1:** kick failure → F7 snackbar + sheet stays | `groups/flow_test` | ✅ now |
| `create_group_screen` | cover upload, create w/ + w/o cover, 5-group limit dialog, empty/whitespace guards | `groups_screens_test` | ✅ |
| `invite_screen` | search, member exclusion, debounce | `groups_screens_test` | ✅ |
| `donate_shards_screen` | invalid amounts (0/abc); **GAP → +2:** valid amount → donateToGroup+success snackbar+pop; failure → snackbar+stays | `groups_screens_test` | ✅ now |
| `leaderboard_screen` | render/skeleton/error only; **GAP → +2:** tier-chip tap re-watches the family member, row tap → group-detail nav | `groups_screens_test` | ✅ now |
| `notification_center_screen` | tap→markRead, deep-link nav, mark-all-read, realtime insert, empty | `notification_center_test` | ✅ |
| `chat_screen` | send+clear, empty guard, load-older, undecryptable label | `chat_screen_test` | ✅ |
| `feed_screen` | radius chips select, retry reload, pull-to-refresh, card→detail; **GAP → +1:** empty-feed pull-to-refresh | `feed_test` | ✅ now |
| `create_event` / `event_detail` / `event_edit` | full create submit flow, date-row labels, edit submit+pop, cancel-event dialog, co_promotor gating, skeleton pins | `create_event_test` + `event_detail_test` | ✅ |
| `shard_ledger` / `cosmetics` / `minigames` / `photos` / `party_finder` / `qr` / `subscriptions` | state + navigation interactions (I-53..I-74-era suites + U-25 pins) | per-feature tests | ✅ |
| `main_shell` (router) | tab taps, **R18 badge** render/hide/active-hide, **R19 fade**, R21; **GAP → +1:** badge count live update | `main_shell_test` | ✅ now |

**Count:** 3 screens upgraded from render-only to fully interactive (age_gate,
privacy_terms — the pre-existing I-45-era gap on the post-OTP legal funnel);
13 interaction gaps closed across 7 files; +15 tests total.

## 2. The additions (all TDD: written first, GREEN-proven against the current tree)

| # | Mission item | Test | File |
|---|---|---|---|
| 1 | (5) disabled controls | tapping the 'Bloqueado' status readout fires no action: no dialog, no snackbar, `verifyNever` on send/decline, `getBlockStatus` called exactly once | `friends/flow_test.dart` |
| 2 | (5) disabled controls | tapping the 'Amigos' status readout fires no action | `friends/flow_test.dart` |
| 3 | (5) disabled controls | settings 'Notificaciones' + 'Privacidad' rows: tap → no dialog, settings stays | `profile_screens_test.dart` |
| 4 | (5) disabled controls | edit-profile 'Cambiar contraseña': tap → no dialog/snackbar/navigation | `profile_screens_test.dart` |
| 5 | (3) member sheet | failed kick → mapped F7 error snackbar ('Error del servidor'), sheet stays open, no reload (`getGroupMembers` once) | `groups/flow_test.dart` |
| 6 | (4) refresh on empties | the EMPTY feed is still pull-to-refreshable (service `listCalls ≥ 2` on a fling) | `feed_test.dart` |
| 7 | (7) badges count updates | requests-tab badge count follows the pending data live (2 → 1 via a container-level refresh) | `friends/flow_test.dart` |
| 8 | (7) badges count updates | shell Grupos-tab badge count follows the pending data live (3 → 1) | `main_shell_test.dart` |
| 9 | audit gap: auth | age gate: underage DOB (year-grid pick) → §5.2 error + Continuar stays disabled | `auth_interactions_test.dart` |
| 10 | audit gap: auth | age gate: adult DOB → Continuar enables → pushes privacy-terms (legal funnel, U-14 R5) | `auth_interactions_test.dart` |
| 11 | audit gap: auth | privacy terms: 'Crear cuenta' disabled until BOTH consents, tap disabled CTA no-op, both ticked → profile-setup push | `auth_interactions_test.dart` |
| 12 | audit gap: groups | leaderboard tier-chip tap re-watches that family member (shared recording list — the family override instantiates one notifier per member) + chip selected state | `groups_screens_test.dart` |
| 13 | audit gap: groups | leaderboard row tap pushes the group-detail route | `groups_screens_test.dart` |
| 14 | audit gap: groups | donate valid amount → `donateToGroup(groupId, 120)` + success snackbar + pop | `groups_screens_test.dart` |
| 15 | audit gap: groups | donate failure → mapped error snackbar + form stays | `groups_screens_test.dart` |

**Already covered (verified, no additions needed):** the forgot-password flow
(U-14 R3 — `auth_interactions_test` ForgotPasswordScreen group, 6 tests), the
sign-out confirm (U-15 R7 — `profile_screens_test`, cancel/confirm pair), the
member-sheet happy paths (U-16 R17 — `groups/flow_test`, 5 tests), the
friends/groups/blocked/my-groups empty-state refreshes (U-16 R13 — 9 tests),
the OTP back-link (U-14 R1 — `otp_ux_test`, 2 tests), and the disabled
*semantics* of the no-op controls (U-26 — `a11y_test` §4.1.2 group). The
disabled-control interaction angle (tap → nothing) was the one untested
dimension — now closed.

## 3. Files modified (lock evidence — 9 locks, all U-28, all released)

| File | Change | Lock |
|---|---|---|
| `test/features/auth/auth_interactions_test.dart` | +2 routes (privacy/setup markers) + 3 tests (age gate ×2, privacy terms ×1) | acquire 07294416877a9084953e9675 → release |
| `test/features/feed/feed_test.dart` | +1 (empty feed refresh) | acquire 72c70e18c25aed6168c26b12 → release |
| `test/router/main_shell_test.dart` | +2 live notifiers + 1 test (badge count update) | acquire e2c6946ae08ea9f81f808ac2 → release |
| `test/features/friends/flow_test.dart` | +1 live notifier + 3 tests (badge update, disabled status ×2) | acquire f1caf2a4103bce41511eeeab → release |
| `test/features/groups/flow_test.dart` | +1 test (kick-failure snackbar) | acquire f9d3520e5d36b001532fb161 → release |
| `test/features/groups_screens_test.dart` | +2 mocks/notifiers + 4 tests (donate ×2, leaderboard ×2) | acquire 9ea1ffdaa35c892f05693294 → release |
| `test/features/profile_screens_test.dart` | +2 tests (disabled rows, password no-op) | acquire 575e6990fb848854ba656266 → release |
| `docs/to-fix/TODO.md` | U-28 workstream block | acquire b802f899fb97030c6d655fd5 → release |
| `docs/history/phase-04-ui/2026-08-11_U28-interactions.md` | this log | created under its lock (4e544c6cd8bbfd41db48dfc7) → release |

## 4. Commands run (reproducibility)

```bash
export AGENT_NAME=U-28
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
flutter test <7 target files>                              # baseline 140/140
tools/agent_lock.sh acquire <9 paths> --owner U-28        # all held (16:04Z)
# RED/GREEN per file (each new test written, run, fixed):
#   MISTAKE 1: the underage year '2014' sat below the year-grid fold — the
#     missed tap landed on the dialog's actions bar and closed it. Fixed with
#     tester.ensureVisible on the year finder.
#   MISTAKE 2: the family override instantiates ONE notifier per family
#     member — the leaderboard chip test's recording notifier only ever saw
#     'micro'. Fixed with an injected shared recording list.
#   MISTAKE 3: const MaterialApp(theme: _navTheme()) — method call in a const
#     context; dropped the const on the MaterialApp.
#   MISTAKE 4: groups_screens_test has no _wrap helper — used _pump.
dart format <7 test files>                                # all formatted
dart analyze                                               # 0 issues
flutter test <7 target files + feed/ dir>                  # 163/163
flutter test                                               # FULL 2024/0 (run 1)
flutter test                                               # FULL 2024/0 (run 2)
tools/agent_lock.sh release <path> --owner U-28            # all 9 released
```

## 5. Test results

- **+15 tests** across 7 files (2009 baseline → **2024**).
- Scope run (the 7 touched files + `test/features/feed/`) — **163/163**.
- `dart analyze` — **0 issues** (final; `dart format`-clean).
- **Full suite ×2 — 2024 pass / 0 failures each** (zero regressions; the
  a11y, responsive, conventions-guard, l10n, and U-series restyle suites all
  stayed green unchanged).

## 6. MISTAKE blocks

- **MISTAKE (year-grid fold):** the underage test tapped `find.text('2014')`
  inside the year grid, but the year sits below the 600px viewport — the tap
  "missed" the Text and landed on the dialog's actions overflow bar (closing
  the dialog mid-helper). `tester.ensureVisible(yearFinder)` before the tap
  fixes it; the M3 year grid is a lazy ListView, so an off-fold year is
  *findable but not hittable*.
- **MISTAKE (family override semantics):** for `AsyncNotifierProvider.family`,
  `overrideWith(() => notifierInstance)` instantiates a **fresh notifier per
  family member** — the leaderboard chip test recorded only `['micro']` even
  though the tap fired. The recording list must be injected/shared, not
  notifier-owned. (The first RED run proved the tap worked; the assertion
  itself was wrong.)
- **MISTAKE (const context):** `const MaterialApp(theme: _navTheme())` —
  `_navTheme()` is a method invocation; analyzer-flagged, dropped the const.
- **MISTAKE (helper mismatch):** the donate-failure + leaderboard tests
  initially used a `_wrap` helper that exists in `friends/flow_test.dart` but
  not in `groups_screens_test.dart` — compile-RED, repointed to `_pump`.

## 7. Decisions made and why

- **Zero production-code changes.** Every gap was a test-side gap; the
  behaviors were already implemented (U-14..U-17, U-26) and their
  *semantic/rendering* contracts pinned — this pass closes the interaction
  dimension (tap → what happens) without touching any screen.
- **Age-gate + privacy-terms were the last render-only auth screens.** I-45's
  original suite covered login/signup/OTP/setup but stopped at the legal
  funnel (render pins in `auth_screens_test.dart` only); U-14 R5 explicitly
  kept the funnel, so its interactive gates deserve the same treatment as the
  rest of auth. The date-picker test drives the real Material es picker
  (year-toggle → year-grid → 'ACEPTAR') instead of stubbing `showDatePicker`
  — the full user path, including the year-mode affordance.
- **Live badge updates pinned at the provider-refresh seam.** Both badge
  tests mutate the notifier's data and force a container-level refresh
  (`container.refresh(provider)` — an external invalidation that bypasses
  the R20 throttle by design), then assert the re-derived count. This is the
  honest "count updates" contract: the badge follows the pending data, not
  just the mount-time value.
- **Disabled-control no-ops asserted at the interaction level** (tap → no
  dialog/snackbar/navigation + `verifyNever` on service calls), complementing
  U-26's semantic assertions (disabled flags) — the two pin the same contract
  from both the behavior and the accessibility side.
- **Donate success/failure + leaderboard chips/rows** were the remaining
  interaction gaps in groups (a screen whose taps existed in code but had
  zero behavioral pins) — closed with mocktail repository mocks.

## 8. Issues found / handoffs

- **U-29 (integration smoke):** nothing device-bound needed — all fifteen
  additions are widget-harness interactions (the legal funnel, badge
  reactivity, and refresh-on-empty are covered hermetically). If the smoke
  pass wants one flow row, the age-gate → privacy-terms → profile-setup chain
  now has a widget-level ledger it can mirror on device.
- **U-30 (doc finalization):** (1) the age-gate/privacy-terms interaction
  suite means the DISCO §5.1 "disabled CTA" language now has behavioral pins
  on the legal funnel; (2) the leaderboard tier chips + row push are now
  pinned (a §5.4 family-select pattern if the doc wants a line).
- **V-05 (test matrix):** the interaction matrix in this log (§1) is the
  per-screen tap/enterText/refresh ledger for the 4.4 completion evidence.
- **Pre-existing, reported (not touched):** the F1..F7 product flags from
  U-23..U-25 remain open (signup CTA voice, section-header voices, event
  badge vocabulary, create-family CTA, 18px/40px icon scales, attendance-qr
  action-as-widget, event-type uppercase); `_getMemberLimit` '14' hardcode
  (I-46); the stale `test/README.md` baseline text (D-05/I-48).

## 9. Sources consulted

- `docs/history/phase-02-flutter-foundation/2026-08-09_I45-widget-interactions.md`
  (the original interaction suite + its gap list — the audit's baseline).
- U-14/U-15/U-16/U-17/U-18/U-23..U-27 daily logs + handoff tables (the
  behavior paths this pass pins).
- Flutter SDK (read-only, 3.44.1): `material/date_picker.dart` (M3 year-grid
  toggle + es `MaterialLocalizations` 'ACEPTAR' — the probe-driven selectors),
  `widgets/scrollable.dart` (`Scrollable.ensureVisible` for the year-grid
  fold), Riverpod 2.x family-override semantics (one notifier per member).
- `test/support/fake_supabase_http.dart` + the existing flow-test harnesses
  (the hermetic patterns reused verbatim).

## 10. Change log

| Date | Change |
|---|---|
| 2026-08-11 | v1.0 authored by U-28 (interaction audit table; +15 tests across 7 files: legal-funnel interactions, disabled-control no-ops, badge live updates, empty-feed refresh, kick-failure snackbar, donate success/failure, leaderboard chips/rows; 2024/2024 full suite ×2). |
