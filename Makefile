# Samay frontend — Flutter app.
.PHONY: help init start build dev install build-install uninstall clear clean env test \
        analyze check secrets hooks guard-local guard-env guard-release track-guard deploy publish \
        tunnel-android tunnel-waydroid signing-restore login \
        release bundle-install

ifneq ($(filter command line environment,$(origin PROD)),)
$(error PROD is not an input; use ENV=testing-local|testing|staging|prod)
endif
ifneq ($(filter command line environment,$(origin TESTING)),)
$(error TESTING is not an input; use ENV=testing-local)
endif

APP_NAME := samay_app
# Single environment selector — the ONLY environment flag. Values:
#   testing-local — local Docker stack (dev signing, needs JWT_SECRET)
#   testing       — hosted testing API behind the free Cloudflare tunnel
#   staging       — vault-gated staging release
#   prod          — vault-gated production release
# ENV is explicit: there is no default. Internal aliases below are derived.
RELEASE := $(filter staging prod,$(ENV))
PROD    := $(if $(RELEASE),true,false)
TESTING := $(if $(filter testing-local,$(ENV)),true,false)
BUILD_MODE     ?= $(if $(RELEASE),release,debug)
# Android product flavor (build.gradle.kts flavorDimensions "env"): `dev` for
# testing-local/testing (AGP reserves the "test" prefix), else the ENV value.
ANDROID_FLAVOR ?= $(if $(RELEASE),$(ENV),dev)
# Compile define for the app (paywall picks RC price vs custom app_config on it).
APP_ENV := $(if $(filter prod,$(ENV)),prod,dev)
# iOS export method for `build ENV=staging|prod TARGET=ios`: store (App Store Connect,
# default) or ad-hoc (an on-device ad-hoc IPA). MODE=adhoc is the shorthand.
MODE ?= store
IOS_EXPORT_METHOD ?= $(if $(filter adhoc,$(MODE)),ad-hoc,app-store-connect)
# RevenueCat opt-in: RC=true injects the env's public SDK key from the vault
# (the app-build profile emits it). Unset/false ⇒ no key ⇒ the app is in stub
# mode (purchase UI disabled). See <private-ops-repo> docs + <private-ops-repo>.
RC ?= false
APK := build/app/outputs/flutter-apk/app-$(ANDROID_FLAVOR)-$(BUILD_MODE).apk
IPA_ADHOC := build/ios/ipa/$(APP_NAME)-adhoc.ipa
APP_ID := com.qallariy.samay
# Vault fetch/wipe helper for staging/prod builds. No fallback: it stops if it is
# absent (all-or-nothing).
RELEASE_SECRETS ?= tools/release-signing-not-in-repo.sh

export PATH := /opt/homebrew/opt/ruby/bin:/Users/daerean/.local/share/gem/ruby/4.0.0/bin:$(PATH)
BREW_BUNDLE := /opt/homebrew/opt/ruby/bin/bundle

IOS_DEVELOPMENT_TEAM ?= $(shell sed -n 's/^IOS_DEVELOPMENT_TEAM=//p' .env.local 2>/dev/null | head -1)

TUNNEL_HOST          ?= <build-host>
TUNNEL_ANDROID_PORT  ?= 5565
TUNNEL_WAYDROID_PORT ?= 5566

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

define waydroid-preflight
command -v waydroid >/dev/null 2>&1 || { echo "waydroid CLI not found."; exit 1; }; WS=$$(waydroid status 2>/dev/null || true); echo "$$WS" | grep -Eq 'Container:[[:space:]]*RUNNING' || { echo "Waydroid container not RUNNING."; exit 1; }; WIP=$$(echo "$$WS" | awk '/IP address:/ {print $$3}'); [ -n "$$WIP" ] || { echo "Waydroid has no session IP yet."; exit 1; }; echo "$$WIP"
endef

NO_PUB ?= true
TARGET ?=

# Store-native release tracks (for `build ENV=staging|prod` + `deploy`). TRACK is a
# comma-separated list; there is NO TRACK=all. Vocabularies are per-TARGET and
# are NOT interchangeable:
#   ios:     internal external prod
#   android: internal alpha beta production
TRACK ?=
IOS_TRACKS     := internal external prod
ANDROID_TRACKS := internal alpha beta production
TRACK_REQUIRED ?= false

ifeq ($(NO_PUB),false)
PUB_FLAG :=
else
PUB_FLAG := --no-pub
endif

ENV_FILE := $(wildcard .env)
ifeq ($(ENV_FILE),)
FLUTTER_DEFINES :=
else
FLUTTER_DEFINES := --dart-define-from-file=.env
endif
# Environment define for dev/build runs (the prod build lines add it explicitly).
FLUTTER_DEFINES += --dart-define=APP_ENV=$(APP_ENV)

ANDROID_GATEWAY_HOST := $(if $(findstring Linux,$(shell uname -s)),10.0.2.2,127.0.0.1)
OS_IS_DARWIN := $(findstring Darwin,$(shell uname -s))
# Local stack wiring. Defaults read the monorepo backend env; a lane can point
# at its own disposable stack with LOCAL_JWT_ENV and LOCAL_KONG_PORT.
LOCAL_JWT_ENV ?= ../backend/supabase/.env
JWT_SECRET ?= $(shell sed -n 's/^JWT_SECRET=//p' $(LOCAL_JWT_ENV) 2>/dev/null | head -1)
LOCAL_KONG_PORT ?= $(shell sed -n 's/^KONG_HTTP_PORT=\([0-9]*\).*/\1/p' $(LOCAL_JWT_ENV) 2>/dev/null | head -1)
ifeq ($(strip $(LOCAL_KONG_PORT)),)
LOCAL_KONG_PORT := 54386
endif

