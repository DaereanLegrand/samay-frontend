#!/usr/bin/env bash
# =============================================================================
# check_anon_matches_stack.sh — fail before a 5-minute build if the app's
# compiled anon key would be rejected by the local stack.
#
# Why this exists: the app's credentials are baked in at BUILD time from
# `--dart-define-from-file=<defines>` (the vault's dart_defines.env, or .env),
# while the stack validates tokens at RUN time using the JWT_SECRET it was
# started with. Nothing forced the two to agree, so it was possible to publish a
# build that installs fine and answers {"message":"Unauthorized"} to every
# request — which is exactly what happened to the Android AAB on 2026-11-24
# (built with the pre-regen key while the stack ran the post-regen secret).
#
# The check is authoritative: it compares against the RUNNING container, not
# against a file, so it is correct for both secret sources:
#   ENV=testing-local → stack from supabase/.env
#   ENV=testing       → stack from the vault (stack.env on the RAM disk)
#
# Usage: bash tools/check_anon_matches_stack.sh <defines-file>
#   <defines-file> is a KEY=VALUE file containing SUPABASE_ANON_KEY.
# Exit 0 = the key will be accepted. Exit 1 = it would be rejected.
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFINES="${1:?usage: check_anon_matches_stack.sh <defines-file>}"
BACKEND_ENV="${BACKEND_ENV:-$ROOT/../backend/supabase/.env}"

[ -r "$DEFINES" ] || { echo "check-anon: defines file not readable: $DEFINES" >&2; exit 2; }

read_key() { sed -n "s/^$1=//p" "$2" 2>/dev/null | head -1 | tr -d '"'; }

APP_ANON="$(read_key SUPABASE_ANON_KEY "$DEFINES")"
if [ -z "$APP_ANON" ]; then
  echo "check-anon: $DEFINES has no SUPABASE_ANON_KEY — the build would ship no credentials." >&2
  exit 1
fi

KONG_PORT="$(read_key KONG_HTTP_PORT "$BACKEND_ENV")"
KONG_PORT="${KONG_PORT%%   *}"; KONG_PORT="${KONG_PORT:-54386}"

KONG="$(docker ps --format '{{.Names}}' --filter "publish=$KONG_PORT" 2>/dev/null | head -1)"
if [ -z "$KONG" ]; then
  echo "check-anon: no Kong publishing :$KONG_PORT — cannot verify. Start the stack first" >&2
  echo "            (make -C ../backend start APP=samay ENV=<testing-local|testing>)." >&2
  exit 2
fi

STACK_ANON="$(docker exec "$KONG" printenv ANON_KEY 2>/dev/null)"
if [ -z "$STACK_ANON" ]; then
  echo "check-anon: $KONG has no ANON_KEY in its environment." >&2
  exit 2
fi

if [ "$APP_ANON" = "$STACK_ANON" ]; then
  echo "check-anon: OK — build credential matches the stack ($KONG)"
  exit 0
fi

fp() { printf '%s' "$1" | shasum -a 256 | cut -c1-16; }
echo "check-anon: MISMATCH — this build would answer 'Unauthorized' to every request." >&2
echo "              build key ($DEFINES): $(fp "$APP_ANON")" >&2
echo "              stack key ($KONG):     $(fp "$STACK_ANON")" >&2
echo "" >&2
echo "            The build is compiled with one secret generation and the stack" >&2
echo "            runs another. Fix the source, do not rebuild blindly:" >&2
echo "              - ENV=testing      → the vault profile the stack was started" >&2
echo "                                   with; re-fetch it (make deploy fetches)." >&2
echo "              - ENV=testing-local → supabase/.env must carry the running" >&2
echo "                                   stack's JWT_SECRET / anon key." >&2
exit 1
