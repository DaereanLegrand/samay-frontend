.PHONY: build dev install clean build-cli build-linux build-api lint check test \
        test-all test-unit test-integration test-backend-static test-go \
        flutter-test flutter-analyze define-env secrets-check tunnel-android \
        supabase-start supabase-stop supabase-status supabase-reset \
        supabase-docker-start supabase-docker-stop supabase-docker-status supabase-docker-reset \
        supabase-db-test supabase-backend-tests supabase-stack-check \
        supabase-testing-start supabase-testing-stop supabase-testing-status supabase-testing-reset \
        supabase-seed-dev \
        migrate-check \
        ios-beta ios-release android-alpha android-release \
        deploy-api deploy-dashboard deploy-venue bundle-install

APP_NAME := samay_app
APK := build/app/outputs/flutter-apk/app-release.apk
GO_BIN := samay
GO_BIN_LINUX := samay-linux

# iOS install config (MKE-02: APPLE_PASSWORD is NEVER a Make variable — it is
# read from the sourced env files or the shell env at recipe time only, so it
# cannot leak into `make -n` output, shell history, or CI logs).
IOS_UDID      ?= 00008110-000254960A79401E
APPLE_ID      ?= burner.dom@icloud.com
MACVM_PATH    ?= /Users/daerean/Codes/Samay

# SSH tunnel config (MKE-08 — remote-device adb, Juega pattern).
TUNNEL_HOST   ?= <build-host>
TUNNEL_PORT   ?= 5555
TUNNEL_CMD    ?= flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d localhost:$(TUNNEL_PORT)

NO_PUB ?= true
TARGET ?=

ifeq ($(NO_PUB),false)
PUB_FLAG :=
else
PUB_FLAG := --no-pub
endif

# ── Compile-time defines (I-34 seam — M-13 owns the full env-sourcing pass) ──
#
# SEC-03/SEC-09/M-31/SUP-05: `.env` is NOT a Flutter asset anymore. The app
# reads SUPABASE_URL / SUPABASE_ANON_KEY via `String.fromEnvironment` at
# compile time, so build/run targets inject them here instead of bundling.
#
# - When a local `.env` exists (dev: `cp .env.example .env`), the default
#   injects it via `--dart-define-from-file` (Flutter ≥ 3.28 supports .env
#   files). No `.env` → no defines → the app fails fast at startup with a
#   StateError ("Missing required env variable"), never ships misconfigured.
# - `--dart-define` entries take precedence over `--dart-define-from-file`,
#   so CI/deploy passes explicit defines (CLI vars also override make):
#     make build FLUTTER_DEFINES="--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=..."
# - NEVER pass SUPABASE_SERVICE_ROLE_KEY or other server-side secrets to
#   flutter build/run (they are CLI/API-server/Edge-Function env only).
ENV_FILE := $(wildcard .env)
ifeq ($(ENV_FILE),)
FLUTTER_DEFINES :=
else
FLUTTER_DEFINES := --dart-define-from-file=.env
endif

# Test targets are intentionally define-FREE by default (I-34 proved
# `--dart-define` flips exactly the two env-dependent cases in
# test/core/env_config_test.dart, which assert the empty-default behavior).
# To prove a define reaches the app during a test run, pass it explicitly:
#   make test-unit FLUTTER_TEST_DEFINES="--dart-define=SUPABASE_URL=..."
FLUTTER_TEST_DEFINES ?=

# ── load-env (MKE-03 / M-13) ────────────────────────────────────────────────
# Source the local env files into the recipe shell; `set -a` exports, so
# later recipe lines and subprocesses inherit the values. `[ -r ] &&` guards
# a fresh clone with no local files — NOTE: macOS /bin/sh (bash 3.2) EXITS
# the shell when `.` is invoked on a missing file (even with `|| true`), so
# `.` is never run on an absent file. NEVER echo these values — the .env
# files may hold dev credentials (secrets-check enforces none are committed).
# Used by the build/dev/install/docker targets; the make-level
# `FLUTTER_DEFINES` decision above (I-34/M-11) is independent of this.
define load-env
set -a; [ -r ./.env.local ] && . ./.env.local || true; [ -r ./.env ] && . ./.env || true; set +a
endef

# Helper: print the effective dart-define flags for the current invocation.
define-env:
	@echo "ENV_FILE=$(ENV_FILE)"
	@echo "FLUTTER_DEFINES=$(FLUTTER_DEFINES)"

