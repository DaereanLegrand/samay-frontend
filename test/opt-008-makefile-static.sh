#!/usr/bin/env bash
# =============================================================================
# Samay — STATIC gate for the Makefile finalization (agent M-15).
#
# Makefile-side verification of the release-pipeline surface (fastlane stubs,
# migrate-check refresh, deploy placeholders, bundle-install) — no stack, no
# docker, no bundle, no fastlane required. Exit 0 = all checks pass:
#
#   1. `make -n` resolves for ALL documented targets (the full .PHONY
#      inventory, incl. override forms TARGET=/OVERRIDES=/FLUTTER_DEFINES=).
#   2. Fastlane upload-lane contract: `publish` maps each ios track to its
#      upload lane and android to `track_play`; every lane uploads the
#      vault-built artifact (no rebuild, no `match`):
#        TRACK=internal → fastlane ios track_internal
#        TRACK=external → fastlane ios track_external
#        TRACK=prod     → fastlane ios track_prod
#        android        → fastlane android track_play
#   3. migrate-check RED probe: tools/check_migrations.sh is run against a
#      SCRATCH git repo — GREEN on a clean committed pair of stacks, RED on a
#      planted untracked migration, RED on a planted future-dated migration
#      (real repo is never touched).
#   4. bash -n on tools/check_migrations.sh and this file.
#
# NOTE for M-17/M-18: when fastlane/Fastfile + Gemfile land, the conditional
# stub probe (§2) auto-skips; keep the four lane names EXACTLY as above.
# M-17 (2026-08-10) added §2b: Fastfile lane/Appfile/Gemfile assertions + the
# no-real-credential-shape scan over fastlane/ (placeholder policy).
# M-18 (2026-08-10) extended §2b: platform :android + the track_play upload
# lane, no .jks/JSON-key material in fastlane/ OR android/, and
# android/app/keystores/ absent (the keystore lives in the vault, never the repo).
# M-27 (2026-08-10) added §6: the android platform contract —
#   - the gradle wrapper is COMMITTED and deterministic (gradlew / gradlew.bat
#     / gradle-wrapper.jar exist and are NOT gitignored; flutter_tools would
#     auto-inject them, but a committed wrapper removes that dependency),
#   - gradle-wrapper.properties pins the distribution (version + -all variant
#     verified against Flutter 3.44.1 by a real `flutter build apk --debug`),
#   - the manifest carries allowBackup=false (E2EE R12), predictive back,
#     and CAMERA; gallery uses the Android Photo Picker, so READ_MEDIA_IMAGES /
#     READ_EXTERNAL_STORAGE must be ABSENT (Play Photo and Video Permissions
#     policy — no broad media access),
#   - build.gradle.kts reads the §3.3 keystore envs and NEVER debug-signs
#     release (fail-fast guard present; the debug-signing line is gone),
#   - no .jks/.keystore is tracked by git.
# M-28 (2026-08-10) added §7: the iOS platform contract —
#   - Info.plist carries the privacy usage descriptions (I-28: camera + photo
#     library; M-28: photo-library ADD for the future save-to-gallery),
#   - minimum iOS is 16.0 (product requirement) — enforced in
#     BOTH the pbxproj (IPHONEOS_DEPLOYMENT_TARGET, 3 configs) and the
#     Podfile (platform :ios '16.0'); a mismatch breaks the build,
#   - the Podfile post_install enables the I-28 permission_handler macros
#     (PERMISSION_CAMERA / PERMISSION_PHOTOS) — without them the plugin
#     returns MissingPluginException at runtime,
#   - signing stays placeholder-only: CODE_SIGN_STYLE = Manual,
#     DEVELOPMENT_TEAM = XXXXXXXXXX (the §3.3 TEAM_ID placeholder), empty
#     PROVISIONING_PROFILE_SPECIFIER, bundle id com.qallariy.samay (matches
#     fastlane/Appfile) — the vault .p12 + provisioning profile sign the build,
#   - Podfile.lock / SPM Package.resolved resolve purchases_flutter 10.8.0
#     → PurchasesHybridCommon 18.29.0 → RevenueCat 5.83.0 (the I-71 conflict
#     fix; stale lock pinned PurchasesHybridCommon 14.3.0 and broke pod
#     install — iOS AND macOS now resolve this chain via Flutter SPM),
#   - no real team ids / certs / provisioning shapes are tracked by git.
# M-29 (2026-08-10) added §8: the non-product platform contract —
#   - web/ is placeholder polish only (the app targets iOS+Android per MVP
#     §1): index.html title/description/apple-meta/theme-color black and
#     manifest.json name/colors/description must read 'Samay' + #000000
#     (never the Flutter "A new Flutter project." default or the template
#     #0175C2 blue),
#   - macos/ product naming: PRODUCT_NAME = samay (== pubspec name, the
#     bundle name; the pre-campaign 'samay_app' rename artifact is gone),
#     CFBundleDisplayName = Samay (matches iOS display name), bundle id
#     com.qallariy.samay, and no 'samay_app' literal remains in tracked
#     macos/ files (pbxproj TEST_HOST ×3 + Runner.xcscheme BuildableName ×5
#     were part of the rename),
#   - the I-01/I-19-era SPM/CocoaPods state is committed deliberately:
#     macos/Flutter/GeneratedPluginRegistrant.swift + macos/Podfile.lock are
#     tracked (same I-71 chain as iOS), while ephemeral/ + Pods/ stay
#     gitignored — NO build outputs may ever be tracked in any platform dir,
#   - linux/ + windows/ are scaffold-clean: window titles read 'Samay'
#     (my_application.cc ×2 / main.cpp), binary names stay samay_app
#     (CMakeLists BINARY_NAME — build-level identity, pinned so nobody
#     churns them), and no Flutter-default titles survive.
# Usage: bash test/opt-008-makefile-static.sh
# =============================================================================
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
MAKEFILE="$REPO/Makefile"
FAILURES=0
fail() { echo "  ❌ $*"; FAILURES=$((FAILURES + 1)); }
pass() { echo "  ✅ $*"; }

