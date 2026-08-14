# U-13 — Juega Flow Study: the flow-alignment report that feeds U-14..U-17 (2026-08-11)

**Agent:** U-13 | **Phase:** 04-ui (4.4) | **Status:** DONE (READ-ONLY research → report; no Samay code, no Juega code, no Juega infra touched)

**User directive (the campaign's north star):** *"Samay must look similar to Juega in UI AND FLOW but both are different with different colorschemes."* The **look** is done (U-01..U-12, flows byte-identical). This report delivers the **flow** comparison and the ordered change list for U-14 (auth/onboarding), U-15 (profile/settings), U-16 (friends/groups), U-17 (shell/tabs).

**Sources (read in full):**
- Samay: `lib/` (all 130 Dart files), `test/` + `integration_test/` (all), `docs/process/*` (AGENT-RULES, FILE-OWNERSHIP, ORCHESTRATION, DEVELOPMENT-WORKFLOW, AGENT-REGISTRY), `docs/design/DISCO-DESIGN-SYSTEM.md`, U-01..U-12 daily logs, `docs/to-fix/TODO.md`, `docs/to-fix/LESSONS_FROM_JUEGA.md`, `AGENTS.md`, `Makefile`, `pubspec.yaml`.
- Juega (`/Users/daerean/Codes/apps/Juega`, READ-ONLY): `lib/` (every Dart file: router, main_shell, all 6 auth screens + provider, profile, settings + 5 sub-screens, social (feed/friends/groups/requests/search/public-profile/group-detail/create-group/invite/blocked) + provider + service, leaderboard, shared widgets (premium_card, action_button, bottom_sheet, alert_dialog, error_view, error_banner, loading_overlay), `main.dart`), `integration_test/` (all 11), `test/` (structure + key files), `docs/to-fix/IMPLEMENTATION_PLAN.md`.

**Nothing was modified in Juega.** Locks held: this report + `docs/to-fix/TODO.md` only.

---

## 0. TL;DR — the flow scoreboard

Juega's **flow architecture** differs from Samay's in exactly four high-value ways:

1. **Juega has NO pre-auth funnel.** Splash → login (with an in-screen login/signup **toggle**) → OTP → **onboarding** (4-step PageView with a progress bar) → map. Samay has a 6-screen pre-auth funnel (welcome → signup → OTP → age gate → privacy/terms → profile setup) with **no onboarding step** and **no splash**.
2. **Juega's social surface lives INSIDE the feed tab** (Feed/Friends/Groups sub-tabs, pending-count badges, per-item processing spinners) instead of separate shell tabs (Samay: Grupos tab + friends via buttons).
3. **Juega's settings is a shell TAB** (5 tabs: map/feed/leaderboard/profile/settings); Samay has 5 tabs too (feed/grupos/eventos/notis/perfil) but settings is a pushed screen. Same tab count, different payload.
4. **Juega pushes detail sub-screens with `Navigator.push(MaterialPageRoute)`** while the shell tabs use go_router; Samay routes everything through go_router. (Samay's go_router-everything is *better* — see NOT-TO-COPY §4.2.)

Pattern counts: **18 'feel' patterns** catalogued (§3), **7 flow maps** (§2), **21 recommendations** (§5: U-14×5, U-15×5, U-16×7, U-17×4) — 13 DIRECT, 8 ADAPTED, plus **6 explicit NOT-to-copy flags** (§4.3).

---

## 1. Method

1. Read every Samay lib/test/doc file (per the campaign rules — no shortcuts).
2. Read every Juega lib/test/integration_test file + key docs. Extracted flow steps and "feel" decisions per screen.
3. Built the side-by-side flow maps (§2) with Juega evidence `file:line`.
4. Marked every pattern DIRECT (same pattern, copy the flow shape) or ADAPTED (reimagined for Samay's disco/social product) plus NOT-to-copy (fitness-specific).
5. Ordered the recommendations into U-14..U-17 scopes, each with Juega evidence, Samay target file (post-M-23 paths), change description, and test impact (which existing tests pin the behavior being changed — all `restyle_test.dart` files are render-only; flow changes touch `*_screens_test.dart`, `*_flow_test.dart`, `otp_ux_test`, `auth_interactions_test`, `app_router_test`, `main_shell_test`).
6. Re-verified every Juega cite by re-reading the cited lines; confirmed every Samay target file exists at the cited path (glob check).

---

## 2. Flow maps — Juega vs Samay, side by side

### 2.1 Auth / onboarding

| Step | Juega | Samay |
|---|---|---|
| Entry | `SplashScreen` (logo scale+fade, `AppDurations.splash` = 2200ms) → `context.go(login)` or `context.go(map/onboarding)` — splash does the full decision (`splash_screen.dart:41-119`) | No splash. `GoRouter(initialLocation: login)` (`app_router.dart:101`); the `AuthGuard` decides on route (`auth_guard.dart:27-41`) |
| Login / signup | **One screen, `_isLogin` toggle** — same form morphs, "¿No tienes cuenta? Regístrate" link swaps fields (`login_screen.dart:30,97,135,171`) | **Two separate screens**: `WelcomeScreen` (brand moment, glowAccent CTA + divider, `welcome_screen.dart:34-45`) → `LoginScreen` or `SignupContactScreen` |
| Validation | `Form` + `TextFormField.validator` (inline, per-field) | Manual `FormState`-style validators + `VInput.errorText` |
| Forgot password | **Dedicated route** `/forgot-password` (`forgot_password_screen.dart`; success state replaces the form in-place + floating snackbar `:139-163`) | **Inline TextButton on login** that calls `resetPasswordForEmail` with no screen and no feedback (`login_screen.dart:92-100`) |
| Signup OTP | Login screen pushes `OtpVerificationScreen` via `MaterialPageRoute` (`login_screen.dart:55-63`) | `context.push(RoutePaths.verify, extra: VerifyExtra(...))` (`signup_contact_screen.dart:86-89`) |
| OTP UX | Auto-verify **transition-guarded** (`shouldAutoVerify` — only on 0→6 chars, never backspace; `verify_email_screen.dart:36-42,373-388`); attempts-remaining counter with color shift (`:391-402`); **persisted** rate-limit block (SharedPreferences, hashed email) + `mm:ss` countdown (`:127-145,404-411`); resend cooldown 120s; "back to login" **signs out** (`:305-308`) | Auto-verify on 6 digits with a `_failedAttempts` counter (in-memory only, max 5 → blocked until resend) (`otp_verification_screen.dart:87-93,138-150`); resend cooldown 60s; no back-to-login; inline error text |
| Post-OTP | `routeAfterAuth()` → `map` or `onboarding` (`auth_provider.dart:246-261`) | → `ageGate` route (`otp_verification_screen.dart:135`) |
| Profile/onboarding | **4-step PageView onboarding** (activity/theme/privacy/obfuscation): animated progress bar, select-card options, CTA disabled until answered, save-on-finish with error snackbar (`onboarding_screen.dart:99-158,172-234`) | **5 sequential screens**: age gate (M3 date picker, `age_gate_screen.dart:50-73`) → privacy/terms (checkboxes) → profile setup (username + avatar placeholder, `profile_setup_screen.dart:37-50`) |
| Password reset (deep link) | Dedicated `/reset-password` screen (new password + confirm, success state) | Not present (GoTrue's magic-link reset lands nowhere in-app) |
| Banned | n/a (no ban concept in Juega) | `BannedScreen` route, guard-confined (`auth_guard.dart:23-25`) |

### 2.2 Shell + tabs

| Aspect | Juega | Samay |
|---|---|---|
| Shell route | `ShellRoute` + `MainShell`, 5 tabs (`app_router.dart:124-148`) | `ShellRoute` + `MainShell`, 5 tabs (`app_router.dart:179-219`) |
| Tabs | map / feed / leaderboard / profile / **settings** (`main_shell.dart:20-27`) | feed / grupos / eventos / notis / perfil (`main_shell.dart:20-51`) |
| Tab transition | 150ms fade-in (`main_shell.dart:40-43`), **reduced-motion honored** | none (go_router default) — U-18's job |
| Tab persistence | `NoTransitionPage` per tab → each tab keeps its state (`app_router.dart:129-146`) | plain `GoRoute` builders; shell keeps a `Navigator` per tab (state kept by go_router), but **each tab's screen remounts its providers on re-entry** |
| Nav bar form | Floating pill: `PremiumCard` blur card, `extendBody: true`, selected = accent tint + **indicator dot** + filled icon, unselected = outlined icon (`main_shell.dart:45-59,88-155`) | Standard `BottomNavigationBar`: outlined→filled icon swap only (U-08), black surface, no badge, no indicator dot (`main_shell.dart:76-91`) |
| Pending-count badge | **On the feed tab icon** (friend requests + group invites), only when not on that tab (`main_shell.dart:78,123-138`) | none anywhere in the shell |
| Settings | **A shell tab** | Pushed screen from profile AppBar (`profile_screen.dart:63-66`) |
| Connectivity | none (no offline banner) | `ConnectivityBanner` above the Navigator (all routes) (`app.dart:37-47`) |

### 2.3 Profile

| Step | Juega | Samay |
|---|---|---|
| Own profile | `SliverAppBar` expanded hero: avatar (accent ring, **tap-to-pick via file_picker**, `profile_screen.dart:56-88,191-225`), **inline edit-name dialog** (`:90-112`), rank label; stat cards row (`:234-247`); section headers + empty cards ("no prismas yet"…) | `ListView`: `ProfileAvatar` (initials; avatar upload lives in **edit profile** screen), Playfair username, `VBalanceCard` (shards/preshards, taps to ledger), groups list, cosmetics entry (`profile_screen.dart:69-176`) |
| Empty states | Inline `PremiumCard` empties with icon + hint per section (`:268-282,305-323,355-373`) | `Text`/inline empties (`profileNoGroupsYet` `:124-133`) |
| Edit | Dialog-based inline editing (name) | Full `EditProfileScreen` (avatar, username immutable, bio) |
| Detail of a list item (ride) | **`showRideDetail` dialog** — full detail in a modal (stats, map preview, photos, edit/delete) (`ride_detail_sheet.dart:25-34`) | n/a (no per-item detail on profile) |
| Refresh | no pull-to-refresh on own profile | `RefreshIndicator` + provider refresh (`profile_screen.dart:76-77`) |

### 2.4 Settings

| Aspect | Juega | Samay |
|---|---|---|
| Layout | **Grouped section cards**: VISUAL / PRIVACY / ACCOUNT / LEGAL / DEBUG, uppercase section headers, rows with value + chevron (`settings_screen.dart:80-198`) | Flat `ListView` of `ListTile`s + `Divider`s, no grouping (`settings_screen.dart:22-90`) |
| Theme | Row that **cycles** auto/light/dark with live value label (`:86-94`; toggle in onboarding too) | `SegmentedButton` (dark/system) with white/black styling (U-09) (`:156-183`) |
| Destructive rows | Sign out is a **danger-colored row inside the Account card** (`:145-152`) | Sign-out row + separate delete-account screen reachable from a danger row (`:60-65,67-74`) |
| Version footer | `versionFooter` centered at bottom (`:187-190`) | same (`:76-88`) |
| Sub-screens | `PrivacyZonesScreen`, `EulaScreen`, `PrivacyPolicyScreen`, `DebugLogScreen` — pushed with `MaterialPageRoute` | `BlockedUsersScreen`, `DeleteAccountScreen` — go_router pushes |

### 2.5 Friends / social

| Step | Juega | Samay |
|---|---|---|
| Entry | **Feed tab → Friends sub-tab** (`feed_screen.dart:120-145`) — the social surface is inside the feed | Friends entry buttons live on the **Grupos tab** (`my_groups_screen.dart:62-75`) + settings (blocked) |
| Landing layout | Action-tile row (Search / Requests / Blocked) with badge on Requests (`friends_tab.dart:62-108`) + friend cards | Friends list screen with inline search field (`friends_list_screen.dart:38-103`) |
| Friend row | Card, avatar, name, **overflow menu → remove** (`friends_tab.dart:254-293`) | `ListTile` + presence dot + chevron, tap → public profile (`friends_list_screen.dart:83-98`) |
| Requests | 3 tabs with **count badges on Received + Invitations** (`requests_screen.dart:104-157`); **per-row `isProcessing` spinners** inside accept/decline buttons (`:213-247,370-403`); pull-to-refresh per tab | 3 tabs, **no badges**, accept/decline as TextButtons with no per-item busy state (`requests_screen.dart:60-96,122-133`) |
| Search | 300ms debounce (`search_screen.dart:49`), **autofocus** (`:88`), status pills, **mutual-friend dialog** when the RPC returns 'accepted' (`:208-226`), unblock from search (`:236-245`) | 300ms config-driven debounce (`search_screen.dart:39-53`), `VButton.outlined` add-friend, no autofocus, snackbar on send (`:58-73`) |
| Public profile | Big avatar + name + **single status button** (add / pending / already-friends + remove / unblock), block via overflow menu (`public_profile_screen.dart:99-225`) | Avatar + `@handle` + bio + shared-groups placeholder + status button matrix + block/report overflow (`public_profile_screen.dart:141-257`) |

### 2.6 Groups

| Step | Juega | Samay |
|---|---|---|
| Landing | Groups sub-tab: create-team CTA card + group cards (cover, name, description, role chip) (`groups_tab.dart:84-145`) | Grupos shell tab: create/ranking buttons row + friends/requests links + group tiles (`my_groups_screen.dart:33-140`) |
| Create | Simple 2-field form (name + description), full-width accent CTA (`create_group_screen.dart:74-119`) | Cover picker + name + description + limit dialog (bigger form) (`create_group_screen.dart` — same shape, more fields) |
| Detail | Description + member count + **leave button inline** (with `JuegaAlertDialog` confirm, `group_detail_screen.dart:160-181`); member rows with **tap → actions bottom sheet** (kick/promote/demote/transfer, admin-gated, `:55-107`); pull-to-refresh (`:184`) | Tabbed detail (chat/members/events): hero Playfair name, donate/create/invite CTA row, frozen banner, members tab with contributor section, leave via **overflow menu** (`group_detail_screen.dart:113-135,317-340`) |
| Invite | Multi-select rows (selected = accent border + check circle), **sticky bottom CTA with count** when ≥1 selected, per-user success/failure summary snackbar then pop (`invite_screen.dart:91-115,159-180`) | Multi-select rows (Checkbox), **AppBar action button with count** (`invite_screen.dart:100-106`), single success snackbar (`:73-78`) |
| Donate (shards) | n/a (no currency) | `DonateShardsScreen` — amount field, snackbar errors, glowAccent CTA (`donate_shards_screen.dart:30-66,99-104`) |
| Leaderboard | Leaderboard is a **shell tab** (global, prisma-based) | Ranking is a pushed screen with tier chips (`leaderboard_screen.dart:29-67`) |

### 2.7 Feed

| Step | Juega | Samay |
|---|---|---|
| Structure | Feed header + **3 sub-tabs** (Feed/Friends/Groups) in a rounded container (`feed_screen.dart:84-160`) | Feed hero (Playfair glow) + radius chips + featured carousel + upcoming list (`feed_screen.dart:38-110`) |
| Loading | Accent spinner (`feed_screen.dart:180`) | `VLoadingView` (white spinner, §5.8) |
| Error | Plain centered text, **no retry** (`:181`) | `ErrorView` with retry (`:42-45`) |
| Empty | "No activity" centered text, still pull-to-refreshable (`:186-203`) | `VEmptyView` (icon + title + description) (`:100-107`) |
| Infinite scroll | `loadMore()` at the end of the list (`:217-228`) | none (single fetch) |
| Pull-to-refresh | Yes, both states (`:187,205`) | Yes (`:49-50`) |
| Cards | Author + action text + obfuscated time-ago + route map preview + like/comment placeholders (`:253-373`) | Cover + name + type/scope badges + date + location (`:354-454`) |
| Post time | **Obfuscated** by author's privacy setting (`:268-281`) | n/a (event dates, not posts) |

---

## 3. The 'feel' patterns list (18 patterns)

The 18 recurring decisions that make Juega *feel* like Juega, with Juega evidence and the Samay verdict.

| # | Pattern | Juega evidence | Samay today | Verdict |
|---|---|---|---|---|
| F1 | **Initial loading = centered accent spinner** on every list/screen, never a skeleton | `friends_tab.dart:38`, `groups_tab.dart:35`, `feed_screen.dart:180` | `VLoadingView` white spinner — **already equivalent** (§5.8) | DIRECT (already matched) |
| F2 | **Empty state = icon + text + hint, centered, still scrollable + refreshable** (`SizedBox(0.4–0.6×h)`) | `friends_tab.dart:112-128`, `requests_screen.dart:178-183`, `blocked_users_screen.dart:72-75` | `VEmptyView` (icon+title+desc) but **no CTA/hint on most** and often not wrapped in `RefreshIndicator` | DIRECT (extend, not replace) |
| F3 | **Pull-to-refresh on every data list — including empty and error states** | `friends_tab.dart:43`, `groups_tab.dart:39,84`, `requests_screen.dart:254,327,411`, `blocked_users_screen.dart:69`, `feed_screen.dart:187,205` | feed/profile yes; **friends list, requests tabs, groups list: NO** | DIRECT |
| F4 | **Per-item busy state** — the exact row being acted on shows an inline spinner; other rows stay interactive | `requests_screen.dart:213-247` (`isProcessing(r.friendshipId)`), `blocked_users_screen.dart:105-123`, provider `friends_groups_provider.dart:58-60,130-141` | global `_sending` bools; buttons disabled app-wide or not at all | DIRECT |
| F5 | **Count badges on request/invite entry points** (tab icons, action tiles, nav bar) | `main_shell.dart:123-138`, `friends_tab.dart:83,203-218`, `requests_screen.dart:104-157` | none | DIRECT |
| F6 | **Debounce + autofocus on every search field** | `search_screen.dart:49,88`, `invite_screen.dart:78,144` | debounce yes (config-driven); **autofocus no** | DIRECT |
| F7 | **Success/error feedback = floating snackbar, always; error text only for validation** | `invite_screen.dart:107-113`, `search_screen.dart` (dialog for mutual), `onboarding_screen.dart:155-158`, `forgot_password_screen.dart:44-51` | snackbars yes; mixed with inline `showAppError` blocking dialogs (`login_screen.dart:55`, `signup_contact_screen.dart:97`) | ADAPTED |
| F8 | **Confirmations = themed dialog with destructive variant + barrier-dismissible** | `juega_alert_dialog.dart:35-67`, `group_detail_screen.dart:164-175`, `profile_screen.dart:119-142` | raw `AlertDialog`s, correct semantics, but no shared widget (6+ hand-rolled sites) | DIRECT |
| F9 | **Bottom sheet = the secondary detail/actions surface** (member actions, with handle) | `juega_bottom_sheet.dart:17-66`, `group_detail_screen.dart:83-93` | none used (dialogs + popup menus instead) | ADAPTED |
| F10 | **Full-screen error view = message + retry, compact** | `juega_error_view.dart:9-58` | `ErrorView` with icon + retry — **already equivalent** (better: icon) | DIRECT (already matched) |
| F11 | **Back-nav: every pushed screen has an explicit back affordance** (leading arrow, often custom-styled) | `requests_screen.dart:67-70`, `search_screen.dart:76-79`, `group_detail_screen.dart:127-130` | default AppBar back (go_router) — equivalent; **no custom handles needed** | DIRECT (already matched) |
| F12 | **Tab persistence across switches** (`NoTransitionPage`, shell `Navigator` per tab) | `app_router.dart:129-146` | go_router shell keeps per-tab navigators — equivalent; **but re-entry re-fetches** because screens watch providers that refetch on mount | ADAPTED |
| F13 | **Reduced-motion honored on every animation** (fade gate, static glow) | `main_shell.dart:35,40-43` | tokens/glow spec honor `disableAnimations` (§6.2); shell has no animation yet | DIRECT (pending U-18) |
| F14 | **In-place success states** (form morphs into a confirmation, no new route) | `forgot_password_screen.dart:139-163`, `reset_password_screen.dart:85-100` | n/a (Samay has no such flows) | ADAPTED |
| F15 | **Theme choice applied live** (picked during onboarding, togglable in settings) | `onboarding_screen.dart:91-97`, `settings_screen.dart:86-94` | settings `SegmentedButton` only | ADAPTED |
| F16 | **List rows are cards with 12-16px radius on a colored surface**, not hairline-separated tiles | every list (friends/groups/requests/search/blocked/members) | hairline rows on black (§4.2 radius = 0 — **deliberately different, see NOT-TO-COPY N2**) | NOT-TO-COPY |
| F17 | **Text scale clamped 0.85–1.15 app-wide** | `main.dart:306-316` | full textScaler honored, no clamp (§7.3) | NOT-TO-COPY (a11y regression — §7.3 wins) |
| F18 | **Settings = grouped section cards with uppercase headers + value rows** | `settings_screen.dart:80-198` | flat divider list | ADAPTED (grouping pattern yes; card look per N2) |

---

## 4. The DIFFERENT-PRODUCT guard

### 4.1 DIRECT (12) — same pattern, same flow shape
F1/F2/F3/F4/F5/F6/F8/F10/F11/F13 + the onboarding-progress-bar concept and the settings-grouping concept (F18) *in flow terms*.

### 4.2 ADAPTED (6) — the pattern is right, the product is different
1. **F7 feedback** — Juega's bare floating snackbars become Samay's snackbar-vs-`showAppError` policy (blocking dialogs stay for auth-level errors; snackbars for row actions) — already Samay's convention; keep it, standardize placement.
2. **F9 bottom sheet** — Juega uses sheets for member actions; Samay should keep dialogs for **confirmations** (danger reads better in a dialog, U-04 dialogTheme is already black+sharp) and use the sheet only where a *list of choices* is needed (member actions, report reasons) — the disco sheet spec is U-18/U-19's.
3. **F12 tab persistence** — Samay keeps go_router (correct for deep links + the invite-token routing); the *flow* improvement is provider-level: shell-tab providers should not refetch the world on every tab return (Juega solves this with `lastFetchedAt` throttling, `friends_groups_provider.dart:90-119`).
4. **F14 in-place success** — applies to Samay's OTP verify → "email already registered" case, and to the future forgot-password screen (U-14): morph, don't navigate.
5. **F15 live theme** — Samay is dark-only (P1); the *flow* worth copying is "preference chosen once early, changed later in settings" — for Samay that preference is the **profile username/bio and the onboarding of interests** (social-discovery framing), not a theme.
6. **F18 settings grouping** — adopt the *grouping* (Visual/Account/Legal sections) with Samay's sharp hairline cards (VCard), not Juega's rounded glass cards.

### 4.3 NOT-to-copy (6 explicit flags — fitness-specific or brand-violating)
- **N1 — Fitness metrics everywhere** (km/month, rides, avg speed): Samay's "stats" are shards, rank, group contributions. Don't add stat-card rows to the profile unless they're shard/rank/leaderboard stats (already present via the balance card).
- **N2 — Rounded glass cards (`PremiumCard` blur, radius xxl)** — violates DISCO §1 P2 (no gradients/no rounded pastel) and §4.2 (radius = 0 everywhere except avatars/dots). The nav pill, the stat cards, the feed cards, the setting cards: **none** of that chrome transfers. The *structure* transfers, the material does not.
- **N3 — Accent-colored spinners everywhere** (`CircularProgressIndicator(color: accent)`): §5.8 says white spinner; accent is reserved for brand moments (welcome/checkout). Keep `VLoadingView` white.
- **N4 — Text-scale clamp 0.85–1.15** (`main.dart:306-316`): DISCO §7.3 mandates honoring the system textScaler; a clamp is a WCAG 1.4.4 regression. Do not copy.
- **N5 — Emoji-driven content** (onboarding steps 🚴🎨🔒⏱️, feed avatars with emoji, "🔮"/"🔥" stat decorations): not the disco voice (P2 minimalist; Playfair + Inter; no emoji in brand surfaces).
- **N6 — The 5-tab layout with settings as a tab**: Samay's tab bar is already 5 tabs and its events/notis tabs are *product* tabs; adding settings as a 6th tab (or replacing a product tab) would trade discoverability for chrome. Settings stays a pushed screen (Juega only made it a tab because it has 3 spare slots: map/leaderboard/profile/settings).

---

## 5. Ordered recommendations — the U-14..U-17 scope

Every row: **Juega evidence** (file:line, re-verified) → **Samay target** (post-M-23 path) → **change** → **test impact**.

### 5.1 U-14 — Auth / onboarding (5 recs, ordered)

| # | Rec | DIRECT/ADAPTED | Juega evidence | Samay target | Change | Test impact |
|---|---|---|---|---|---|---|
| R1 | **Add a "back to login" affordance on the OTP screen that signs out and returns to login** (Juega's `_back()` also clears the transient session; it's the *escape hatch* of the pre-auth funnel) | DIRECT | `verify_email_screen.dart:305-308,466-472` | `lib/features/auth/screens/otp_verification_screen.dart` | Add a `TextButton` ("Volver a iniciar sesión") below resend: `signOut()` + `context.go(RoutePaths.login)` (guard the "email already registered" dialog path — it already signs out). New l10n key. | `otp_ux_test.dart` + `auth_interactions_test.dart`: +1-2 tests (tap back → login route, session cleared). Existing 72 auth tests stay green. |
| R2 | **Add the attempts-remaining counter to the OTP screen** (Juega shows `N restantes` with a color shift to error at ≤1; Samay only blocks silently at 5) | DIRECT | `verify_email_screen.dart:391-402` | `lib/features/auth/screens/otp_verification_screen.dart` | Render `authOtpAttemptsRemaining(n)` when `_failedAttempts > 0`; color `AppColors.error` when ≤1. New l10n key. | `test/features/auth/otp_ux_test.dart`: +2 (counter appears after a wrong code; turns glowPink at 1). |
| R3 | **Replace the inline forgot-password TextButton with a real `/forgot-password` screen (email → in-place success state + floating snackbar)** | DIRECT | `forgot_password_screen.dart:36-60,94-163` (route `app_router.dart:37`) | new `lib/features/auth/screens/forgot_password_screen.dart` + route in `lib/core/router/app_router.dart` | Port the screen with the disco treatment (displayMedium header — §3.2 auth site; `VInput`; success state swaps the form; snackbar). Login's inline button → `context.push(RoutePaths.forgotPassword)`. 2 new l10n keys + `RoutePaths` entry. | `test/features/auth/auth_interactions_test.dart`: the existing "forgot password" assertion must be repointed (it currently taps the inline button and asserts no navigation); +1-2 tests (form → success; snackbar). `app_router_test` route table +1. |
| R4 | **Collapse the welcome screen into the login/signup toggle? NO — keep Samay's welcome screen** (brand moment, P3/P4: the Playfair wordmark + glowAccent CTA is the product's signature; Juega's toggle exists because its login screen *is* its brand moment). **Instead: reduce the funnel cost** — welcome's secondary CTA stays "Iniciar sesión"; no flow change. | ADAPTED (explicit keep) | `login_screen.dart:30,171` (the thing we deliberately do NOT copy) | `lib/features/auth/screens/welcome_screen.dart` | **No change.** Documented so U-14 doesn't "align" it away. | none |
| R5 | **Post-OTP profile bootstrap: keep the 3-screen funnel (age gate → privacy/terms → profile setup) but add the missing *completion signal*** — Juega's onboarding shows progress and a final "start" CTA; Samay's last step (profile setup) already ends at the shell. **ADAPTED scope:** only add the OTP→funnel progress feel via the existing `profile_setup` header (already `displayMedium`); **defer a true onboarding merge to a post-MVP decision** — the age gate is a legal requirement (Peru L29733/MVP), privacy consent must be explicit, so Juega's "4 preference cards" pattern is NOT the Samay shape (N5 + legal). | ADAPTED (keep legal funnel) | `onboarding_screen.dart:172-234` (progress bar + step CTA — the *feel* to borrow) | `lib/features/auth/screens/otp_verification_screen.dart` + `age_gate_screen.dart` | Optional polish only: keep byte-identical flows; add nothing mandatory. | none (defer) |

### 5.2 U-15 — Profile / settings (5 recs, ordered)

| # | Rec | DIRECT/ADAPTED | Juega evidence | Samay target | Change | Test impact |
|---|---|---|---|---|---|---|
| R6 | **Group the settings screen into sections with uppercase headers** (VISUAL/ACCOUNT/LEGAL-shaped: "Apariencia", "Cuenta", "Legal") — keep the flat sharp rows (VCard grouping, hairline dividers — N2) | ADAPTED | `settings_screen.dart:80-198` (headers `:201-211`, cards `:213-231`) | `lib/features/profile/screens/settings_screen.dart` | Wrap rows in `VCard`-per-section with `labelSmall` mutedStrong uppercase headers (l10n keys; §2.4-safe). | `test/features/profile_screens_test.dart` + `restyle_test.dart`: settings finders stay text-based → mostly green; +2-3 (section headers render). |
| R7 | **Move sign-out + delete into a danger *pair* at the bottom of the account section and add a confirm dialog to sign-out** (Juega signs out with zero confirmation from a danger row — Samay should *improve*: a confirm dialog prevents accidental logout, matching the delete flow's dialog discipline) | ADAPTED | `settings_screen.dart:145-152` | `lib/features/profile/screens/settings_screen.dart` | Keep rows; add `AlertDialog` confirm on sign-out (destructive variant per F8). New l10n key. | `test/features/profile_screens_test.dart`: the sign-out test must tap through the confirm dialog; +1 test. |
| R8 | **Add inline edit affordance on the profile header** (Juega edits display name from the profile itself — the avatar tap and the name tap both open editors) | ADAPTED | `profile_screen.dart:56-88` (avatar pick), `:90-112` (inline name dialog) | `lib/features/profile/screens/profile_screen.dart` | Wrap the header avatar + name in tap targets → `context.push(RoutePaths.profileEdit)` (the existing edit screen is the Samay-shaped editor; an inline dialog would violate the sharp-dialog spec for a form this size). **Avatar tap** is the new affordance (currently only editable via edit screen). | `test/features/profile_screens_test.dart` + `avatar_flow_test.dart`: +2 (avatar tap opens edit; name tap opens edit). |
| R9 | **Profile empty states: adopt the icon+title+hint voice for the groups box** (Juega's per-section empty cards; Samay's "Sin grupos aún" is a bare `Text` in a 60px box) | DIRECT | `profile_screen.dart:268-282,305-323` | `lib/features/profile/screens/profile_screen.dart:124-133` | Replace the 60px `Text` with `VEmptyView(icon: group_outlined, title: profileNoGroupsYet, description: profileNoGroupsHint?)` — new l10n key for the hint. | `restyle_test.dart`: +1-2 (VEmptyView present, strings). |
| R10 | **Version footer + theme picker stay as-is** (both already exceed Juega: `SegmentedButton` ≥ cycling row — it shows *all* options; footer already `mutedStrong` AA). No change. | DIRECT (explicit keep) | `settings_screen.dart:86-94` (worse pattern) | `lib/features/profile/screens/settings_screen.dart:156-183` | none | none |

### 5.3 U-16 — Friends / groups (7 recs, ordered)

| # | Rec | DIRECT/ADAPTED | Juega evidence | Samay target | Change | Test impact |
|---|---|---|---|---|---|---|
| R11 | **Add per-item busy spinners to the requests accept/decline buttons** (the strongest flow-feel win in the social surface) | DIRECT | `requests_screen.dart:213-247,370-403`; provider `friends_groups_provider.dart:58-60` | `lib/features/friends/screens/requests_screen.dart` + `lib/features/friends/providers/friends_providers.dart` | Add an `isProcessing(id)` set to the requests provider (or local state); swap the tapped action to a 16-20px spinner while in flight. | `test/features/friends_screens_test.dart` + `restyle_test.dart`: +2 (spinner appears on tapped row; other row's button still enabled). |
| R12 | **Add count badges to the Requests tabs** (Received + Invites) and to the entry points (friends-list/requests buttons on the Grupos tab) | DIRECT | `requests_screen.dart:104-157`, `friends_tab.dart:83,203-218` | `lib/features/friends/screens/requests_screen.dart`; entry rows in `lib/features/groups/screens/my_groups_screen.dart:62-75` | Badge on the received/invites `Tab`s (count from the already-loaded providers); small `VBadge.accent`-style counter on the "Solicitudes" button. | `restyle_test.dart` +2 (badges render with data, hidden with none). |
| R13 | **Wrap the friends/requests/blocked/groups lists in pull-to-refresh, including their empty states** | DIRECT | `friends_tab.dart:43`, `groups_tab.dart:39,84`, `requests_screen.dart:254,327,411`, `blocked_users_screen.dart:69` | `friends_list_screen.dart`, `requests_screen.dart`, `blocked_users_screen.dart`, `my_groups_screen.dart` | `RefreshIndicator` + `AlwaysScrollableScrollPhysics` around each list *and* empty state (invalidate the corresponding provider). | `test/features/friends_screens_test.dart` etc.: +1 per screen (drag → invalidate called). Existing assertions unchanged. |
| R14 | **Add autofocus + the 2-char min-hint to the friend search** (Juega autofocuses; Samay's invite screen already has the min-chars hint — mirror it on search) | DIRECT | `search_screen.dart:88` (autofocus), `invite_screen.dart:129-137` (min-chars hint, Samay's own) | `lib/features/friends/screens/search_screen.dart` | `autofocus: true` on the search `TextField`; reuse the existing `groupsMinCharsHint`-style hint when `query.length < 2`. | `test/features/friends_screens_test.dart`: +1 (keyboard focus on entry — `tester.testTextInput`). |
| R15 | **Mutual-friend success dialog on "Agregar amigo" when the RPC reports instant-accept** (Juega's atomic `send_friend_request` returns 'accepted'; Samay's repository returns the friendship status — check it and show the dialog) | DIRECT | `search_screen.dart:208-226`, `public_profile_screen.dart:133-151` | `lib/features/friends/screens/search_screen.dart:58-73` + `lib/features/profile/screens/public_profile_screen.dart:74-95` | If `sendFriendRequest` returns `accepted`, show the existing-style dialog (title + "Se aceptó al instante…" + OK) before refreshing. New l10n key. | `test/features/friends_screens_test.dart`: +1 (repo stub returns accepted → dialog). |
| R16 | **Group-detail: move "Abandonar grupo" from the overflow menu to an inline danger row under the member count** (Juega's inline leave with confirm dialog; Samay buries it in the menu) | ADAPTED | `group_detail_screen.dart:160-181` | `lib/features/groups/screens/group_detail_screen.dart` | Keep the existing confirm `AlertDialog` (Samay-shaped), relocate the trigger: danger `TextButton.icon` next to the member count (mirroring Juega's row), remove the menu item (keep the frozen item if frozen). | `test/features/groups_screens_test.dart`: the leave test taps the new row; `restyle_test.dart`: +1. |
| R17 | **Group member actions bottom sheet for admins (kick/promote/demote)** — the members tab rows become tappable for admins, opening a sharp themed sheet (U-18 provides the sheet chrome); non-admins see nothing | ADAPTED | `group_detail_screen.dart:55-107,197-199` | `lib/features/groups/screens/group_members_screen.dart` (+ `group_detail_screen.dart` members tab) | Sheet with admin-gated options; actions call the existing `groupsRepositoryProvider` member-role RPCs; **confirm kick via dialog** (F8). | `test/features/groups_screens_test.dart` + `restyle_test.dart`: +3 (sheet opens for admin, options gated, kick confirms). |

### 5.4 U-17 — Shell / tabs (4 recs, ordered)

| # | Rec | DIRECT/ADAPTED | Juega evidence | Samay target | Change | Test impact |
|---|---|---|---|---|---|---|
| R18 | **Pending-count badge on the shell (Grupos tab)** — friend requests + group invites counted and shown on the Grupos tab icon when not on it (Juega shows it on the feed tab — Samay's requests entry is the Grupos tab, so the badge follows the entry) | DIRECT | `main_shell.dart:78,123-138` | `lib/core/router/main_shell.dart` | Watch a lightweight "pending counts" provider (friendRequests + groupInvites lengths — both already exist); render a `VBadge`-styled counter on the Grupos `BottomNavigationBarItem` when `> 0`. `shellIndexFor` untouched. | `test/router/main_shell_test.dart`: +2 (badge with data, hidden without; badge disappears when the tab is active). |
| R19 | **Add the shell fade-in transition honoring reduced motion** (150ms opacity cross-fade on tab switch; static under `disableAnimations`) | DIRECT | `main_shell.dart:35,40-43` | `lib/core/router/main_shell.dart` | `AnimatedSwitcher`/FadeTransition keyed on `currentIndex`, duration `SamayDurations.fast` (150ms), `easeOutCubic`; skip when `MediaQuery.disableAnimations`. | `test/router/main_shell_test.dart`: +2 (transition widget present; static under reduced-motion). Coordination with U-18. |
| R20 | **Tab re-entry staleness: throttle shell-tab refetches** (Juega's `refresh()` skips when < 15s old — prevents the "refetch the world on every tab switch" feel) | ADAPTED | `friends_groups_provider.dart:90-119` | `lib/features/groups/providers/groups_providers.dart`, `lib/features/friends/providers/friends_providers.dart`, `lib/features/profile/providers/profile_providers.dart` | Add a `lastFetchedAt` guard to the family providers' refresh paths (or rely on Riverpod keepAlive where already present). Must not mask real invalidation from actions. | `test/providers/*`: +1 per provider (refresh within 15s → no refetch; after → refetch). |
| R21 | **Keep settings pushed (NOT a 6th tab)** and keep `mainFeed` as `initialLocation` (post-login landing); only verify the tab order stays product-first (feed → groups → events → notis → profile) | ADAPTED (explicit keep) | `app_router.dart:124-148` (the 5-tab shell we do NOT mirror) | `lib/core/router/app_router.dart` + `main_shell.dart` | none (documented) | none |

---

## 6. What Juega does better in flow — and what the restyles preserved

**Juega's genuine flow wins (all captured in §5):**
1. **The funnel is 3 screens, not 8** (login/OTP/onboarding vs welcome/signup/OTP/age/privacy/setup) — but Samay's extra screens are legal/brand (age gate, consent, Playfair wordmark), so the *win* Samay can take is **feel, not count**: progress signals, escape hatches, and busy states (R1, R2, R5).
2. **Every actionable row tells you it's working** (per-item spinners, status pills, count badges) — Samay's binary "button disabled vs enabled" loses that tactile honesty (R11, R12, R15).
3. **The social surface is one discoverable place** (feed tab sub-tabs) vs Samay's friends-buttons-buried-on-groups-tab. **This is a product decision, not a flow copy** — Samay's current entry points stay; the *feel* (badges, refresh, autofocus) transfers (R12, R13, R14).
4. **Pull-to-refresh is universal** — Samay's data lists that lack it feel dead next to Juega (R13).
5. **Error handling is calm** — compact views + snackbars, no blocking dialogs for row actions; Samay's `showAppError(blocking: true)` on auth is correct, but the restyle pass already replaced most row-action errors with snackbars (U-07..U-12 zero-change contracts kept those in place) (F7).

**What the U-01..U-12 restyles preserved (verified, nothing regressed):**
- Every flow decision the restyles made was **byte-identical** — routes, labels, taps, dialogs, validators (pinned by the untouched `*_screens_test.dart` files and the per-feature `restyle_test.dart` RED/GREEN ledgers).
- The **loading/empty/error voice** (`VLoadingView`/`VEmptyView`/`ErrorView`) is now ahead of Juega (icon + AA-contrast text vs Juega's bare centered `Text` in places — e.g. `feed_screen.dart:181` has *no retry*).
- The **shell already swaps outlined→filled icons** (U-08) — Juega's equivalent with a dot; the badge (R18) is the missing half.

---

## 7. Disco-brand constraints (guard rails for U-14..U-17)

1. **Fancy titles are spent, not multiplied** (§3.2 exhaustive): the new screens/rows in R1-R17 must NOT add Playfair sites — every recommendation above uses Inter + existing token roles.
2. **Glow discipline** (§2.5 rule 3): ≤1 glow accent per screen. R12's badges are `VBadge.accent`-scale (tiny), R18's shell badge is a 9-10px counter — both within budget; no new glow fills.
3. **Sharpness** (§4.2): all new surfaces (R6's section cards, R17's sheet, R8's affordances) are radius-0 with hairlines. The Juega glass/radius is explicitly N2.
4. **Black always + AA text** (§1 P1, §2.4): every new string uses `mutedStrong`/white; error states use `AppColors.error` (glowPink), never raw red; the sign-out confirm (R7) follows the delete-account dialog precedent (`delete_account_screen.dart:56-83`).
5. **Reduced motion** (§6.2/§7.5): R19's fade and any future sheet animation must gate on `disableAnimations` (U-18's contract).

---

## 8. Issues found (READ-ONLY — reported, not touched)

1. **Juega `integration_test/auth_flow_test.dart:170-174` asserts "Continuar con Google"/"Continuar con Apple" strings that no longer exist in the login screen** (only in ARB: `app_es.arb:100`). Juega's own integration suite has stale assertions — a caution for U-29's Samay smoke suite (assert behaviors that exist).
2. **Samay pre-existing (reported by U-11, still open):** `group_detail_screen._getMemberLimit` hardcodes `'14'` (`group_detail_screen.dart:305-308`) — out of scope for U-16 flow work (data fix, I-46).
3. **Samay `friends_list_screen.dart:89-90` renders `@username` twice** (title + subtitle) — pre-existing; a flow-cleanup candidate for U-16 (Juega shows name only), but it is a *content* change (l10n/behavior) — flag for the U-16 agent to decide with the orchestrator.
4. **Samay search has no min-length hint while invite has one** (`invite_screen.dart:129-137` vs `search_screen.dart:94-95` shows nothing until the query is non-empty) — inconsistency surfaced by the F6 pattern; folded into R14.
5. **Juega `groups_tab.dart:39` error state renders literal 'Error' text** — Samay's `ErrorView` is strictly better; no action.
6. **`docs/design/DISCO-DESIGN-SYSTEM.md` §5.3 promises a `VCard.featured` widget that never shipped** (U-08 handoff; inline Container instead) — already flagged to U-30; this study confirms no new card variants are needed for R6.

---

## 9. Verification log (per the mission)

- **Juega cites re-verified by re-reading:** `main_shell.dart:40-43,78,105,123-138`; `splash_screen.dart:41-119`; `login_screen.dart:30,47-64,97,124-135,171`; `verify_email_screen.dart:36-42,98,127-145,373-388,391-402,404-411,466-472`; `onboarding_screen.dart:91-97,99-158,172-234`; `forgot_password_screen.dart:36-60,94-163`; `reset_password_screen.dart:85-100`; `feed_screen.dart:84-160,180-248`; `friends_tab.dart:43,62-108,112-128,203-218,254-293`; `groups_tab.dart:39,84,92-122`; `requests_screen.dart:104-157,178-183,213-247,254,327,339,411`; `search_screen.dart:49,76-91,208-226,236-245`; `public_profile_screen.dart:99-225`; `group_detail_screen.dart:55-107,127-130,160-181,197-199`; `invite_screen.dart:78,91-115,129-137,144,159-180`; `create_group_screen.dart:74-119`; `blocked_users_screen.dart:69-75,105-123`; `settings_screen.dart:80-198,201-211,213-231`; `profile_screen.dart:56-112,119-142,191-225,268-282,305-323`; `juega_bottom_sheet.dart:17-66`; `juega_alert_dialog.dart:35-67`; `juega_error_view.dart:9-58`; `juega_error_banner.dart:10-70`; `juega_loading_overlay.dart:20-46`; `friends_groups_provider.dart:58-60,90-119,130-141`; `app_router.dart:25-39,124-148`; `main.dart:306-316`; `app_durations.dart:4-9`; `app_config.dart:4-7`; `auth_provider.dart:246-261`.
- **Every Samay target exists at the cited path** (glob-verified, post-M-23 layout): all `lib/features/{auth,profile,friends,groups,feed}/screens/*`, `lib/core/router/{app_router,main_shell,auth_guard}.dart`, `lib/shared/widgets/state_views.dart` etc.
- **Scope discipline:** all recommendations are flow-scoped to U-14..U-17; no changes to data layer, repositories, or routes' semantics beyond R3's new route; no Samay code modified by this agent.

---

## 10. Sources consulted

- Juega app source (read-only): `/Users/daerean/Codes/apps/Juega/lib/**` (all), `integration_test/**` (all), `test/**` (structure + key files), `docs/to-fix/IMPLEMENTATION_PLAN.md`, `docs/to-fix/TODO.md`.
- Samay: `docs/design/DISCO-DESIGN-SYSTEM.md` (full), `docs/process/*` (full), `docs/history/phase-04-ui/2026-08-11_U01..U12-*.md` (all 12), `docs/to-fix/TODO.md`, `docs/to-fix/LESSONS_FROM_JUEGA.md`, `lib/**` + `test/**` + `integration_test/**` (all).
- Flutter SDK (read-only, 3.44.1) — not needed for this read-only pass beyond patterns already documented in U-07..U-12 logs.

## 11. Change log

| Date | Change |
|---|---|
| 2026-08-11 | v1.0 authored by U-13 (flow study; feeds U-14..U-17 + TODO.md workstream block). |
