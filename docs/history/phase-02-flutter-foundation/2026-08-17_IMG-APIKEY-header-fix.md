# IMG-APIKEY — Kong apikey header for storage images (2026-08-17)

Agent: `IMG-APIKEY-FIX` · Phase 02 (Flutter foundation) · No commits (working tree only).

## What was built

`VNetworkImage` (`lib/shared/widgets/v_network_image.dart`) now sends the Kong
**key-auth** `apikey` header on Supabase storage image reads, fixing the
"just broken img" errors on every stored cover/banner in the app.

- New optional constructor param `Map<String, String>? httpHeaders` (keeps the
  const constructor — final field, default `null`).
- New static helper `VNetworkImage.storageHeadersFor(String url, String apiKey)`:
  returns `{'apikey': apiKey}` when `apiKey` is non-empty **AND** `url` contains
  `/storage/v1/` (covers public reads and signed-URL reads); otherwise `null`.
- `build` passes `httpHeaders: httpHeaders ?? storageHeadersFor(imageUrl, EnvConfig.supabaseAnonKeyRaw)`
  to `CachedNetworkImage` (verified in the pinned 3.4.1 source: `cached_image_widget.dart:169`
  `final Map<String, String>? httpHeaders;`, wired at `:247` `headers: httpHeaders`).
- Non-storage URLs and test environments (empty compile-time key) keep today's
  behavior exactly — the helper returns `null` and no header is sent.

## Root cause

Every app-rendered image goes through `VNetworkImage` → `CachedNetworkImage`.
All stored image URLs are Supabase storage public URLs, e.g.
`https://samay-api.qallariy.lat/storage/v1/object/public/groups/group_covers/1786927556873.png`.
In this self-hosted stack Kong enforces **key-auth on every `/storage/v1/` route**
(`supabase/volumes/api/kong.yml`, service `storage-v1`, plugin `key-auth`, key
name `apikey`). Verified live: bare GET of the public URL (no `apikey`) returns
**401**; with header `apikey: <anon key>` returns **200**. `CachedNetworkImage`
sent no headers, so every stored cover/banner rendered as the
`broken_image_outlined` error widget.

The anon key is public by design (cannot bypass RLS — SECURITY.md §2.8; ships
in the app bundle via dart-define).

## Decisions made and why

- **Raw env getter** — uses `EnvConfig.supabaseAnonKeyRaw` (the
  `const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '')` that does
  NOT throw when empty), not `EnvConfig.supabaseAnonKey` (the validating getter).
  Widget tests without `--dart-define` keep working hermetically: empty key ⇒
  `storageHeadersFor` returns null ⇒ no header. A non-empty key in a real build
  ⇒ header attached to storage URLs only.
- **Explicit `httpHeaders` passthrough is first** (`httpHeaders ?? helper`) — a
  caller-supplied header map always wins; the helper is the default only.
- **Storage-URL containment check** in the helper — non-storage hosts (avatars
  served elsewhere, future CDNs) never get the key, so behavior outside the
  Supabase storage surface is unchanged.

## MISTAKE

Self-hosted public-bucket URLs are NOT loadable without the anon key. The
"public bucket ⇒ bare public URL loads without auth" assumption is wrong for
this Kong-Supabase stack: Kong's `storage-v1` service applies `key-auth` to
every route, public objects included, so a bare GET is `401` and
`CachedNetworkImage` (no headers) always fell through to the broken-image widget.
Any future change to the storage gateway (new host, HTTPS termination, CDN)
must re-verify the key-auth surface — see `supabase/volumes/api/kong.yml`.

## Files created/modified

- `lib/shared/widgets/v_network_image.dart` — field, static helper, build wiring
  (locked `tools/agent_lock.sh acquire … --owner IMG-APIKEY-FIX`).
- `test/widgets/v_network_image_test.dart` — 5 new tests + `RecordingNetwork*`
  recording harness (locked, same owner).
- `docs/history/phase-02-flutter-foundation/2026-08-17_IMG-APIKEY-header-fix.md` —
  this log (created under lock at PREP, filled at DOCUMENT).
- `tools/agent_lock.sh release lib/shared/widgets/v_network_image.dart test/widgets/v_network_image_test.dart docs/history/phase-02-flutter-foundation/2026-08-17_IMG-APIKEY-header-fix.md --owner IMG-APIKEY-FIX`

## Tests added + results

RED (compile errors, the right reason — behavior missing):
```
$ flutter test test/widgets/v_network_image_test.dart
  lib/shared/widgets/v_network_image.dart:26:9: Error: No named parameter with the name 'httpHeaders'.
  test/widgets/v_network_image_test.dart:395:23: Error: Member not found: 'VNetworkImage.storageHeadersFor'.
  (×3) → compile failure
```

GREEN / VALIDATE:
```
$ flutter test test/widgets/v_network_image_test.dart            # 16/16 pass (11 pre-existing + 5 new)
$ flutter test test/widgets/v_network_image_disk_cache_test.dart  # 1/1 pass (unaffected)
$ dart analyze lib/shared/widgets/v_network_image.dart test/widgets/v_network_image_test.dart
  → No issues found!
```

New tests:
1. `storageHeadersFor` unit group (3): storage+key ⇒ `{'apikey': ...}`; non-storage URL ⇒ null; empty key ⇒ null.
2. Widget: explicit `httpHeaders: {'apikey': 'anon-123'}` ⇒ recorded request carried the header AND image rendered (`RawImage` found, no broken-image widget).
3. Widget: default (no implict headers, empty test key) on a non-storage URL ⇒ no `apikey` header recorded.

## Sources consulted

- `~/.pub-cache/hosted/pub.dev/cached_network_image-3.4.1/lib/src/cached_image_widget.dart`
  (lines 169/215/247 — `httpHeaders` param confirmed in the pinned version).
- `supabase/volumes/api/kong.yml` (storage-v1 service, `key-auth` plugin, `apikey` key name).
- `lib/core/config/env_config.dart` (`supabaseAnonKeyRaw` Raw getter).

## Commands run

```bash
export AGENT_NAME=IMG-APIKEY-FIX
tools/agent_lock.sh acquire lib/shared/widgets/v_network_image.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire test/widgets/v_network_image_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire docs/history/phase-02-flutter-foundation/2026-08-17_IMG-APIKEY-header-fix.md --owner "$AGENT_NAME"

# RED proof
flutter test test/widgets/v_network_image_test.dart   # compile errors (httpHeaders / storageHeadersFor)

# GREEN + focused VALIDATE (full suite deliberately NOT run)
flutter test test/widgets/v_network_image_test.dart            # 16/16
flutter test test/widgets/v_network_image_disk_cache_test.dart # 1/1
dart analyze lib/shared/widgets/v_network_image.dart test/widgets/v_network_image_test.dart  # 0 issues

tools/agent_lock.sh release lib/shared/widgets/v_network_image.dart --owner "$AGENT_NAME"
tools/agent_lock.sh release test/widgets/v_network_image_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh release docs/history/phase-02-flutter-foundation/2026-08-17_IMG-APIKEY-header-fix.md --owner "$AGENT_NAME"
tools/agent_lock.sh list   # confirm no locks held
```

## Issues found (report only)

- `flutter_secure_storage_macos` prints a Swift Package Manager adoption warning on
  every `flutter test` run — pre-existing, unrelated to this change.