echo "═══════════════════════════════════════════════════════════════"
echo "  M-15 — Makefile finalization static verification"
echo "═══════════════════════════════════════════════════════════════"

# ── 1. Every documented target resolves via `make -n` ────────────────────────
echo ""
echo "━━━ 1. make -n resolves all documented targets ━━━"
TARGETS="help init start build dev install build-install clean clear uninstall \
check test analyze env secrets tunnel-android tunnel-waydroid signing-restore \
track-guard \
release bundle-install"
for t in $TARGETS; do
  if make -n "$t" >/dev/null 2>&1; then
    pass "make -n $t"
  else
    fail "make -n $t does not resolve"
  fi
done

# Override forms (the documented seam surfaces)
if make -n bundle-install >/dev/null 2>&1; then pass "make -n bundle-install (stub resolves dry)"; else fail "make -n bundle-install"; fi
if make -n dev TARGET=ios-adhoc >/dev/null 2>&1; then pass "make -n dev TARGET=ios-adhoc (enrolled ad-hoc device branch resolves dry)"; else fail "make -n dev TARGET=ios-adhoc"; fi
if make -n dev TARGET=ios-adhoc ENV=testing-local >/dev/null 2>&1; then pass "make -n dev TARGET=ios-adhoc ENV=testing-local (TESTING defines + register prereq resolve dry)"; else fail "make -n dev TARGET=ios-adhoc ENV=testing-local"; fi
if make -n build TARGET=ios-adhoc >/dev/null 2>&1; then pass "make -n build TARGET=ios-adhoc (fastlane adhoc_local branch resolves dry)"; else fail "make -n build TARGET=ios-adhoc"; fi
if make -n install TARGET=ios-adhoc >/dev/null 2>&1; then pass "make -n install TARGET=ios-adhoc (devicectl device-install branch resolves dry)"; else fail "make -n install TARGET=ios-adhoc"; fi
if make -n dev TARGET=waydroid >/dev/null 2>&1; then pass "make -n dev TARGET=waydroid (Darwin tunnel-waydroid + direct branches resolve dry)"; else fail "make -n dev TARGET=waydroid"; fi
if make -n dev TARGET=android >/dev/null 2>&1; then pass "make -n dev TARGET=android (Darwin tunnel-android + emulator branches resolve dry)"; else fail "make -n dev TARGET=android"; fi
if make -n install TARGET=waydroid >/dev/null 2>&1; then pass "make -n install TARGET=waydroid (tunneled adb install resolves dry)"; else fail "make -n install TARGET=waydroid"; fi
if make -n clear TARGET=waydroid >/dev/null 2>&1; then pass "make -n clear TARGET=waydroid (tunneled pm clear resolves dry)"; else fail "make -n clear TARGET=waydroid"; fi
if make -n tunnel-waydroid >/dev/null 2>&1; then pass "make -n tunnel-waydroid (waydroid tunnel target resolves dry)"; else fail "make -n tunnel-waydroid"; fi
if make -n uninstall TARGET=all >/dev/null 2>&1; then pass "make -n uninstall TARGET=all (all-devices branch resolves dry)"; else fail "make -n uninstall TARGET=all"; fi
if make -n build TARGET=all >/dev/null 2>&1; then pass "make -n build TARGET=all (all-platforms branch resolves dry)"; else fail "make -n build TARGET=all"; fi
if make -n install TARGET=all >/dev/null 2>&1; then pass "make -n install TARGET=all (all-devices branch resolves dry)"; else fail "make -n install TARGET=all"; fi
if make -n dev TARGET=ios >/dev/null 2>&1; then pass "make -n dev TARGET=ios (physical-iPhone flutter run branch resolves dry)"; else fail "make -n dev TARGET=ios"; fi
if make -n signing-restore >/dev/null 2>&1; then pass "make -n signing-restore (pbxproj placeholder restore resolves dry)"; else fail "make -n signing-restore"; fi
if make -n help >/dev/null 2>&1; then pass "make -n help (target cheatsheet resolves dry)"; else fail "make -n help"; fi
if make -n build-install TARGET=all >/dev/null 2>&1; then pass "make -n build-install TARGET=all (build+install sweep resolves dry)"; else fail "make -n build-install TARGET=all"; fi
if make -n uninstall TARGET=simulator >/dev/null 2>&1; then pass "make -n uninstall TARGET=simulator (simctl branch resolves dry)"; else fail "make -n uninstall TARGET=simulator"; fi

# ── 1b. TRACK vocabulary contract (`build ENV=staging|prod` + `deploy`) ─────────────
# Store-native, per-TARGET vocabularies; comma lists allowed; no TRACK=all.
echo ""
echo "━━━ 1b. TRACK contract ━━━"
check_track() { # label TARGET TRACK expect-zero?
  local st; make -s track-guard TARGET="$2" TRACK="$3" >/dev/null 2>&1; st=$?
  if { [ "$4" = 0 ] && [ "$st" = 0 ]; } || { [ "$4" != 0 ] && [ "$st" != 0 ]; }; then
    pass "TRACK: $1"
  else
    fail "TRACK: $1 (expected exit-nonzero=$4, got $st)"
  fi
}
check_track "ios accepts prod"                ios     prod           0
check_track "ios accepts internal,external"   ios     internal,external 0
check_track "ios rejects alpha"               ios     alpha          1
check_track "android accepts production"      android production     0
check_track "android accepts internal,beta"   android internal,beta  0
check_track "android rejects external"        android external       1
check_track "TARGET=all accepts the union"    all     internal,prod  0
check_track "TARGET=all rejects TRACK=all"    all     all            1
if make -s deploy TARGET=ios >/dev/null 2>&1; then
  fail "deploy without TRACK must fail"
else
  pass "deploy without TRACK fails (TRACK required)"
