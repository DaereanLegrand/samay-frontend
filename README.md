# Samay

**Samay** is a disco/social-life mobile app for the 18–35 Latin American urban
demographic: plan social gatherings, invite friends, attend events
(QR-verified), earn and spend **shards**, climb group rank leaderboards, and
relive the night through photos and mini-games.

This repository is a **3-track project**:

| Track | What | Status |
|-------|------|--------|
| **Flutter app** (`lib/`) | iOS + Android app — auth, profile, friends, groups, shard donations, rankings, events, QR, E2EE chat (1:1 + group), feed/photos, notifications, minigames, party finder. Most screens live behind feature flags; subscriptions stay gated (RevenueCat wiring pending) | Phases 00–04 done; phase 05+ foundations landed; edge functions pending |
| **Go admin CLI** (`cmd/samay-admin/`, `internal/`) | Cobra-based operational CLI (`samay`) using the `service_role` key — users, events, groups, reports, shards, config, subs, system | Complete |
| **Self-hosted Supabase** (`supabase/`, `supabase-testing/`) | PostgreSQL 17 + GoTrue + PostgREST + Realtime + Storage + Kong gateway; Docker Compose and `config.toml` dual setups; migration-based testing | Done — approved port map enforced |

Docs hub: [`docs/README.md`](docs/README.md). DB catalog: `<private-ops-repo>/DATABASE.md`. Go CLI/API surface: `<private-ops-repo>/BACKEND.md`.

---

## Quickstart

Prerequisites: Flutter (`/opt/homebrew/share/flutter/bin/flutter` on this machine),
Go ≥ 1.26, Docker + `docker compose`.

```bash
# 1. Dart dependencies
flutter pub get

# 2. Environment
cp .env.example .env
# Fill in SUPABASE_URL / SUPABASE_ANON_KEY (local or remote)

# 3. Run the app (or: make dev TARGET=android)
flutter run

# 4. Tests (backend-only — directive 2026-08-31)
make test                # go test ./... + static opt gates
make check               # dart analyze + flutter analyze + go vet + ports + secrets
make build-cli           # builds ./samay admin CLI binary

# 5. Backend stack (self-hosted Supabase on the approved ports)
make supabase-docker-start
bash test/run_all_backend.sh   # curl backend integration tests (needs the stack)
```

### Environment: compile-time `--dart-define`

The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` at **build time** via
`--dart-define-from-file=.env` (`EnvConfig` → `String.fromEnvironment`).
Nothing env-related is bundled as a Flutter asset and `.env` is gitignored.

### Make targets

| Target | What it does |
|--------|--------------|
| `make build` | `flutter build apk` (or `TARGET=ios` → unsigned IPA) |
| `make dev` | `flutter run` (TARGET=android/simulator/ios-adhoc/device id) |
| `make install` | Install APK/IPA to device |
| `make build-cli` / `build-linux` | Go admin CLI binaries |
| `make build-api` | Gin API server binary |
| `make flutter-analyze` | `dart analyze` static analysis |
| `make test` | Go + backend static opt gates |
| `make check` | dart analyze + flutter analyze + go vet + ports gate + secrets gate |
| `make clean` | Build artifacts |
| `make supabase-*` / `supabase-docker-*` / `supabase-testing-*` | Supabase stack lifecycle |

**Build target notes:**
- `TARGET=android` and `TARGET=waydroid` both use the `.env` URL by default
  (production). Use `TESTING=true` to point at the local stack at
  `http://10.0.2.2:54386` with a fresh anon JWT (e.g. `make dev
  TARGET=android TESTING=true`).
- Android 9+ allows cleartext HTTP (`usesCleartextTraffic` in manifest) so
  the `TESTING=true` local-stack URL works from the emulator.

### Supabase port map (coexists with the Juega stack)

Juega owns host ports `5432, 54321, 54323, 8443` — never map Samay onto them.
Samay's approved map:

| Service | Port |
|---------|------|
| PostgreSQL (direct) | **54382** |
| Studio | **54381** |
| Mailpit (dev email) | **54384** |
| Kong (API gateway — REST, Auth, Realtime, Storage) | **54386** |
| Analytics | **54388** |
| Kong HTTPS | **54443** |

Local API base URL: `http://127.0.0.1:54386`. Self-hosting details:
[`<private-ops-repo>/SELFHOSTING.md`](<private-ops-repo>/SELFHOSTING.md); deployment targets are
placeholders in [`<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md`](<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md)
— do not invent deployment URLs in code or docs.
Database migrations: `supabase/migrations/**` (63 SQL files across 43 numbered
domain dirs, mirrored byte-identical into `supabase-testing/migrations/`),
applied by `supabase/migrate.sh` / `reset.sh`.

