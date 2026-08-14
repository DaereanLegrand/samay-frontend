# Phase 15 — Post-MVP Web Servers · PLAN

> Compiled by D-12 (2026-08-09) from `docs/specs/steps/phase-15-post-mvp-web-servers/*`
> and `docs/specs/steps/cross-references.md`. Read-only planning aid — post-MVP,
> but I-41 (Gin scaffold) runs during 4.2 as groundwork.

## Summary

Build the shared Go API server (`samay-api-server`, Gin) plus three frontends:
Admin Dashboard (React), Promotor Portal (React, Culqi paid events), and Samay
Venue (Flutter, Tono B2B ecosystem). All business logic is imported from
`internal/ops` — zero duplication with the CLI (same Go module
`github.com/samay-app/samay`).

Key mechanics (from specs):
- **APIS:** `cmd/samay-api-server/main.go` (env → DB client → Gin) +
  `routes.go`. Route namespaces: `/api/v1/health`, `/api/v1/admin/*` (admin_users
  only), `/api/v1/promotor/*` (verified Samay users), `/api/v1/venue/*`
  (venue_users). JWT middleware verifies Supabase-issued tokens against JWKS,
  extracts user ID + role. Default port 8080; `make build-api` target.
- **DASH:** React 18 + TS + Tailwind (black/white/gray), TanStack Query, Recharts,
  Supabase JS auth (admin_users). Pages: dashboard/stats+charts, users (+detail:
  ledger/groups/events/reports + actions), events (feature/cancel/distribute),
  groups, reports queue (remove/warn/dismiss + bulk dismiss), feature requests,
  config (inline edit + reset), subscriptions (overrides), audit log (read-only).
  Role-based UI: super_admin full; moderator reports+users only.
- **PORT:** React, same stack, separate deployment. Login with existing Samay
  account ("Continuar con tu cuenta de Samay"). Pages: my paid events, create paid
  event (link to app event, ticket price in céntimos, quantity, sale window, Culqi
  recipient), event management (guest list, manual add/remove, refund via Culqi
  API, CSV export), revenue & payouts (gross, 5% fee, net, payout status/history).
  New tables: `paid_events`, `ticket_purchases` (ticket QR token). Culqi webhook →
  Edge Function → `ticket_purchases` + buyer push with ticket QR.
- **VENU:** Flutter companion app for venue staff; venue profile (verified badge),
  event management (Tono events + promo codes), door dashboard (QR scanner for
  attendance + ticket QRs, live guest list, capacity counter, manual override,
  fast mode), analytics (attendance trends, peak times, revenue, promo usage,
  aggregated demographics), optional in-venue ordering module. Separate `venue`
  Postgres schema with its own RLS; main app reads via read-only views. Venue tiers
  (Basic/Standard/Premium).
- **DEPL:** single Go binary (systemd or Docker) behind Nginx/HTTPS; React
  frontends as static files (Nginx/Cloudflare Pages); Flutter apps via stores;
  CLI runs locally; Supabase self-hosted with backups + monitoring; external
  services (Pusher Beams, RevenueCat, PostHog, Culqi).
- Deployment URLs: **placeholders only** (see `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md`).

## Steps & dependency status (cross-references.md, verified 2026-08-09)

| Step | Direct deps | Dep status | Step status |
|------|-------------|------------|-------------|
| `APIS` | `DBCL`✅, `ROOT`✅, `USRS`✅, `EVTC`✅, `GRPS`✅, `RPTS`✅, `SHRD`✅, `CONF`✅, `SUBS`✅, `SYST`✅, `AUDT`✅ | ALL GREEN | ✅ **Landed (I-41, 2026-08-09)** — `cmd/samay-api-server/main.go` + `routes.go` exist (Gin scaffold: 31 admin routes + `/api/v1/health` + reserved 501 namespaces); `make build-api` target present (Makefile:530); 17 httptest tests (`main_test.go` 3 + `routes_test.go` 14) green; `ADMIN_API_KEY` placeholder gate (JWT/JWKS = S-06/M-21) |
| `DASH` | `APIS`❌, `DATA`✅ | 1/2 green | ❌ |
| `PORT` | `APIS`❌, `DATA`✅ | 1/2 green | ❌ |
| `VENU` | `APIS`❌, `DATA`✅, `FLUT`✅ | 2/3 green | ❌ |
| `DEPL` | `APIS`❌, `DASH`❌, `PORT`❌, `VENU`❌, `INFR`✅ | 1/5 green | ❌ |