fi
if grep -qE '^deploy:' "$MAKEFILE" && grep -qE '^publish:' "$MAKEFILE"; then
  pass "deploy + publish targets present"
else
  fail "deploy/publish targets missing"
fi

# ── 1c. ENV drives every run/build/install verb ──────────────────────────────
# ENV=testing-local|testing|staging|prod must resolve for dev/build/install, reach the
# nested $(MAKE) sweeps, and pull the vault dart-defines for staging/prod.
# ENV is required; prod is not gated by a separate confirmation.
echo ""
echo "━━━ 1c. ENV honored by dev/build/install ━━━"
env_resolves() { # label  args...
  local label="$1"; shift
  if make -n "$@" >/dev/null 2>&1; then pass "ENV: $label"; else fail "ENV: $label (make -n $* did not resolve)"; fi
}
env_resolves "dev simulator ENV=testing"       dev     TARGET=simulator ENV=testing
env_resolves "dev simulator ENV=testing-local" dev     TARGET=simulator ENV=testing-local
env_resolves "dev simulator ENV=staging"       dev     TARGET=simulator ENV=staging
env_resolves "dev simulator ENV=prod"           dev     TARGET=simulator ENV=prod
env_resolves "build simulator ENV=staging"     build   TARGET=simulator ENV=staging
env_resolves "build android ENV=staging"       build   TARGET=android   ENV=staging
env_resolves "build android ENV=prod"           build   TARGET=android   ENV=prod
env_resolves "install simulator ENV=staging"   install TARGET=simulator ENV=staging
env_resolves "build-install simulator testing" build-install TARGET=simulator ENV=testing

# Nested $(MAKE) invocations must carry ENV (TARGET=all sweeps).
# (Capture first: `set -o pipefail` + `grep -q` can SIGPIPE the producer.)
for pair in "build TARGET=all ENV=staging" "install TARGET=all ENV=staging"; do
  OUT="$(make -n $pair 2>/dev/null || true)"
  if grep -qE 'TARGET=\$t ENV="staging"' <<<"$OUT"; then
    pass "nested ENV propagation: make -n $pair"
  else
    fail "nested ENV propagation missing: make -n $pair"
  fi
done
OUT="$(make -n build TARGET=simulator ENV=staging 2>/dev/null || true)"
if grep -q -- '--dart-define-from-file=' <<<"$OUT"; then
  pass "staging simulator build pulls the vault dart-defines file"
else
  fail "staging simulator build does not reference the vault dart-defines file"
fi
OUT="$(make -s env ENV=staging 2>/dev/null || true)"
if grep -q 'ENV=staging' <<<"$OUT"; then
  pass "env verb reports ENV=staging"
else
  fail "env verb does not report ENV"
fi

# guard-env: ENV is required and must be one of the four values.
if make -s guard-env ENV= >/dev/null 2>&1; then
  fail "guard-env accepted an unset ENV"
else
  pass "guard-env rejects an unset ENV"
fi
for e in testing-local testing staging prod; do
  if make -s guard-env ENV="$e" >/dev/null 2>&1; then
    pass "guard-env accepts ENV=$e"
  else
    fail "guard-env rejected ENV=$e"
  fi
done
if make -s guard-env ENV=local >/dev/null 2>&1; then
  fail "guard-env accepted the removed ENV=local"
else
  pass "guard-env rejects the removed ENV=local"
fi
if make -s guard-release ENV=testing >/dev/null 2>&1; then
  fail "guard-release accepted ENV=testing"
else
  pass "guard-release rejects ENV=testing"
fi

# ── 2. Fastlane upload-lane contract (vault-built artifacts; no match) ───────
echo ""
echo "━━━ 2. Fastlane upload-lane contract ━━━"
# `publish` maps each ios track to its upload lane and android to track_play —
# all upload lanes consume the vault-built artifact (no rebuild, no match).
for pair in internal:track_internal external:track_external prod:track_prod; do
  tk="${pair%%:*}"; ln="${pair##*:}"
  if grep -qE "lane=$ln" "$MAKEFILE"; then
    pass "publish: ios $tk → $ln"
  else
    fail "publish: ios $tk does not map to $ln"
  fi
done
if grep -q 'fastlane android track_play' "$MAKEFILE"; then
  pass "publish: android → track_play"
else
  fail "publish does not invoke fastlane android track_play"
fi

# Conditional LIVE stub probe: while fastlane/Fastfile is absent the stub must
# fail fast with a clear message (make reports a failing recipe as exit 2 — the
# recipe itself exits 1; assert message + non-zero status). Auto-skips once the
# Fastfile lands.
if [ ! -f "$REPO/fastlane/Fastfile" ]; then
  OUT="$(make bundle-install 2>&1)"; ST=$?
  if [ "$ST" -ne 0 ] && printf '%s' "$OUT" | grep -q "Gemfile"; then
    pass "LIVE probe: make bundle-install fails fast with the Gemfile message (exit $ST)"
  else
    fail "LIVE probe: make bundle-install did not fail with the Gemfile message (exit $ST)"
  fi
else
  echo "  ⏭  fastlane/Fastfile present — stub fail-fast probes skipped (M-17 landed)"
fi

# ── 2b. M-17/M-18 fastlane scaffold (iOS + Android, §3.3) ───────────────────
# Fastfile must define BOTH §3.3 iOS lanes under platform :ios AND BOTH §3.3
# Android lanes under platform :android, Appfile must carry the
# app_identifier + team_id placeholders, Gemfile must declare fastlane +
# cocoapods (MKE-10), and fastlane/ + android/ must contain NO real credential
# shapes (private-key material — which is what .p8 and Google service-account
# JSON content look like — no .jks keystores, no Apple app-specific
# passwords), and the §3.3 path-only files must NOT exist (ASC .p8, Google
# Play service-account JSON). android/app/keystores/ must be ABSENT (the
# keystore is generated + kept in a secret store at release time, never in
# the repo). The fail-fast guard message pins the "credentials not configured
# (placeholders)" contract.
echo ""
echo "━━━ 2b. M-17 fastlane iOS scaffold ━━━"
FL="$REPO/fastlane/Fastfile"
AF="$REPO/fastlane/Appfile"
GF="$REPO/Gemfile"