# ENV=testing-local points builds at the local stack (TESTING is derived above); needs JWT_SECRET.
ifeq ($(TESTING),true)
TESTING_JWT_SECRET := $(JWT_SECRET)
# Prefer the stack's registered anon key. A freshly minted JWT has a different
# signature/iat and Kong's REST key-auth does not accept it unless it is added
# to keyauth_credentials (the old register target appended it under
# jwt_secrets, so /auth worked but /rest returned 401).
TESTING_ANON_KEY := $(shell sed -n 's/^SUPABASE_ANON_KEY=//p' $(LOCAL_JWT_ENV) 2>/dev/null | head -1 | tr -d '"')
ifeq ($(strip $(TESTING_ANON_KEY)),)
ifneq ($(strip $(TESTING_JWT_SECRET)),)
TESTING_ANON_KEY := $(shell JWT_SECRET='$(TESTING_JWT_SECRET)' python3 tools/gen_testing_anon_key.py)
endif
endif
LOCAL_DEFINES := --dart-define=SUPABASE_URL=http://$(ANDROID_GATEWAY_HOST):$(LOCAL_KONG_PORT) --dart-define=SUPABASE_ANON_KEY=$(TESTING_ANON_KEY)
build: | testing-kong-register
dev: | testing-kong-register
install: | testing-kong-register
tunnel-android: | testing-kong-register
endif

# ── Resolved env defines — ONE source per ENV, used by dev + non-store builds ─
#   local   → local Docker stack (:$(LOCAL_KONG_PORT)) + the Kong anon registration
#   testing → .env verbatim (written by `make init`)
#   staging → vault app-build profile (staging-apple / staging-android)
#   prod    → vault app-build profile (apple / android)
# Recursive `=` so PROD_DEFINES (defined in the PROD block below) resolves at
# use time. RC=true adds the vault RevenueCat public keys on any ENV.
VAULT_PROFILE_FOR = $(if $(filter ios ios-adhoc simulator,$(1)),apple,android)
ENV_DEFINES = $(if $(filter true,$(TESTING)),$(LOCAL_DEFINES),$(if $(RELEASE),--dart-define-from-file=$(PROD_DEFINES) --dart-define=APP_ENV=$(APP_ENV),$(FLUTTER_DEFINES)))

# Android/Waydroid dev run command, shared by `dev` and the tunnel targets. It
# ALWAYS pins the selected product flavor: without `--flavor`, `flutter run`
# triggers an unflavored `assembleDebug` that builds EVERY flavor, including the
# vault-gated `staging`/`prod` ones whose `google-services.json` is absent (so
# it dies in `process<Flavor>DebugGoogleServices`).
ANDROID_RUN = flutter run --flavor $(ANDROID_FLAVOR) $(PUB_FLAG) $(ENV_DEFINES)

ifeq ($(PROD),true)
ifeq ($(TESTING),true)
$(error internal: RELEASE and TESTING are mutually exclusive)
endif
RAM_DIR             ?= /Volumes/SamayRAM
KEYSTORE_PROPERTIES ?= $(RAM_DIR)/keystore.properties
PROD_DEFINES        ?= $(RAM_DIR)/dart_defines.env
EXPORT_OPTIONS      ?= $(RAM_DIR)/ExportOptions.plist
endif

ifeq ($(TESTING),true)
LANE_SUPABASE_URL := http://<local-lan-ip>:54386
else
LANE_SUPABASE_URL := $(shell sed -n 's/^SUPABASE_URL=//p' .env 2>/dev/null | head -1)
endif
LANE_SUPABASE_ANON_KEY := $(shell sed -n 's/^SUPABASE_ANON_KEY=//p' .env 2>/dev/null | head -1)

define load-env
set -a; [ -r ./.env.local ] && . ./.env.local || true; [ -r ./.env ] && . ./.env || true; set +a
endef

ENV_TARGETS := init dev start build build-install install testing-kong-register env deploy publish release
$(ENV_TARGETS): guard-env
guard-env:
	@case "$(ENV)" in testing-local|testing|staging|prod) ;; *) echo "ENV is required: testing-local|testing|staging|prod"; exit 2;; esac

guard-release:
	@case "$(ENV)" in staging|prod) ;; *) echo "ENV=staging|prod required"; exit 2;; esac
deploy publish release: guard-release

help:
	@echo "Samay frontend — APP implicit; ENV=<testing-local|testing|staging|prod> required"
	@echo "  BUILD/RUN: build dev install build-install uninstall clear clean"
	@echo "  TUNNELS:   tunnel-android tunnel-waydroid signing-restore"
	@echo "  LOGIN:     login [TARGET=simulator]"
	@echo "  GATES:     analyze check secrets hooks env"
	@echo "  RELEASE:   release bundle-install"
	@echo "  TRACKS:    deploy TARGET=ios|android|all TRACK=<list>  (build honours TRACK too)"
	@echo "  ENV:       testing-local (Docker) | testing (tunnel) | staging|prod (vault)"
	@echo "  IOS MODE:  build ENV=prod|staging TARGET=ios MODE=store|adhoc"

env:
	@echo "ENV=$(ENV)"
	@echo "config: $(if $(filter true,$(TESTING)),local stack (:$(LOCAL_KONG_PORT)),$(if $(RELEASE),vault profile $(call VAULT_PROFILE_FOR,$(TARGET)) ($(ENV)),.env))"
	@echo "APP_ENV=$(APP_ENV) ANDROID_FLAVOR=$(ANDROID_FLAVOR) BUILD_MODE=$(BUILD_MODE)"
	@echo "ENV_FILE=$(ENV_FILE)"
	@echo "ENV_DEFINES=$(ENV_DEFINES)"