## Orchestration agents contributing (groundwork during 4.2)

| Agent | Contribution |
|-------|--------------|
| I-41 | `cmd/samay-api-server/**` Gin scaffold (⚙️ M-21 later adds `build-api` CI) |
| I-39/I-40 | `internal/ops` error handling + `internal/db` query builder/crud hardening (APIS depends on these being solid) |
| I-42 | API-server tests (`cmd/samay-api-server/**` tests) |
| I-43 | `internal/ops/system.go` stats/health (APIS `/admin/dashboard/stats` source) |
| I-50/I-51 | Repository layer + typed REST client (app-side patterns the web frontends mirror) |
| M-21 | ~~`.github/workflows/build.yml`~~ + `build-api` — **workflow removed 2026-08-14 (no GitHub Actions); the `build-api` Makefile target remains** |

DASH/PORT/VENU/DEPL themselves are post-MVP workstreams with no 4.2 I-agent.

## Acceptance checklist (from the step specs)

**APIS (`APIS-go-api-server.md`):**
- [ ] `cmd/samay-api-server/main.go`: env → `DBCL` client → Gin; middleware chain (CORS, request logging, JWT verify vs Supabase JWKS, role extraction); default port 8080
- [ ] `routes.go`: `/api/v1/health` ({"status":"ok","version":"1.0"}); admin routes mapping to `SYST/USRS/EVTC/GRPS/RPTS/CONF/SUBS` ops per the spec table (22 routes listed); promotor + venue namespaces stubbed with auth
- [ ] Auth middleware: admin_users DB check (super_admin/moderator), promotor role check per event, venue_users check
- [ ] `make build-api` → single binary; `curl /api/v1/health` works

**DASH (`DASH-admin-dashboard-react.md`):**
- [ ] Tech stack in place (React 18 + TS + Tailwind + TanStack Query + Recharts + Supabase JS)
- [ ] All 10 pages per spec (dashboard w/ 4 charts + quick actions, users, user detail w/ tabs, events, groups, reports queue w/ inline actions + bulk dismiss, feature requests, config w/ inline edit + reset, subscriptions w/ overrides, audit log read-only)
- [ ] Login via Supabase Auth (admin_users); role-based UI (super_admin vs moderator)

**PORT (`PORT-promotor-portal-react.md`):**
- [ ] Login "Continuar con tu cuenta de Samay" (existing account, no registration)
- [ ] My Paid Events (status badges, stats); Create Paid Event (link/push event, price céntimos, quantity, sale window, Culqi recipient, preview)
- [ ] Event management: guest list + search, manual add/remove, refund (Culqi API + status update), CSV export
- [ ] Revenue & payouts (gross, 5% fee, net, status, history); Culqi webhook flow (charge → Edge Function → `ticket_purchases` → buyer push w/ ticket QR)
- [ ] New tables `paid_events` + `ticket_purchases` created

**VENU (`VENU-vive-venue-app-flutter.md`):**
- [ ] Venue profile (verified badge request), event management + promo codes, door dashboard (QR scan both QR types, live guest list, capacity counter, manual override, fast mode), analytics (aggregated, no PII), optional ordering module
- [ ] `venue` schema (8 tables listed) with isolated RLS; read-only views into `public`
- [ ] Venue tier handling (Basic/Standard/Premium)

**DEPL (`DEPL-deployment-architecture.md`):**
- [ ] Architecture per diagram (mobile + 2 React SPAs + venue app → API server → Supabase)
- [ ] Go binary deploy (systemd/Docker) + Nginx/HTTPS (Let's Encrypt) + CORS
- [ ] React static deploys (Nginx or Cloudflare Pages, SPA routing, `VITE_API_URL` build-time)
- [ ] Flutter store pipelines (fastlane — no GitHub Actions, decision 2026-08-14); Supabase backups + monitoring
- [ ] External services wired (Pusher Beams, RevenueCat, PostHog, Culqi); placeholder URLs only

## Phase exit gate

All 5 steps green in cross-references.md; API server serving all three frontends
with JWT auth; paid-event round-trip (Culqi sandbox) verified; `venue` schema
isolated; deployment docs matching reality; full matrix green.
