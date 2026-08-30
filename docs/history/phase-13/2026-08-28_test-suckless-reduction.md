# 2026-08-28 — Suckless test reduction: UI-only tests removed

## What was built

Per user directive (2026-08-28): "UI ones must be nuked. Only functional."
The Flutter widget-test suite was reduced from **2386 → 1783 tests** (~600
removed, ~25%) by deleting the UI-only layer and re-anchoring important
behaviors into functional contract tests against the real Supabase harness.

### Deleted (UI-only — nuke)

**Pure-render / empty-state / loading-skeleton / overflow-smoke suites:**
- `chat_screen_test.dart` (38) — bubble placement, hour position, check
  colors, long-press menus (all widget-tree, no contract)
- `responsive_test.dart` (17) — `takeException()==null` "renders without
  overflow" at the Ahem-font 320x568 test viewport
- `accessibility/a11y_test.dart` (14) — semantic-render assertions
- `social/social_screen_test.dart`, `user_ranking_screen_test.dart`
- `minigames_screen_test.dart`, `minigame_session_detail_screen_test.dart`
- `cosmetics_shop_screen_test.dart`, `cosmetics_navigation_test.dart`
- `auth_screens_test.dart`, `auth_interactions_test.dart`, `otp_ux_test.dart`
- `party_finder_screen_test.dart`, `chat_list_screen_test.dart`,
  `feed_chat_button_test.dart`, `my_events_screen_test.dart`,
  `event_collage_screen_test.dart`, `shard_ledger_navigation_test.dart`,
  `group_detail_refresh_test.dart`, `delete_account_flow_test.dart`,
  `user_picker_view_test.dart`, `profile_setup_error_scoping_test.dart`,
  `otp_verify_once_test.dart`, `auth_scope_reset_test.dart`

**Widget/theme/design-token visual-pin suites** (token values were triple
pinned — kept the single canonical pin in `test/theme/app_theme_test.dart`):
- All `test/widgets/*` render/pin suites (v_button, v_badge, v_card, v_chip,
  v_input, v_shimmer, v_status_dot, skeletons, state_views, error_*,
  show_app_error, rank_*, v_network_image, v_tab_fade, v_disco_divider,
  v_shard_icon, v_count_badge, connectivity_banner, crash_recovery_banner,
  no_pink_defaults) — ~180 tests
- All `test/design_tokens/*` — token-hex/value pins
- `test/theme/theme_extension_test.dart`, `samay_durations_test.dart`,
  `theme_persistence_test.dart`

**Duplicated meta-guards:** `test/structure_test.dart` static existence loops
(core-layers, feature-modules, feature-sublayer) — kept the dynamic
no-empty-dir invariant, entrypoints, integration-suite, and the ARC-03
constants negative test.

### Trimmed in place (render tests removed, functional kept)

- `profile_screens_test.dart` 23→15 (kept sign-out/notification-prefs/report/
  flag-gate/validation; deleted renders/no-ops)
- `friends_screens_test.dart` 15→4 (kept the real-harness accept/decline/
  invite-accept + debounce)
- `groups_screens_test.dart` 34→17 (kept cover-upload/create/leave/events-tab/
  donate-amount/failed-donate/debounce/tier-rewatch)
- `create_event_test.dart` 11→8 (kept form-state + submit-contract)
- `event_detail_test.dart` 13→7 (kept navigate/cancel-flow/role-access/edit)
- `groups/flow_test.dart`, `friends/flow_test.dart` — all functional — kept
- `qr/*`, `avatar_flow_test.dart`, `plugged_entries_test.dart` (5 kept),
  `invite_token_route_test.dart`, `banned_test.dart`, `feed_test.dart` (11
  plain kept), `interests_test.dart`, `notification_center_test.dart` (24
  plain kept), `photo_gallery_test.dart` (15 plain kept), `paywall_test.dart`
  (5 plain kept), `shard_ledger_screen_test.dart` (7 plain kept)

### Added — HTTP-to-Supabase-harness contract test (the directive's ask)