# Interactive setup; then `make start` runs against the chosen backend.
init:
	@bash tools/init.sh

start: dev

testing-kong-register:
	@[ -n "$(TESTING_JWT_SECRET)" ] || { echo "testing-local needs JWT_SECRET (the local stack signing secret)."; exit 1; }
	@[ -n "$(TESTING_ANON_KEY)" ] || { echo "testing-local: failed to mint the anon JWT."; exit 1; }
	@KONG=$$(docker ps --format '{{.Names}}' --filter publish=$(LOCAL_KONG_PORT) | head -1); \
	if [ -z "$$KONG" ]; then \
		echo "No Kong on 127.0.0.1:$(LOCAL_KONG_PORT) — temp JWT NOT registered."; \
	elif docker exec "$$KONG" sh -c 'grep -qF "$(TESTING_ANON_KEY)" /usr/local/kong/kong.yml' 2>/dev/null; then \
		echo "TESTING: anon JWT already registered in $$KONG"; \
	elif docker exec "$$KONG" sh -c 'printf "\n  - consumer: anon\n    key: %s\n" "$(TESTING_ANON_KEY)" >> /usr/local/kong/kong.yml' 2>/dev/null && docker exec "$$KONG" kong reload >/dev/null 2>&1; then \
		echo "TESTING: anon JWT registered in $$KONG (24h)"; \
	else \
		echo "Kong registration failed on $$KONG — app will 401."; \
	fi

