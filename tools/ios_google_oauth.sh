#!/usr/bin/env bash
# =============================================================================
# ios_google_oauth.sh — inject the Google iOS OAuth client into Info.plist for
# a build, and restore it afterwards.
#
# Google Sign-In on iOS needs the iOS OAuth client id as `GIDClientID` and its
# reversed form as a `CFBundleURLSchemes` entry (so the SDK can receive the
# auth callback). Neither value is committed; the PROD build materializes the
# id from the vault (`google-oauth-client-id`) into the RAM disk and this
# script patches the tracked Info.plist transiently.
#
# Usage:
#   tools/ios_google_oauth.sh apply <client_id> [<Info.plist>]
#       -> prints the backup path (caller must pass it to `restore`)
#   tools/ios_google_oauth.sh restore <backup> [<Info.plist>]
# =============================================================================
set -euo pipefail

PLIST_DEFAULT="ios/Runner/Info.plist"
SUFFIX=".apps.googleusercontent.com"

apply() {
  local client_id="${1:?usage: apply <client_id> [<plist>]}"
  local plist="${2:-$PLIST_DEFAULT}"
  [ -f "$plist" ] || { echo "Info.plist not found: $plist" >&2; exit 1; }
  case "$client_id" in
    *"$SUFFIX") local bare="${client_id%$SUFFIX}" ;;
    *) echo "client id does not end with $SUFFIX: $client_id" >&2; exit 1 ;;
  esac
  local reversed="com.googleusercontent.apps.${bare}"
  local backup
  backup="$(mktemp "${TMPDIR:-/tmp}/samay-Info.XXXXXX.plist")"
  cp "$plist" "$backup"

  # GIDClientID (add or replace).
  if plutil -extract GIDClientID raw "$plist" >/dev/null 2>&1; then
    plutil -replace GIDClientID -string "$client_id" "$plist"
  else
    plutil -insert GIDClientID -string "$client_id" "$plist"
  fi

  # Reversed client id URL scheme (add or replace the whole URLTypes block,
  # remapping any existing bundle id scheme is unnecessary — Samay has none).
  if plutil -extract CFBundleURLTypes raw "$plist" >/dev/null 2>&1; then
    plutil -replace CFBundleURLTypes -json \
      "[{\"CFBundleTypeRole\":\"Editor\",\"CFBundleURLSchemes\":[\"$reversed\"]}]" \
      "$plist"
  else
    plutil -insert CFBundleURLTypes -json \
      "[{\"CFBundleTypeRole\":\"Editor\",\"CFBundleURLSchemes\":[\"$reversed\"]}]" \
      "$plist"
  fi

  echo "$backup"
}

restore() {
  local backup="${1:?usage: restore <backup> [<plist>]}"
  local plist="${2:-$PLIST_DEFAULT}"
  [ -f "$backup" ] || { echo "backup not found: $backup" >&2; exit 1; }
  cp "$backup" "$plist"
  rm -f "$backup"
  echo "restored $plist"
}

case "${1:-}" in
  apply)   shift; apply "$@" ;;
  restore) shift; restore "$@" ;;
  *) echo "usage: $0 apply <client_id> [<plist>] | restore <backup> [<plist>]" >&2; exit 2 ;;
esac
