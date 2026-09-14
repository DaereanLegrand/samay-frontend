.PHONY: help build dev install build-install clean clear-storage uninstall build-cli build-linux build-api lint check test \
        test-all test-backend-static test-go \
        flutter-analyze define-env secrets-check tunnel-android tunnel-waydroid \
        ios-signing-restore \
        install-hooks \
        supabase-start supabase-stop supabase-status supabase-reset supabase-init \
        supabase-docker-start supabase-docker-stop supabase-docker-status supabase-docker-reset \
        supabase-db-test supabase-backend-tests supabase-stack-check \
        supabase-testing-start supabase-testing-stop supabase-testing-status supabase-testing-reset \
        supabase-testing-init \
        supabase-seed-config \
        supabase-seed-test \
        migrate-check \
        ios-beta ios-release android-alpha android-release \
        deploy-api deploy-dashboard deploy-venue bundle-install

# ── Help ─────────────────────────────────────────────────────────────────────
# Usage cheatsheet for every documented target. TARGET values: all, android,
# waydroid, ios, ios-adhoc, simulator (see each target's comments).
help:
	@echo "Samay — make targets (TARGET=all|android|waydroid|ios|ios-adhoc|simulator)"
	@echo ""
	@echo "  BUILD / RUN"
	@echo "    build [TARGET]           build for a platform: ios-adhoc (device IPA),"
	@echo "                             simulator (Runner.app), android (APK), ios"
	@echo "                             (unsigned iphoneos IPA), all (sweep, skips unavailable)"
	@echo "    dev [TARGET]             build + run with hot reload (ios = physical iPhone,"
	@echo "                             simulator, android/waydroid via LAN tunnels, ios-adhoc ="
	@echo "                             deploy + launch); auto-fixes Xcode/signing state"
	@echo "    install [TARGET]         install the built app on target device(s)"
	@echo "    build-install [TARGET]   build + install in one go (any TARGET)"
	@echo "    uninstall TARGET         remove the app from device(s) (TARGET REQUIRED)"
	@echo "    clear-storage TARGET     wipe the app's local data on device(s)"
	@echo "    clean                    flutter clean + remove Go binaries and IPAs"
	@echo ""
	@echo "  DEVICE TUNNELS (macOS -> <build-host>)"
	@echo "    tunnel-android           SSH adb tunnel to the <build-host>'s Android/emulator (LAN-first)"
	@echo "    tunnel-waydroid          SSH adb tunnel to the <build-host>'s waydroid"
	@echo "    ios-signing-restore      reset the pbxproj signing placeholders (opt-008)"
	@echo ""
	@echo "  CHECKS / TESTS"
	@echo "    check                    full static gate: analyzers + go vet + ports + secrets"
	@echo "    test / test-all          full local gate (Go + backend static)"
	@echo "    test-backend-static      static opt gates (no stack needed)"
	@echo "    test-go                  go test ./..."
	@echo "    flutter-analyze          dart analyze"
	@echo "    secrets-check            committed-secret scan"
	@echo "    define-env               print the effective dart-define flags"
	@echo "    install-hooks            wire the pre-commit gate (core.hooksPath)"
	@echo ""
	@echo "  GO BINARIES"
	@echo "    build-cli                build ./samay (admin CLI)"
	@echo "    build-linux              build ./samay-linux (admin CLI, linux/amd64)"
	@echo "    build-api                build ./samay-api-server (Gin API server)"
	@echo ""
	@echo "  SUPABASE STACKS (ports 54382/54386/54381/54384/54443 — never Juega's)"
	@echo "    supabase-start/stop/status/reset      prod stack lifecycle (reset = fresh schema + config, no user data)"
	@echo "    supabase-init            start prod stack + migrations + seed-config (fresh DB)"
	@echo "    supabase-docker-*        same, explicit docker compose lifecycle"
	@echo "    supabase-testing-*       testing stack lifecycle (mutually exclusive with prod)"
	@echo "    supabase-testing-init    testing stack + MAILPIT + migrations + seed-config"
	@echo "    supabase-db-test         pgTAP schema tests"
	@echo "    supabase-backend-tests   backend opt-test suite (needs the stack up)"
	@echo "    supabase-stack-check     stack health/port check"
	@echo "    supabase-seed-config     idempotent re-apply of required app config"
	@echo "    supabase-seed-test       apply @tester test-data snapshot (explicit only)"
	@echo "    migrate-check            migration drift check"
	@echo ""
	@echo "  RELEASE / DEPLOY"
	@echo "    ios-beta / ios-release   fastlane TestFlight / App Store lanes"
	@echo "    android-alpha / android-release   fastlane Firebase / Play lanes"
	@echo "    deploy-api / deploy-dashboard / deploy-venue   deploy placeholders (not wired)"
	@echo "    bundle-install           install bundler gems (fastlane)"

APP_NAME := samay_app
# Android dev-build mode (2026-08-15 fix, M-27 preserved): `make build
# TARGET=android|waydroid` (and the bare `make build`) builds a DEBUG apk.
# Dev installs never need the §3.3 release keystore (the M-27 fail-fast
# guard still kills assembleRelease/bundleRelease without it), and the
# debug-signed apk installs `-r` over the debug apps already on the devices.
# Real release/AAB packaging goes through fastlane/M-22 — never this target.
BUILD_MODE ?= debug
APK := build/app/outputs/flutter-apk/app-$(BUILD_MODE).apk
GO_BIN := samay
GO_BIN_LINUX := samay-linux
IPA_ADHOC := build/ios/ipa/$(APP_NAME)-adhoc.ipa
# Package id the app is installed under on every platform (uninstall/clear).
APP_ID := com.qallariy.samay

