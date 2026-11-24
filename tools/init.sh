#!/usr/bin/env bash
# Interactive setup — TESTING-LOCAL ONLY.
#
# There is no frontend env file. A local run reads the backend's
# `../backend/.env/testing-local.env` (URL, anon key, OAuth ids) through the Makefile's
# LOCAL_DEFINES, so one `make init APP=samay ENV=testing-local` in the backend is
# all the configuration this app needs.
#
# Release ENVs (testing|staging|prod) read the vault via `make deploy`; there is
# nothing to write here for them.
set -euo pipefail
cd "$(dirname "$0")/.."

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
[ -t 0 ] || { echo "make init requires an interactive terminal"; exit 1; }

BACKEND_ENV="../backend/.env/testing-local.env"

bold "== samay app setup (testing-local) =="
echo
ok=1
for t in flutter gum docker; do
  have "$t" && echo "  ok   $t" || { echo "  MISS $t (required)"; ok=0; }
done
echo
[ "$ok" -eq 1 ] || { echo "Install the required tools, then re-run 'make init'."; exit 1; }

if [ ! -r "$BACKEND_ENV" ]; then
  echo "MISS $BACKEND_ENV" >&2
  echo "This app has no env file of its own. Configure the local backend first:" >&2
  echo "  make -C ../backend init APP=samay ENV=testing-local" >&2
  echo "  make -C ../backend start APP=samay ENV=testing-local" >&2
  exit 1
fi

port="$(sed -n 's/^KONG_HTTP_PORT=\([0-9]*\).*/\1/p' "$BACKEND_ENV" | head -1)"
echo "  ok   $BACKEND_ENV (Kong :${port:-54396})"
echo
echo "next: make start ENV=testing-local"
