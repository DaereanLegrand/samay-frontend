# Samay frontend — Flutter app.
.PHONY: help init start build dev install build-install uninstall clear clean env test \
        analyze check secrets hooks guard-local track-guard deploy publish \
        tunnel-android tunnel-waydroid signing-restore login \
        ios-beta ios-release android-alpha android-release release bundle-install

APP_NAME := samay_app
PROD ?= false
BUILD_MODE ?= $(if $(filter true,$(PROD)),release,debug)
APK := build/app/outputs/flutter-apk/app-$(BUILD_MODE).apk
IPA_ADHOC := build/ios/ipa/$(APP_NAME)-adhoc.ipa
APP_ID := com.qallariy.samay
# Vault fetch/wipe helper for PROD builds. No fallback: PROD stops if it is
# absent (all-or-nothing).
RELEASE_SECRETS ?= tools/release-signing-not-in-repo.sh

export PATH := /opt/homebrew/opt/ruby/bin:/Users/daerean/.local/share/gem/ruby/4.0.0/bin:$(PATH)
BREW_BUNDLE := /opt/homebrew/opt/ruby/bin/bundle

IOS_DEVELOPMENT_TEAM ?= $(shell sed -n 's/^IOS_DEVELOPMENT_TEAM=//p' .env.local 2>/dev/null | head -1)

TUNNEL_HOST          ?= <build-host>
TUNNEL_ANDROID_PORT  ?= 5565
TUNNEL_WAYDROID_PORT ?= 5566
TUNNEL_CMD    ?= flutter run $(PUB_FLAG) $(DEV_DEFINES) -d localhost:$(TUNNEL_ANDROID_PORT)
TUNNEL_WAYDROID_CMD ?= flutter run $(PUB_FLAG) $(DEV_DEFINES) -d localhost:$(TUNNEL_WAYDROID_PORT)

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

# Store-native release tracks (for `build PROD=true` + `deploy`). TRACK is a
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