# ── Toolchain PATH (../Juega pattern) ────────────────────────────────────────
# Every recipe resolves the Homebrew ruby (and its gem binstubs) first — the
# macOS system ruby (2.6.10) and its bundler reject the Gemfile (>= 3.0) and
# the bundler-4 lockfile ("The running version of Bundler ... does not match
# ..."). Mirror of Juega's Makefile export (Juega also prepends openjdk@21 —
# Samay's Flutter builds use their own JDK, so only the ruby/gem bins here).
# Like Juega, the lanes are invoked via the COMMITTED ./bin/fastlane binstub
# (never the `bundle` command — Xcode's make 3.81 execvp's simple commands
# directly and would resolve `bundle` to /usr/bin/bundle, bypassing this
# export; the slash-qualified binstub resolves by path, and its
# `#!/usr/bin/env ruby` picks this exported PATH).
export PATH := /opt/homebrew/opt/ruby/bin:/Users/daerean/.local/share/gem/ruby/4.0.0/bin:$(PATH)
# Absolute bundler for the explicit setup step (make bundle-install) — same
# fast-path rationale as above.
BREW_BUNDLE := /opt/homebrew/opt/ruby/bin/bundle

# Apple Developer enrollment signing team for iOS DEVICE builds
# (make build TARGET=ios-adhoc): an env export wins; otherwise .env.local
# (gitignored — the repo contract never tracks a real team ID; find yours
# with `security find-identity -v -p codesigning`).
IOS_DEVELOPMENT_TEAM ?= $(shell sed -n 's/^IOS_DEVELOPMENT_TEAM=//p' .env.local 2>/dev/null | head -1)


# SSH tunnel config (MKE-08 — remote-device adb, Juega pattern).
#
# Port scheme: EVERY (repo, target) pair uses its own LOCAL port so waydroid
# AND android (emulator) can tunnel at the same time, and Juega (5555/5556)
# and Vive (5565/5566) can tunnel concurrently from the same Mac. The
# <build-host>-side device ports stay 5555 (emulator adbd / waydroid adbd).
TUNNEL_HOST          ?= <build-host>
TUNNEL_ANDROID_PORT  ?= 5565
TUNNEL_WAYDROID_PORT ?= 5566
TUNNEL_CMD    ?= flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d localhost:$(TUNNEL_ANDROID_PORT)
TUNNEL_WAYDROID_CMD ?= flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d localhost:$(TUNNEL_WAYDROID_PORT)

# Juega-pattern tunnel helpers (macOS → <build-host>): `dev`/`install`/`clear-storage`
# route TARGET=android|waydroid through these on Darwin; non-Darwin hosts run
# `waydroid status`/adb directly. The SSH host is resolved at runtime by
# <tunnel-host-helper>: the LOCAL-network <build-host> (<local-lan-ip> /
# <build-host>) is used whenever it is pingable, otherwise the remote alias
# (<build-host> — e.g. Tailscale) — adb auth only works over the LAN path.
define tunnel-android
  HOST="$(TUNNEL_HOST)"; [ -n "$$HOST" ] || { echo "TUNNEL_HOST is required"; exit 2; }; \
  (trap 'kill $$SSH_PID 2>/dev/null; adb disconnect localhost:$(TUNNEL_ANDROID_PORT) 2>/dev/null' EXIT; \
   ssh -N -L $(TUNNEL_ANDROID_PORT):127.0.0.1:5555 "$$HOST" & SSH_PID=$$!; sleep 3; \
   adb connect localhost:$(TUNNEL_ANDROID_PORT); \
   $(1))
endef

define tunnel-waydroid
  HOST="$(TUNNEL_HOST)"; [ -n "$$HOST" ] || { echo "TUNNEL_HOST is required"; exit 2; }; \
  WIP=$$(ssh "$$HOST" "waydroid status | awk '/IP address/ {print \$$3}'"); \
  (trap 'kill $$SSH_PID 2>/dev/null; adb disconnect localhost:$(TUNNEL_WAYDROID_PORT) 2>/dev/null' EXIT; \
   ssh -N -L $(TUNNEL_WAYDROID_PORT):$$WIP:5555 "$$HOST" & SSH_PID=$$!; sleep 3; \
   adb connect localhost:$(TUNNEL_WAYDROID_PORT); \
   $(1))
endef

# Direct (non-Darwin) waydroid preflight — `waydroid status` is the oracle:
# CLI installed → container RUNNING → session IP resolved (the IP line only
# appears once the Android session has a network address). Echoes "<ip>" on
# success so callers can do `IP=$$($(call waydroid-preflight)); ...`. Single
# physical line: it is substituted INLINE into recipe shell lines.
define waydroid-preflight
command -v waydroid >/dev/null 2>&1 || { echo "❌  waydroid CLI not found on this machine — install Waydroid or use TARGET=android."; exit 1; }; WS=$$(waydroid status 2>/dev/null || true); echo "$$WS" | grep -Eq 'Container:[[:space:]]*RUNNING' || { echo "❌  Waydroid container not RUNNING — start it first ('waydroid show-full-ui'), then retry. status:"; echo "$$WS"; exit 1; }; WIP=$$(echo "$$WS" | awk '/IP address:/ {print $$3}'); [ -n "$$WIP" ] || { echo "❌  Waydroid RUNNING but no session IP yet — open the Waydroid UI once so the session gets an address, then retry."; exit 1; }; echo "$$WIP"
endef

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

