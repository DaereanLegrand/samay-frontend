#!/usr/bin/env bash
# =============================================================================
# check_ruby_toolchain.sh — make the Ruby/bundler toolchain self-verifying.
#
# Why this exists: `brew upgrade ruby` swaps the Cellar keg and rewrites
# /opt/homebrew/opt/ruby, but the previous keg's gem DIRECTORY can go away
# while its .gemspec stays behind in /opt/homebrew/lib/ruby/gems/<abi>/specifications.
# RubyGems then resolves the stale spec and dies with
#
#   cannot load such file -- .../gems/bundler-<v>/exe/bundle (LoadError)
#
# before a single line of project code runs. That is exactly how a release
# build died on 2026-11-23 (Homebrew moved ruby 4.0.6 -> 4.0.10 at 16:23, and
# Gemfile.lock pins BUNDLED WITH 4.0.16, whose gem dir was gone).
#
# This script repairs that class of breakage and fails loudly if it cannot:
#
#   1. assert the Homebrew Ruby is first on PATH (`bundle exec` re-execs
#      `ruby` from PATH, so a system-Ruby-first shell loads ruby 2.6 and the
#      bundler from 4.x cannot load).
#   2. assert `bundle` runs at all, at the version pinned by Gemfile.lock.
#   3. if bundler is missing, reinstall exactly the pinned version.
#   4. rebuild native extensions RubyGems reports as unbuilt (homebrew's
#      message: "ignoring <gem> because its extensions are not built").
#   5. assert `bundle check` is satisfied (no network install here — that is
#      `make bundle-install`).
#
# Usage: bash tools/check_ruby_toolchain.sh [--repair]
#   without --repair it only diagnoses (exit 1 on any problem)
#   with    --repair it fixes what it can, then re-verifies
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

RUBY_BIN_DIR="/opt/homebrew/opt/ruby/bin"
RUBY="$RUBY_BIN_DIR/ruby"
GEM="$RUBY_BIN_DIR/gem"
BUNDLE="$RUBY_BIN_DIR/bundle"

REPAIR=0
[ "${1:-}" = "--repair" ] && REPAIR=1

FAILURES=0
fail() { printf '  FAIL  %s\n' "$*" >&2; FAILURES=$((FAILURES + 1)); }
ok() { printf '  ok    %s\n' "$*"; }
note() { printf '  ..    %s\n' "$*"; }

pinned_bundler() {
  # BUNDLED WITH is the authoritative pin for `bundle exec` in this repo.
  sed -n '/^BUNDLED WITH$/{n;s/^ *//;p;q;}' Gemfile.lock 2>/dev/null
}

echo "── ruby toolchain ──"

# ── 1. Homebrew Ruby must be first on PATH ──────────────────────────────────
if [ ! -x "$RUBY" ]; then
  fail "no Homebrew ruby at $RUBY (brew install ruby)"
else
  ruby_ver="$("$RUBY" -v 2>/dev/null | awk '{print $2}')"
  ok "homebrew ruby $ruby_ver"
fi

first_ruby="$(command -v ruby 2>/dev/null || true)"
if [ "$first_ruby" = "$RUBY" ]; then
  ok "PATH resolves ruby -> $RUBY"
else
  fail "PATH ruby is '${first_ruby:-none}', not $RUBY — 'bundle exec' re-execs
        'ruby' from PATH, so a system Ruby (2.6) first makes bundler 4.x
        unloadable. The Makefile exports the right PATH; run through make, or
        export PATH=\"$RUBY_BIN_DIR:\$PATH\"."
fi

# ── 2. bundler present, runnable, and at the pinned version ─────────────────
PINNED="$(pinned_bundler)"
if [ -n "$PINNED" ]; then ok "Gemfile.lock pins bundler $PINNED"; else note "Gemfile.lock has no BUNDLED WITH"; fi

bundle_ok=0
if [ -x "$BUNDLE" ]; then
  if out="$("$BUNDLE" -v 2>&1)"; then
    case "$out" in
      *LoadError*|*"cannot load such file"*) : ;;
      *) bundle_ok=1; ok "bundle -v -> $(printf '%s' "$out" | tail -1)" ;;
    esac
  fi
fi

if [ "$bundle_ok" -eq 0 ]; then
  if [ "$REPAIR" -eq 1 ] && [ -n "$PINNED" ]; then
    note "the 'bundle' shim is broken (stale bundler gemspec with no gem dir)"
    note "repairing: gem install bundler -v $PINNED"
    "$GEM" install bundler -v "$PINNED" --no-document >/dev/null 2>&1 || true
    if out="$("$BUNDLE" -v 2>&1)" && ! printf '%s' "$out" | grep -q LoadError; then
      bundle_ok=1; ok "repaired: bundle -v -> $(printf '%s' "$out" | tail -1)"
    else
      fail "the 'bundle' shim is broken and the repair did not fix it"
    fi
  else
    fail "the 'bundle' shim is broken (stale bundler gemspec with no gem dir)"
    note "rerun with --repair (or: gem install bundler -v ${PINNED:-<pinned>})"
  fi
fi

# ── 3. the version Gemfile.lock expects must actually be activated ──────────
if [ "$bundle_ok" -eq 1 ] && [ -n "$PINNED" ]; then
  got="$("$BUNDLE" -v 2>/dev/null | tail -1 | tr -d '[:space:]')"
  if [ "$got" = "$PINNED" ]; then
    ok "bundler version matches the pin"
  else
    fail "bundler is $got but Gemfile.lock pins $PINNED"
    if [ "$REPAIR" -eq 1 ]; then
      note "repairing: gem install bundler -v $PINNED"
      "$GEM" install bundler -v "$PINNED" --no-document >/dev/null 2>&1 || true
      got="$("$BUNDLE" -v 2>/dev/null | tail -1 | tr -d '[:space:]')"
      [ "$got" = "$PINNED" ] && ok "repaired to $PINNED" || fail "still $got"
    fi
  fi
fi

# ── 4. rebuild native extensions RubyGems flagged as unbuilt ────────────────
unbuilt="$("$GEM" list --no-versions 2>&1 >/dev/null | sed -n 's/^Ignoring \(.*\) because its extensions.*/\1/p' | sort -u)"
if [ -z "$unbuilt" ]; then
  ok "no unbuilt native extensions"
else
  note "unbuilt extensions: $(printf '%s' "$unbuilt" | tr '\n' ' ')"
  if [ "$REPAIR" -eq 1 ]; then
    while IFS= read -r g; do
      [ -n "$g" ] || continue
      note "repairing: gem pristine $g"
      "$GEM" pristine "$g" >/dev/null 2>&1 || true
    done <<EOF
$unbuilt
EOF
    left="$("$GEM" list --no-versions 2>&1 >/dev/null | sed -n 's/^Ignoring \(.*\) because its extensions.*/\1/p' | sort -u)"
    [ -z "$left" ] && ok "native extensions rebuilt" || fail "still unbuilt: $(printf '%s' "$left" | tr '\n' ' ')"
  else
    fail "native extensions are not built — rerun with --repair"
  fi
fi

# ── 5. Gemfile dependencies satisfied (no install performed here) ───────────
if [ "$bundle_ok" -eq 1 ]; then
  if PATH="$RUBY_BIN_DIR:$PATH" "$BUNDLE" check >/dev/null 2>&1; then
    ok "bundle check: dependencies satisfied"
  else
    fail "bundle check failed — run 'make bundle-install'"
  fi
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "ruby toolchain: PASS"
  exit 0
fi
printf 'ruby toolchain: %d problem(s)\n' "$FAILURES" >&2
exit 1
