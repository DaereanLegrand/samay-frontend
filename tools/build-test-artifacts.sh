#!/usr/bin/env bash
# Build test APK + ad-hoc IPA for one disposable backend stack.
# Usage: tools/build-test-artifacts.sh <stack-env> <out-dir> [lane]
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <stack-env> <out-dir> [lane]" >&2
  exit 2
fi

STACK_ENV="$1"
OUT_DIR="$2"
LANE="${3:-lane}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

[ -r "$STACK_ENV" ] || { echo "missing stack env: $STACK_ENV" >&2; exit 1; }

read_env() {
  local key="$1"
  sed -n "s/^${key}=\([^[:space:]#]*\).*/\1/p" "$STACK_ENV" | head -1
}

KONG_PORT="$(read_env KONG_HTTP_PORT)"
KONG_PORT="${KONG_PORT:-54386}"
JWT_SECRET="$(read_env JWT_SECRET)"
[ -n "$JWT_SECRET" ] || { echo "JWT_SECRET missing from $STACK_ENV" >&2; exit 1; }
ANON_KEY="$(JWT_SECRET="$JWT_SECRET" python3 tools/gen_testing_anon_key.py)"
HOST="${LOCAL_KONG_HOST:-127.0.0.1}"
TEAM="${IOS_DEVELOPMENT_TEAM:-$(sed -n 's/^IOS_DEVELOPMENT_TEAM=//p' .env.local 2>/dev/null | head -1)}"

mkdir -p "$OUT_DIR/$LANE"
rm -rf build/ios/ipa build/ios/archive

make build ENV=testing-local TARGET=android \
  LOCAL_JWT_ENV="$STACK_ENV" \
  LOCAL_KONG_PORT="$KONG_PORT"

# The installed ad-hoc profile carries Push but not Sign in with Apple. For a
# disposable test build we drop only the Apple Sign In entitlement; production
# builds keep it. Restore the tracked file on every exit path.
ENTITLEMENTS="ios/Runner/Runner.entitlements"
ENTITLEMENTS_BACKUP="$(mktemp)"
cp "$ENTITLEMENTS" "$ENTITLEMENTS_BACKUP"
restore_entitlements() {
  cp "$ENTITLEMENTS_BACKUP" "$ENTITLEMENTS"
  rm -f "$ENTITLEMENTS_BACKUP"
}
trap restore_entitlements EXIT INT TERM HUP
cat > "$ENTITLEMENTS" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>production</string>
</dict>
</plist>
EOF

IPA="build/ios/ipa/samay_app-adhoc.ipa"
make build ENV=testing-local TARGET=ios-adhoc \
  LOCAL_JWT_ENV="$STACK_ENV" \
  LOCAL_KONG_PORT="$KONG_PORT" \
  LANE_SUPABASE_URL="http://$HOST:$KONG_PORT" \
  LANE_SUPABASE_ANON_KEY="$ANON_KEY" \
  IOS_DEVELOPMENT_TEAM="$TEAM"

APK="build/app/outputs/flutter-apk/app-dev-debug.apk"
[ -f "$APK" ] || { echo "missing APK: $APK" >&2; exit 1; }
[ -f "$IPA" ] || { echo "missing ad-hoc IPA: $IPA" >&2; exit 1; }

APK_OUT="$(basename "$APK")"
IPA_OUT="samay_app-adhoc.ipa"
cp "$APK" "$OUT_DIR/$LANE/$APK_OUT"
cp "$IPA" "$OUT_DIR/$LANE/$IPA_OUT"
{
  echo "lane=$LANE"
  echo "commit=$(git rev-parse HEAD)"
  echo "backend=http://$HOST:$KONG_PORT"
  echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "ipa_signing=ad-hoc"
  echo "apple_signin=disabled-in-test-build"
  echo "apk=$APK_OUT sha256=$(shasum -a 256 "$APK" | cut -d' ' -f1)"
  echo "ipa=$IPA_OUT sha256=$(shasum -a 256 "$IPA" | cut -d' ' -f1)"
} > "$OUT_DIR/$LANE/manifest.txt"
echo "artifacts: $OUT_DIR/$LANE"