# Host address an Android AVD guest uses to reach THIS machine's API gateway
# (Kong 54386). On Linux the emulator's LAN-IP hairpin is unreliable (wlan0
# power-save/roaming silently drops SYNs — 2026-08-22 session: healthy stack,
# intermittent errno-110 from `make dev TARGET=android`), and 127.0.0.1 inside
# the guest is the GUEST itself; 10.0.2.2 is the emulator's canonical alias for
# host loopback (sub-ms, wlan-independent).
ANDROID_GATEWAY_HOST := $(if $(findstring Linux,$(shell uname -s)),10.0.2.2,127.0.0.1)
# Non-empty on Darwin (see the TARGET=android define override below).
OS_IS_DARWIN := $(findstring Darwin,$(shell uname -s))

# Test targets are intentionally define-FREE by default (I-34 proved
# `--dart-define` flips exactly the two env-dependent cases that the deleted
# Flutter test suite covered). The only remaining test surface is backend
# (Go + curl opt-tests), which reads the env directly.
FLUTTER_TEST_DEFINES ?=

# ── TESTING mode (TESTING=true) ──────────────────────────────────────────────
# Points EVERY Flutter build/run/install at the LOCAL self-hosted stack
# (Kong on the approved 127.0.0.1:54386) instead of .env's URL, and mints a
# FRESH temporary anon JWT (24h, signed with the local stack's JWT_SECRET
# from supabase/.env) instead of reusing the committed publishable key — so
# test builds never touch the remote stack and never bake the repo-wide key.
# The temp JWT is registered with the local Kong (idempotent append to the
# container's resolved /usr/local/kong/kong.yml + kong reload — the TRACKED
# template keeps only $VAR refs per the opt-007 gate) and dies with the next
# kong restart (entrypoint re-templates) or after 24h.
#   make dev TESTING=true | make build TESTING=true | make install TESTING=true
TESTING ?= false
ifeq ($(TESTING),true)
TESTING_JWT_SECRET := $(or $(shell sed -n 's/^JWT_SECRET=//p' supabase/.env 2>/dev/null | head -1),$(JWT_SECRET))
ifeq ($(strip $(TESTING_JWT_SECRET)),)
$(error TESTING=true needs the local stack signing secret: JWT_SECRET in supabase/.env (or exported))
endif
TESTING_ANON_KEY := $(shell JWT_SECRET='$(TESTING_JWT_SECRET)' python3 tools/gen_testing_anon_key.py)
FLUTTER_DEFINES += --dart-define=SUPABASE_URL=http://$(ANDROID_GATEWAY_HOST):54386 --dart-define=SUPABASE_ANON_KEY=$(TESTING_ANON_KEY)
build: | testing-kong-register
dev: | testing-kong-register
install: | testing-kong-register
tunnel-android: | testing-kong-register
endif

# ── fastlane lane env (ios-adhoc builds) ─────────────────────────────────────
# The adhoc_local lane reads SUPABASE_URL / SUPABASE_ANON_KEY from the
# environment (Fastfile dart_defines).
#   * DEFAULT (TESTING unset): the production API — SUPABASE_URL is read from
#     .env (placeholder per <private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md R03 — put the
#     real Kong domain there) and SUPABASE_ANON_KEY likewise from .env.
#   * TESTING=true: the LOCAL stack via this Mac's LAN IP <local-lan-ip>
#     (127.0.0.1 is NOT reachable from the iPhone); SUPABASE_URL is pinned to
#     that LAN address and SUPABASE_ANON_KEY still comes from .env (the local
#     stack's anon key, valid for the local Kong). The freshly minted
#     TESTING_ANON_KEY is still registered with Kong by testing-kong-register
#     and is consumed by the FLUTTER_DEFINES-based build/dev/install targets.
ifeq ($(TESTING),true)
LANE_SUPABASE_URL := http://<local-lan-ip>:54386
else
LANE_SUPABASE_URL := $(shell sed -n 's/^SUPABASE_URL=//p' .env 2>/dev/null | head -1)
endif

LANE_SUPABASE_ANON_KEY := $(shell sed -n 's/^SUPABASE_ANON_KEY=//p' .env 2>/dev/null | head -1)