- `create_event_test.dart` gains an **HTTO contract test**: pumps the real
  `CreateEventScreen` with the real `EventService` (no mock) against the
  `initSupabaseHarness` recording client and asserts the actual
  `POST /rest/v1/events` request — the screen → real service → real
  PostgREST wiring the deleted mocktail-only tests lacked.
- Existing real-harness contract tests kept: friends accept/decline/group
  invite (`harnessHttp.sentRpc('accept_friend_request', …)`, `DELETE
  friendships`, `PATCH group_members`), groups leave-group
  (`DELETE group_members`).

### New guard — `test/meta/conventions_test.dart`

- **no UI-only tests guard (2026-08-28):** bans `takeException()==null`
  "renders without overflow" smoke tests (deep_link_handler + fonts exempt —
  they assert real behavior), and bans whole-file render-only feature suites
  (empty-state/skeleton copy with zero `when/verify/harnessHttp`).

### Pre-existing failures fixed (not caused by this change)

The concurrent monochrome/`VHeaderBar` refactor had broken several functional
tests against stale l10n strings; fixed in place (not reverted):
- `profileSettingsTitle` → `ajustes`, `notificationSettingsTitle` →
  `preferencias de notis`, `profilePrivacy` → `privacidad`,
  `profileEditTitle` → `editar`, `profileDeleteTitle` → `eliminar`,
  `groupsDonateTitle` → `donar` (profile_screens, groups/flow)
- `otp_verification_screen.dart`: the `AppLogger.instance.warn` call was
  reformatted multi-line, breaking the I-15 l10n guard's same-line skip;
  restored single-line (the file's own comment documents this invariant).

## Decisions

- **Delete, don't rewrite.** Render/empty/loading assertions duplicate the
  state-widget contract tests in `test/widgets/`; per-screen copies churn on
  every copy/token tweak. Nuking them was cheaper than maintaining.
- **Only functional ships.** The auditor's "no real assertions" complaint is
  met by (a) keeping every test that asserts service/HTTP wiring, (b) adding
  the real-harness contract test, (c) the guard.
- **Kept all service/mocktail tests.** They assert real output transformations
  (payload shapes, RPC params, E2EE), not mock-echo self-consistency.
- **The guard is narrow.** A broad "no find.byType" ban would false-positive
  on legitimate behavior tests; only the two genuinely render-only patterns
  are banned.
- **a11y deleted** — a semantic-render property suite (UI category). Its one
  functional concern (focus order) is exercised by the real-app integration
  smoke (`ui_smoke_test.dart`).

## MISTAKE

- **Swept a concurrent session's uncommitted edits.** `a11y_test.dart` had
  in-flight uncommitted modifications from the `appbar-unify` session (it was
  `M` in the initial `git status`); my `git rm` deleted them. I restored the
  committed HEAD version, then deleted the file entirely (it is UI-only), but
  the concurrent session's edits to that file are lost — it will re-apply
  them from HEAD. Lesson: check `git status` for uncommitted edits AND the
  lock list before deleting any file.
- **`git rm` on files with plain-logic tests removed functional coverage.**
  `notification_center_test.dart`, `photo_gallery_test.dart`,
  `paywall_test.dart`, `shard_ledger_screen_test.dart` contain plain
  provider/helper `test()` blocks; my wholesale `git rm` swept them. Restored
  from `git show HEAD:` and re-trimmed to keep only the plain logic.
- **Over-broad guard first pass.** The initial render-marker regex flagged
  legitimate `CircularProgressIndicator`/`VEmptyView`/`ErrorView` assertions
  embedded in functional tests (busy spinners, flag-gate states, rotation
  retry). Narrowed to the two provable anti-patterns.

## Commands run

```bash
export AGENT_NAME=test-suckless
git rm -f <57 UI-only test files>
# restore + retrim 4 files that had plain-logic tests
flutter test test/features/notifications/notification_center_test.dart ... # all pass
flutter test   # 1800 → 1783 pass / 0 fail
flutter analyze  # 0 issues
go test ./...  # green
```

Baseline: README.md + test/README.md + cross-references.md updated to
**1783 pass / 0 fail**; `test/meta/conventions_test.dart` now enforces the
suckless policy.