if [ -f "$FL" ]; then
  grep -q 'platform :ios' "$FL" && pass "Fastfile declares platform :ios" || fail "Fastfile missing 'platform :ios'"
  for LANE in adhoc_local track_internal track_external track_prod; do
    if grep -q "lane :$LANE" "$FL"; then
      pass "Fastfile defines lane :$LANE"
    else
      fail "Fastfile missing lane :$LANE"
    fi
  done
  if grep -q 'match(' "$FL"; then
    fail "Fastfile still references fastlane match (must be vault-only signing)"
  else
    pass "Fastfile has no match (vault-only signalling)"
  fi
  grep -q 'credentials not configured' "$FL" && pass "lanes fail fast on placeholder credentials" || fail "Fastfile missing the fail-fast placeholder guard"
else
  fail "fastlane/Fastfile missing — M-17 must create it (§3.3 contract)"
fi

# Android half (M-18): platform :android + the upload lane; the same guard message.
if [ -f "$FL" ]; then
  grep -q 'platform :android' "$FL" && pass "Fastfile declares platform :android" || fail "Fastfile missing 'platform :android'"
  for LANE in track_play; do
    if grep -q "lane :$LANE" "$FL"; then
      pass "Fastfile defines lane :$LANE"
    else
      fail "Fastfile missing lane :$LANE (§3.3 contract)"
    fi
  done
  grep -q 'fastlane/keys/google-play-service-account.json' "$FL" && pass "PLAY_SERVICE_ACCOUNT_JSON placeholder pinned" || fail "PLAY_SERVICE_ACCOUNT_JSON placeholder missing"
fi

if [ -f "$AF" ]; then
  grep -q 'com.qallariy.samay' "$AF" && pass "Appfile app_identifier = com.qallariy.samay (pbxproj-verified)" || fail "Appfile missing app_identifier"
  grep -q 'XXXXXXXXXX' "$AF" && pass "Appfile team_id placeholder (XXXXXXXXXX)" || fail "Appfile missing the TEAM_ID placeholder"
else
  fail "fastlane/Appfile missing — M-17 must create it"
fi

if [ -f "$GF" ]; then
  grep -q 'gem "fastlane"' "$GF" && pass "Gemfile declares fastlane" || fail "Gemfile missing 'gem \"fastlane\"'"
  grep -q 'gem "cocoapods"' "$GF" && pass "Gemfile declares cocoapods" || fail "Gemfile missing 'gem \"cocoapods\"' (MKE-10)"
else
  fail "Gemfile missing — M-17 must create it (MKE-10)"
fi

if [ -d "$REPO/fastlane" ]; then
  if grep -rqE -- '-----BEGIN|BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY' "$REPO/fastlane"; then
    fail "fastlane/ contains private-key material (-----BEGIN … PRIVATE KEY)"
  else
    pass "fastlane/ contains no private-key material"
  fi
  if grep -rqE '[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}' "$REPO/fastlane"; then
    fail "fastlane/ contains an app-specific-password shape (xxxx-xxxx-xxxx-xxxx)"
  else
    pass "fastlane/ contains no app-specific-password shape"
  fi
  if [ -f "$REPO/fastlane/keys/AppStoreConnect_AAAAAAAAAA.p8" ]; then
    fail "fastlane/keys/AppStoreConnect_AAAAAAAAAA.p8 must NOT exist (§3.3 — path only)"
  else
    pass "fastlane/keys/AppStoreConnect_AAAAAAAAAA.p8 absent (path only, per §3.3)"
  fi
  if [ -f "$REPO/fastlane/keys/google-play-service-account.json" ]; then
    fail "fastlane/keys/google-play-service-account.json must NOT exist (§3.3 — path only)"
  else
    pass "fastlane/keys/google-play-service-account.json absent (path only, per §3.3)"
  fi
  grep -q 'AAAAAAAAAA' "$FL" && pass "ASC key-id placeholder (AAAAAAAAAA) present" || fail "ASC key-id placeholder missing"
fi

# No .jks keystores or private-key material anywhere in android/ (M-18
# contract — the §3.3 keystore is path-only; M-27 wires the gradle
# signingConfigs to the env, the .jks itself lives in a secret store).
if find "$REPO/fastlane" "$REPO/android" -name '*.jks' -o -name '*.p8' 2>/dev/null | grep -q .; then
  fail "a .jks/.p8 file exists in fastlane/ or android/ (never create one)"
else
  pass "no .jks/.p8 files in fastlane/ or android/"
fi
if [ -d "$REPO/android" ]; then
  if grep -rqE -- '-----BEGIN|BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY' "$REPO/android"; then
    fail "android/ contains private-key material (-----BEGIN … PRIVATE KEY)"
  else
    pass "android/ contains no private-key material"
  fi
fi
if [ -d "$REPO/android/app/keystores" ]; then
  fail "android/app/keystores/ must NOT exist (§3.3 — path only; keystore generated at release time)"
else
  pass "android/app/keystores/ absent (path only, per §3.3)"
fi


# ── 5. Self syntax ───────────────────────────────────────────────────────────
echo ""
echo "━━━ 5. Self syntax ━━━"
if bash -n "$0" 2>/dev/null; then pass "bash -n $0"; else fail "bash -n $0"; fi

