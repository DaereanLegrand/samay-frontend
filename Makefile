.PHONY: build dev install clean build-cli build-linux lint test \
        flutter-test flutter-analyze \
        supabase-start supabase-stop supabase-status supabase-reset \
        supabase-docker-start supabase-docker-stop supabase-docker-status supabase-docker-reset \
        supabase-testing-start supabase-testing-stop supabase-testing-status supabase-testing-reset \
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

# ── Flutter ───────────────────────────────────────────────────────────────────

build:
	@if [ "$(TARGET)" = "ios" ]; then \
		flutter build ios --release --no-codesign $(PUB_FLAG) && \
		cd build/ios && rm -rf Payload && mkdir Payload && \
		cp -R iphoneos/Runner.app Payload/ && \
		mkdir -p ipa && zip -r -y ipa/$(APP_NAME).ipa Payload && rm -rf Payload && \
		echo "✅  IPA: build/ios/ipa/$(APP_NAME).ipa"; \
	else \
		flutter build apk $(PUB_FLAG) && \
		echo "✅  APK: $(APK)"; \
	fi

dev:
	@if [ "$(TARGET)" = "waydroid" ]; then \
		IP=$$(waydroid status | awk '/IP address:/ {print $$3}'); \
		adb connect "$$IP:5555"; \
		flutter run $(PUB_FLAG) -d "$$IP:5555"; \
	elif [ "$(TARGET)" = "android" ]; then \
		DEV=$$(adb devices | grep -o 'emulator-[0-9]*' | head -1); \
		if [ -n "$$DEV" ]; then \
			flutter run $(PUB_FLAG) -d "$$DEV"; \
		else \
			flutter run $(PUB_FLAG); \
		fi; \
	elif [ -n "$(TARGET)" ]; then \
		flutter run $(PUB_FLAG) -d "$(TARGET)"; \
	else \
		flutter run $(PUB_FLAG); \
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

supabase-testing-start:
	cd supabase-testing && docker compose up -d --wait

supabase-testing-stop:
	cd supabase-testing && docker compose down

supabase-testing-status:
	cd supabase-testing && docker compose ps

supabase-testing-reset:
	cd supabase-testing && docker compose down && rm -rf volumes/db/data volumes/storage && docker compose up -d --wait