# `dev` always targets the testing API (see .env). Explicit define wins over the file.
API_TESTING_URL := $(shell sed -n 's/^API_TESTING_URL=//p' .env 2>/dev/null | head -1)
API_TESTING_URL := $(if $(API_TESTING_URL),$(API_TESTING_URL),https://samay-api-testing.qallariy.lat)

ANDROID_GATEWAY_HOST := $(if $(findstring Linux,$(shell uname -s)),10.0.2.2,127.0.0.1)
OS_IS_DARWIN := $(findstring Darwin,$(shell uname -s))

# TESTING=true points builds at the local stack; requires JWT_SECRET.
TESTING ?= false
ifeq ($(TESTING),true)
TESTING_JWT_SECRET := $(JWT_SECRET)
ifneq ($(strip $(TESTING_JWT_SECRET)),)
TESTING_ANON_KEY := $(shell JWT_SECRET='$(TESTING_JWT_SECRET)' python3 tools/gen_testing_anon_key.py)
endif
FLUTTER_DEFINES += --dart-define=SUPABASE_URL=http://$(ANDROID_GATEWAY_HOST):54386 --dart-define=SUPABASE_ANON_KEY=$(TESTING_ANON_KEY)
build: | testing-kong-register
dev: | testing-kong-register
install: | testing-kong-register
tunnel-android: | testing-kong-register
endif

# `dev` always points SUPABASE_URL at the testing API (explicit define wins over .env).
ifeq ($(TESTING),true)
DEV_DEFINES := $(FLUTTER_DEFINES)
else
DEV_DEFINES := $(FLUTTER_DEFINES) --dart-define=SUPABASE_URL=$(API_TESTING_URL)
endif

ifeq ($(PROD),true)
ifeq ($(TESTING),true)
$(error PROD=true and TESTING=true are mutually exclusive)
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

help:
	@echo "Samay frontend — make targets (TARGET=all|android|waydroid|ios|ios-adhoc|simulator)"
	@echo "  BUILD/RUN: build dev install build-install uninstall clear clean"
	@echo "  TUNNELS:   tunnel-android tunnel-waydroid signing-restore"
	@echo "  LOGIN:     login [TARGET=simulator]"
	@echo "  GATES:     analyze check secrets hooks env"
	@echo "  RELEASE:   ios-beta ios-release android-alpha android-release release bundle-install"
	@echo "  TRACKS:    deploy TARGET=ios|android|all TRACK=<list>  (build PROD=true honours TRACK too)"

env:
	@echo "ENV_FILE=$(ENV_FILE)"
	@echo "FLUTTER_DEFINES=$(FLUTTER_DEFINES)"

# Interactive setup; then `make start` runs against the chosen backend.
init:
	@bash tools/init.sh

start: dev

testing-kong-register:
	@[ -n "$(TESTING_JWT_SECRET)" ] || { echo "TESTING=true needs JWT_SECRET (the local stack signing secret)."; exit 1; }
	@[ -n "$(TESTING_ANON_KEY)" ] || { echo "TESTING=true: failed to mint the anon JWT."; exit 1; }
	@KONG=$$(docker ps --format '{{.Names}}' --filter publish=54386 | head -1); \
	if [ -z "$$KONG" ]; then \
		echo "No Kong on 127.0.0.1:54386 — temp JWT NOT registered."; \
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
			make build TARGET=$$t NO_PUB=$(NO_PUB) || true; \
		done; \
	elif [ "$(TARGET)" = "ios" ] && [ "$(PROD)" != "true" ]; then \
		flutter build ios --release --no-codesign $(PUB_FLAG) $(FLUTTER_DEFINES) && \
		cd build/ios && rm -rf Payload && mkdir Payload && \
		cp -R iphoneos/Runner.app Payload/ && \
		mkdir -p ipa && zip -r -y ipa/$(APP_NAME).ipa Payload && rm -rf Payload && \
		echo "IPA: build/ios/ipa/$(APP_NAME).ipa"; \
	elif [ "$(TARGET)" = "ios-adhoc" ]; then \
		IOS_DEVELOPMENT_TEAM="$(IOS_DEVELOPMENT_TEAM)" \
		SUPABASE_URL="$(LANE_SUPABASE_URL)" \
		SUPABASE_ANON_KEY="$(LANE_SUPABASE_ANON_KEY)" \
		./bin/fastlane ios adhoc_local && \
		echo "IPA: $(IPA_ADHOC)"; \
	elif [ "$(TARGET)" = "simulator" ]; then \
		flutter build ios --simulator $(PUB_FLAG) $(FLUTTER_DEFINES) && \
		echo "Simulator app: build/ios/iphonesimulator/Runner.app"; \
	elif [ "$(TARGET)" = "android" ] && [ "$(PROD)" = "true" ]; then \
		[ -x "$(RELEASE_SECRETS)" ] || { echo "PROD=true needs executable $(RELEASE_SECRETS) (vault fetch/wipe)."; exit 1; }; \
		trap '$(RELEASE_SECRETS) wipe >/dev/null 2>&1 || true' EXIT INT TERM HUP; \
		$(RELEASE_SECRETS) wipe >/dev/null 2>&1 || true; \
		$(RELEASE_SECRETS) fetch android; \
		[ -f "$(KEYSTORE_PROPERTIES)" ] || { echo "vault 'android' profile yielded no $(KEYSTORE_PROPERTIES)."; exit 1; }; \
		[ -f "$(PROD_DEFINES)" ] || { echo "vault 'android' profile yielded no $(PROD_DEFINES)."; exit 1; }; \
		KEYSTORE_PROPERTIES="$(KEYSTORE_PROPERTIES)" flutter build appbundle --release $(PUB_FLAG) --dart-define-from-file="$(PROD_DEFINES)" && \
		echo "AAB: build/app/outputs/bundle/release/app-release.aab"; \
	elif [ "$(TARGET)" = "ios" ] && [ "$(PROD)" = "true" ]; then \
		[ -x "$(RELEASE_SECRETS)" ] || { echo "PROD=true needs executable $(RELEASE_SECRETS) (vault fetch/wipe)."; exit 1; }; \
		PLIST_BACKUP=""; \
		cleanup() { \
			[ -n "$$PLIST_BACKUP" ] && tools/ios_google_oauth.sh restore "$$PLIST_BACKUP" >/dev/null 2>&1 || true; \
			$(RELEASE_SECRETS) wipe >/dev/null 2>&1 || true; \
		}; \
		trap cleanup EXIT INT TERM HUP; \
		$(RELEASE_SECRETS) wipe >/dev/null 2>&1 || true; \
		$(RELEASE_SECRETS) fetch apple; \
		[ -f "$(EXPORT_OPTIONS)" ] || { echo "vault 'apple' profile yielded no $(EXPORT_OPTIONS)."; exit 1; }; \
		[ -f "$(PROD_DEFINES)" ] || { echo "vault 'apple' profile yielded no $(PROD_DEFINES)."; exit 1; }; \
		GID=$$(cat "$(RAM_DIR)/google-oauth-client-id"); \
		[ -n "$$GID" ] || { echo "vault 'apple' profile yielded no google-oauth-client-id."; exit 1; }; \
		PLIST_BACKUP=$$(tools/ios_google_oauth.sh apply "$$GID"); \
		flutter build ipa --release $(PUB_FLAG) --dart-define-from-file="$(PROD_DEFINES)" --dart-define=GOOGLE_OAUTH_IOS_CLIENT_ID="$$GID" --export-options-plist="$(EXPORT_OPTIONS)" && \
		echo "IPA: build/ios/ipa/*.ipa"; \
	else \
		flutter build apk --$(BUILD_MODE) $(PUB_FLAG) $(FLUTTER_DEFINES) && \
		echo "APK: $(APK)"; \
	fi

# `build` validates TRACK when supplied (PROD ios/android); it is not required
# here — only `deploy` requires it (see the track-aware deploy section).
build: track-guard

dev:
	$(load-env)
	@UNAME=$$(uname); \
	if [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "android" ]; then \
		$(call tunnel-android, flutter run $(PUB_FLAG) $(DEV_DEFINES) -d localhost:$(TUNNEL_ANDROID_PORT)); \
	elif [ "$$UNAME" = "Darwin" ] && [ "$(TARGET)" = "waydroid" ]; then \
		$(call tunnel-waydroid, flutter run $(PUB_FLAG) $(DEV_DEFINES) -d localhost:$(TUNNEL_WAYDROID_PORT)); \
	elif [ "$(TARGET)" = "waydroid" ]; then \
		IP=$$($(call waydroid-preflight)); \
		adb connect "$$IP:5555"; \
		flutter run $(PUB_FLAG) $(DEV_DEFINES) -d "$$IP:5555"; \
	elif [ "$(TARGET)" = "android" ]; then \
		DEV=$$(adb devices | grep -o 'emulator-[0-9]*' | head -1); \
		if [ -n "$$DEV" ]; then \
			flutter run $(PUB_FLAG) $(DEV_DEFINES) -d "$$DEV"; \
		else \
			flutter run $(PUB_FLAG) $(DEV_DEFINES); \
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
		flutter run $(PUB_FLAG) $(DEV_DEFINES) -d "$$DEV"; \
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
		flutter run $(PUB_FLAG) $(DEV_DEFINES) -d "$$DEVICE"; \
		RC=$$?; \
		if [ "$$RC" -ne 0 ]; then \
			echo "Known iOS/Xcode regression (flutter/flutter#181480); stale Xcode windows are auto-closed (NO_XCODE_RESET=1 disables)."; \
		fi; \
		exit $$RC; \
	elif [ "$(TARGET)" = "ios-adhoc" ]; then \
		make build TARGET=ios-adhoc NO_PUB=$(NO_PUB) && \
		make install TARGET=ios-adhoc NO_PUB=$(NO_PUB) && \
		DEVICE=$$(idevice_id -l 2>/dev/null | head -1); \
		if [ -n "$$DEVICE" ]; then \
			xcrun devicectl device process launch --device "$$DEVICE" "$(APP_ID)" && \
			echo "Launched $(APP_ID) on $$DEVICE" || \
			echo "Installed, but could not launch $(APP_ID)."; \
		fi; \
	elif [ -n "$(TARGET)" ]; then \
		flutter run $(PUB_FLAG) $(DEV_DEFINES) -d "$(TARGET)"; \
	else \
		flutter run $(PUB_FLAG) $(DEV_DEFINES); \
	fi

install:
	$(load-env)
	@UNAME=$$(uname); \
	if [ "$(TARGET)" = "android" ] || [ "$(TARGET)" = "waydroid" ]; then \
		if [ ! -f "$(APK)" ]; then \
			echo "APK not found at $(APK) — run 'make build TARGET=android' first."; \
			exit 0; \
		fi; \
	fi; \
	if [ "$(TARGET)" = "all" ]; then \
		for t in android waydroid ios-adhoc simulator; do \
			echo "install to $$t"; \
			make install TARGET=$$t NO_PUB=$(NO_PUB) ALL_SIMS=1 || true; \
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

build-install:
	@if [ -z "$(TARGET)" ]; then \
		echo "make build-install REQUIRES a target: TARGET=all|android|waydroid|ios|ios-adhoc|simulator"; \
		exit 1; \
	fi
	@make build TARGET=$(TARGET) NO_PUB=$(NO_PUB) && \
		make install TARGET=$(TARGET) NO_PUB=$(NO_PUB)

uninstall:
	@if [ -z "$(TARGET)" ]; then \
		echo "make uninstall REQUIRES a target: TARGET=all|android|waydroid|ios|ios-adhoc|simulator."; \
		exit 1; \
	fi
	@UNAME=$$(uname); \
	if [ "$(TARGET)" = "all" ]; then \
		for t in android waydroid ios-adhoc simulator; do \
			echo "uninstall from $$t"; \
			make uninstall TARGET=$$t || true; \
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
		$(TUNNEL_CMD))