---

## Repo layout map

```
lib/                          Flutter app
  main.dart                   Supabase.initialize (dart-define env) → runApp
  app.dart                    SamayApp (MaterialApp.router, dark theme)
  core/                       config/, design_tokens/, deep_links/, errors/,
                              extensions/, logging/, models/ (freezed),
                              providers/, repositories/, router/, services/,
                              telemetry/, theme/, utils/
  crypto/                     E2EE chat stack (X3DH, double ratchet,
                              group sender keys, key store) — see
                              docs/security/E2EE-ARCHITECTURE.md
  features/                   auth/ chat/ cosmetics/ events/ feed/ friends/
                              groups/ minigames/ notifications/ party_finder/
                              photos/ profile/ qr/ shards/
                              social/ (serves the `/main/groups` bottom tab:
                              Grupos + Amigos pills, global user ranking)
                              subscriptions/ — each nests screens/ providers/
                              widgets/ logic/
  l10n/                       ARB localizations — Spanish-first (`app_es.arb`
                              template), English secondary; generated classes
  shared/                     shared widgets (v_button, v_input, v_card, …)

cmd/samay-admin/              Cobra CLI entry — thin wrappers
cmd/samay-api-server/         Gin API scaffold (admin routes + health)
internal/db|ops|format|validate   PostgREST client, business logic,
                              formatters, shared validation
                              — surface: <private-ops-repo>/BACKEND.md

supabase/                     Self-hosted stack: config.toml, docker-compose*.yml,
                              migrations/**, seed-*.sql, run/reset/migrate scripts,
                              tests/schema_test.sql (pgTAP), volumes/
supabase-testing/             Isolated testing stack (same layout)

test/                         Backend curl opt-tests
  opt-NNN-*.sh                curl integration tests (self-contained, exit 0/1)
  run_all_backend.sh          Runs every opt test against http://127.0.0.1:54386
test_runner.sh                gum-based MANUAL end-user QA runner

docs/                         See docs/README.md for the map
tools/                        check_secrets/check_ports/check_migrations,
                              agent_lock.sh, seed_dev_data.sh, hooks
```

---

## Testing summary

Baseline numbers below are re-verified whenever docs change; if you change
code, update them in the same commit.

**Testing is reserved for the backend, or per task there are NO integration
tests (directive 2026-08-31).** The Flutter/Dart test trees were deleted
(`test/*.dart`, `integration_test/` flows + `runner.sh`, `test_driver/`) and
must NOT be recreated. There is no `make flutter-test` / `make test-file` /
`make test-feature` / `make test-integration`.