# ── Flutter ───────────────────────────────────────────────────────────────────

build:
	$(load-env)
	@if [ "$(TARGET)" = "ios" ]; then \
		flutter build ios --release --no-codesign $(PUB_FLAG) $(FLUTTER_DEFINES) && \
		cd build/ios && rm -rf Payload && mkdir Payload && \
		cp -R iphoneos/Runner.app Payload/ && \
		mkdir -p ipa && zip -r -y ipa/$(APP_NAME).ipa Payload && rm -rf Payload && \
		echo "✅  IPA: build/ios/ipa/$(APP_NAME).ipa"; \
	else \
		flutter build apk $(PUB_FLAG) $(FLUTTER_DEFINES) && \
		echo "✅  APK: $(APK)"; \
	fi

dev:
	$(load-env)
	@if [ "$(TARGET)" = "waydroid" ]; then \
		IP=$$(waydroid status | awk '/IP address:/ {print $$3}'); \
		adb connect "$$IP:5555"; \
		flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d "$$IP:5555"; \
	elif [ "$(TARGET)" = "android" ]; then \
		DEV=$$(adb devices | grep -o 'emulator-[0-9]*' | head -1); \
		if [ -n "$$DEV" ]; then \
			flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d "$$DEV"; \
		else \
			flutter run $(PUB_FLAG) $(FLUTTER_DEFINES); \
		fi; \
	elif [ -n "$(TARGET)" ]; then \
		flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d "$(TARGET)"; \
	else \
		flutter run $(PUB_FLAG) $(FLUTTER_DEFINES); \
	fi

install:
	$(load-env)
	@if [ "$(TARGET)" = "ios" ]; then \
		if [ -z "$$APPLE_PASSWORD" ]; then \
			echo "❌  APPLE_PASSWORD not set. Add it to ./.env.local (never committed) or export it (export APPLE_PASSWORD=... make install TARGET=ios)."; \
			exit 1; \
		fi; \
		ssh macvm "FLUTTER_DEFINES='$$FLUTTER_DEFINES' zsh -c 'source ~/.zprofile; source ~/.zshrc 2>/dev/null; export PATH; cd $(MACVM_PATH) && git stash push -m \"build_save\" 2>/dev/null; git pull; make build TARGET=ios NO_PUB=$(NO_PUB) FLUTTER_DEFINES=\"\$$FLUTTER_DEFINES\"; git stash pop 2>/dev/null; true'" && \
		mkdir -p build/ios/ipa && \
		scp macvm:$(MACVM_PATH)/build/ios/ipa/$(APP_NAME).ipa build/ios/ipa/ && \
		ALTSERVER_ANISETTE_SERVER="http://127.0.0.1:6969" \
		altserver -u $(IOS_UDID) -a $(APPLE_ID) -p "$$APPLE_PASSWORD" build/ios/ipa/$(APP_NAME).ipa; \
	elif [ "$(TARGET)" = "waydroid" ]; then \
		IP=$$(waydroid status | awk '/IP address:/ {print $$3}'); \
		adb connect "$$IP:5555" && adb -s "$$IP:5555" install -r $(APK); \
	elif [ "$(TARGET)" = "android" ]; then \
		DEV=$$(adb devices | grep -o 'emulator-[0-9]*' | head -1); \
		if [ -n "$$DEV" ]; then \
			adb -s "$$DEV" install -r $(APK); \
		else \
			adb -d install -r $(APK); \
		fi; \
	else \
		adb install -r $(APK); \
	fi

clean:
	flutter clean
	rm -f $(GO_BIN) $(GO_BIN_LINUX)
	rm -rf build/ios/ipa

# ── Go ────────────────────────────────────────────────────────────────────────

build-cli:
	go build -o $(GO_BIN) ./cmd/samay-admin

build-linux:
	GOOS=linux GOARCH=amd64 go build -o $(GO_BIN_LINUX) ./cmd/samay-admin

build-api:
	go build -o samay-api-server ./cmd/samay-api-server

# ── Tests ─────────────────────────────────────────────────────────────────────
# MKE-06 (M-11): separated targets. `make test` (= test-all) is the full local
# gate: Flutter unit/widget + Go + the backend STATIC gates (opt-005 seed-dev,
# opt-007 compose — no stack needed) + the hermetic integration suite.
# The LIVE backend opt-tests (001/002/003/004/006) need the stack up
# (`make supabase-docker-start`) and run via `bash test/run_all_backend.sh`.