# Register the TESTING anon JWT with the local Kong so the app's requests
# pass key-auth (the temp key is NOT the committed $ANON_KEY credential).
# The Kong container is located by the approved host port (54386) so this
# works whichever local stack is up (supabase/ or supabase-testing/).
# Appends to the CONTAINER-side resolved config only — the tracked
# kong.yml template keeps its $VAR refs (opt-007 no-literal-key gate) and
# the entrypoint regenerates the resolved file on every kong restart, so
# the temp key is truly temporary. Non-fatal: a build without the stack
# still proceeds (the app fails fast at runtime if Kong is unreachable).
testing-kong-register:
	@[ -n "$(TESTING_ANON_KEY)" ] || { echo "❌  TESTING=true: failed to mint the anon JWT (see tools/gen_testing_anon_key.py)."; exit 1; }
	@KONG=$$(docker ps --format '{{.Names}}' --filter publish=54386 | head -1); \
	if [ -z "$$KONG" ]; then \
		echo "⚠️  No Kong on 127.0.0.1:54386 — temp JWT NOT registered (app will 401). Start a stack: make supabase-docker-start / supabase-testing-start"; \
	elif docker exec "$$KONG" sh -c 'grep -qF "$(TESTING_ANON_KEY)" /usr/local/kong/kong.yml' 2>/dev/null; then \
		echo "✅  TESTING mode: anon JWT already registered in $$KONG (127.0.0.1:54386)"; \
	elif docker exec "$$KONG" sh -c 'printf "\n  - consumer: anon\n    key: %s\n" "$(TESTING_ANON_KEY)" >> /usr/local/kong/kong.yml' 2>/dev/null && docker exec "$$KONG" kong reload >/dev/null 2>&1; then \
		echo "✅  TESTING mode: 127.0.0.1:54386 + fresh anon JWT registered in $$KONG (24h; cleared on kong restart)"; \
	else \
		echo "⚠️  Kong registration failed on $$KONG — temp JWT NOT registered (app will 401)."; \
	fi

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
	@if [ "$(TARGET)" = "all" ]; then \
		for t in ios-adhoc simulator android; do \
			echo "━━━ build for $$t ━━━"; \
			make build TARGET=$$t NO_PUB=$(NO_PUB) || true; \
		done; \
	elif [ "$(TARGET)" = "ios" ]; then \
		flutter build ios --release --no-codesign $(PUB_FLAG) $(FLUTTER_DEFINES) && \
		cd build/ios && rm -rf Payload && mkdir Payload && \
		cp -R iphoneos/Runner.app Payload/ && \
		mkdir -p ipa && zip -r -y ipa/$(APP_NAME).ipa Payload && rm -rf Payload && \
		echo "✅  IPA: build/ios/ipa/$(APP_NAME).ipa"; \
	elif [ "$(TARGET)" = "ios-adhoc" ]; then \
		IOS_DEVELOPMENT_TEAM="$(IOS_DEVELOPMENT_TEAM)" \
		SUPABASE_URL="$(LANE_SUPABASE_URL)" \
		SUPABASE_ANON_KEY="$(LANE_SUPABASE_ANON_KEY)" \
		./bin/fastlane ios adhoc_local && \
		echo "✅  IPA: $(IPA_ADHOC)"; \
	elif [ "$(TARGET)" = "simulator" ]; then \
		flutter build ios --simulator $(PUB_FLAG) $(FLUTTER_DEFINES) && \
		echo "✅  Simulator app: build/ios/iphonesimulator/Runner.app"; \
	else \
		flutter build apk --$(BUILD_MODE) $(PUB_FLAG) $(FLUTTER_DEFINES) && \
		echo "✅  APK: $(APK)"; \
	fi

# NOTE (dev, TARGET=ios-adhoc): the delegation below uses a LITERAL `make`,
# not the $(MAKE) variable — GNU make EXECUTES recipe lines containing
# $(MAKE) even under `make -n`, which would run the chain for real and break
# opt-008's dry-run gate. A literal `make` still inherits MAKEFLAGS
# (TESTING=true etc.) through the recipe environment.
dev:
	$(load-env)
	@UNAME=$$(uname); \
	if [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "android" ]; then \
		$(call tunnel-android, flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d localhost:$(TUNNEL_ANDROID_PORT)); \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "waydroid" ]; then \
		$(call tunnel-waydroid, flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d localhost:$(TUNNEL_WAYDROID_PORT)); \
	elif [ "$(TARGET)" = "waydroid" ]; then \
		IP=$$($(call waydroid-preflight)); \
		adb connect "$$IP:5555"; \
		flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d "$$IP:5555"; \
	elif [ "$(TARGET)" = "android" ]; then \
		DEV=$$(adb devices | grep -o 'emulator-[0-9]*' | head -1); \
		if [ -n "$$DEV" ]; then \
			flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d "$$DEV"; \
		else \
			flutter run $(PUB_FLAG) $(FLUTTER_DEFINES); \
		fi; \
	elif [ "$(TARGET)" = "simulator" ]; then \
		DEVS=$$(xcrun simctl list devices booted | awk -F '[()]' '/Booted/ {print $$2}'); \
		if [ -z "$$DEVS" ]; then \
			DEV=$$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ {print $$2; exit}'); \
			xcrun simctl boot "$$DEV"; \
			open -a Simulator; \
		elif [ $$(echo "$$DEVS" | wc -l | tr -d ' ') -eq 1 ]; then \
			DEV=$$DEVS; \
		else \
			echo "$$DEVS" | gum choose --header "Pick a simulator:" > /tmp/_sim_pick && \
			DEV=$$(cat /tmp/_sim_pick); \
		fi; \
		flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d "$$DEV"; \
	elif [ "$(TARGET)" = "ios" ]; then \
		DEVICE=$$(flutter devices --machine 2>/dev/null | python3 -c 'import json,sys; devs=json.load(sys.stdin); ios=[d["id"] for d in devs if d.get("targetPlatform")=="ios" and not d.get("emulator")]; print(ios[0] if ios else "")'); \
		if [ -z "$$DEVICE" ]; then DEVICE=$$(idevice_id -l 2>/dev/null | head -1); fi; \
		if [ -z "$$DEVICE" ]; then \
			echo "❌  No physical iOS device found. Connect + unlock the iPhone (flutter devices) and retry."; \
			exit 1; \
		fi; \
		TEAM=$$(sed -n 's/^IOS_DEVELOPMENT_TEAM=//p' .env.local 2>/dev/null | head -1); \
		if [ -z "$$TEAM" ] || [ "$$TEAM" = "XXXXXXXXXX" ]; then \
			echo "❌  IOS_DEVELOPMENT_TEAM not set in .env.local — dev TARGET=ios needs the real team for signing."; \
			exit 1; \
		fi; \
		make ios-signing-restore; \
		trap 'make ios-signing-restore 2>/dev/null' EXIT INT TERM HUP; \
		$(BREW_BUNDLE) exec ruby tools/ios_dev_signing.rb apply "$$TEAM"; \
		grep -q "DEVELOPMENT_TEAM = $$TEAM" ios/Runner.xcodeproj/project.pbxproj || { echo "❌  signing patch did not stick — a previous run's restore raced this one; rerun."; exit 1; }; \
		echo "📱  Running on device: $$DEVICE"; \
		if [ "$(NO_XCODE_RESET)" != "1" ]; then \
			echo "🔄  Quitting Xcode (the proven remedy — clears the stale temp Runner workspace; flutter reopens it, flutter/flutter#181480)"; \
			osascript -e 'tell application "Xcode" to quit' 2>/dev/null || true; \
			sleep 2; \
			killall Xcode 2>/dev/null || true; \
		fi; \
		if [ "$(CLEAN_INSTALL)" = "1" ]; then \
			echo "🧹  CLEAN_INSTALL=1 — uninstalling $(APP_ID) from device (stale-state fix, flutter/flutter#181480)"; \
			xcrun devicectl device uninstall app --device "$$DEVICE" "$(APP_ID)" 2>/dev/null || true; \
		else \
			xcrun devicectl device process terminate --device "$$DEVICE" "$(APP_ID)" 2>/dev/null || true; \
		fi; \
		flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d "$$DEVICE"; \
		RC=$$?; \
		if [ "$$RC" -ne 0 ]; then \
			echo "ℹ️  Known iOS 26/Xcode 26 regression (flutter/flutter#181480): every flutter run leaves a temp Runner workspace open in Xcode, so the next run's debug-launch automation resolves the STALE workspace and times out waiting for CONFIGURATION_BUILD_DIR. This target now closes those stale windows automatically (NO_XCODE_RESET=1 disables). Remedies if it still hangs: rerun, rerun with CLEAN_INSTALL=1, or quit Xcode. Local Network permission for your terminal is also required."; \
		fi; \
		exit $$RC; \
	elif [ "$(TARGET)" = "ios-adhoc" ]; then \
		make build TARGET=ios-adhoc NO_PUB=$(NO_PUB) && \
		make install TARGET=ios-adhoc NO_PUB=$(NO_PUB) && \
		DEVICE=$$(idevice_id -l 2>/dev/null | head -1); \
		if [ -n "$$DEVICE" ]; then \
			xcrun devicectl device process launch --device "$$DEVICE" "$(APP_ID)" && \
			echo "✅  Launched $(APP_ID) on device $$DEVICE" || \
			echo "⚠️  Installed, but could not launch $(APP_ID) on device (already running?)"; \
		fi; \
	elif [ -n "$(TARGET)" ]; then \
		flutter run $(PUB_FLAG) $(FLUTTER_DEFINES) -d "$(TARGET)"; \
	else \
		flutter run $(PUB_FLAG) $(FLUTTER_DEFINES); \
	fi