tunnel-waydroid:
	@HOST="$(TUNNEL_HOST)"; [ -n "$$HOST" ] || { echo "TUNNEL_HOST is required"; exit 2; }; \
		WIP=$$(ssh "$$HOST" "waydroid status | awk '/IP address/ {print \$$3}'"); \
		(trap 'kill $$SSH_PID 2>/dev/null; adb disconnect localhost:$(TUNNEL_WAYDROID_PORT) 2>/dev/null' EXIT; \
		ssh -N -L $(TUNNEL_WAYDROID_PORT):$$WIP:5555 "$$HOST" & SSH_PID=$$!; sleep 1; \
		adb connect localhost:$(TUNNEL_WAYDROID_PORT); \
		$(TUNNEL_WAYDROID_CMD))

signing-restore:
	@git checkout HEAD -- ios/Runner.xcodeproj/project.pbxproj && \
		rm -f /tmp/samay-pbxproj.bak 2>/dev/null; \
		echo "ios signing restored from HEAD"

login:
	@python3 tools/xcode_login.py --target "$(TARGET)" --device "$(DEVICE)" $(if $(DRY_RUN),--dry-run,)

# Prod / open-testing releases are LOCAL-ONLY and vault-gated: run on the Mac
# with the vault profile materialized on a RAM disk; never in CI.
guard-local:
	@if [ -n "$$CI" ] || [ -n "$$GITHUB_ACTIONS" ] || [ -n "$$GITEA_ACTIONS" ] || [ -n "$$ACT" ]; then \
		echo "release/open-testing targets are LOCAL-ONLY (vault-gated); refusing in CI."; exit 1; \
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