test: test-all

test-all: test-unit test-go test-backend-static test-integration

# test/ only — integration_test/ is excluded (separate runner below).
test-unit: flutter-test

flutter-test:
	flutter test test/ $(FLUTTER_TEST_DEFINES)

test-integration:
	bash integration_test/runner.sh

test-backend-static:
	bash test/opt-005-seed-dev-static.sh
	bash test/opt-007-compose-static.sh

test-go:
	go test ./...

flutter-analyze:
	dart analyze

# ── Static checks (MKE-09 / M-11, secrets gate M-13) ────────────────────────
# Pre-CI gate: both analyzers + Go vet + the approved port map
# (tools/check_ports.sh --strict must exit 0 — see AGENTS.md Port Convention)
# + the committed-secret scan (tools/check_secrets.sh, MKE-02/MKE-03).
check: secrets-check
	dart analyze
	flutter analyze
	go vet ./...
	tools/check_ports.sh --strict

lint: flutter-analyze
	go vet ./... && golangci-lint run ./... || echo "golangci-lint not installed, using go vet only"

# Migration hygiene gate (MKE-07 CI parity, M-15). Logic lives in
# tools/check_migrations.sh (so test/opt-008-makefile-static.sh can RED-probe
# it against a scratch repo). Checks, in order:
#   1. no UNTRACKED migration files in EITHER stack (supabase/migrations +
#      supabase-testing/migrations — migrations must be committed to apply)
#   2. latest migration + file count match between the two stacks (M-10 parity)
#   3. no migration dated after today (UTC) — the YYYYMMDDHHMMSS convention
#   4. every migration matches the 14-digit timestamp convention
migrate-check:
	@tools/check_migrations.sh

# ── Supabase ──────────────────────────────────────────────────────────────────

# CLI-managed alternative (supabase start) — port-safe vs Juega since the
# config.toml remap (db 54382 / api 54386 / studio 54381 / inbucket 54384),
# but mutually exclusive with the compose stack below: both bind the same
# approved ports, so run EITHER `supabase start` OR `make supabase-docker-start`.
supabase-start:
	supabase start

supabase-stop:
	supabase stop

supabase-status:
	supabase status

supabase-reset:
	supabase db reset

# ── Docker / Self-hosted Supabase ──────────────────────────
# Canonical dev stack (SELFHOSTING.md). Each stack dir's .env sets
# COMPOSE_FILE (the override layering incl. docker-compose.s3.yml → MinIO);
# pass OVERRIDES to override the layering for a single run, e.g.:
#   make supabase-docker-start OVERRIDES="-f docker-compose.yml"   # file backend
# Host ports are env-driven (POSTGRES_PORT/KONG_HTTP_PORT/... in .env,
# approved defaults 54382/54386/54381/54384/54443) — never hardcoded here.
OVERRIDES ?=

supabase-docker-start:
	$(load-env)
	cd supabase && docker compose $(OVERRIDES) up -d --wait

supabase-docker-stop:
	$(load-env)
	cd supabase && docker compose down

supabase-docker-status:
	$(load-env)
	cd supabase && docker compose ps

# Full reset: down → remove DB + storage bind dirs → also remove the MinIO
# named volume (reset.sh does NOT clear it — M-06 gotcha; the `|| true` guard
# covers a fresh clone where the volume doesn't exist yet) → fresh stack up.
supabase-docker-reset:
	$(load-env)
	cd supabase && docker compose down && rm -rf volumes/db/data volumes/storage && (docker volume rm samay_minio-data 2>/dev/null || true) && docker compose up -d --wait

# Apply DEMO/dev seed data (supabase/seed-dev.sql, agent I-75) to a running
# stack. Demo-only — NOT applied by default (production seed stays clean).
# psql invocation mirrors supabase/reset.sh (host port 54382 = the approved
# POSTGRES_PORT default; pinned by test/opt-005-seed-dev-static.sh §8).
supabase-seed-dev:
	cd supabase && PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -f seed-dev.sql

