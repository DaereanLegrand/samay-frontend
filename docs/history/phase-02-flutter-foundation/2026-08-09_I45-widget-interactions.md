# 2026-08-09 — I-45: Widget interaction tests (TST-07 / M-14)

**Agent:** I-45 (interaction/error/loading/empty widget tests for `test/features/**`)
**Status:** DONE
**Scope:** `test/features/auth/auth_interactions_test.dart` (new), `test/features/profile/delete_account_flow_test.dart` (new),
`test/support/fake_supabase_http.dart` (new), `test/features/groups_screens_test.dart` (3 new tests),
`test/features/friends_screens_test.dart` (4 new tests), `docs/to-fix/TODO.md` (M-14 status), this log.

## Audit — what existed before (TST-07 gap)

| Screen test file | Interactions tested before I-45 | Gaps filled by I-45 |
|---|---|---|
| `auth_screens_test.dart` | none (pump + find.text only) | → new `auth/auth_interactions_test.dart`: login enterText→signIn→navigation, login AsyncError inline+blocking dialog, empty-fields guard, signup password mismatch / weak-password validation, valid signup → checkEmail+sendOtp → OTP navigation, profile-setup empty-username guard + createProfile call + feed navigation |
| `friends_screens_test.dart` | tab taps, debounce (I-21), provider loading/empty/error states | RequestsScreen accept/decline → service call + provider reload; group-invite accept → service + reload; SearchScreen AsyncError → ErrorView |
| `groups_screens_test.dart` | cover-upload + create flows, 5-group limit dialog (I-36), provider states | CreateGroupScreen empty-name guard (no service call); GroupDetailScreen donate navigation; leave-group confirm-dialog flow (cancel + confirm → service call → pop) |
| `profile_screens_test.dart` | delete-account empty/wrong-email guards | → new `profile/delete_account_flow_test.dart`: matching-email → confirm dialog → deleteAccount called → login navigation; mismatch → snackbar |
| `otp_ux_test.dart` (I-29), `banned_test.dart` (I-35), `avatar_flow_test.dart` (I-36) | already full interaction coverage | (no changes — reference patterns) |

## What was built

1. **`test/support/fake_supabase_http.dart`** — hermetic Supabase harness for widget tests:
   - `RecordingHttpClient extends http.BaseClient` — answers every PostgREST request with `200 []`
     (content-type json) and **records method + URL** so tests assert the exact service calls
     (`sent(method, 'key=value')` helper). Zero network. `package:http` import carries an
     `// ignore_for_file: depend_on_referenced_packages` (it is a transitive dep pinned by
     supabase_flutter; test seams are the only direct importers).
   - `MemoryLocalStorage`/`MemoryAsyncStorage` (the proven H-01 pattern) + `seededSessionJson` +
     `initSupabaseHarness({sessionEmail})` — idempotent per test process, `autoRefreshToken: false`.
     The seeded session makes `SupabaseService.instance.auth.currentUser` resolve (needed by the
     delete-account email match and the leave-group service) **without any network**: the fake
     access token is not a real JWT → `expiresAt == null` → gotrue treats it as not expired and
     never refreshes (verified in gotrue 2.20.0 `Session.fromJson`/`recoverSession`).
   - **Why this seam:** `requests_screen.dart`, `group_detail_screen.dart` and `search_screen.dart`
     call `SupabaseService.instance.*` (final singleton, private ctor — not mockable), so
     ProviderContainer overrides cannot reach those calls; the injected `httpClient` at
     `Supabase.initialize` is the only hermetic boundary.
2. **`test/features/auth/auth_interactions_test.dart`** (8 tests) — `_RecordingAuthNotifier extends
   AuthNotifier` injected via `authStateProvider.overrideWith` (the I-29 pattern) recording
   `signIn`/`checkEmail`/`sendOtp`/`createProfile`, with a router harness (`/main/feed` marker,
   real `/auth/verify` route). Covers the full login/signup/profile-setup interaction contracts.
3. **`test/features/profile/delete_account_flow_test.dart`** (2 tests) — seeded-session harness +
   fake notifier; confirms `deleteAccount()` fires and navigation to login; mismatch → snackbar.
4. **`test/features/groups_screens_test.dart`** — `_pumpGroupDetail` router harness (push-based so
   `context.pop()` has a parent) + `_loadedGroupDetailOverrides`; 3 new tests (empty-name guard,
   donate navigation via `router.state.matchedLocation`, leave-group dialog cancel/confirm flow
   asserting the DELETE hits `group_members?group_id=eq.<id>` and the pop lands on `/home`).