ios-beta: guard-local
	@[ -f fastlane/Fastfile ] || { echo "fastlane iOS not wired yet."; exit 1; }
	@grep -q 'beta_testflight' fastlane/Fastfile || { echo "lane 'beta_testflight' missing."; exit 1; }
	bundle exec fastlane ios beta_testflight

ios-release: guard-local
	@[ -f fastlane/Fastfile ] || { echo "fastlane iOS not wired yet."; exit 1; }
	@grep -q 'release_appstore' fastlane/Fastfile || { echo "lane 'release_appstore' missing."; exit 1; }
	bundle exec fastlane ios release_appstore

android-alpha: guard-local
	@[ -f fastlane/Fastfile ] || { echo "fastlane Android not wired yet."; exit 1; }
	@grep -q 'alpha_firebase' fastlane/Fastfile || { echo "lane 'alpha_firebase' missing."; exit 1; }
	bundle exec fastlane android alpha_firebase

android-release: guard-local
	@[ -f fastlane/Fastfile ] || { echo "fastlane Android not wired yet."; exit 1; }
	@grep -q 'release_play' fastlane/Fastfile || { echo "lane 'release_play' missing."; exit 1; }
	bundle exec fastlane android release_play

bundle-install:
	@[ -f Gemfile ] || { echo "No Gemfile — fastlane not wired yet."; exit 1; }
	$(BREW_BUNDLE) install