# pgTAP schema tests (312 assertions, supabase/tests/schema_test.sql) against
# the SELF-HOSTED stack — `supabase db test --db-url` connects to the running
# compose DB on the approved port (verified: CLI v2.113.0 enables pgtap, then
# runs pg_prove via the supabase/pg_prove:3.36 docker image; first run pulls
# that image). NOT `supabase db test` bare: that targets the CLI-managed
# stack, which conflicts with the compose stack on the same approved ports.
# No-CLI fallback (no docker image needed):
#   PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres \
#     -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql
PGTAP_DB_URL ?= postgres://postgres:postgres@localhost:54382/postgres
supabase-db-test:
	@bash -c 'nc -z 127.0.0.1 54382 2>/dev/null' || { echo "❌  PostgreSQL not reachable on 54382 — start the stack first: make supabase-docker-start"; exit 1; }
	@command -v supabase >/dev/null || { echo "❌  supabase CLI not found — psql fallback: PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql"; exit 1; }
	supabase db test --db-url "$(PGTAP_DB_URL)" -- supabase/tests/schema_test.sql

# LIVE backend integration tests (test/opt-*.sh): RLS/events/chat/photos/E2EE
# (opt-001..006) hit Kong on the approved 54386 and need the stack up + reset;
# opt-005/opt-007 are static gates that pass anywhere. Runner:
# test/run_all_backend.sh (auto-discovery, per-file summary, exit 0/1).
supabase-backend-tests:
	@bash -c 'nc -z 127.0.0.1 54386 2>/dev/null' || { echo "❌  Kong not reachable on 54386 — start + reset the stack first: make supabase-docker-start && make supabase-docker-reset"; exit 1; }
	bash test/run_all_backend.sh

# Static stack gates (no stack needed): opt-005 (seed-dev) + opt-007 (compose
# parse/parity) + the repo-wide port-map gate (AGENTS.md Port Convention).
supabase-stack-check:
	bash test/opt-005-seed-dev-static.sh
	bash test/opt-007-compose-static.sh
	tools/check_ports.sh --strict

supabase-testing-start:
	$(load-env)
	cd supabase-testing && docker compose $(OVERRIDES) up -d --wait

supabase-testing-stop:
	$(load-env)
	cd supabase-testing && docker compose down

supabase-testing-status:
	$(load-env)
	cd supabase-testing && docker compose ps

supabase-testing-reset:
	$(load-env)
	cd supabase-testing && docker compose down && rm -rf volumes/db/data volumes/storage && (docker volume rm samay-testing_minio-data 2>/dev/null || true) && docker compose up -d --wait

# ── Remote-device tunnel (MKE-08 / M-13) ─────────────────────────────────────
# SSH-forward adb from a remote host that has a device attached (Juega
# pattern, read-only reference). Usage:
#   make tunnel-android                                   # default: <build-host>:5555 → flutter run
#   make tunnel-android TUNNEL_HOST=ci-box TUNNEL_PORT=5555
#   make tunnel-android TUNNEL_CMD="adb -s localhost:5555 install -r build/app/outputs/flutter-apk/app-release.apk"
tunnel-android:
	@(trap 'adb disconnect localhost:$(TUNNEL_PORT); kill 0' EXIT; \
		ssh -N -L $(TUNNEL_PORT):127.0.0.1:$(TUNNEL_PORT) $(TUNNEL_HOST) & sleep 1; \
		adb connect localhost:$(TUNNEL_PORT); \
		$(TUNNEL_CMD))

# ── Secrets gate (MKE-02 / MKE-03, M-13) ─────────────────────────────────────
# Committed-secret scan over TRACKED files only (git grep — untracked local
# .env/.env.local are by design not scanned). Patterns + documented
# allowlists live in tools/check_secrets.sh.
secrets-check:
	@tools/check_secrets.sh

# ── Fastlane stubs (MKE-05 / MKE-07 Makefile half, M-15) ─────────────────────
# Lane-name CONTRACT for M-17 (iOS) / M-18 (Android) — fixed HERE and in
# DEPLOYMENT-PLACEHOLDER.md §3.2/§3.3; M-22's release.yml invokes the same
# names. These four targets are the ONLY make-level fastlane entrypoints:
#
#   make ios-beta        → bundle exec fastlane ios beta_testflight     (M-17)
#   make ios-release     → bundle exec fastlane ios release_appstore    (M-17)
#   make android-alpha   → bundle exec fastlane android alpha_firebase  (M-18)
#   make android-release → bundle exec fastlane android release_play    (M-18)
#
# Until M-17/M-18 create fastlane/Fastfile with those lanes, each stub fails
# fast with a clear message (never a confusing bundler/fastlane error). Lanes
# may carry ONLY the §3.3 placeholder credentials — no real values ever
# (secrets-check enforces). `make -n` always resolves.
ios-beta:
	@[ -f fastlane/Fastfile ] || { echo "❌  fastlane iOS not wired yet — M-17 must create fastlane/Fastfile with the 'ios beta_testflight' lane (contract: DEPLOYMENT-PLACEHOLDER.md §3.3)."; exit 1; }
	@grep -q 'beta_testflight' fastlane/Fastfile || { echo "❌  lane 'beta_testflight' missing from fastlane/Fastfile — M-17 must implement it (DEPLOYMENT-PLACEHOLDER.md §3.3)."; exit 1; }
	bundle exec fastlane ios beta_testflight