5. **`test/features/friends_screens_test.dart`** — `_CountingFriendRequestsNotifier` /
   `_CountingGroupInvitesNotifier` (rebuild counters = the `ref.invalidate` reload contract);
   4 new tests asserting PATCH/DELETE requests to `friendships`/`group_members` plus the reload,
   and SearchScreen error state → `ErrorView` + retry.

## MISTAKE blocks

- **MISTAKE (harness, finder):** tapping `find.text('Eliminar cuenta').last` did NOT trigger the
  button — `.last` resolved to the AppBar title text. Switched to `find.widgetWithText(TextButton, …)`,
  which is robust. (Same class of bug as the `LoginScreen` existing test which already used
  `widgetWithText` — I should have copied that immediately.)
- **MISTAKE (harness, HTTP):** first `RecordingHttpClient` build returned a `StreamedResponse`
  without `request:`. postgrest 2.8.0 + http 1.6.0: `BaseClient._sendUnstreamed` calls
  `Response.fromStream(await send(request))` **without** forwarding the request, and postgrest
  `_parseResponse` dereferences `response.request!.headers` → `_TypeError: Null check operator…`.
  Fix: attach `request` to the `StreamedResponse` (it propagates through `Response.fromStream`).
- **MISTAKE (harness, router):** `router.go()` replaces the stack — the leave-group flow's
  `context.pop()` threw `GoError: There is nothing to pop`. Fix: `router.push()` in the harness.
- **MISTAKE (attempted):** `const ValidationError(...)` — `ValidationError` has no const ctor.

## Tests (RED → GREEN)

```bash
flutter test test/features/auth/auth_interactions_test.dart    # 8/8 pass
flutter test test/features/profile/delete_account_flow_test.dart # 2/2 pass
flutter test test/features/groups_screens_test.dart            # 25/25 pass (was 22)
flutter test test/features/friends_screens_test.dart           # 15/15 pass (was 11)
flutter test test/features/                                    # 117 pass / 1 fail
flutter analyze <my 5 files>                                   # No issues found!
```

Full suite at completion: **905+ pass, 4 unique failing tests** — `config_provider_test.dart` (1),
`user_provider_test.dart` (1), `realtime_service_test.dart` (2) — all **I-44-owned files still under
lock mid-write** (mocktail verification failures/timeouts in their in-flight tests), plus a flaky
`chat_e2ee_test.dart` loading failure (I-38 in-flight). **None of my files or previously-green
files fail.** The 12 I-44 "loading" failures from the session baseline are gone (their files now
compile) — the failure *set* changed only by other agents' in-flight work.

## Commands run

```bash
export AGENT_NAME="I-45-widget-interactions"
tools/agent_lock.sh acquire test/support/fake_supabase_http.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire test/features/auth/auth_interactions_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire test/features/profile/delete_account_flow_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire test/features/groups_screens_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire test/features/friends_screens_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire docs/history/phase-02-flutter-foundation/2026-08-09_I45-widget-interactions.md --owner "$AGENT_NAME"
tools/agent_lock.sh acquire docs/to-fix/TODO.md --owner "$AGENT_NAME"   # waited for I-44's lock, then updated M-14
# ... edit + validate ...
tools/agent_lock.sh release <each path> --owner "$AGENT_NAME"
```

## Issues found / reported (not fixed — out of scope)

- `requests_screen.dart` / `group_detail_screen.dart` / `search_screen.dart` / `blocked_users_screen.dart`
  still reach `SupabaseService.instance` directly (singleton) — unmockable at the provider layer.
  Tested hermetically via the injected HTTP client; migrating these call sites to the decomposed
  service providers (I-11 seam) would make them provider-overridable. Pre-existing M-38/H-14 tail.
- `chat_e2ee_test.dart` (I-38) fails on `subscribeToMessages decrypts realtime rows before delivery`
  — unrelated to this work (verified with/without my files); reported for I-38.
- `04-TESTING.md` TST-07 row left for D-03/I-44 (D-03 owns the category files; I-44 holds its lock);
  TODO.md M-14 updated here per assignment.
- Integration suite: no new flow file — these interactions (provider-injected error/empty/loading
  states, validation guards) are widget-harness territory; `integration_test/auth_flow_test.dart`
  already covers the end-to-end auth navigation hermetically (same rationale as I-29's log).
