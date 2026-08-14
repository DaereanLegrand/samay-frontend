# Phase 00 — REPO + INFR: Repository Setup & Supabase Deployment

## Date: 2026-05-10

## What was built

### REPO — Repository & Go Module Scaffolding
- **AGENTS.md** — development methodology with TDD workflow, parallel track policy, port conventions, validation gate
- **Go module** initialized at `github.com/samay-app/samay` (`go.mod`)
- Directory scaffold:
  - `cmd/samay-admin/` — Admin CLI entry point
  - `cmd/samay-api-server/` — API server placeholder (post-MVP)
  - `internal/ops/` — shared business logic
  - `internal/db/` — Supabase client helpers
  - `internal/format/` — output formatters
- `.env.example` — template vars (Supabase, Pusher, RevenueCat, PostHog)
- `.gitignore` — Go binaries, .env, IDE files, Flutter build cache
- Go test files (`client_test.go`, `main_test.go`) — TDD: written before main implementation

### INFR — Supabase Self-Hosted Deployment (Port-Constrained)
- `supabase/config.toml` — port remapping (only services with exposed ports listed):
  - PostgreSQL: 54322 → **5432** (direct DB access)
  - Studio: 54321 → **54381**
  - Mailpit (Email): 54324 → **54384**
  - Kong (API Gateway): 54321 → **54386** (all API routes)
  - Analytics: 54327 → **54388**
  - Pooler: 54329 → disabled (not needed for dev)
- Auth (GoTrue), Realtime, Storage, pg-meta, Edge Runtime routed through Kong — no individual host ports

## Decisions
- **Supabase CLI** used for deployment (not raw Docker Compose) — installed v2.90.0, cleaner port management
- **Port offset varies:** blocked ports remapped to +60 range (54321→54381, 54322→5432, 54323→54386 via Kong, 54324→54384, 54327→54388, 54329→disabled)
- Go `internal/` package visibility restricts CLI-only code from leaking — API server (post-MVP) lives in same module so it can import `internal/ops`

## MISTAKE: Initial `config.toml` used wrong format for Supabase CLI
The first version used `[edge_functions]` section name. The correct section is `[edge_runtime]`. Also `[realtime]`, `[storage]`, `[auth]` don't have `port` keys — those services route through Kong.

## Supabase Start Output
```
Studio:      http://127.0.0.1:54381
Mailpit:     http://127.0.0.1:54384
Project URL: http://127.0.0.1:54386
REST API:    http://127.0.0.1:54386/rest/v1
Edge Fns:    http://127.0.0.1:54386/functions/v1
DB URL:      postgresql://postgres:postgres@127.0.0.1:5432/postgres
```
- Warning `no files matched pattern: supabase/seed.sql` is expected — will be created in DATA step
- Coexists with existing `juega-app-2` Supabase instance (different ports, no conflicts)

## Commands Run
```bash
go mod init github.com/samay-app/samay
mkdir -p cmd/samay-admin cmd/samay-api-server internal/ops internal/db internal/format
git init
supabase start
go test ./...
```

## Next Steps
- `DATA` — full database schema migration (30 tables, enums, constraints, seed data)
- `SECU` — RLS policies on all tables
- Tests for Go module should pass after dependencies installed