# ── 6. Android platform contract (M-27) ──────────────────────────────────────
# The gradle wrapper is committed for deterministic CI (M-21 handoff): the
# three wrapper files must exist and must NOT be gitignored — flutter_tools
# auto-injects a missing wrapper, but the committed one removes that runtime
# dependency. git ls-files asserts tracked status; BEFORE the orchestrator's
# checkpoint commit the files are legitimately untracked-but-commit-pending,
# which the git check-ignore probe accepts (a gitignored wrapper would never
# ship — that is the real regression this catches).
echo ""
echo "━━━ 6. Android platform contract (M-27) ━━━"
WRAPPER_FILES="gradlew gradlew.bat gradle/wrapper/gradle-wrapper.jar"
for wf in $WRAPPER_FILES; do
  W="$REPO/android/$wf"
  if [ -f "$W" ]; then
    pass "android/$wf exists"
  else
    fail "android/$wf missing — the gradle wrapper must be committed (M-21/M-27)"
    continue
  fi
  if git -C "$REPO" ls-files --error-unmatch -- "android/$wf" >/dev/null 2>&1; then
    pass "android/$wf tracked by git"
  elif git -C "$REPO" check-ignore -q -- "$W"; then
    fail "android/$wf is GITIGNORED — it can never be committed (CI would depend on flutter_tools auto-injection)"
  else
    pass "android/$wf untracked but commit-pending (orchestrator checkpoint will commit it)"
  fi
done

# gradle-wrapper.properties: distribution pinned, version + variant documented.
WP="$REPO/android/gradle/wrapper/gradle-wrapper.properties"
if [ -f "$WP" ]; then
  if grep -Fq 'distributionUrl=https\://services.gradle.org/distributions/gradle-9.4.1-all.zip' "$WP"; then
    pass "wrapper pins gradle-9.4.1-all.zip (verified against Flutter 3.44.1 by a real build)"
  else
    fail "wrapper distributionUrl is not the pinned gradle-9.4.1-all.zip — update opt-008 in lockstep"
  fi
else
  fail "gradle-wrapper.properties missing"
fi

# Manifest: E2EE backup policy + predictive back + the I-28 permission set.
MF="$REPO/android/app/src/main/AndroidManifest.xml"
if [ -f "$MF" ]; then
  grep -q 'android:allowBackup="false"' "$MF" && pass "manifest allowBackup=false (E2EE R12)" || fail "manifest missing android:allowBackup=\"false\""
  grep -q 'android:enableOnBackInvokedCallback="true"' "$MF" && pass "manifest predictive back enabled (targetSdk 33+)" || fail "manifest missing android:enableOnBackInvokedCallback=\"true\""
  grep -q 'android.permission.CAMERA' "$MF" && pass "manifest CAMERA permission (I-28)" || fail "manifest missing CAMERA (I-28)"
  grep -q 'android.permission.READ_MEDIA_IMAGES' "$MF" && fail "manifest must NOT declare READ_MEDIA_IMAGES (Play Photo & Video policy — gallery uses the Android Photo Picker)" || pass "manifest has no READ_MEDIA_IMAGES (photo picker, policy-compliant)"
  grep -q 'android.permission.READ_EXTERNAL_STORAGE' "$MF" && fail "manifest must NOT declare READ_EXTERNAL_STORAGE (photo picker needs no media permission)" || pass "manifest has no READ_EXTERNAL_STORAGE"
  grep -q 'android:usesCleartextTraffic="true"' "$MF" && fail "manifest re-enables global cleartext (SEC 2026-10-04 — use networkSecurityConfig)" || pass "no global usesCleartextTraffic flag"
  grep -q 'android:networkSecurityConfig="@xml/network_security_config"' "$MF" && pass "manifest wires networkSecurityConfig" || fail "manifest missing android:networkSecurityConfig"
else
  fail "android manifest missing"
fi

# SEC (2026-10-04): release denies cleartext, debug permits it.
NSC="$REPO/android/app/src/main/res/xml/network_security_config.xml"
NSC_DBG="$REPO/android/app/src/debug/res/xml/network_security_config.xml"
if [ -f "$NSC" ] && grep -q 'cleartextTrafficPermitted="false"' "$NSC"; then
  pass "release network security config denies cleartext"
else
  fail "main network_security_config.xml missing or does not deny cleartext"
fi
if [ -f "$NSC_DBG" ] && grep -q 'cleartextTrafficPermitted="true"' "$NSC_DBG"; then
  pass "debug network security config permits cleartext (dev only)"
else
  fail "debug network_security_config.xml missing or does not permit cleartext"
fi

# Signing contract: §3.3 keystore envs wired, debug-signing of release gone,
# fail-fast guard present (grep-level; behavior verified by a real build).
BG="$REPO/android/app/build.gradle.kts"
if [ -f "$BG" ]; then
  for ENVNAME in ANDROID_KEYSTORE_PATH ANDROID_KEYSTORE_ALIAS ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS_PASSWORD; do
    grep -q "$ENVNAME" "$BG" && pass "build.gradle.kts reads $ENVNAME (§3.3)" || fail "build.gradle.kts missing $ENVNAME"
  done
  grep -q 'signingConfigs.getByName("debug")' "$BG" && fail "build.gradle.kts still debug-signs release (M-27 must remove it)" || pass "release buildType never signs with the debug key"
  grep -q 'Release builds NEVER fall back to the debug key' "$BG" && pass "fail-fast signing guard present" || fail "build.gradle.kts missing the fail-fast signing guard"
else
  fail "android/app/build.gradle.kts missing"
fi

# No keystore material is ever tracked (the .jks stays in a secret store).
JKS="$(git -C "$REPO" ls-files | grep -E '\.(jks|keystore)$' || true)"
if [ -n "$JKS" ]; then
  fail "tracked keystore file(s): $JKS — never commit a .jks (§3.3)"
else
  pass "no .jks/.keystore tracked by git"
fi