install:
	$(load-env)
	@UNAME=$$(uname); \
	if [ "$(TARGET)" = "android" ] || [ "$(TARGET)" = "waydroid" ]; then \
		if [ ! -f "$(APK)" ]; then \
			echo "⚠️  APK not found at $(APK) — run 'make build TARGET=android' first (skipping install)."; \
			exit 0; \
		fi; \
	fi; \
	if [ "$(TARGET)" = "all" ]; then \
		for t in android waydroid ios-adhoc simulator; do \
			echo "━━━ install to $$t ━━━"; \
			make install TARGET=$$t NO_PUB=$(NO_PUB) ALL_SIMS=1 || true; \
		done; \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "android" ]; then \
		$(call tunnel-android, adb -s localhost:$(TUNNEL_ANDROID_PORT) install -r $(APK)); \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "waydroid" ]; then \
		$(call tunnel-waydroid, adb -s localhost:$(TUNNEL_WAYDROID_PORT) install -r $(APK)); \
	elif [ "$(TARGET)" = "ios" ] || [ "$(TARGET)" = "ios-adhoc" ]; then \
		if [ ! -f "$(IPA_ADHOC)" ]; then \
			echo "⚠️  IPA not found at $(IPA_ADHOC) — run 'make build TARGET=ios-adhoc' first (skipping install)."; \
			exit 0; \
		fi; \
		DEVICE=$$(idevice_id -l 2>/dev/null | head -1); \
		if [ -z "$$DEVICE" ]; then \
			echo "⚠️  no iOS device connected — skipped."; \
			exit 0; \
		fi; \
		echo "📱  Installing $(IPA_ADHOC) to device: $$DEVICE"; \
		xcrun devicectl device install app --device "$$DEVICE" "$(IPA_ADHOC)" && \
		echo "✅  Installed $(IPA_ADHOC) to device $$DEVICE"; \
	elif [ "$(TARGET)" = "simulator" ]; then \
		APP="build/ios/iphonesimulator/Runner.app"; \
		if [ ! -d "$$APP" ]; then \
			echo "❌  Simulator app not found at $$APP. Run 'make build TARGET=simulator' first."; \
			exit 1; \
		fi; \
		if [ "$(ALL_SIMS)" = "1" ]; then \
			DEVS=$$(xcrun simctl list devices booted | awk -F '[()]' '/Booted/ {print $$2}'); \
			if [ -z "$$DEVS" ]; then \
				DEV=$$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ {print $$2; exit}'); \
				xcrun simctl boot "$$DEV"; \
				open -a Simulator; \
				DEVS="$$DEV"; \
			fi; \
			for DEV in $$DEVS; do \
				echo "📱  Installing $$APP to simulator: $$DEV"; \
				xcrun simctl install "$$DEV" "$$APP" && \
				echo "✅  Installed to simulator $$DEV"; \
			done; \
		else \
			DEVS=$$(xcrun simctl list devices booted | awk -F '[()]' '/Booted/ {print $$2}'); \
			if [ -z "$$DEVS" ]; then \
				DEV=$$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ {print $$2; exit}'); \
				xcrun simctl boot "$$DEV"; \
				open -a Simulator; \
			elif [ $$(echo "$$DEVS" | wc -l | tr -d ' ') -eq 1 ]; then \
				DEV=$$DEVS; \
			else \
				echo "$$DEVS" | gum choose --header "Pick a simulator:" > /tmp/_sim_pick && \
				DEV=$$(cat /tmp/_sim_pick); \
			fi; \
			echo "📱  Installing $$APP to simulator: $$DEV"; \
			xcrun simctl install "$$DEV" "$$APP" && \
			echo "✅  Installed to simulator $$DEV"; \
		fi; \
	elif [ "$(TARGET)" = "waydroid" ]; then \
		IP=$$($(call waydroid-preflight)); \
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