# Signed PROD artifacts for BOTH platforms in one command (local-only,
# vault-gated). Each platform fetches its vault profile into the RAM disk,
# builds, then wipes — so each prompts for the vault passphrase once. The
# per-platform targets are `build PROD=true TARGET=ios|android`; this target
# is just the two-step convenience wrapper.
release:
	@$(MAKE) build PROD=true TARGET=ios NO_PUB=$(NO_PUB)
	@$(MAKE) build PROD=true TARGET=android NO_PUB=$(NO_PUB)

# ── Track-aware build + deploy ───────────────────────────────────────────────
# build PROD=true TARGET=ios|android TRACK=<list>   → validated build only
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
	for t in $$targets; do $(MAKE) --no-print-directory build PROD=true TARGET=$$t TRACK="$(TRACK)" NO_PUB=$(NO_PUB); done; \
	$(MAKE) --no-print-directory publish TARGET="$(TARGET)" TRACK="$(TRACK)"

publish: TRACK_REQUIRED=true
publish: track-guard
	@set -e; \
	targets="$(TARGET)"; \
	case "$$targets" in ios|android) : ;; all) targets="ios android";; *) echo "publish: TARGET must be ios|android|all"; exit 1;; esac; \
	[ -x "$(RELEASE_SECRETS)" ] || { echo "publish: needs executable $(RELEASE_SECRETS) (vault fetch/wipe)."; exit 1; }; \
	for t in $$targets; do \
		case "$$t" in ios) profile=apple;; android) profile=android;; esac; \
		$(RELEASE_SECRETS) fetch "$$profile"; \
		eval "$$($(RELEASE_SECRETS) env "$$profile")"; \
		for track in $$(echo "$(TRACK)" | tr ',' ' '); do \
			[ -n "$$track" ] || continue; \
			case "$$t" in \
				ios) \
					case " $(IOS_TRACKS) " in *" $$track "*) ;; *) echo "publish: skip ios/$$track (not an iOS track)"; continue;; esac; \
					case "$$track" in internal) lane=track_internal;; external) lane=track_external;; prod) lane=release_appstore;; esac; \
					TRACK="$$track" bundle exec fastlane ios "$$lane";; \
				android) \
					case " $(ANDROID_TRACKS) " in *" $$track "*) ;; *) echo "publish: skip android/$$track (not an Android track)"; continue;; esac; \
					TRACK="$$track" bundle exec fastlane android track_play;; \
			esac; \
		done; \
		$(RELEASE_SECRETS) wipe; \
	done