# ── Flutter ──────────────────────────────────────────────────────────────────
build:
	$(load-env)
	@if [ "$(TARGET)" = "all" ]; then \
		for t in ios-adhoc simulator android; do \
			echo "build for $$t"; \
			make build TARGET=$$t ENV="$(ENV)" NO_PUB=$(NO_PUB) || true; \
		done; \
	elif [ "$(TARGET)" = "ios" ] && [ "$(PROD)" != "true" ]; then \
		flutter build ios --release --no-codesign $(PUB_FLAG) $(ENV_DEFINES) && \
		cd build/ios && rm -rf Payload && mkdir Payload && \
		cp -R iphoneos/Runner.app Payload/ && \
		mkdir -p ipa && zip -r -y ipa/$(APP_NAME).ipa Payload && rm -rf Payload && \
		echo "IPA: build/ios/ipa/$(APP_NAME).ipa"; \
	elif [ "$(TARGET)" = "ios-adhoc" ]; then \
		[ -n "$(RELEASE)" ] && { echo "ENV=$(ENV): use 'make build ENV=$(ENV) TARGET=ios MODE=adhoc' for a vault-signed ad-hoc IPA."; exit 1; }; \
		IOS_DEVELOPMENT_TEAM="$(IOS_DEVELOPMENT_TEAM)" \
		SUPABASE_URL="$(LANE_SUPABASE_URL)" \
		SUPABASE_ANON_KEY="$(LANE_SUPABASE_ANON_KEY)" \
		./bin/fastlane ios adhoc_local && \
		echo "IPA: $(IPA_ADHOC)"; \
	elif [ "$(TARGET)" = "simulator" ]; then \
		PLIST_BACKUP=""; FIREBASE_BACKUP=""; \
		sim_cleanup() { \
			[ -n "$$PLIST_BACKUP" ] && tools/ios_google_oauth.sh restore "$$PLIST_BACKUP" >/dev/null 2>&1 || true; \
			if [ -n "$$FIREBASE_BACKUP" ]; then cp "$$FIREBASE_BACKUP" ios/Runner/GoogleService-Info.plist; rm -f "$$FIREBASE_BACKUP"; fi; \
			[ -n "$(RELEASE)" ] && $(RELEASE_SECRETS) wipe >/dev/null 2>&1 || true; \
		}; \
		trap sim_cleanup EXIT INT TERM HUP; \
		if [ -n "$(RELEASE)" ]; then \
			[ -x "$(RELEASE_SECRETS)" ] || { echo "ENV=$(ENV) needs executable $(RELEASE_SECRETS) (vault fetch)."; exit 1; }; \
			RC="$(RC)" $(RELEASE_SECRETS) fetch apple $(ENV); \
			if [ -s "$(RAM_DIR)/GoogleService-Info.plist" ]; then FIREBASE_BACKUP=$$(mktemp); cp ios/Runner/GoogleService-Info.plist "$$FIREBASE_BACKUP"; cp "$(RAM_DIR)/GoogleService-Info.plist" ios/Runner/GoogleService-Info.plist; fi; \
			IOS_GID=$$(cat "$(RAM_DIR)/google-oauth-ios-client-id" 2>/dev/null || true); \
			if [ -n "$$IOS_GID" ]; then PLIST_BACKUP=$$(tools/ios_google_oauth.sh apply "$$IOS_GID") || exit 1; fi; \
		fi; \
		flutter build ios --simulator $(PUB_FLAG) $(ENV_DEFINES) && \
		echo "Simulator app: build/ios/iphonesimulator/Runner.app"; \
	elif [ "$(TARGET)" = "android" ] && [ "$(PROD)" = "true" ]; then \
		[ -x "$(RELEASE_SECRETS)" ] || { echo "ENV=staging|prod needs executable $(RELEASE_SECRETS) (vault fetch/wipe)."; exit 1; }; \
		mkdir -p android/app/src/$(ANDROID_FLAVOR); \
		android_cleanup() { rm -f android/app/src/$(ANDROID_FLAVOR)/google-services.json; $(RELEASE_SECRETS) wipe >/dev/null 2>&1 || true; }; \
		trap android_cleanup EXIT INT TERM HUP; \
		$(RELEASE_SECRETS) wipe >/dev/null 2>&1 || true; \
		RC="$(RC)" $(RELEASE_SECRETS) fetch android $(ENV); \
		[ -f "$(KEYSTORE_PROPERTIES)" ] || { echo "vault '$(ENV)/android' profile yielded no $(KEYSTORE_PROPERTIES)."; exit 1; }; \
		[ -f "$(PROD_DEFINES)" ] || { echo "vault '$(ENV)/android' profile yielded no $(PROD_DEFINES)."; exit 1; }; \
		[ -f "$(RAM_DIR)/google-services.json" ] || { echo "vault '$(ENV)/android' profile yielded no google-services.json ($(ENV) Firebase config)."; exit 1; }; \
		cp "$(RAM_DIR)/google-services.json" android/app/src/$(ANDROID_FLAVOR)/google-services.json; \
		KEYSTORE_PROPERTIES="$(KEYSTORE_PROPERTIES)" flutter build appbundle --release --flavor $(ANDROID_FLAVOR) $(PUB_FLAG) --dart-define-from-file="$(PROD_DEFINES)" --dart-define=APP_ENV=$(APP_ENV) && \
		KEYSTORE_PROPERTIES="$(KEYSTORE_PROPERTIES)" flutter build apk --release --flavor $(ANDROID_FLAVOR) $(PUB_FLAG) --dart-define-from-file="$(PROD_DEFINES)" --dart-define=APP_ENV=$(APP_ENV) && \
		echo "AAB: build/app/outputs/bundle/$(ANDROID_FLAVOR)Release/app-$(ANDROID_FLAVOR)-release.aab" && \
		echo "APK: $(APK)"; \
	elif [ "$(TARGET)" = "ios" ] && [ "$(PROD)" = "true" ]; then \
		[ -x "$(RELEASE_SECRETS)" ] || { echo "ENV=staging|prod needs executable $(RELEASE_SECRETS) (vault fetch/wipe)."; exit 1; }; \
		PLIST_BACKUP=""; \
		PBX_BACKUP=""; \
		FIREBASE_BACKUP=""; \
		cleanup() { \
			[ -n "$$PLIST_BACKUP" ] && tools/ios_google_oauth.sh restore "$$PLIST_BACKUP" >/dev/null 2>&1 || true; \
			if [ -n "$$FIREBASE_BACKUP" ]; then cp "$$FIREBASE_BACKUP" ios/Runner/GoogleService-Info.plist; rm -f "$$FIREBASE_BACKUP"; fi; \
			if [ -n "$$PBX_BACKUP" ]; then cp "$$PBX_BACKUP" ios/Runner.xcodeproj/project.pbxproj; rm -f "$$PBX_BACKUP"; fi; \
			$(RELEASE_SECRETS) wipe >/dev/null 2>&1 || true; \
		}; \
		trap cleanup EXIT INT TERM HUP; \
		$(RELEASE_SECRETS) wipe >/dev/null 2>&1 || true; \
		RC="$(RC)" IOS_EXPORT_METHOD="$(IOS_EXPORT_METHOD)" $(RELEASE_SECRETS) fetch apple $(ENV); \
		[ -f "$(EXPORT_OPTIONS)" ] || { echo "vault '$(ENV)/apple' profile yielded no $(EXPORT_OPTIONS)."; exit 1; }; \
		[ -f "$(PROD_DEFINES)" ] || { echo "vault '$(ENV)/apple' profile yielded no $(PROD_DEFINES)."; exit 1; }; \
		[ -f "$(RAM_DIR)/GoogleService-Info.plist" ] || { echo "vault '$(ENV)/apple' profile yielded no GoogleService-Info.plist ($(ENV) Firebase config)."; exit 1; }; \
		FIREBASE_BACKUP=$$(mktemp); cp ios/Runner/GoogleService-Info.plist "$$FIREBASE_BACKUP"; cp "$(RAM_DIR)/GoogleService-Info.plist" ios/Runner/GoogleService-Info.plist; \
		IOS_GID=$$(cat "$(RAM_DIR)/google-oauth-ios-client-id" 2>/dev/null); \
		[ -n "$$IOS_GID" ] || { echo "vault '$(ENV)/apple' profile yielded no google-oauth-ios-client-id."; exit 1; }; \
		[ -f "$(RAM_DIR)/provisioning-profile.mobileprovision" ] || { echo "vault '$(ENV)/apple' profile yielded no provisioning-profile.mobileprovision."; exit 1; }; \
		PROF_NAME=$$(security cms -D -i "$(RAM_DIR)/provisioning-profile.mobileprovision" | plutil -extract Name raw -); \
		PROF_TEAM=$$(security cms -D -i "$(RAM_DIR)/provisioning-profile.mobileprovision" | plutil -extract TeamIdentifier.0 raw -); \
		PBX_BACKUP=$$(mktemp); cp ios/Runner.xcodeproj/project.pbxproj "$$PBX_BACKUP"; \
		$(BREW_BUNDLE) exec ruby tools/ios_store_signing.rb apply "$$PROF_TEAM" "$$PROF_NAME" && \
		grep -q "DEVELOPMENT_TEAM = $$PROF_TEAM" ios/Runner.xcodeproj/project.pbxproj || { echo "store signing patch did not stick (profile '$$PROF_NAME', team '$$PROF_TEAM')."; exit 1; }; \
		PLIST_BACKUP=$$(tools/ios_google_oauth.sh apply "$$IOS_GID"); \
		flutter build ipa --release $(PUB_FLAG) --dart-define-from-file="$(PROD_DEFINES)" --dart-define=GOOGLE_OAUTH_IOS_CLIENT_ID="$$IOS_GID" --dart-define=APP_ENV=$(APP_ENV) --export-options-plist="$(EXPORT_OPTIONS)" && \
		echo "IPA: build/ios/ipa/*.ipa"; \
	else \
		flutter build apk --$(BUILD_MODE) --flavor $(ANDROID_FLAVOR) $(PUB_FLAG) $(ENV_DEFINES) && \
		echo "APK: $(APK)"; \
	fi