# Clear the app's local storage (Juega parity — device workflow).
clear-storage:
	@UNAME=$$(uname); \
	if [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "android" ]; then \
		$(call tunnel-android, adb -s localhost:$(TUNNEL_ANDROID_PORT) shell pm clear $(APP_ID)); \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "waydroid" ]; then \
		$(call tunnel-waydroid, adb -s localhost:$(TUNNEL_WAYDROID_PORT) shell pm clear $(APP_ID)); \
	elif [ "$(TARGET)" = "waydroid" ]; then \
		IP=$$($(call waydroid-preflight)); \
		adb connect "$$IP:5555" && adb -s "$$IP:5555" shell pm clear $(APP_ID); \
	elif [ "$(TARGET)" = "android" ]; then \
		DEV=$$(adb devices | grep -o 'emulator-[0-9]*' | head -1); \
		if [ -n "$$DEV" ]; then \
			adb -s "$$DEV" shell pm clear $(APP_ID); \
		else \
			adb -d shell pm clear $(APP_ID); \
		fi; \
	else \
		adb shell pm clear $(APP_ID); \
	fi

# Build + install in one go for any supported TARGET (all, android, waydroid,
# ios, ios-adhoc, simulator). Delegates to the individual targets, so the same
# skip-when-unavailable semantics apply.
build-install:
	@if [ -z "$(TARGET)" ]; then \
		echo "❌  make build-install REQUIRES a target: TARGET=all|android|waydroid|ios|ios-adhoc|simulator"; \
		exit 1; \
	fi
	@make build TARGET=$(TARGET) NO_PUB=$(NO_PUB) && \
		make install TARGET=$(TARGET) NO_PUB=$(NO_PUB)

# Uninstall the app from the targeted device(s). TARGET=all uninstalls from
# every reachable device: android (emulator), waydroid (tunnel), ios-adhoc
# (physical iPhone), simulator — any device that is not available is SKIPPED,
# never an error. Individual targets work like install/clear.
uninstall:
	@if [ -z "$(TARGET)" ]; then \
		echo "❌  make uninstall REQUIRES a target: TARGET=all|android|waydroid|ios|ios-adhoc|simulator (nothing was uninstalled)."; \
		exit 1; \
	fi
	@UNAME=$$(uname); \
	if [ "$(TARGET)" = "all" ]; then \
		for t in android waydroid ios-adhoc simulator; do \
			echo "━━━ uninstall from $$t ━━━"; \
			make uninstall TARGET=$$t || true; \
		done; \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "android" ]; then \
		$(call tunnel-android, if adb -s localhost:$(TUNNEL_ANDROID_PORT) shell pm list packages $(APP_ID) 2>/dev/null | grep -q $(APP_ID); then adb -s localhost:$(TUNNEL_ANDROID_PORT) uninstall $(APP_ID); else echo "⚠️  $(APP_ID) not installed on android — nothing to do."; fi); \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "waydroid" ]; then \
		$(call tunnel-waydroid, if adb -s localhost:$(TUNNEL_WAYDROID_PORT) shell pm list packages $(APP_ID) 2>/dev/null | grep -q $(APP_ID); then adb -s localhost:$(TUNNEL_WAYDROID_PORT) uninstall $(APP_ID); else echo "⚠️  $(APP_ID) not installed on waydroid — nothing to do."; fi); \
	elif [ "$(TARGET)" = "waydroid" ]; then \
		IP=$$(waydroid status | awk '/IP address:/ {print $$3}'); \
		if [ -z "$$IP" ]; then echo "⚠️  waydroid not running — skipped."; else adb connect "$$IP:5555" && if adb -s "$$IP:5555" shell pm list packages $(APP_ID) 2>/dev/null | grep -q $(APP_ID); then adb -s "$$IP:5555" uninstall $(APP_ID); else echo "⚠️  $(APP_ID) not installed on waydroid — nothing to do."; fi; fi; \
	elif [ "$(TARGET)" = "android" ]; then \
		DEV=$$(adb devices | awk 'NR>1 && $$2=="device" {print $$1; exit}'); \
		if [ -z "$$DEV" ]; then \
			echo "⚠️  no Android device/emulator available — skipped."; \
		elif adb -s "$$DEV" shell pm list packages $(APP_ID) 2>/dev/null | grep -q $(APP_ID); then \
			adb -s "$$DEV" uninstall $(APP_ID); \
		else \
			echo "⚠️  $(APP_ID) not installed on $$DEV — nothing to do."; \
		fi; \
	elif [ "$(TARGET)" = "ios" ] || [ "$(TARGET)" = "ios-adhoc" ]; then \
		DEVICE=$$(idevice_id -l 2>/dev/null | head -1); \
		if [ -z "$$DEVICE" ]; then \
			echo "⚠️  no iOS device connected — skipped."; \
		else \
			echo "📱  Uninstalling $(APP_ID) from device: $$DEVICE"; \
			xcrun devicectl device uninstall app --device "$$DEVICE" "$(APP_ID)" && \
			echo "✅  Uninstalled $(APP_ID) from device $$DEVICE"; \
		fi; \
	elif [ "$(TARGET)" = "simulator" ]; then \
		DEVS=$$(xcrun simctl list devices booted | awk -F '[()]' '/Booted/ {print $$2}'); \
		if [ -z "$$DEVS" ]; then \
			echo "⚠️  no booted simulator — skipped."; \
		else \
			if [ $$(echo "$$DEVS" | wc -l | tr -d ' ') -eq 1 ]; then \
				DEV=$$DEVS; \
			else \
				echo "$$DEVS" | gum choose --header "Pick a simulator:" > /tmp/_sim_pick && \
				DEV=$$(cat /tmp/_sim_pick); \
			fi; \
			if ! xcrun simctl get_app_container "$$DEV" "$(APP_ID)" >/dev/null 2>&1; then \
				echo "⚠️  $(APP_ID) not installed on simulator — nothing to do."; \
			else \
				echo "📱  Uninstalling $(APP_ID) from simulator: $$DEV"; \
				xcrun simctl uninstall "$$DEV" "$(APP_ID)" && \
				echo "✅  Uninstalled $(APP_ID) from simulator $$DEV"; \
			fi; \
		fi; \
	else \
		echo "❌  TARGET=$(TARGET) unknown for uninstall. Use: all, android, waydroid, ios, ios-adhoc, simulator."; \
		exit 1; \
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
# Testing is reserved for the BACKEND (directive 2026-08-31): Go unit tests
# (`go test ./...`) + the backend STATIC gates (opt-005 seeds, opt-007
# compose — no stack needed) + pgTAP (`supabase db test`). There are NO
# Dart/Flutter tests and NO integration tests in this repo — the Flutter test
# trees (`test/*.dart`, `integration_test/`) were deleted. The LIVE backend
# opt-tests (001/002/003/004/006) need the stack up
# (`make supabase-docker-start`) and run via `bash test/run_all_backend.sh`.