| Layer | Command | Baseline (2026-08-31) |
|-------|---------|----------------------|
| Static analysis | `dart analyze` | **0 issues** |
| Go | `go test ./...` | green — **188 tests**, 6 packages |
| Backend (curl) | `bash test/run_all_backend.sh` | **30 opt-tests** (opt-031 added 2026-09-15 — group match creation auto-invites every active group member (2a) and posts a `minigame_group_messages` notice in the group chat readable by members only (2b); the notice trigger also creates the group chat when missing (server guarantee) and `get_chat_inbox` surfaces the notice as chat activity (preview/bump/unread); opt-030 added 2026-09-11 — the pending-invite context RPC `get_minigame_invite_context` (`215_minigame_invite_context`) returns ONLY the inviter + group name so a not-yet-accepted invitee never resolves/flashes the participant roster; + opt-019-minigame-lobby 2026-08-30, opt-020-minigame-voting + opt-021-minigame-play-v2 2026-08-30; opt-006/016/018/020 reconciled 2026-08-31 to the current contracts — answer-first gate + hardening + `{list,count}` mirror shape; opt-020/021 extended 2026-09-01 with the reactor-side Pasar — `'pasar'` wire, `{list,count,pass}` mirror, `emoji - pass/2` scoring; opt-016 extended 2026-09-01 with TEST I — the lobby invite RPC `invite_minigame_players` (idempotent re-invite, `not_creator`, friends-only, frozen-cap, notification dispatch); opt-016 extended 2026-09-02 with TEST F rewrite (decline DELETEs the invite row — a declined invite is indistinguishable from one that never existed) + TEST J (re-invite after DECLINE/KICK is a plain fresh invite — invited 1, fresh pending row, INSERT notification, RLS restored, participants grow — no special resend path); opt-022 added 2026-09-03 (round-key request ring `206_minigame_key_request` — participant-only request/resolve, dedup, never-self-clear, bundle-seam serve); opt-023 added 2026-09-03 (`207_minigame_reaction_event` — per-tap `state.reactions_seq` + `state.reactions_event`, same-emoji re-tap signalled; reworked 2026-09-09 — corrected emoji↔Pasar exclusivity by row existence so fresh/same-emoji taps are accepted, added TEST F for the 250 ms `too_fast` spam gate); opt-024 added 2026-09-08 (events attendee capacity — entitlement tier 7/14/56/1120, `create_event` RPC, standalone `/events/create` flow; repo-wide `promotor→host` / `co_promotor→staff` rename); opt-025 added 2026-09-08 (events manual guest invites — host `invite_event_guests` search-and-invite, invitee `accept/decline_event_invite`, seat-reservation capacity + decline-frees-seat, host-read roster RLS `ei_read_event_access`, `ei_update_own` dropped for the SECURITY DEFINER invite family; migration `060_events/05_manual_invites.sql`); opt-026 added 2026-09-08 (events host-designates-staff — `designate_event_staff`/`remove_event_staff` RPCs, capacity + invite-seat conversion, `ep_read_event_access` roster RLS via the `event_host_access_view` barrier view, `ep_insert_host` dropped — event_hosts writes RPC-only, the attendance-code RPCs treat host/staff as attendees; migration `060_events/06_staff.sql`; TEST G updated 2026-09-08 to the code family once the legacy QR-token surface was removed); opt-027 added 2026-09-08 (events rotating attendance code — `get_my_code`/`validate_code` authenticator-style 24-hex time-window derivation (`event_code`, HMAC domain `samay.code.v1:`) from per-attendee secrets in `event_code_keys`, host/staff-only single confirmation, decline/staff-removal key purge; attendee side is a plain rotating QR; migration `060_events/07_code.sql`; the legacy QR-token flow — token table + rotate/validate RPCs + `qr.token_valid_seconds` — was REMOVED, one code flow only; file renamed 2026-09-08 to `opt-027-events-code.sh`; still the 26th opt-test; TEST A/B extended 2026-09-09 with `serverNowMs` server-clock-anchor assertions — the RPC now returns the server's epoch ms and the test pins it inside the issued window; TEST C2 added 2026-09-09 — a PENDING invitee is NOT an attendee (a host/staff/confirmed invite is required: `get_my_code` → `not_invited`, and a leaked/temporarily-minted code can never confirm them — `validate_code` → `not_invited`, no `event_attendances` row, invite stays `pending`) (PASS 30→37)); opt-028 added 2026-09-14 (Two Lies One Truth end-to-end — create/invite/accept/start, prompt-less answer (see 217 below), vote_0..2 + auto-advance, settle; migration `208_minigame_two_lies_one_truth`; TEST C updated 2026-09-15 to submit with NO topic prompt — two_lies is prompt-less by design, the shared 202 prompt gate is bypassed for this game type via `217_minigame_two_lies_no_prompt`); opt-029 added 2026-09-14 (public partidas `211_minigame_public` — host-only publish/unpublish, `list_public_minigames` feed with host username + `is_member`, stranger public join, unpublish closes the lobby door; group partidas rejected `group_session`; 16/16); needs the stack up; opt-007 static gate reports SERVICE_KEY-vs-.env alignment drift on opt-001..006 — local `.env` rotated after the 2026-08-25 baseline; runtime runs pass) |
| SQL (pgTAP) | `supabase db test` | **plan(999)** assertions (needs the stack; +5 from 2026-09-20 — `218_minigame_full_ranking` ranks EVERY participant in the settle-once leaderboard (the paid-position WHERE filters are gone; only the top N are paid) + corrected two stale 49t assertions (`ms_read_public` added to the `minigame_sessions` expected policy set; the dropped 209 `set_drunk_bottle_spin` block replaced by the live `spin/stop_drunk_bottle` DEFINER/search_path/ACL posture); +15 from Sections 62–64 2026-09-11/15 — `215_minigame_invite_context` (invitee-scoped SECURITY DEFINER context RPC), `216_minigame_group_message` (`minigame_group_messages` table + `mgm_read_group_member` member-read policy, `create_minigame_session` group fan-out, `notify_minigame_group_message` DEFINER trigger), and the group-chat guarantee (`chats_group_reference_uniq` one-chat-per-group, the trigger creates a missing group chat, `get_chat_inbox` counts a minigame notice as chat activity); +20 from Section 49t 2026-09-14 — merged PR (`209`–`213`): drunk-bottle/charades RPC presence + DEFINER/search_path/ACL posture, `charades` enum + seeded words, and the public-partida surface (`211`: `minigame_sessions.is_public`, `idx_minigame_sessions_public`, `ms_read_public` with its direct+active+signed-in qual, `set_minigame_public` host/direct gates, `list_public_minigames`, the `join_minigame_session` public bypass); on top of +5 from Section 49s 2026-09-14 — `208_minigame_two_lies_one_truth` enum entry, vote_0..2 reaction check + RPC acceptance, seeded topic prompts; on top of +2 from Section 21g 2026-09-10 — `event_attendances` joins `supabase_realtime` with REPLICA IDENTITY FULL so a scan confirming the caller (guest or host/staff — only this table records a host/staff member) flips an already-open detail/QR screen to the terminal "Ya te registraste" state (`060_events/08_realtime.sql`, membership add in `960_realtime`); on top of +3 from Section 21d/21f 2026-09-09 — a PENDING invitee is not an attendee: `get_my_code`/`validate_code` gate on CONFIRMED invites (`status = 'accepted' OR status = 'attended'`) so a pending row can never mint/confirm a code, and `event_roster_membership_view` projects CONFIRMED (accepted/attended) memberships only so a pending invitee reads no roster (opt-027 TEST C2); on top of +1 from Section 49n fix 2026-09-09 — `minigame_reactions.last_tap_at` drives the server reaction controlled-spam gate (207); on top of +5 from Section 21f 2026-09-09 — the attendee-side event roster (`060_events/09_attendee_roster.sql`): `event_roster_membership_view` security-barrier membership view, `ep_read_member_roster` + `ei_read_confirmed_roster` member-read policies, `event_hosts` REPLICA IDENTITY FULL + realtime publication — event members see the organizer roster + confirmed attendees live (opt-025 TEST H); on top of +2 from Section 21e 2026-09-09 — `event_invites` joins `supabase_realtime` with REPLICA IDENTITY FULL so the event detail's host/staff guest roster live-updates when an invitee accepts/declines on their own device (`060_events/08_realtime.sql`, membership add in `960_realtime`); on top of −13 from 2026-09-08 pivot — Section 21d rewritten from the legacy QR-token assertions to the code family: `event_code`/`get_my_code`/`validate_code` presence + no-anon-EXECUTE + `event_code_keys` FORCE-RLS / zero client policies / unique (event,user) key + invite/host purge triggers (`060_events/07_code.sql`); also updated 2026-09-08: `app_config` tuning-row count 47→43 (−4 legacy rows: `qr.token_valid_seconds`, `qr.display_countdown_seconds`, `security.max_qr_token_rotations`, `security.max_failed_qr_validations`; the code-window key renamed `code.window_seconds`); +5 from Section 21c 2026-09-08 — events staff RPC family presence + no-anon-EXECUTE + `event_host_access_view` + FORCE-RLS (`060_events/06_staff.sql`); also updated 2026-09-08: `event_hosts` RLS policy list — `ep_insert_host` dropped (event_hosts writes RPC-only), `ep_read_event_access` added; +4 from Section 21b 2026-09-08 — events manual-invite RPC presence + no-anon-EXECUTE posture (`060_events/05_manual_invites.sql`); also fixed 2026-09-08: `event_invites` RLS policy list (own-row read + `ei_read_event_access`, `ei_update_own` dropped), `app_config` tuning-row count 42→46 (+4 events capacity keys), and PUBLIC-EXECUTE hardening of the Stage-1 `event_seats_used`/`assert_event_capacity` helpers; on top of +5 from Section 49r 2026-09-04 — emoji ↔ Pasar exclusivity per voter (`already_reacted`/`already_passed`) + the per-voter `state.reactions.<subject>.voters` mirror map in both reaction RPCs; on top of +8 from Section 49r `207_minigame_reaction_event` 2026-09-03 — both reaction RPCs bump `state.reactions_seq` + record `state.reactions_event {seq, round, reaction, voter_id}` in one atomic mirror UPDATE, seq never reset on advance; on top of +12 from Section 49q `206_minigame_key_request` 2026-09-03 — `request_minigame_round_keys` + `resolve_minigame_key_request` participant-only SECURITY DEFINER RPCs, search_path `''`, PUBLIC revoked / authenticated grants; on top of +6 from Section 49p + the 49b/49g additions 2026-09-02 — decline-deletes, re-invite-after-decline/kick pure-INSERT idempotency, `minigame_sessions` REPLICA IDENTITY FULL; on top of +10 from Section 49o `205_minigame_invite_lobby` 2026-09-01 — `invite_minigame_players(p_session_id, p_invitees)` creator-only lobby invite RPC: typed lifecycle statuses, blocked/friends-only privacy mirror, frozen player-cap re-check, idempotent pending-skip, ACL posture; on top of +12 from Section 49n `204_minigame_pasar` 2026-09-01, +22 from 2026-08-31 and +60 from 2026-08-30) || Manual end-user QA | `bash test_runner.sh` | gum-based manual runner |
| Manual end-user QA | `bash test_runner.sh` | gum-based manual runner |

See [`test/README.md`](test/README.md) for the full test matrix and the curl
test-writing guide.

---

## How to add a feature

Build in layers so the next feature slots in without a rewrite:

1. Data shapes → typed freezed models in `lib/core/models/`.
2. Business logic → feature services (`lib/core/services/`) or repositories
   (`lib/core/repositories/`) — screens stay dumb; Go side goes in
   `internal/ops`.
3. State → Riverpod providers co-located with the feature (cross-cutting ones
   in `lib/core/providers/`).
4. UI → `lib/shared/widgets/` + design tokens (`docs/design/DESIGN.md`);
   loading/error/empty via `VStateView` family; lists via builders.
5. Routes → constants/builders in `lib/core/router/route_paths.dart`; no raw
   path strings elsewhere.
6. New behavior ships behind a feature flag (`lib/core/config/feature_flags.dart`).
7. Tuneable values go in `app_config` (`./samay config set <key> <value>
   --confirm`) — never hardcode economy/QR/limit constants.
8. Write the failing test first at every touched backend layer (Go
   `*_test.go`, curl opt-test `test/opt-NNN-*.sh`, pgTAP case in
   `supabase/tests/schema_test.sql`), implement the minimum, then run
   `make check` + `make test`. There are no Dart/Flutter or integration tests
   (directive 2026-08-31).

---

## Status & known gaps

- **Done:** foundation, admin CLI, auth/profiles, friends/groups (+ donations +
  rankings), events creation/detail, QR attendance/scanner (SQL RPC backing),
  E2EE chat 1:1 + group, feed/photos foundations, notification center,
  minigames, party finder, paywall shell, self-hosted infra + test stacks.
- **Pending:** Edge Functions (`supabase/functions/` is a boot stub — QR/rank/
  notify mechanics ship as SQL RPCs + pg_cron meanwhile), server-side rate
  limiting, RevenueCat webhook + subscription wiring, event invites/status
  server flows, cosmetics purchase flow, wager full-flow, collage PNG export,
  video souvenir/music library, alpha/beta launch phases, post-MVP web servers.
  Authoritative per-step statuses: `docs/specs/steps/cross-references.md`;
  open work items: specs kept under `docs/specs/steps/` for unimplemented steps.
- **Security posture + open items:** [`docs/security/SECURITY.md`](docs/security/SECURITY.md).