ios-release:
	@[ -f fastlane/Fastfile ] || { echo "❌  fastlane iOS not wired yet — M-17 must create fastlane/Fastfile with the 'ios release_appstore' lane (contract: DEPLOYMENT-PLACEHOLDER.md §3.3)."; exit 1; }
	@grep -q 'release_appstore' fastlane/Fastfile || { echo "❌  lane 'release_appstore' missing from fastlane/Fastfile — M-17 must implement it (DEPLOYMENT-PLACEHOLDER.md §3.3)."; exit 1; }
	bundle exec fastlane ios release_appstore

android-alpha:
	@[ -f fastlane/Fastfile ] || { echo "❌  fastlane Android not wired yet — M-18 must create fastlane/Fastfile with the 'android alpha_firebase' lane (contract: DEPLOYMENT-PLACEHOLDER.md §3.3)."; exit 1; }
	@grep -q 'alpha_firebase' fastlane/Fastfile || { echo "❌  lane 'alpha_firebase' missing from fastlane/Fastfile — M-18 must implement it (DEPLOYMENT-PLACEHOLDER.md §3.3)."; exit 1; }
	bundle exec fastlane android alpha_firebase

android-release:
	@[ -f fastlane/Fastfile ] || { echo "❌  fastlane Android not wired yet — M-18 must create fastlane/Fastfile with the 'android release_play' lane (contract: DEPLOYMENT-PLACEHOLDER.md §3.3)."; exit 1; }
	@grep -q 'release_play' fastlane/Fastfile || { echo "❌  lane 'release_play' missing from fastlane/Fastfile — M-18 must implement it (DEPLOYMENT-PLACEHOLDER.md §3.3)."; exit 1; }
	bundle exec fastlane android release_play

# ── Ruby bundle (MKE-10 — Gemfile itself is M-19's; this is the guard) ──────
# `bundle install` is Gemfile.lock-aware: it resolves dependencies AND freezes
# the lockfile that M-19 commits. Guards on Gemfile presence so a pre-fastlane
# clone gets a clear message instead of bundler's own error.
bundle-install:
	@[ -f Gemfile ] || { echo "❌  No Gemfile — fastlane's Gemfile is M-19 scope (MKE-10). Nothing to bundle yet."; exit 1; }
	bundle install

# ── Deploy placeholders (M-16 scope, landed with M-15) ───────────────────────
# Deployment is NOT wired. These targets echo the target shapes and point at
# DEPLOYMENT-PLACEHOLDER.md (the placeholder-registry doc, §1.2/§6) — they
# never resolve, fetch, or print a real URL, domain, or credential (repo-wide
# placeholder policy). Real deploys land with: API server (I-41 + M-21),
# dashboard/portal (post-MVP DASH/PORT), venue app (post-MVP).
deploy-api:
	@echo "⚠️  deploy-api is a PLACEHOLDER — nothing is deployed."
	@echo "   Target shape: Go samay-api-server behind Nginx/HTTPS (§1.1 #4)."
	@echo "   Contract + registry rows: <private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md (§1.2, §6 R02)."
	@exit 0

deploy-dashboard:
	@echo "⚠️  deploy-dashboard is a PLACEHOLDER — nothing is deployed."
	@echo "   Target shape: Admin Dashboard (React static, §1.1 #5, post-MVP)."
	@echo "   Contract + registry rows: <private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md (§1.2, §6 R06)."
	@exit 0

deploy-venue:
	@echo "⚠️  deploy-venue is a PLACEHOLDER — nothing is deployed."
	@echo "   Target shape: Samay Venue app (Flutter, §1.1 #7, post-MVP);"
	@echo "   distribution lanes per §3.3."
	@echo "   Contract: <private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md."
	@exit 0