# `build` validates TRACK when supplied (PROD ios/android); it is not required
# here — only `deploy` requires it (see the track-aware deploy section).
build: guard-local
build: track-guard

dev: guard-local
	$(load-env)
	@UNAME=$$(uname); \
	PROFILE="$(call VAULT_PROFILE_FOR,$(TARGET))"; \
	PLIST_BACKUP=""; FIREBASE_BACKUP=""; GS_DEST=""; \
	dev_cleanup() { \
		[ -n "$$PLIST_BACKUP" ] && tools/ios_google_oauth.sh restore "$$PLIST_BACKUP" >/dev/null 2>&1 || true; \
		if [ -n "$$FIREBASE_BACKUP" ]; then cp "$$FIREBASE_BACKUP" ios/Runner/GoogleService-Info.plist; rm -f "$$FIREBASE_BACKUP"; fi; \
		if [ -n "$$GS_DEST" ]; then rm -f "$$GS_DEST"; fi; \
		[ -n "$(RELEASE)" ] && $(RELEASE_SECRETS) wipe >/dev/null 2>&1 || true; \
		true; \
	}; \
	trap dev_cleanup EXIT INT TERM HUP; \
	if [ -n "$(RELEASE)" ]; then \
		case "$(TARGET)" in \
			simulator|android|waydroid) : ;; \
			*) echo "ENV=$(ENV) dev runs are supported for TARGET=simulator|android|waydroid."; \
			   echo "On-device iOS: make build ENV=$(ENV) TARGET=ios MODE=adhoc && make install TARGET=ios-adhoc."; \
			   exit 1 ;; \
		esac; \
		[ -x "$(RELEASE_SECRETS)" ] || { echo "ENV=$(ENV) needs executable $(RELEASE_SECRETS) (vault fetch)."; exit 1; }; \
		RC="$(RC)" IOS_EXPORT_METHOD="$(IOS_EXPORT_METHOD)" $(RELEASE_SECRETS) fetch "$$PROFILE" $(ENV) || exit 1; \
		if [ "$(TARGET)" = "android" ] || [ "$(TARGET)" = "waydroid" ]; then \
			[ -s "$(RAM_DIR)/google-services.json" ] || { echo "ENV=$(ENV): vault profile produced no google-services.json."; exit 1; }; \
			mkdir -p android/app/src/$(ANDROID_FLAVOR); \
			GS_DEST="android/app/src/$(ANDROID_FLAVOR)/google-services.json"; \
			cp "$(RAM_DIR)/google-services.json" "$$GS_DEST"; \
		fi; \
		if [ "$(TARGET)" = "simulator" ]; then \
			if [ -s "$(RAM_DIR)/GoogleService-Info.plist" ]; then FIREBASE_BACKUP=$$(mktemp); cp ios/Runner/GoogleService-Info.plist "$$FIREBASE_BACKUP"; cp "$(RAM_DIR)/GoogleService-Info.plist" ios/Runner/GoogleService-Info.plist; fi; \
			IOS_GID=$$(cat "$(RAM_DIR)/google-oauth-ios-client-id" 2>/dev/null || true); \
			if [ -n "$$IOS_GID" ]; then PLIST_BACKUP=$$(tools/ios_google_oauth.sh apply "$$IOS_GID") || exit 1; fi; \
		fi; \
	fi; \
	if [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "android" ]; then \
		$(call tunnel-android, $(ANDROID_RUN) -d localhost:$(TUNNEL_ANDROID_PORT)); \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "waydroid" ]; then \
		$(call tunnel-waydroid, $(ANDROID_RUN) -d localhost:$(TUNNEL_WAYDROID_PORT)); \
	elif [ "$(TARGET)" = "waydroid" ]; then \
		IP=$$($(call waydroid-preflight)); \
		adb connect "$$IP:5555"; \
		$(ANDROID_RUN) -d "$$IP:5555"; \
	elif [ "$(TARGET)" = "android" ]; then \
		DEV=$$(adb devices | grep -o 'emulator-[0-9]*' | head -1); \
		if [ -n "$$DEV" ]; then \
			$(ANDROID_RUN) -d "$$DEV"; \
		else \
			$(ANDROID_RUN); \
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
		flutter run $(PUB_FLAG) $(ENV_DEFINES) -d "$$DEV"; \
	elif [ "$(TARGET)" = "ios" ]; then \
		DEVICE=$$(flutter devices --machine 2>/dev/null | python3 -c 'import json,sys; devs=json.load(sys.stdin); ios=[d["id"] for d in devs if d.get("targetPlatform")=="ios" and not d.get("emulator")]; print(ios[0] if ios else "")'); \
		if [ -z "$$DEVICE" ]; then DEVICE=$$(idevice_id -l 2>/dev/null | head -1); fi; \
		if [ -z "$$DEVICE" ]; then \
			echo "No physical iOS device found."; \
			exit 1; \
		fi; \
		TEAM=$$(sed -n 's/^IOS_DEVELOPMENT_TEAM=//p' .env.local 2>/dev/null | head -1); \
		if [ -z "$$TEAM" ] || [ "$$TEAM" = "XXXXXXXXXX" ]; then \
			echo "IOS_DEVELOPMENT_TEAM not set in .env.local."; \
			exit 1; \
		fi; \
		make signing-restore; \
		trap 'make signing-restore 2>/dev/null' EXIT INT TERM HUP; \
		$(BREW_BUNDLE) exec ruby tools/ios_dev_signing.rb apply "$$TEAM"; \
		grep -q "DEVELOPMENT_TEAM = $$TEAM" ios/Runner.xcodeproj/project.pbxproj || { echo "signing patch did not stick; rerun."; exit 1; }; \
		echo "Running on device: $$DEVICE"; \
		if [ "$(NO_XCODE_RESET)" != "1" ]; then \
			osascript -e 'tell application "Xcode" to quit' 2>/dev/null || true; \
			sleep 2; \
			killall Xcode 2>/dev/null || true; \
		fi; \
		if [ "$(CLEAN_INSTALL)" = "1" ]; then \
			xcrun devicectl device uninstall app --device "$$DEVICE" "$(APP_ID)" 2>/dev/null || true; \
		else \
			xcrun devicectl device process terminate --device "$$DEVICE" "$(APP_ID)" 2>/dev/null || true; \
		fi; \
		flutter run $(PUB_FLAG) $(ENV_DEFINES) -d "$$DEVICE"; \
		RC=$$?; \
		if [ "$$RC" -ne 0 ]; then \
			echo "Known iOS/Xcode regression (flutter/flutter#181480); stale Xcode windows are auto-closed (NO_XCODE_RESET=1 disables)."; \
		fi; \
		exit $$RC; \
	elif [ "$(TARGET)" = "ios-adhoc" ]; then \
		make build TARGET=ios-adhoc ENV="$(ENV)" NO_PUB=$(NO_PUB) && \
		make install TARGET=ios-adhoc ENV="$(ENV)" NO_PUB=$(NO_PUB) && \
		DEVICE=$$(idevice_id -l 2>/dev/null | head -1); \
		if [ -n "$$DEVICE" ]; then \
			xcrun devicectl device process launch --device "$$DEVICE" "$(APP_ID)" && \
			echo "Launched $(APP_ID) on $$DEVICE" || \
			echo "Installed, but could not launch $(APP_ID)."; \
		fi; \
	elif [ -n "$(TARGET)" ]; then \
		flutter run $(PUB_FLAG) $(ENV_DEFINES) -d "$(TARGET)"; \
	else \
		flutter run $(PUB_FLAG) $(ENV_DEFINES); \
	fi

