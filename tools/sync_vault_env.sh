#!/usr/bin/env bash
# =============================================================================
# sync_vault_env.sh — copy the PUBLIC testing config from the vault into this
# app's `.env`. Operator-run and interactive by design: it unlocks `pass`, so
# it is never part of a build or CI.
#
# Why this exists: `make deploy ENV=testing` builds with the VAULT's public
# config (`testing/public/*`), not with `supabase/.env`. For a store build to
# talk to the local Docker stack through the Cloudflare tunnel, the app's
# SUPABASE_URL / SUPABASE_ANON_KEY must be the SAME values the vault serves.
# The anon key is a JWT minted from that stack's JWT_SECRET, so a `make reset`
# with a regenerated secret silently invalidates every store build.
#
# Only PUBLIC entries are copied. Secrets (service-role, JWT secret, tunnel
# token) stay in the vault and never enter the app repo.
#
# Usage:
#   bash tools/sync_vault_env.sh                     # show what would change
#   bash tools/sync_vault_env.sh --write             # update .env in place
#   VAULT_SCOPE=staging bash tools/sync_vault_env.sh # staging instead
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

SCOPE="${VAULT_SCOPE:-testing}"
ENV_FILE="${ENV_FILE:-.env}"
WRITE=0
[ "${1:-}" = "--write" ] && WRITE=1

VAULT_BASE="qallariy/samay/${SCOPE}/public"

# vault entry                       -> .env key
MAP=(
  "supabase-url|SUPABASE_URL"
  "supabase-anon-key|SUPABASE_ANON_KEY"
  "google-oauth-client-id|GOOGLE_OAUTH_CLIENT_ID"
  "google-oauth-ios-client-id|GOOGLE_OAUTH_IOS_CLIENT_ID"
)

command -v pass >/dev/null 2>&1 || { echo "pass not found" >&2; exit 2; }
[ -f "$ENV_FILE" ] || { echo "$ENV_FILE not found (run 'make init ENV=$SCOPE' first)" >&2; exit 2; }

# Distinguish "vault is locked" from "the entry is genuinely absent": a locked
# store makes every `pass show` fail, and reporting that as MISSING would look
# like the entries were never provisioned.
if ! pass ls "${VAULT_BASE}" >/dev/null 2>&1; then
  echo "cannot read ${VAULT_BASE} — unlock the pass store first" >&2
  echo "  (a GPG pinentry prompt is expected: run 'pass show ${VAULT_BASE}/supabase-url' once)" >&2
  exit 2
fi

fingerprint() { # fingerprint <value> -> short sha, never the value itself
  printf '%s' "$1" | shasum -a 256 | cut -c1-16
}

current() { # current <KEY> -> value in .env (quotes stripped)
  sed -n "s/^$1=//p" "$ENV_FILE" | head -1 | tr -d '"' | tr -d "'"
}

upsert() { # upsert <KEY> <VALUE>
  local k="$1" v="$2" tmp
  tmp="$(mktemp)"
  awk -v k="$k" -v v="$v" '
    $0 ~ "^" k "=" { print k "=" v; done=1; next } { print }
    END { if (!done) print k "=" v }
  ' "$ENV_FILE" > "$tmp"
  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

echo "vault scope: $SCOPE   target: $ENV_FILE"
printf '%-28s %-18s %-18s %s\n' KEY LOCAL VAULT STATUS

changes=0
for pair in "${MAP[@]}"; do
  entry="${pair%%|*}"
  key="${pair##*|}"
  if ! vault_val="$(pass show "${VAULT_BASE}/${entry}" 2>/dev/null)"; then
    printf '%-28s %-18s %-18s %s\n' "$key" "-" "MISSING" "skipped"
    continue
  fi
  [ -n "$vault_val" ] || { printf '%-28s %-18s %-18s %s\n' "$key" "-" "EMPTY" "skipped"; continue; }
  local_val="$(current "$key")"

  if [ "$local_val" = "$vault_val" ]; then
    status="same"
  elif [ -z "$local_val" ]; then
    status="absent locally"
    changes=$((changes + 1))
  else
    status="DIFFERS"
    changes=$((changes + 1))
  fi

  printf '%-28s %-18s %-18s %s\n' \
    "$key" "$(fingerprint "$local_val")" "$(fingerprint "$vault_val")" "$status"

  if [ "$WRITE" -eq 1 ] && [ "$status" != "same" ]; then
    upsert "$key" "$vault_val"
  fi
done

echo
if [ "$WRITE" -eq 0 ]; then
  if [ "$changes" -eq 0 ]; then
    echo "no changes: $ENV_FILE already matches the vault."
  else
    echo "$changes value(s) differ. Re-run with --write to copy them into $ENV_FILE."
  fi
else
  echo "$ENV_FILE updated from vault ($SCOPE)."
  echo "Verify the stack agrees, then: make start ENV=$SCOPE"
fi

echo
echo "Note: the anon key is a JWT minted from the stack's JWT_SECRET. If it"
echo "differs, either copy it here (above) or copy this stack's key INTO the"
echo "vault — but never both directions, or the two will keep overwriting."