test: test-all

test-all: test-go test-backend-static

test-backend-static:
	bash test/opt-005-seeds-static.sh
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
	@command -v golangci-lint >/dev/null 2>&1 && golangci-lint run ./... || go vet ./...

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

# ── Supabase (Docker Compose) — Juega pattern ────────────────────────────────
# Backend lifecycle targets mirror ../Juega's Makefile: `make supabase-start`
# boots the SELF-HOSTED compose stack (not the CLI-managed one — the two are
# mutually exclusive on the same approved ports 54382/54386/54381/54384).
#
# SMTP: commented out by now — Samay email is not wired yet (compose holds a
# placeholder GOTRUE_SMTP_PASS + GOTRUE_MAILER_AUTOCONFIRM=true, so local
# signups complete without a mail server). Uncomment the `pass` unlock lines
# once SMTP creds are provisioned (real inbox at release — placeholder domain):
#   SMTP_PASS=$$(pass mail/samayverif@samay.example.com) docker compose up -d --wait
# (Juega also runs `SELECT public.update_daily_prisma_seed();` after up — no
# such function exists for Samay yet, so it is omitted.)
supabase-start:
	cd supabase && docker compose up -d --wait

supabase-stop:
	cd supabase && docker compose down

supabase-status:
	cd supabase && docker compose ps

supabase-reset:
	cd supabase && docker compose down && \
	rm -rf volumes/storage && \
	docker volume rm samay_db-data samay_minio-data 2>/dev/null || true && \
	docker compose up -d && \
	docker compose up -d --wait db auth && \
	sh migrate.sh

# First-run bootstrap: start the stack NON-destructively, apply the baseline
# tree (two-tier via tools/apply_migrations.sh) + required seed-config. Safe on a
# fresh/empty volume — this is the target to run after a manual
# `docker compose down -v` wipe. NOT a no-op on an already-migrated DB
# (migrations carry no ledger) — use supabase-start for that.
supabase-init:
	$(load-env)
	cd supabase && docker compose $(OVERRIDES) up -d --wait && echo "Running migrations..." && bash ../tools/apply_migrations.sh supabase && echo "Applying required seed-config..." && PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f seed-config.sql

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
	cd supabase && docker compose down && rm -rf volumes/storage && (docker volume rm samay_db-data samay_minio-data 2>/dev/null || true) && docker compose up -d && docker compose up -d --wait db auth && echo "Running migrations..." && bash ../tools/apply_migrations.sh supabase && echo "Applying required seed-config..." && PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f seed-config.sql

# Explicit seeding — seed-config is ALREADY auto-applied by init/reset/
# migrate (fundamental app config); this target exists for idempotent re-runs.
supabase-seed-config:
	cd supabase && PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f seed-config.sql

# Test data (@tester universe) — EXPLICIT ONLY, never automatic. Note: the
# 4 storage-object rows dangle until the MinIO blob backup is restored.
supabase-seed-test:
	cd supabase && PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f seed-test.sql

# Drop into a psql REPL against the running stack's DB (approved port map:
# host port POSTGRES_PORT, default 54382). Guards that the stack is up.
in-db:
	$(load-env)
	@bash -c 'nc -z 127.0.0.1 $${POSTGRES_PORT:-54382} 2>/dev/null' || { echo "❌  PostgreSQL not reachable on $${POSTGRES_PORT:-54382} — start the stack first: make supabase-docker-start"; exit 1; }
	PGPASSWORD=postgres psql -h localhost -p $${POSTGRES_PORT:-54382} -U postgres -d postgres

# pgTAP schema tests (956 assertions, supabase/tests/schema_test.sql) against
# the SELF-HOSTED stack — `supabase db test --db-url` connects to the running
# compose DB on the approved port (verified: CLI enables pgtap, then runs
# pg_prove via the supabase/pg_prove:3.36 docker image; first run pulls that
# image). NOT `supabase db test` bare: that targets the CLI-managed stack,
# which conflicts with the compose stack on the same approved ports.
# `sslmode=disable` is REQUIRED since CLI 2.116.0: the compose server exposes
# no TLS and the CLI's pg_prove otherwise fails with "tls error (The server
# does not support SSL connections)" (2026-09-01 regression).
# No-CLI fallback (no docker image needed):
#   PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres \
#     -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql
PGTAP_DB_URL ?= postgres://postgres:postgres@localhost:54382/postgres?sslmode=disable
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