install: guard-local
	$(load-env)
	@UNAME=$$(uname); \
	if [ "$(TARGET)" = "android" ] || [ "$(TARGET)" = "waydroid" ]; then \
		if [ ! -f "$(APK)" ]; then \
			echo "APK not found at $(APK) — run 'make build ENV=$(ENV) TARGET=android' first."; \
			exit 0; \
		fi; \
	fi; \
	if [ "$(TARGET)" = "all" ]; then \
		for t in android waydroid ios-adhoc simulator; do \
			echo "install to $$t"; \
			make install TARGET=$$t ENV="$(ENV)" NO_PUB=$(NO_PUB) ALL_SIMS=1 || true; \
		done; \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "android" ]; then \
		$(call tunnel-android, adb -s localhost:$(TUNNEL_ANDROID_PORT) install -r $(APK)); \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "waydroid" ]; then \
		$(call tunnel-waydroid, adb -s localhost:$(TUNNEL_WAYDROID_PORT) install -r $(APK)); \
	elif [ "$(TARGET)" = "ios" ] || [ "$(TARGET)" = "ios-adhoc" ]; then \
		if [ ! -f "$(IPA_ADHOC)" ]; then \
			echo "IPA not found at $(IPA_ADHOC) — run 'make build TARGET=ios-adhoc' first."; \
			exit 0; \
		fi; \
		DEVICE=$$(idevice_id -l 2>/dev/null | head -1); \
		if [ -z "$$DEVICE" ]; then \
			echo "no iOS device connected — skipped."; \
			exit 0; \
		fi; \
		xcrun devicectl device install app --device "$$DEVICE" "$(IPA_ADHOC)" && \
		echo "Installed to device $$DEVICE"; \
	elif [ "$(TARGET)" = "simulator" ]; then \
		APP="build/ios/iphonesimulator/Runner.app"; \
		if [ ! -d "$$APP" ]; then \
			echo "Simulator app not found at $$APP."; \
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
				xcrun simctl install "$$DEV" "$$APP" && echo "Installed to simulator $$DEV"; \
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
			xcrun simctl install "$$DEV" "$$APP" && echo "Installed to simulator $$DEV"; \
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

clear:
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

build-install: guard-local
	@if [ -z "$(TARGET)" ]; then \
		echo "make build-install REQUIRES a target: TARGET=all|android|waydroid|ios|ios-adhoc|simulator"; \
		exit 1; \
	fi
	@make build TARGET=$(TARGET) ENV="$(ENV)" NO_PUB=$(NO_PUB) && \
		make install TARGET=$(TARGET) ENV="$(ENV)" NO_PUB=$(NO_PUB)

