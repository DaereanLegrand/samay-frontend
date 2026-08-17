# FILE OWNERSHIP MAP — Samay 180-Agent Orchestration

Every repo path is owned by the agent listed. Agents must hold the lock
(`tools/agent_lock.sh acquire <path> --owner <ID>`) before modifying any file.
If a file is not listed, it is **orchestrator-owned** (docs/process/*, repo-locks/*,
tools/agent_lock.sh) or free for any agent with a legitimate need (new files).

Legend: ✅ primary owner · ⚙️ may modify with lock (coordination) · 🔒 read-only

**Appendix A — existing paths without an explicit row (orchestrator-owned/free
by the header rule):** `docs/audit/**` (gate reports), `docs/design/DISCO-LUXE-
DESIGN-SYSTEM.md`, `docs/specs/steps/phase-05..15/*.md` step files,
`<private-ops-repo>/*`, `tools/check_secrets.sh`, `tools/check_migrations.sh`,
`<tunnel-host-helper>`, `tools/ios_dev_signing.rb`,
`tools/gen_testing_anon_key.py`, `tools/icon_gen.dart`, `tools/gemma_critique*`,
`tools/hooks/pre-commit`, `bin/`, `test_driver/`, `test/design_tokens/**`.

---

## Phase 4.1 — Documentation agents (D-01..D-12)

| Path | Owner |
|---|---|
| `AGENTS.md` (port table + agent protocol section) | D-01 ✅ |
| `docs/specs/steps/cross-references.md` | D-02 ✅ |
| `docs/to-fix/TODO.md` + all `docs/to-fix/categories/*.md` | D-03 ✅ |
| `supabase/tests/schema_test.sql` (stale RLS/seed assertions) | D-04 ✅ |
| `README.md` (root) + `test/README.md` + `test_runner.sh` docs | D-05 ✅ |
| `docs/security/SECURITY.md` (new: threat model, security architecture) | D-06 ✅ |
| `docs/security/E2EE-ARCHITECTURE.md` (new: X3DH + Double Ratchet spec) | D-07 ✅ |
| `<private-ops-repo>/SELFHOSTING.md` (new: port map, compose, migration testing) | D-08 ✅ |
| `docs/process/DEVELOPMENT-WORKFLOW.md` (new: locks, tests, checkpoints) | D-09 ✅ |
| `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` (new: URLs as placeholders) | D-10 ✅ |
| `docs/design/DISCO-DESIGN-SYSTEM.md` (new: tokens, typography, palette) | D-11 ✅ |
| `docs/history/**` phase inventory + phase-05+ plan docs | D-12 ✅ |

## Phase 4.2 — Implementation agents (I-01..I-48)

| Path | Owner |
|---|---|
| `integration_test/**` (new modular suite) + `test/run_all_backend.sh` | I-01 ✅ (⚙️ all I-agents add cases) |
| `supabase/docker-compose.yml`, `supabase-testing/docker-compose.yml`, `supabase/config.toml`, `supabase-testing/config.toml` (port remap) | I-02 ✅ (⚙️ M-01..M-10 later) |
| `supabase/migrate.sh`, `supabase/reset.sh`, `supabase/run.sh`, `supabase-testing/*.sh` | I-02 ✅ ⚙️ M-15 |
| `lib/core/router/app_router.dart`, `lib/core/router/auth_guard.dart` | I-03 ✅ (H-03/H-04, errorBuilder, refreshListenable) ⚙️ U-08 |
| `lib/core/router/**` (new: typed extras, MainShell extraction) | I-04 ✅ ⚙️ I-03 |
| `lib/main.dart` (error handlers) + `lib/core/logging/**` (new AppLogger) | I-05 ✅ ⚙️ U-01 |
| `lib/features/**` catch-block sweep + `lib/shared/widgets/error_banner.dart`, `error_view.dart` | I-06 ✅ |
| `lib/core/utils/async_ops.dart` (new: withRetry/withTimeout/backoff — created as `lib/core/utils/async_ops.dart` by I-07; the old `retry.dart` name never shipped) | I-07 ✅ |
| `lib/core/errors/app_error.dart`, `lib/core/extensions/error_mapper.dart` | I-08 ✅ |
| `lib/core/providers/auth_provider.dart` (AsyncNotifier migration) | I-09 ✅ ⚙️ I-47 |
| `lib/core/models/**` (new: freezed models) + generation config (**note: `build.yaml` never created — freezed runs on default builders, I-10**) | I-10 ✅ |
| `lib/core/services/supabase_service.dart` → decompose into `lib/features/*/services/` or `lib/core/services/` | I-11 ✅ |
| `lib/features/**/*provider.dart` state-management audit | I-12 ✅ |
| `lib/features/profile/screens/profile_screen.dart` → provider | I-13 ✅ |
| `l10n.yaml`, `lib/l10n/**` (new ARB), `pubspec.yaml` (flutter_localizations) | I-14 ✅ ⚙️ I-15 |
| `lib/**` string extraction to ARB | I-15 ✅ |
| `lib/core/design_tokens/**` (new) + `lib/core/theme/**` | I-16 ✅ ⚙️ U-01..U-05 |
| `lib/core/theme/app_theme.dart` (disco palette phase 1) | I-17 ✅ ⚙️ U-01..U-05 |
| `assets/fonts/**`, `pubspec.yaml` fonts, `assets/**` | I-18 ✅ |
| `pubspec.yaml` (cached_network_image) + `lib/**` Image.network sweep | I-19 ✅ |
| `lib/**` ListView.builder conversions + const sub-widgets | I-20 ✅ |
| `lib/core/utils/debouncer.dart` + `lib/features/groups/screens/invite_screen.dart` | I-21 ✅ |
| `lib/core/utils/image_processor.dart` (new) | I-22 ✅ |
| `pubspec.yaml` (dead deps removal) | I-23 ✅ ⚙️ I-14/I-19/I-25 |
| `pubspec.yaml` (riverpod/go_router upgrade) + provider migration fallout | I-24 ✅ |
| `lib/core/services/storage_service.dart` (SecureStorage wiring) | I-25 ✅ |
| `lib/core/services/storage_service.dart` (Hive encryption) | I-26 ✅ |
| `lib/core/utils/input_sanitizer.dart` (new) + `lib/features/**` input sites | I-27 ✅ |
| `pubspec.yaml` (permission_handler) + permission service | I-28 ✅ |
| `lib/features/auth/**` OTP rate-limit UX + `lib/core/utils/**` | I-29 ✅ |
| `lib/core/providers/auth_provider.dart` (token refresh) + `lib/main.dart` | I-30 ✅ ⚙️ I-05 |
| `supabase/migrations/**` (new: FORCE RLS + search_path hardening) | I-31 ✅ ⚙️ D-04 |
| `supabase/migrations/**` (RLS audit, missing policies) | I-32 ✅ |
| `supabase/migrations/20260510000001_full_schema.sql` seed section + `supabase/seed.sql` | I-33 ✅ |
| `pubspec.yaml` (.env asset removal) + `lib/core/config/env_config.dart` + `.env.example` | I-34 ✅ ⚙️ M-13 |
| `lib/features/auth/**` (ban screen) + `lib/core/providers/auth_provider.dart` | I-35 ✅ |
| `lib/features/profile/**` (avatar/interest-tags/cosmetics foundation) | I-36 ✅ |
| `lib/crypto/**` (new: X25519, double ratchet, envelope) + `pubspec.yaml` | I-37 ✅ |
| `lib/features/chat/**` (E2EE chat integration) + `lib/core/services/chat_service.dart` | I-38 ✅ |
| `internal/ops/**`, `internal/db/client.go` (error handling, context) | I-39 ✅ ⚙️ I-42 |
| `internal/db/query_builder.go`, `internal/db/crud.go` (new) | I-40 ✅ |
| `cmd/samay-api-server/**` (new Gin scaffold) | I-41 ✅ ⚙️ M-21 |
| `internal/ops/*_test.go`, `internal/db/*_test.go`, `cmd/samay-api-server/**` tests | I-42 ✅ |
| `internal/ops/system.go` (stats/health) | I-43 ✅ |
| `test/services/**`, `test/providers/**` (mocktail behavioral tests) | I-44 ✅ ⚙️ I-47 |
| `test/features/**` (interaction/error/empty states) | I-45 ✅ |
| `test/**` algorithm tests (age, password, OTP, shards, brackets) | I-46 ✅ |
| Fix 23 pre-existing failing Flutter tests | I-47 ✅ |
| `test/pubspec_test.dart`, `test/structure_test.dart` replacement | I-48 ✅ |

### I-49..I-78 — Feature foundations & refactorability

| Path | Owner |
|---|---|
| `lib/core/config/feature_flags.dart` (new — feature-flag provider; created as `lib/core/feature_flags.dart` by I-49, **moved to `config/` by M-24**) | I-49 ✅ ⚙️ M-24 |
| `lib/core/repositories/**` (new repository layer) | I-50 ✅ ⚙️ I-11 |
| `lib/core/services/rest_client.dart` (new typed PostgREST wrapper) | I-51 ✅ |
| `lib/core/providers/realtime_provider.dart` (full lifecycle) | I-52 ✅ ⚙️ I-11 |
| `lib/features/notifications/screens/notification_center_screen.dart` | I-53 ✅ |
| `lib/features/events/screens/create_event_screen.dart` (ECRT foundation) | I-54 ✅ |
| `lib/features/events/screens/event_detail_screen.dart`, `lib/features/events/screens/event_edit_screen.dart` | I-55 ✅ |
| `lib/features/chat/screens/chat_screen.dart` (message list foundation) | I-56 ✅ |
| `lib/features/qr/screens/attendance_qr_screen.dart`, `lib/features/qr/screens/qr_scanner_screen.dart` | I-57 ✅ |
| `lib/features/feed/screens/feed_screen.dart` (real feed foundation) | I-58 ✅ ⚙️ U-08 |
| `lib/features/photos/screens/photo_gallery_screen.dart`, upload flow | I-59 ✅ |
| `lib/features/party_finder/screens/party_finder_screen.dart` (foundation) | I-60 ✅ |
| `lib/features/subscriptions/screens/paywall_screen.dart` (RevenueCat placeholder) | I-61 ✅ |
| `lib/features/cosmetics/screens/cosmetics_shop_screen.dart` (foundation) | I-62 ✅ |
| `lib/features/minigames/screens/minigames_screen.dart` (foundation) | I-63 ✅ |
| `lib/features/shards/screens/shard_ledger_screen.dart` | I-64 ✅ |
| `lib/core/providers/theme_provider.dart` (persistence) | I-65 ✅ ⚙️ U-04 |
| `lib/core/deep_links/deep_link_handler.dart` (new, samay://) | I-66 ✅ ⚙️ I-03 |
| `lib/core/services/connectivity_service.dart`, offline cache layer | I-67 ✅ |
| `lib/core/services/telemetry_service.dart` (PostHog placeholder) | I-68 ✅ |
| `lib/core/router/**` feature-flag route gating | I-69 ✅ ⚙️ I-49 |
| `lib/core/services/crash_reporter.dart` (Sentry placeholder) | I-70 ✅ ⚙️ I-05 |
| `lib/core/providers/config_provider.dart` (refresh + Hive cache) | I-71 ✅ |
| `lib/core/utils/pagination.dart` (new) | I-72 ✅ |
| `lib/core/utils/form_validators.dart` (new) | I-73 ✅ |
| `lib/shared/widgets/state_views.dart` (loading/error/empty) | I-74 ✅ ⚙️ I-06 |
| `tools/seed_dev_data.sh` + `supabase/seed-dev.sql` | I-75 ✅ |
| `test/opt-002-events.sh`, `test/opt-003-chat.sh`, `test/opt-004-photos.sh` | I-76 ✅ |
| `supabase/tests/schema_test.sql` expansion | I-77 ✅ ⚙️ D-04 |
| Full-matrix sweep (fix fallout, no new features) | I-78 ✅ |

## Phase 4.3 — Modifications agents (M-01..M-30)

| Path | Owner |
|---|---|
| `supabase/docker-compose.yml` (healthchecks, pinning, overrides) | M-01..M-05 ✅ |
| `supabase/docker-compose.pg17.yml`, `.s3.yml`, `.mailpit.yml`, kong config | M-06..M-08 ✅ |
| `supabase/volumes/api/kong-entrypoint.sh`, `kong.yml` | M-09 ✅ |
| `supabase/run.sh`, `reset.sh`, `migrate.sh`, `supabase-testing/**` parity | M-10 ✅ |
| `Makefile` (flutter targets, dart-define, test split, go targets) | M-11 ✅ |
| `Makefile` (docker/supabase targets + port map) | M-12 ✅ |
| `Makefile` (env sourcing, secrets via env, no plaintext) | M-13 ✅ |
| `Makefile` (fastlane targets) | M-14 ✅ |
| `Makefile` (migrate-check, CI parity) | M-15 ✅ |
| `Makefile` (install/deploy placeholder targets) | M-16 ✅ |
| `fastlane/Fastfile` (iOS) + `fastlane/Appfile` | M-17 ✅ |
| `fastlane/Fastfile` (Android) | M-18 ✅ |
| `Gemfile` + `fastlane/README.md` | M-19 ✅ |
| ~~`.github/workflows/ci.yml` (lint+test)~~ **removed 2026-08-14 — no GitHub Actions (product decision)** | M-20 ✅ (historical) |
| ~~`.github/workflows/build.yml`~~ + `build-api` (Makefile target still exists) | M-21 ✅ (historical) |
| ~~`.github/workflows/release.yml` (placeholders, no creds)~~ **removed 2026-08-14** | M-22 ✅ (historical) |
| `lib/features/**` restructure (screens/providers/widgets subdirs) — **DONE 2026-08-10 (M-23): every feature dir now nests `screens/ providers/ widgets/ logic/` (only non-empty subdirs created; 58 files moved, zero content changes, full suite green — see `docs/history/phase-00-foundation/2026-08-10_M23-restructure.md`). New convention: `*_screen.dart` → `screens/`, `*_provider(s).dart` → `providers/`, widget-only files → `widgets/`, pure domain logic → `logic/`. Feature services stay in `lib/core/services/` (I-11); cross-cutting providers stay in `lib/core/providers/`.** | M-23 ✅ ⚙️ I-11/I-12 |
| `lib/core/**` restructure (constants/design_tokens/errors/extensions) — **DONE 2026-08-10 (M-24): `lib/core/feature_flags.dart` moved → `lib/core/config/feature_flags.dart` (git mv + all 12 importers rewritten; `lib/core/` root now contains only subdirs); `constants/` deliberately NOT created — the constants home is `design_tokens/` + `config/feature_flags.dart` (AppFeatureFlags/AppFeatureFlag release knobs) + `EnvConfig`, and empty placeholder dirs are forbidden (structure_test dynamic invariant); guards updated (structure_test core-layers list pinned to the 14 real subdirs + ARC-03 no-stray-root-file invariant in conventions_test). See `docs/history/phase-00-foundation/2026-08-10_M24-core-restructure.md`.** | M-24 ✅ |
| `.opencode/**` + `AGENTS.md` agent config (**note: `.agents/**` intentionally never created — documented decision M-25; the same skills exist user-wide in `~/.agents/skills/`, see `.opencode/README.md`**) | M-25 ✅ |
| `analysis_options.yaml` + `tools/pre-commit.sh` + hooks | M-26 ✅ |
| `android/**` (manifests, permissions, minSdk, gradle) | M-27 ✅ |
| `ios/**` (Info.plist, Podfile, signing placeholders) | M-28 ✅ |
| `macos/`, `linux/`, `windows/`, `web/` cleanup | M-29 ✅ |
| `tools/check_ports.sh` (port-map consistency test; created by D-01 in `tools/`) + `<private-ops-repo>/` — **DONE 2026-08-10 (M-30): classifier finalized for the M-series reality — `CONTAINER_HOSTS` + `imgproxy`/`functions` (+ `${pre}-` template prefixes), the six `.env` host-port-map keys validated against the approved map (RED-proven both directions), `${VAR:-PORT}` expansion no longer leaks the trailing `}`, full-line comments skipped, `0.0.0.0` INFO; `--strict` STRICT PASS (19 mappings/202 refs/0 violations); SELFHOSTING.md rows 23-26 + DoD flipped ✅; DEPLOYMENT-PLACEHOLDER.md §1.1/§5/§6/§7 finalized; see `docs/history/phase-00-foundation/2026-08-10_M30-infra-close.md`.** | M-30 ✅ |

## Phase 4.4 — UI agents (U-01..U-30)

| Path | Owner |
|---|---|
| `lib/core/design_tokens/app_colors.dart` (disco palette) | U-01 ✅ |
| `lib/core/design_tokens/app_typography.dart` (Playfair Display + Inter) | U-02 ✅ |
| `lib/core/design_tokens/app_spacing.dart`, `app_radius.dart`, `app_elevation.dart`, `app_icon_sizes.dart` | U-03 ✅ |
| `lib/core/theme/app_theme.dart` + `ThemeExtension` | U-04 ✅ |
| `lib/shared/widgets/v_button.dart`, `v_input.dart`, `v_card.dart`, `v_chip.dart`, `v_badge.dart`, `v_shard_icon.dart`, `rank_badge.dart` (disco restyle) | U-05 ✅ |
| `lib/shared/widgets/**` new: glow text, disco divider, shimmer, state widgets | U-06 ✅ |
| `lib/features/auth/**` screens restyle | U-07 ✅ |
| `lib/core/router/app_router.dart` shell/nav restyle + `lib/features/feed/**` | U-08 ✅ |
| `lib/features/profile/**` screens restyle | U-09 ✅ |
| `lib/features/friends/**` screens restyle | U-10 ✅ |
| `lib/features/groups/**` screens restyle | U-11 ✅ |
| `lib/features/**` coming-soon screens restyle | U-12 ✅ |
| Juega flow study (read-only) → flow alignment report + changes | U-13 ✅ |
| Juega auth/onboarding flow alignment | U-14 ✅ |
| Juega profile/settings flow alignment | U-15 ✅ |
| Juega friends/groups flow alignment | U-16 ✅ |
| Juega main-shell/tab flow alignment | U-17 ✅ |
| Animations + micro-interactions (`lib/core/theme/samay_durations.dart`, reduced-motion) | U-18 ✅ |
| Responsive layout + safe areas | U-19 ✅ |
| `assets/icons/` (disco assets) + `flutter_launcher_icons` (**note: `assets/images/` does not exist — `assets/` is fonts/ + icons/ only**) | U-20 ✅ |
| Empty/loading/error state widgets (shared) | U-21 ✅ |
| Skeleton/shimmer loading states | U-22 ✅ |
| UI review pass: auth → profile | U-23 ✅ |
| UI review pass: friends → groups | U-24 ✅ |
| UI review pass: feed/shell/coming-soon | U-25 ✅ |
| Contrast/a11y audit (WCAG, reduced motion, text scaling) | U-26 ✅ |
| `test/theme/**` + `test/widgets/**` update for disco theme | U-27 ✅ |
| `test/features/**` UI interaction tests for restyled screens | U-28 ✅ |
| `integration_test/ui_smoke_test.dart` | U-29 ✅ |
| UI docs: `docs/design/DISCO-DESIGN-SYSTEM.md` finalization | U-30 ✅ |

## Phase 4.5 — Security agents (S-01..S-20)

| Agent | Domain | Scope (read/write across repo, no permanent owners) |
|---|---|---|
| S-01 | OWASP MASVS audit | Full-app audit report `docs/security/MASVS-AUDIT.md` |
| S-02 | Dependency CVE scan | `pubspec.lock`, `go.sum`, docker images → `docs/security/CVE-SCAN.md` |
| S-03 | RLS/authorization deep audit | All policies + FORCE RLS + search_path → fixes/migration |
| S-04 | PostgREST/SQL injection audit | `.or()`/filter building in Dart + Go query builder |
| S-05 | JWT/session security | PKCE, refresh rotation, storage of tokens |
| S-06 | Edge-function/SSRF/API surface | `cmd/samay-api-server`, Kong config, edge runtime |
| S-07 | Crypto audit (E2EE) | Double-ratchet implementation review (I-37/I-38 output) |
| S-08 | Secrets management audit | `.env`, dart-define, fastlane, CI, git history |
| S-09 | Storage bucket policies audit | Supabase Storage + signed URLs |
| S-10 | Rate limiting/DoS | Kong limits, app_config thresholds, OTP abuse |
| S-11 | Realtime abuse audit | Channels, presence, subscription storms |
| S-12 | Deep-link/universal-link security | Invite links, URL parsing |
| S-13 | Input validation + fuzz | Sanitizer coverage, length caps, NFKC |
| S-14 | Privacy/compliance | Peru L29733, App Store/Play, data minimization |
| S-15 | Supply-chain security | Reproducible builds, go.sum, lockfiles, image pinning |
| S-16 | Container image CVEs | Compose image versions → pin updates |
| S-17 | Go backend security | Service role handling, audit log integrity, IDOR |
| S-18 | Mobile platform security | iOS/Android hardening, backups, keychain/keystore |
| S-19 | AuthN/AuthZ flows attack test | Signup/OTP/login/delete-account abuse paths |
| S-20 | Final consolidated security report | `docs/security/FINAL-SECURITY-REPORT.md` |

## Phase 4.6 — Doc verifiers (V-01..V-10)

| Agent | Verifies |
|---|---|
| V-01 | All docs/specs/product + implementation vs current code |
| V-02 | docs/to-fix/TODO.md + categories statuses vs code |
| V-03 | docs/history/ daily logs + DONE markers vs reality |
| V-04 | Port map consistency (AGENTS.md, config.toml, compose, scripts, tests) |
| V-05 | Test suite completeness matrix (unit/widget/integration/backend/pgTAP) |
| V-06 | E2EE + security docs vs crypto implementation |
| V-07 | Design system docs vs theme implementation |
| V-08 | Agent registry + orchestration docs accuracy |
| V-09 | README/onboarding/docs/process/DEVELOPMENT-WORKFLOW correctness |
| V-10 | Final gate: full validation matrix + gate report `docs/audit/GATE-REPORT.md` |

## Phase-04.6 appendix — ISSUE 4 Group Chat & E2EE workstream (2026-08-15..17)

Group-chat E2EE (Signal sender keys) + realtime group invites, delivered by a
parallel agent campaign. New files and hot paths from that campaign — the
per-file owners below OVERRIDE the Phase 4.2 I-rows for these paths (I-37
owns `lib/crypto/**` at large, but the group sender-key code is D2's).

| Path | Owner |
|---|---|
| `supabase/migrations/20260817000001_group_members_realtime.sql` (+ `supabase-testing/` mirror) | A-realtime-invites ✅ |
| `lib/core/services/realtime_service.dart` — `subscribeToGroupMemberships` | A-realtime-invites ✅ ⚙️ I-52 |
| `lib/features/groups/providers/group_memberships_realtime_listener.dart` (new `GroupMembershipsRealtimeListener`) | A-realtime-invites ✅ |
| `lib/core/router/main_shell.dart` — listener mount (A4) | A-realtime-invites ✅ ⚙️ I-04 |
| `lib/features/groups/screens/group_detail_screen.dart` — invited/Info-tab state (B-invited-state) + Chat-tab `ChatThreadView` (D4) | B-invited-state ✅ ⚙️ D4-chat-ui |
| `lib/features/friends/screens/search_screen.dart` + `requests_screen.dart` — friend-request accept path (C-search-accept) | C-search-accept ✅ ⚙️ I-10/I-15 |
| `supabase/migrations/20260817000002_group_chat_support.sql` (+ `supabase-testing/` mirror) | D1-groupchat-db ✅ |
| `test/opt-010-groups-chat.sh` | D1-groupchat-db ✅ (created) ⚙️ D3-chat-service (check 10, `recipient_id`) |
| `lib/crypto/group_cipher.dart` (new `GroupE2eeCipher` + `GroupSenderKeyRecord`) | D2-group-e2ee ✅ |
| `lib/crypto/envelope.dart` — type 0x03 sender-key frame + `groupIdToBytes`/`groupIdFromBytes` | D2-group-e2ee ✅ ⚙️ I-37 |
| `lib/crypto/constants.dart` — 0x03 / sender-key-bundle constants | D2-group-e2ee ✅ ⚙️ I-37 |
| `test/crypto/group_cipher_test.dart` (new) + `test/crypto/envelope_test.dart` 0x03 cases | D2-group-e2ee ✅ ⚙️ I-37 |
| `lib/core/services/chat_service.dart` — group send/distribution/rekey paths (D3) | D3-chat-service ✅ ⚙️ I-38 |
| `supabase/migrations/20260817000003_group_chat_distribution.sql` (+ `supabase-testing/` mirror) | D3-chat-service ✅ |
| `test/services/chat_service_test.dart` — group routing cases | D3-chat-service ✅ ⚙️ I-44 |
| `lib/features/chat/widgets/chat_thread_view.dart` (new `ChatThreadView`) | D4-chat-ui ✅ |
| `lib/features/chat/screens/chat_screen.dart` — thin screen + group AppBar title | D4-chat-ui ✅ ⚙️ I-56 |
| `lib/features/chat/screens/chat_list_screen.dart` — group rows in the inbox (D4d) | D4-chat-ui ✅ ⚙️ I-38 |
| `lib/features/chat/providers/chat_providers.dart` — `ChatInboxItem.referenceId` (D4c) | D4-chat-ui ✅ ⚙️ I-38/I-12 |
| `lib/features/groups/providers/groups_providers.dart` — `groupChatIdProvider` (D4e) | D4-chat-ui ✅ ⚙️ I-12 |
| `integration_test/group_chat_flow_test.dart` (new) | D4-chat-ui ✅ ⚙️ I-01 (suite owner adds cases) |
| FixA1..FixA4 — ISSUE 4 docs↔code audit fixes (2026-08-16..17) | FixA1..A4 ✅ — scope per their daily logs (`docs/history/phase-04-friends-groups/`, `docs/history/phase-07-chat/`); docs-only fix work (E2EE-ARCHITECTURE.md §9.6/§0.1, cross-references.md, FILE-OWNERSHIP.md appendix) by FixA4-docs |
| Fix-round agents (2026-08-17) — `lib/crypto/group_cipher.dart` + `lib/crypto/constants.dart` + `test/crypto/group_cipher_test.dart` (FixA1b: F1/F2/F4 hardening), `test/features/chat/chat_inbox_test.dart` (FixA3: null-aware element), E2EE-ARCHITECTURE.md §9.6/§1/§6/D8/§0.1 rewrite + cross-references GROU/CHAT rows (FixA4), E2EE-ARCHITECTURE.md §0/§0.3 + cross-references I-37 test-count reconciliation + fix-round logs (FixB1/B2/B3) | FixA1b ✅ ⚙️ FixA2/A3/A4/B1/B2/B3 — scope per their daily logs (`docs/history/phase-07-chat/2026-08-17_FixA1b-crypto-audit.md`, `2026-08-17_FixA3-lint.md`, `docs/history/phase-04-friends-groups/2026-08-17_FixA4-docs.md`, `2026-08-16_FixB2-authz-friendship-guards.md`; FixB1 test-only + FixB3 doc-only work is captured in the D1-groupchat-db fix-round section); doc counts (E2EE-ARCHITECTURE.md §0/§0.3, cross-references I-37) reconciled to 169 by FixB3-docs2 + orchestrator (FixB2's v1-record test, group_cipher 29) — **superseded 2026-08-17 by H1 (rekey-epoch fix, `docs/history/phase-07-chat/2026-08-17_H1-rekey-epoch.md`): 172, group_cipher 32; then by J1: 175, group_cipher 35 (reinstall-heal ×2 + v2-record ×1); then by K1: 179, group_cipher 39 (bundle-identity binding ×4); then by the group key-request retry: 182, group_cipher 42 (reconciled 2026-08-16 docs audit)** |

> **Lock rule reminder:** all paths above are under `tools/agent_lock.sh` — the
> docs listed in the FixA4-docs row are owned per this appendix and were
> edited under FixA4-docs locks.