# ── 7. iOS platform contract (M-28) ─────────────────────────────────────────
# Privacy descriptions, min-iOS 16 parity (pbxproj + Podfile), I-28
# permission_handler macros, placeholder-only signing (never a real team id),
# and the purchases_flutter→PurchasesHybridCommon→RevenueCat resolution
# (the I-71 conflict fix — the stale lock's 14.3.0 pin must never return;
# iOS is SPM-managed, macOS pod-managed).
echo ""
echo "━━━ 7. iOS platform contract (M-28) ━━━"
INFOPLIST="$REPO/ios/Runner/Info.plist"
if [ -f "$INFOPLIST" ]; then
  for KEY in NSCameraUsageDescription NSPhotoLibraryUsageDescription; do
    grep -q "<key>$KEY</key>" "$INFOPLIST" && pass "Info.plist declares $KEY (I-28/M-28)" || fail "Info.plist missing $KEY"
  done
  # SEC-054: unused Always-location and photo-add purpose strings must stay
  # removed (the app only requests when-in-use location and the Photo Picker).
  for KEY in NSLocationAlwaysAndWhenInUseUsageDescription NSPhotoLibraryAddUsageDescription; do
    grep -q "<key>$KEY</key>" "$INFOPLIST" && fail "Info.plist still declares unused $KEY (SEC-054)" || pass "Info.plist no unused $KEY (SEC-054)"
  done
else
  fail "ios/Runner/Info.plist missing"
fi