uninstall:
	@if [ -z "$(TARGET)" ]; then \
		echo "make uninstall REQUIRES a target: TARGET=all|android|waydroid|ios|ios-adhoc|simulator."; \
		exit 1; \
	fi
	@UNAME=$$(uname); \
	if [ "$(TARGET)" = "all" ]; then \
		for t in android waydroid ios-adhoc simulator; do \
			echo "uninstall from $$t"; \
			make uninstall TARGET=$$t ENV="$(ENV)" || true; \
		done; \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "android" ]; then \
		$(call tunnel-android, if adb -s localhost:$(TUNNEL_ANDROID_PORT) shell pm list packages $(APP_ID) 2>/dev/null | grep -q $(APP_ID); then adb -s localhost:$(TUNNEL_ANDROID_PORT) uninstall $(APP_ID); else echo "$(APP_ID) not installed on android."; fi); \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "waydroid" ]; then \
		$(call tunnel-waydroid, if adb -s localhost:$(TUNNEL_WAYDROID_PORT) shell pm list packages $(APP_ID) 2>/dev/null | grep -q $(APP_ID); then adb -s localhost:$(TUNNEL_WAYDROID_PORT) uninstall $(APP_ID); else echo "$(APP_ID) not installed on waydroid."; fi); \
	elif [ "$(TARGET)" = "waydroid" ]; then \
		IP=$$(waydroid status | awk '/IP address:/ {print $$3}'); \
		if [ -z "$$IP" ]; then echo "waydroid not running — skipped."; else adb connect "$$IP:5555" && if adb -s "$$IP:5555" shell pm list packages $(APP_ID) 2>/dev/null | grep -q $(APP_ID); then adb -s "$$IP:5555" uninstall $(APP_ID); else echo "$(APP_ID) not installed on waydroid."; fi; fi; \
	elif [ "$(TARGET)" = "android" ]; then \
		DEV=$$(adb devices | awk 'NR>1 && $$2=="device" {print $$1; exit}'); \
		if [ -z "$$DEV" ]; then \
			echo "no Android device/emulator available — skipped."; \
		elif adb -s "$$DEV" shell pm list packages $(APP_ID) 2>/dev/null | grep -q $(APP_ID); then \
			adb -s "$$DEV" uninstall $(APP_ID); \
		else \
			echo "$(APP_ID) not installed on $$DEV."; \
		fi; \
	elif [ "$(TARGET)" = "ios" ] || [ "$(TARGET)" = "ios-adhoc" ]; then \
		DEVICE=$$(idevice_id -l 2>/dev/null | head -1); \
		if [ -z "$$DEVICE" ]; then \
			echo "no iOS device connected — skipped."; \
		else \
			xcrun devicectl device uninstall app --device "$$DEVICE" "$(APP_ID)" && \
			echo "Uninstalled $(APP_ID) from device $$DEVICE"; \
		fi; \
	elif [ "$(TARGET)" = "simulator" ]; then \
		DEVS=$$(xcrun simctl list devices booted | awk -F '[()]' '/Booted/ {print $$2}'); \
		if [ -z "$$DEVS" ]; then \
			echo "no booted simulator — skipped."; \
		else \
			if [ $$(echo "$$DEVS" | wc -l | tr -d ' ') -eq 1 ]; then \
				DEV=$$DEVS; \
			else \
				echo "$$DEVS" | gum choose --header "Pick a simulator:" > /tmp/_sim_pick && \
				DEV=$$(cat /tmp/_sim_pick); \
			fi; \
			if ! xcrun simctl get_app_container "$$DEV" "$(APP_ID)" >/dev/null 2>&1; then \
				echo "$(APP_ID) not installed on simulator."; \
			else \
				xcrun simctl uninstall "$$DEV" "$(APP_ID)" && echo "Uninstalled $(APP_ID) from simulator $$DEV"; \
			fi; \
		fi; \
	else \
		echo "TARGET=$(TARGET) unknown for uninstall."; \
		exit 1; \
	fi

clean:
	flutter clean
	rm -rf build/ios/ipa

analyze:
	dart analyze

test:
	bash test/opt-008-makefile-static.sh

check: secrets
	dart analyze
	flutter analyze

secrets:
	@tools/check_secrets.sh

hooks:
	@git config core.hooksPath tools/hooks
	@[ -x tools/hooks/pre-commit ] || { echo "tools/hooks/pre-commit missing or not executable"; exit 1; }
	@echo "core.hooksPath -> tools/hooks"

tunnel-android:
	@HOST="$(TUNNEL_HOST)"; [ -n "$$HOST" ] || { echo "TUNNEL_HOST is required"; exit 2; }; \
		(trap 'kill $$SSH_PID 2>/dev/null; adb disconnect localhost:$(TUNNEL_ANDROID_PORT) 2>/dev/null' EXIT; \
		ssh -N -L $(TUNNEL_ANDROID_PORT):127.0.0.1:5555 "$$HOST" & SSH_PID=$$!; sleep 1; \
		adb connect localhost:$(TUNNEL_ANDROID_PORT); \
		$(ANDROID_RUN) -d localhost:$(TUNNEL_ANDROID_PORT))

tunnel-waydroid:
	@HOST="$(TUNNEL_HOST)"; [ -n "$$HOST" ] || { echo "TUNNEL_HOST is required"; exit 2; }; \
		WIP=$$(ssh "$$HOST" "waydroid status | awk '/IP address/ {print \$$3}'"); \
		(trap 'kill $$SSH_PID 2>/dev/null; adb disconnect localhost:$(TUNNEL_WAYDROID_PORT) 2>/dev/null' EXIT; \
		ssh -N -L $(TUNNEL_WAYDROID_PORT):$$WIP:5555 "$$HOST" & SSH_PID=$$!; sleep 1; \
		adb connect localhost:$(TUNNEL_WAYDROID_PORT); \
		$(ANDROID_RUN) -d localhost:$(TUNNEL_WAYDROID_PORT))

signing-restore:
	@git checkout HEAD -- ios/Runner.xcodeproj/project.pbxproj && \
		rm -f /tmp/samay-pbxproj.bak 2>/dev/null; \
		echo "ios signing restored from HEAD"

login:
	@python3 tools/xcode_login.py --target "$(TARGET)" --device "$(DEVICE)" $(if $(DRY_RUN),--dry-run,)