# Static stack gates (no stack needed): opt-005 (seeds) + opt-007 (compose
# parse/parity) + the repo-wide port-map gate (AGENTS.md Port Convention).
supabase-stack-check:
	bash test/opt-005-seeds-static.sh
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
	cd supabase-testing && docker compose down && rm -rf volumes/storage && (docker volume rm samay-testing_db-data samay-testing_minio-data 2>/dev/null || true) && docker compose up -d && docker compose up -d --wait db auth && echo "Running migrations..." && bash ../tools/apply_migrations.sh supabase-testing && echo "Applying required seed-config..." && PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f seed-config.sql

# Testing-stack bootstrap: start NON-destructively, apply all migrations, seed.
# Mailpit is part of the BASE compose (2026-08-22 merge — the overlay caused
# split-brain up/down), so a plain start brings the dev-mail sink too; without
# it GoTrue's OTP sends 500 and burns the 2-per-hour email budget. Same
# fresh-volume semantics as supabase-init (NOT idempotent on a migrated DB).
supabase-testing-init:
	$(load-env)
	cd supabase-testing && docker compose $(OVERRIDES) up -d --wait && echo "Running migrations..." && bash ../tools/apply_migrations.sh supabase-testing && echo "Applying required seed-config..." && PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f seed-config.sql

# ── Remote-device tunnel (MKE-08 / M-13) ─────────────────────────────────────
# SSH-forward adb from a remote host that has a device attached (Juega
# pattern, read-only reference). Usage:
#   make tunnel-android                                   # default: <build-host> → flutter run
#   make tunnel-android TUNNEL_HOST=ci-box TUNNEL_ANDROID_PORT=5565
#   make tunnel-android TUNNEL_CMD="adb -s localhost:5565 install -r build/app/outputs/flutter-apk/app-debug.apk"
tunnel-android:
	@HOST="$(TUNNEL_HOST)"; [ -n "$$HOST" ] || { echo "TUNNEL_HOST is required"; exit 2; }; \
		(trap 'kill $$SSH_PID 2>/dev/null; adb disconnect localhost:$(TUNNEL_ANDROID_PORT) 2>/dev/null' EXIT; \
		ssh -N -L $(TUNNEL_ANDROID_PORT):127.0.0.1:5555 "$$HOST" & SSH_PID=$$!; sleep 1; \
		adb connect localhost:$(TUNNEL_ANDROID_PORT); \
		$(TUNNEL_CMD))

# Waydroid variant: forwards the <build-host>'s waydroid adb port (resolved via
# `ssh <build-host> "waydroid status"`) into localhost:$(TUNNEL_WAYDROID_PORT).
tunnel-waydroid:
	@HOST="$(TUNNEL_HOST)"; [ -n "$$HOST" ] || { echo "TUNNEL_HOST is required"; exit 2; }; \
		WIP=$$(ssh "$$HOST" "waydroid status | awk '/IP address/ {print \$$3}'"); \
		(trap 'kill $$SSH_PID 2>/dev/null; adb disconnect localhost:$(TUNNEL_WAYDROID_PORT) 2>/dev/null' EXIT; \
		ssh -N -L $(TUNNEL_WAYDROID_PORT):$$WIP:5555 "$$HOST" & SSH_PID=$$!; sleep 1; \
		adb connect localhost:$(TUNNEL_WAYDROID_PORT); \
		$(TUNNEL_WAYDROID_CMD))

# Restore the iOS project's §3.3 signing PLACEHOLDERS (opt-008 contract).
# `dev TARGET=ios` patches the pbxproj for automatic signing; this undoes that
# patch by checking out HEAD (the placeholder version). Restoring to a fixed
# state (not a per-run backup) makes the trap idempotent and race-free: a
# killed run's trap can never clobber another run's patch — at worst it leaves
# placeholders and the interrupted run fails signing with a clear message.
ios-signing-restore:
	@git checkout HEAD -- ios/Runner.xcodeproj/project.pbxproj && \
		rm -f /tmp/samay-pbxproj.bak /tmp/juega-pbxproj.bak 2>/dev/null; \
		echo "✅  ios signing restored from HEAD (placeholders)"

# ── Secrets gate (MKE-02 / MKE-03, M-13) ─────────────────────────────────────
# Committed-secret scan over TRACKED files only (git grep — untracked local
# .env/.env.local are by design not scanned). Patterns + documented
# allowlists live in tools/check_secrets.sh.
secrets-check:
	@tools/check_secrets.sh

# ── Pre-commit hooks (TOOL-04, M-26) ─────────────────────────────────────────
# Wires git's core.hooksPath to the COMMITTED tools/hooks/ dir (never
# .git/hooks/ — that is per-clone state). The pre-commit hook delegates to
# tools/pre-commit.sh, the FAST gate: dart analyze + secrets-check +
# check_ports --strict + opt-008 makefile-static. Run once per clone (the
# setting is local to each checkout). Exit codes: 0 wired, 1 hook file
# missing/not executable (gates never silently skip).
install-hooks:
	@git config core.hooksPath tools/hooks
	@[ -x tools/hooks/pre-commit ] || { echo "❌  tools/hooks/pre-commit missing or not executable — fix before committing."; exit 1; }
	@echo "✅  core.hooksPath → tools/hooks — pre-commit gate active (tools/pre-commit.sh)"

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
	$(BREW_BUNDLE) install

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