# Min-iOS 16 parity: pbxproj (all 3 Runner configs) + Podfile platform line.
PBX="$REPO/ios/Runner.xcodeproj/project.pbxproj"
if [ -f "$PBX" ]; then
  COUNT=$(grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 16.0' "$PBX")
  if [ "$COUNT" -eq 3 ]; then
    pass "pbxproj IPHONEOS_DEPLOYMENT_TARGET = 16.0 ×3 (MVP iOS 16+ spec)"
  else
    fail "pbxproj IPHONEOS_DEPLOYMENT_TARGET = 16.0 expected ×3, found $COUNT"
  fi
  grep -q 'IPHONEOS_DEPLOYMENT_TARGET = 15.5' "$PBX" && fail "pbxproj still has the old 15.5 deployment target" || pass "pbxproj has no 15.5 deployment target"
else
  fail "ios/Runner.xcodeproj/project.pbxproj missing"
fi

PF="$REPO/ios/Podfile"
if [ -f "$PF" ]; then
  grep -q "platform :ios, '16.0'" "$PF" && pass "Podfile platform :ios '16.0' (matches pbxproj)" || fail "Podfile platform is not '16.0'"
  grep -q 'PERMISSION_CAMERA=1' "$PF" && pass "Podfile PERMISSION_CAMERA=1 (I-28)" || fail "Podfile missing PERMISSION_CAMERA=1"
  grep -q 'PERMISSION_PHOTOS=1' "$PF" && pass "Podfile PERMISSION_PHOTOS=1 (I-28)" || fail "Podfile missing PERMISSION_PHOTOS=1"
else
  fail "ios/Podfile missing"
fi

# Signing: placeholder team + Manual style on the Runner target; the bundle id
# must match fastlane/Appfile. RunnerTests (test bundle) may stay Automatic.
if [ -f "$PBX" ]; then
  grep -q 'CODE_SIGN_STYLE = Manual' "$PBX" && pass "pbxproj CODE_SIGN_STYLE = Manual (vault-cert manual signing)" || fail "pbxproj CODE_SIGN_STYLE = Manual missing"
  grep -q 'DEVELOPMENT_TEAM = XXXXXXXXXX' "$PBX" && pass "pbxproj DEVELOPMENT_TEAM = XXXXXXXXXX (§3.3 placeholder)" || fail "pbxproj DEVELOPMENT_TEAM is not the placeholder"
  grep -q 'PROVISIONING_PROFILE_SPECIFIER = ""' "$PBX" && pass "pbxproj PROVISIONING_PROFILE_SPECIFIER empty" || fail "pbxproj PROVISIONING_PROFILE_SPECIFIER not empty"
  grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.qallariy.samay;' "$PBX" && pass "pbxproj bundle id com.qallariy.samay (Appfile-verified)" || fail "pbxproj bundle id mismatch"
fi

# The I-71 conflict chain (PurchasesHybridCommon 14.3.0 → pod install broke
# with "run pod update PurchasesHybridCommon") is now resolved at TWO levels:
# the iOS Podfile.lock must NOT drag the RevenueCat chain back into pods
# (Flutter SPM consumes purchases_flutter 10.8.0 → PurchasesHybridCommon
# 18.29.0 → RevenueCat 5.83.0 via Package.resolved — see the SPM check
# below), and the macos Podfile.lock still pins the pod chain directly.
PLOCK="$REPO/ios/Podfile.lock"
if [ -f "$PLOCK" ]; then
  grep -q 'purchases_flutter (10.8.0)' "$PLOCK" && fail "ios Podfile.lock must NOT list purchases_flutter (SPM-managed since Flutter 3.44 SPM migration)" || pass "ios Podfile.lock keeps the RevenueCat chain SPM-managed"
  grep -q 'PurchasesHybridCommon (18.29.0)' "$PLOCK" && fail "ios Podfile.lock must NOT list PurchasesHybridCommon (SPM-managed)" || pass "ios Podfile.lock keeps PurchasesHybridCommon SPM-managed"
  grep -q 'RevenueCat (5.83.0)' "$PLOCK" && fail "ios Podfile.lock must NOT list RevenueCat (SPM-managed)" || pass "ios Podfile.lock keeps RevenueCat SPM-managed"
else
  fail "ios/Podfile.lock missing"
fi
# SPM resolution pins the same I-71 chain versions (Flutter 3.44 SwiftPM).
PACKAGE_RESOLVED="$REPO/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ -f "$PACKAGE_RESOLVED" ]; then
  grep -q '"version" : "18.29.0"' "$PACKAGE_RESOLVED" && pass "SPM Package.resolved PurchasesHybridCommon 18.29.0 (I-71 conflict resolved)" || fail "SPM Package.resolved does not pin PurchasesHybridCommon 18.29.0"
  grep -q '"version" : "5.83.0"' "$PACKAGE_RESOLVED" && pass "SPM Package.resolved RevenueCat 5.83.0" || fail "SPM Package.resolved does not pin RevenueCat 5.83.0"
else
  fail "ios Package.resolved missing (SPM integration absent)"
fi

# No real team ids / certs / provisioning-material shapes tracked by git
# (the XXXXXXXXXX placeholder is the ONLY allowed team shape).
REAL_TEAM="$(git -C "$REPO" ls-files ios/ | xargs grep -hEo 'DEVELOPMENT_TEAM = [A-Z0-9]{10}' 2>/dev/null | grep -v '^DEVELOPMENT_TEAM = XXXXXXXXXX' || true)"
if [ -n "$REAL_TEAM" ]; then
  fail "a real 10-char DEVELOPMENT_TEAM is tracked: $REAL_TEAM"
else
  pass "no real DEVELOPMENT_TEAM tracked (placeholder only)"
fi
if git -C "$REPO" ls-files ios/ | grep -qE '\.(mobileprovision|p12|cer|p8)$'; then
  fail "certificate/provisioning material is tracked under ios/"
else
  pass "no .mobileprovision/.p12/.cer/.p8 tracked under ios/"
fi

# ── 8. Non-product platform contract (M-29) ──────────────────────────────────
# web/macos/linux/windows are Flutter-scaffold dirs kept for tooling (removing
# them breaks `flutter create .`-style workflows) — the app ships iOS+Android
# only (product scope: iOS+Android). This section pins their product naming +
# hygiene so the dirs stay consistent and documented without ever becoming
# products.
echo ""
echo "━━━ 8. Non-product platform contract (M-29) ━━━"

# 8a. web/ placeholder polish: title + description + apple meta + black theme.
IDX="$REPO/web/index.html"
if [ -f "$IDX" ]; then
  grep -q '<title>Samay</title>' "$IDX" && pass "web title = Samay" || fail "web/index.html <title> is not 'Samay'"
  grep -q 'name="description" content="Samay — Social event planning app"' "$IDX" && pass "web description = Samay tagline" || fail "web/index.html description is not the Samay tagline"
  grep -q 'content="A new Flutter project."' "$IDX" && fail "web/index.html still has the Flutter-template description" || pass "web/index.html has no Flutter-template description"
  grep -q '<meta name="theme-color" content="#000000">' "$IDX" && pass "web theme-color = #000000" || fail "web/index.html missing theme-color #000000"
  grep -q '<meta name="apple-mobile-web-app-capable" content="yes">' "$IDX" && pass "web apple-mobile-web-app-capable present" || fail "web/index.html missing apple-mobile-web-app-capable"
  grep -q 'content="Samay"' "$IDX" && pass "web apple-mobile-web-app-title = Samay" || fail "web/index.html apple-mobile-web-app-title is not 'Samay'"
  grep -q 'content="#0175C2"' "$IDX" && fail "web/index.html still has the template #0175C2 blue" || pass "web/index.html has no template #0175C2 blue"
else
  fail "web/index.html missing"
fi

MFN="$REPO/web/manifest.json"
if [ -f "$MFN" ]; then
  grep -q '"name": "Samay"' "$MFN" && pass "manifest name = Samay" || fail "manifest.json name is not 'Samay'"
  grep -q '"short_name": "Samay"' "$MFN" && pass "manifest short_name = Samay" || fail "manifest.json short_name is not 'Samay'"
  grep -q '"theme_color": "#000000"' "$MFN" && pass "manifest theme_color = #000000" || fail "manifest.json theme_color is not #000000"
  grep -q '"background_color": "#000000"' "$MFN" && pass "manifest background_color = #000000" || fail "manifest.json background_color is not #000000"
  grep -q '"description": "Samay — Social event planning app"' "$MFN" && pass "manifest description = Samay tagline" || fail "manifest.json description is not the Samay tagline"
  grep -q '#0175C2' "$MFN" && fail "manifest.json still has the template #0175C2 blue" || pass "manifest.json has no template #0175C2 blue"
  if python3 -c "import json,sys; json.load(open('$MFN'))" 2>/dev/null; then
    pass "manifest.json parses as JSON"
  else
    fail "manifest.json is not valid JSON"
  fi
else
  fail "web/manifest.json missing"
fi

# 8b. macos/ product naming: bundle name = pubspec name, display name = Samay.
AIC="$REPO/macos/Runner/Configs/AppInfo.xcconfig"
if [ -f "$AIC" ]; then
  grep -q '^PRODUCT_NAME = samay$' "$AIC" && pass "macos PRODUCT_NAME = samay (== pubspec name)" || fail "macos AppInfo.xcconfig PRODUCT_NAME is not 'samay'"
  grep -q '^PRODUCT_BUNDLE_IDENTIFIER = com.qallariy.samay$' "$AIC" && pass "macos bundle id = com.qallariy.samay" || fail "macos AppInfo.xcconfig bundle id mismatch"
else
  fail "macos/Runner/Configs/AppInfo.xcconfig missing"
fi

MPL="$REPO/macos/Runner/Info.plist"
if [ -f "$MPL" ]; then
  grep -q '<key>CFBundleDisplayName</key>' "$MPL" && grep -A1 '<key>CFBundleDisplayName</key>' "$MPL" | grep -q '<string>Samay</string>' && pass "macos CFBundleDisplayName = Samay" || fail "macos Info.plist CFBundleDisplayName is not 'Samay'"
else
  fail "macos/Runner/Info.plist missing"
fi

# The pre-campaign 'samay_app' rename artifact must be fully gone from the
# tracked macos/ tree (pbxproj TEST_HOST ×3 + product reference, xcscheme
# BuildableName ×5, AppInfo.xcconfig).
STALE="$(git -C "$REPO" ls-files macos/ | xargs grep -l 'samay_app' 2>/dev/null || true)"
if [ -n "$STALE" ]; then
  fail "stale 'samay_app' literal(s) remain in tracked macos/ files: $STALE"
else
  pass "no 'samay_app' literal remains in tracked macos/ files"
fi
if [ -f "$REPO/macos/Runner.xcodeproj/project.pbxproj" ]; then
  COUNT=$(grep -c 'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/samay.app' "$REPO/macos/Runner.xcodeproj/project.pbxproj")
  if [ "$COUNT" -eq 3 ]; then
    pass "macos RunnerTests TEST_HOST → samay.app ×3 (matches PRODUCT_NAME)"
  else
    fail "macos pbxproj TEST_HOST expects samay.app ×3, found $COUNT"
  fi
fi

# 8c. The I-01/I-19-era SPM/CocoaPods state: generated plugin registrant +
# Podfile.lock are committed deliberately; ephemeral/ + Pods/ are generated
# and MUST stay untracked.
GPR="$REPO/macos/Flutter/GeneratedPluginRegistrant.swift"
if [ -f "$GPR" ] && git -C "$REPO" ls-files --error-unmatch -- "macos/Flutter/GeneratedPluginRegistrant.swift" >/dev/null 2>&1; then
  pass "macos GeneratedPluginRegistrant.swift committed (deliberate)"
else
  fail "macos/Flutter/GeneratedPluginRegistrant.swift missing or untracked"
fi
MPL_LCK="$REPO/macos/Podfile.lock"
if [ -f "$MPL_LCK" ] && git -C "$REPO" ls-files --error-unmatch -- "macos/Podfile.lock" >/dev/null 2>&1; then
  pass "macos/Podfile.lock committed"
  grep -q 'purchases_flutter (10.8.0)' "$MPL_LCK" && fail "macos Podfile.lock must NOT list purchases_flutter (SPM-managed since Flutter 3.44)" || pass "macos Podfile.lock keeps the RevenueCat chain SPM-managed"
  grep -q 'PurchasesHybridCommon (18.29.0)' "$MPL_LCK" && fail "macos Podfile.lock must NOT list PurchasesHybridCommon (SPM-managed)" || pass "macos Podfile.lock keeps PurchasesHybridCommon SPM-managed"
else
  fail "macos/Podfile.lock missing or untracked"
fi
# macOS SPM resolution pins the same I-71 chain versions (Flutter 3.44
# SwiftPM). Presence-based (like the iOS Package.resolved check) — the
# file lands in git with the migration to SPM.
MPACKAGE_RESOLVED="$REPO/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ -f "$MPACKAGE_RESOLVED" ]; then
  grep -q '"version" : "18.29.0"' "$MPACKAGE_RESOLVED" && pass "macos SPM Package.resolved PurchasesHybridCommon 18.29.0 (I-71 conflict resolved)" || fail "macos SPM Package.resolved does not pin PurchasesHybridCommon 18.29.0"
  grep -q '"version" : "5.83.0"' "$MPACKAGE_RESOLVED" && pass "macos SPM Package.resolved RevenueCat 5.83.0" || fail "macos SPM Package.resolved does not pin RevenueCat 5.83.0"
else
  fail "macos Package.resolved missing (SPM integration absent)"
fi

# 8d. No build outputs may EVER be tracked in any platform dir (git ls-files
# scan for generated/gitignore-class files — the template .gitignore rules
# keep them out; this pins that contract).
BUILD_PAT='/(Pods|ephemeral|\.symlinks|DerivedData|xcuserdata|build)/|\.app/$|/build/|(^|/)(\.dSYM|Runner\.app|flutter_assets)(/|$)|\.(o|dylib|a)$'
STRAYS="$(git -C "$REPO" ls-files macos/ linux/ windows/ web/ | grep -E "$BUILD_PAT" || true)"
if [ -n "$STRAYS" ]; then
  fail "build artifacts tracked in platform dirs: $STRAYS"
else
  pass "no build artifacts tracked in macos/ linux/ windows/ web/"
fi

# 8e. linux/ + windows/ window titles read Samay; binary names stay samay_app
# (build-level identity — changing them breaks the desktop build systems).
LCC="$REPO/linux/runner/my_application.cc"
if [ -f "$LCC" ]; then
  grep -q 'gtk_header_bar_set_title(header_bar, "Samay")' "$LCC" && pass "linux header-bar title = Samay" || fail "linux my_application.cc header-bar title is not 'Samay'"
  grep -q 'gtk_window_set_title(window, "Samay")' "$LCC" && pass "linux window title = Samay" || fail "linux my_application.cc window title is not 'Samay'"
else
  fail "linux/runner/my_application.cc missing"
fi
WCP="$REPO/windows/runner/main.cpp"
if [ -f "$WCP" ]; then
  grep -q 'window.Create(L"Samay"' "$WCP" && pass "windows window title = Samay" || fail "windows main.cpp window title is not 'Samay'"
else
  fail "windows/runner/main.cpp missing"
fi
WRC="$REPO/windows/runner/Runner.rc"
if [ -f "$WRC" ]; then
  grep -q 'VALUE "FileDescription", "Samay"' "$WRC" && pass "windows FileDescription = Samay" || fail "windows Runner.rc FileDescription is not 'Samay'"
  grep -q 'VALUE "ProductName", "Samay"' "$WRC" && pass "windows ProductName = Samay" || fail "windows Runner.rc ProductName is not 'Samay'"
  grep -q 'VALUE "OriginalFilename", "samay_app.exe"' "$WRC" && pass "windows OriginalFilename stays samay_app.exe (binary identity)" || fail "windows Runner.rc OriginalFilename drifted from samay_app.exe"
else
  fail "windows/runner/Runner.rc missing"
fi
grep -q 'set(BINARY_NAME "samay_app")' "$REPO/linux/CMakeLists.txt" && pass "linux BINARY_NAME stays samay_app (build-level, documented)" || fail "linux BINARY_NAME drifted"
grep -q 'set(BINARY_NAME "samay_app")' "$REPO/windows/CMakeLists.txt" && pass "windows BINARY_NAME stays samay_app (build-level, documented)" || fail "windows BINARY_NAME drifted"

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo "  ❌ $FAILURES makefile-static check(s) failed."
  exit 1
fi
echo "  ✅ all makefile-static checks passed."
exit 0
