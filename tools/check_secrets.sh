#!/usr/bin/env bash
# =============================================================================
# check_secrets.sh — committed-secret gate.
#
# Source of truth: the LOCAL gitignored-style env files. Every value declared
# under a secret-ish variable name (_KEY/_SECRET/_TOKEN/_PASSWORD/_PASSWD/_DSN,
# JWT_SECRET included by suffix rule) is grepped against all TRACKED files;
# a single hit means a live local secret leaked into version control -> FAIL.
#
# Env files scanned (may not exist):
#   .env  .env.local  supabase/.env  supabase/.env.local
#   supabase-testing/.env  supabase-testing/.env.local
#
# Those env files are EXCLUDED from the scan itself: a value defined there and
# present nowhere else is not a leak. A value found in code, tests, docs,
# compose, volumes — anything tracked outside those files — fails the gate.
#
# Plus two generic shape checks over tracked files:
#   S1  sb_secret_[A-Za-z0-9_-]{16,}   real Supabase service-role key shape
#   S2  BEGIN … PRIVATE KEY blocks
#
# Usage: tools/check_secrets.sh    # exit 0 = clean, 1 = violations
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

VIOLATIONS=0

ENV_FILES=(.env .env.local supabase/.env supabase/.env.local
           supabase-testing/.env supabase-testing/.env.local)
EXCLUDES=()
for f in "${ENV_FILES[@]}"; do EXCLUDES+=(":(exclude)$f"); done

printf '── secrets-check: tracked-file scan against local env values ──\n'

# ── collect candidate values (secret-ish variable names only) ────────────────
candidates="$(mktemp)"
trap 'rm -f "$candidates"' EXIT
: > "$candidates"
for f in "${ENV_FILES[@]}"; do
  [ -r "$f" ] || continue
  grep -E '^[A-Za-z0-9_]*(_KEY|_SECRET|_TOKEN|_PASSWORD|_PASSWD|_DSN)=' "$f" || true
done | while IFS= read -r kv; do
  v="${kv#*=}"
  v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
  case "$v" in
    '' | http* | *//* | */*) continue ;;
    your-* | *change-in-production* | *example* | *placeholder* | *changeme*)
      continue ;;
  esac
  [ "${#v}" -ge 20 ] && printf '%s\n' "$v"
done | sort -u > "$candidates"

COUNT=$(wc -l < "$candidates" | tr -d ' ')
while IFS= read -r v; do
  [ -n "$v" ] || continue
  hits="$(git grep -n -I -F -- "$v" -- . "${EXCLUDES[@]}" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    printf '  ✗ a live local secret value appears in tracked files:\n'
    printf '%s\n' "$hits" | sed 's/^/      /'
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done < "$candidates"
printf '  ✓ %d local secret value(s) checked against tracked files\n' "$COUNT"

shape_violation() { # shape_violation <label> <ERE>
  local label="$1" pattern="$2" hits
  hits="$(git grep -n -I -E -- "$pattern" -- . "${EXCLUDES[@]}" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    printf '  ✗ %s:\n' "$label"
    printf '%s\n' "$hits" | sed 's/^/      /'
    VIOLATIONS=$((VIOLATIONS + 1))
  else
    printf '  ✓ %s\n' "$label"
  fi
}

shape_violation 'S1 no service-role key shape (sb_secret_*)' 'sb_secret_[A-Za-z0-9_-]{16,}'
shape_violation 'S2 no private-key blocks' 'BEGIN [A-Z ]*PRIVATE KEY'

# S3: no signing material or secret-store files are ever tracked (path match
# only — content-matching would false-positive on docs).
bad_tracked="$(git ls-files -z | tr '\0' '\n' | grep -E \
  '\.(jks|keystore|p12|mobileprovision|provisionprofile|kdbx|enc|p8)$|(^|/)keystore\.properties$|(^|/)service-account\.json$' || true)"
if [ -n "$bad_tracked" ]; then
  printf '  ✗ S3 tracked signing material / secret-store files:\n'
  printf '%s\n' "$bad_tracked" | sed 's/^/      /'
  VIOLATIONS=$((VIOLATIONS + 1))
else
  printf '  ✓ S3 no tracked signing material\n'
fi

if [ "$VIOLATIONS" -ne 0 ]; then
  printf 'secrets-check: FAIL — %d violation(s). Remove the literal; secrets live only in the env files.\n' "$VIOLATIONS" >&2
  exit 1
fi
printf 'secrets-check: PASS — no committed secrets.\n'
exit 0
