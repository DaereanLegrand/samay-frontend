.PHONY: build dev install clean build-cli build-linux build-api lint test \
        flutter-test flutter-analyze define-env \
        supabase-start supabase-stop supabase-status supabase-reset \
        supabase-docker-start supabase-docker-stop supabase-docker-status supabase-docker-reset \
        supabase-testing-start supabase-testing-stop supabase-testing-status supabase-testing-reset \
        supabase-seed-dev \
        migrate-check

APP_NAME := samay_app
APK := build/app/outputs/flutter-apk/app-release.apk
GO_BIN := samay
GO_BIN_LINUX := samay-linux

# iOS install config
IOS_UDID      ?= 00008110-000254960A79401E
APPLE_ID      ?= burner.dom@icloud.com
APPLE_PASSWORD ?=
MACVM_PATH    ?= /Users/daerean/Codes/Samay

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

# Helper: print the effective dart-define flags for the current invocation.
define-env:
	@echo "ENV_FILE=$(ENV_FILE)"
	@echo "FLUTTER_DEFINES=$(FLUTTER_DEFINES)"

# ── Flutter ───────────────────────────────────────────────────────────────────

build:
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
	@if [ "$(TARGET)" = "ios" ]; then \
		if [ -z "$(APPLE_PASSWORD)" ]; then \
			echo "❌  APPLE_PASSWORD required. Pass it via: make install TARGET=ios APPLE_PASSWORD=..."; \
			exit 1; \
		fi; \
		ssh macvm "zsh -c 'source ~/.zprofile; source ~/.zshrc 2>/dev/null; export PATH; cd $(MACVM_PATH) && git stash push -m \"build_save\" 2>/dev/null; git pull; make build TARGET=ios NO_PUB=$(NO_PUB); git stash pop 2>/dev/null; true'" && \
		mkdir -p build/ios/ipa && \
		scp macvm:$(MACVM_PATH)/build/ios/ipa/$(APP_NAME).ipa build/ios/ipa/ && \
		ALTSERVER_ANISETTE_SERVER="http://127.0.0.1:6969" \
		altserver -u $(IOS_UDID) -a $(APPLE_ID) -p $(APPLE_PASSWORD) build/ios/ipa/$(APP_NAME).ipa; \
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

test: flutter-test
	go test ./... -v

flutter-test:
	flutter test

flutter-analyze:
	dart analyze

lint: flutter-analyze
	go vet ./... && golangci-lint run ./... || echo "golangci-lint not installed, using go vet only"

migrate-check:
	@echo "Checking migrations are committed to git..."
	@git status --short supabase/migrations/ | grep -q '?' && \
		echo "UNTRACKED MIGRATIONS FOUND (see above)" || true
	@echo "Migration files in git:"
	@git ls-files supabase/migrations/ | sort

# ── Supabase ──────────────────────────────────────────────────────────────────

supabase-start:
	supabase start

supabase-stop:
	supabase stop

supabase-status:
	supabase status

supabase-reset:
	supabase db reset

# ── Docker / Self-hosted Supabase ──────────────────────────

supabase-docker-start:
	cd supabase && docker compose up -d --wait

supabase-docker-stop:
	cd supabase && docker compose down

supabase-docker-status:
	cd supabase && docker compose ps

supabase-docker-reset:
	cd supabase && docker compose down && rm -rf volumes/db/data volumes/storage && docker compose up -d --wait

# Apply DEMO/dev seed data (supabase/seed-dev.sql, agent I-75) to a running
# stack. Demo-only — NOT applied by default (production seed stays clean).
# psql invocation mirrors supabase/reset.sh (host port 54382, approved map).
supabase-seed-dev:
	cd supabase && PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -f seed-dev.sql

supabase-testing-start:
	cd supabase-testing && docker compose up -d --wait

supabase-testing-stop:
	cd supabase-testing && docker compose down

supabase-testing-status:
	cd supabase-testing && docker compose ps

supabase-testing-reset:
	cd supabase-testing && docker compose down && rm -rf volumes/db/data volumes/storage && docker compose up -d --wait