# Vault-gated ENVs (staging/prod) are LOCAL-ONLY: run on the Mac with the vault
# profile materialized on a RAM disk; never in CI. No-op for testing-local/testing.
guard-local:
	@if [ -n "$(RELEASE)" ] && { [ -n "$$CI" ] || [ -n "$$GITHUB_ACTIONS" ] || [ -n "$$GITEA_ACTIONS" ] || [ -n "$$ACT" ]; }; then \
		echo "ENV=$(ENV) is vault-gated (staging/prod); LOCAL-ONLY — refusing in CI."; exit 1; \
	fi

# Validate TRACK against the per-TARGET store-native vocabulary. Silent no-op
# when TRACK is empty and TRACK_REQUIRED is false (so `build` stays usable
# without it); `deploy` sets TRACK_REQUIRED=true. No TRACK=all.
track-guard:
	@tracks="$(TRACK)"; \
	case ",$$tracks," in *,all,*) echo "TRACK=all is not allowed — list tracks explicitly (ios: $(IOS_TRACKS) · android: $(ANDROID_TRACKS))."; exit 1;; esac; \
	if [ -z "$$tracks" ]; then \
		if [ "$(TRACK_REQUIRED)" = "true" ]; then echo "TRACK is required (TARGET=$(TARGET) — ios: $(IOS_TRACKS) · android: $(ANDROID_TRACKS))."; exit 1; fi; \
		exit 0; \
	fi; \
	case "$(TARGET)" in \
		ios) allowed="$(IOS_TRACKS)";; \
		android) allowed="$(ANDROID_TRACKS)";; \
		all) allowed="$(IOS_TRACKS) $(ANDROID_TRACKS)";; \
		*) echo "TRACK requires TARGET=ios|android|all (got '$(TARGET)')."; exit 1;; \
	esac; \
	for t in $$(echo "$$tracks" | tr ',' ' '); do \
		case " $$allowed " in *" $$t "*) : ;; *) echo "unknown TRACK '$$t' for TARGET=$(TARGET) (allowed: $$allowed)."; exit 1;; esac; \
	done

bundle-install:
	@[ -f Gemfile ] || { echo "No Gemfile — fastlane not wired yet."; exit 1; }
	$(BREW_BUNDLE) install

# Signed PROD artifacts for BOTH platforms in one command (local-only,
# vault-gated). Each platform fetches its vault profile into the RAM disk,
# builds, then wipes — so each prompts for the vault passphrase once. The
# per-platform targets are `build ENV=staging|prod TARGET=ios|android`; this target
# is just the two-step convenience wrapper.
release:
	@$(MAKE) build TARGET=ios ENV="$(ENV)" NO_PUB=$(NO_PUB)
	@$(MAKE) build TARGET=android ENV="$(ENV)" NO_PUB=$(NO_PUB)

# ── Track-aware build + deploy ───────────────────────────────────────────────
# build ENV=staging|prod TARGET=ios|android TRACK=<list>   → validated build only
# deploy TARGET=ios|android|all TRACK=<list>        → build every platform in
#   scope (vault-gated), then publish the built artifact to each requested
#   store track via fastlane. TRACK is required, store-native, comma-separated;
#   there is NO TRACK=all. For TARGET=all a track valid for only one platform
#   is applied there and skipped on the other.
#   ios tracks: internal (TestFlight internal) external (TestFlight external) prod (App Store)
#   android tracks: internal alpha beta production (Google Play)
deploy: TRACK_REQUIRED=true
deploy: track-guard
	@set -e; \
	targets="$(TARGET)"; \
	case "$$targets" in ios|android) : ;; all) targets="ios android";; *) echo "deploy: TARGET must be ios|android|all"; exit 1;; esac; \
	for t in $$targets; do $(MAKE) --no-print-directory build TARGET=$$t ENV="$(ENV)" TRACK="$(TRACK)" NO_PUB=$(NO_PUB); done; \
	$(MAKE) --no-print-directory publish TARGET="$(TARGET)" ENV="$(ENV)" TRACK="$(TRACK)"

publish: TRACK_REQUIRED=true
publish: track-guard
	@set -e; \
	targets="$(TARGET)"; \
	case "$$targets" in ios|android) : ;; all) targets="ios android";; *) echo "publish: TARGET must be ios|android|all"; exit 1;; esac; \
	[ -x "$(RELEASE_SECRETS)" ] || { echo "publish: needs executable $(RELEASE_SECRETS) (vault fetch/wipe)."; exit 1; }; \
	pub_cleanup() { $(RELEASE_SECRETS) wipe >/dev/null 2>&1 || true; true; }; \
	trap pub_cleanup EXIT INT TERM HUP; \
	for t in $$targets; do \
		case "$$t" in ios) profile=apple;; android) profile=android;; esac; \
		RC="$(RC)" IOS_EXPORT_METHOD="$(IOS_EXPORT_METHOD)" $(RELEASE_SECRETS) fetch "$$profile" $(ENV); \
		eval "$$($(RELEASE_SECRETS) env "$$profile")"; \
		for track in $$(echo "$(TRACK)" | tr ',' ' '); do \
			[ -n "$$track" ] || continue; \
			case "$$t" in \
				ios) \
					case " $(IOS_TRACKS) " in *" $$track "*) ;; *) echo "publish: skip ios/$$track (not an iOS track)"; continue;; esac; \
					case "$$track" in internal) lane=track_internal;; external) lane=track_external;; prod) lane=track_prod;; esac; \
					TRACK="$$track" bundle exec fastlane ios "$$lane";; \
				android) \
					case " $(ANDROID_TRACKS) " in *" $$track "*) ;; *) echo "publish: skip android/$$track (not an Android track)"; continue;; esac; \
					ENV="$(ENV)" TRACK="$$track" bundle exec fastlane android track_play;; \
			esac; \
		done; \
		$(RELEASE_SECRETS) wipe; \
	done
