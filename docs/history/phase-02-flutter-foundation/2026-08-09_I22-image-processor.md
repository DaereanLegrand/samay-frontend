# 2026-08-09 — I-22: Client-side image processor (PERF-03 / M-36)

**Agent:** I-22 (image processing utility + group-cover upload wiring)
**Status:** DONE (⚠️ one call-site swap BLOCKED — see §6)
**Scope:** `lib/core/utils/image_processor.dart` (new shared utility),
`lib/core/services/media_service.dart` (compress before `uploadBinary`),
`lib/features/groups/create_group_screen.dart` (call-site swap — **BLOCKED**,
handoff diff in §7), unit tests, media-service wiring tests, TODO.md
M-36 / 10-PERFORMANCE.md PERF-03 statuses.

---

## 1. What was built

### `lib/core/utils/image_processor.dart` (new)
`ImageProcessor` — client-side downscaling for uploads (finding PERF-03/M-36,
Juega's `ImageProcessor` as reference):

- `compress(File image, {int maxLongEdge = 1920})` — reads the file, returns
  upload-ready bytes: downscaled to ≤ 1920px on the long edge (PNG), or the
  original bytes when processing is unnecessary.
- `compressBytes(Uint8List, {maxLongEdge})` — bytes variant for callers that
  already hold the payload (`MediaService`).
- `shouldResize(File, {minBytes = 512 KB})` — the size check: files at or
  above the threshold justify processing; smaller ones pass through.
- Processing pipeline: `ImageDescriptor.encoded` reads header dimensions
  **without decoding pixels** (fast, low-memory), `instantiateImageCodec(
  targetWidth, targetHeight)` decodes directly at the capped resolution, and
  `toByteData(format: png)` re-encodes. Aspect is preserved by computing both
  targets from the long-edge scale.
- Skip paths: files below `skipThresholdBytes` (512 KB) only get a cheap
  header validation and pass through untouched; images already within the
  cap pass through untouched (no re-encode, no quality loss).
- Safety guard: if the re-encoded payload would be **larger** than the input
  (pathological cases), the original bytes are returned — a processor never
  grows an upload.
- Non-image/corrupt input → `ValidationError('imagen', …)` — consistent with
  the `AppError` hierarchy (error classes stay Spanish by design, mapped at
  presentation).

### `lib/core/services/media_service.dart` (modified)
`uploadGroupCover` now compresses via `ImageProcessor.compressBytes` **before**
`uploadBinary`, and the signature dropped the `extension` param (the stored
object is always PNG — the extension must match the content, which fixes a
latent HEIC-mismatch class of bug too). The path is
`group_covers/<ts>.png`. No callers existed, so the signature change is safe.

### Tests
- `test/utils/image_processor_test.dart` (new, 8 tests) — see §4.
- `test/services/media_service_test.dart` (new, 3 tests) — wiring evidence:
  `uploadBinary` receives the downscaled payload (byte-size < original) for
  full-resolution input, the original bytes for small input, and the returned
  URL points at the `.png` object.

### Docs
- `docs/to-fix/TODO.md` — M-36 → 🔄 (I-22 evidence + BLOCKED note).
- `docs/to-fix/categories/10-PERFORMANCE.md` — PERF-03 → 🔄 (same).

---

## 2. Decisions & rationale

1. **`dart:ui`-only, PNG re-encode (no new dependency).** The `image` package
   (Juega's JPEG encoder) is not in `pubspec.yaml` and adding deps is
   I-23's lock-held domain. Verified against the installed Flutter 3.44.1
   `dart:ui` source (`painting.dart`): `ImageByteFormat` = rawRgba,
   rawStraightRgba, rawUnmodified, rawExtendedRgba128, **png** — no JPEG
   encoder exists client-side without a package. PNG downscale to 1920px is
   the resolution win (the main bandwidth lever); JPEG-80 is documented as a
   follow-up (add `image` package, swap the encode step — the pipeline is a
   single `_process` entry point).
2. **Main-isolate processing (chosen after empirical verification, per
   mission).** An `Isolate.run` variant was built first. Probe results:
   - flutter_tester: dart:ui engine calls (`ImmutableBuffer`,
     `ImageDescriptor`, codec, `toByteData`) **fail inside spawned isolates**
     — with the fallback disabled, the large-image tests threw.
   - macOS desktop embedder (`flutter test -d macos`, real engine): **same
     result** — the isolate path fails there too.
   → Chose main-isolate processing with the tradeoff documented in the class
   doc: a UI-thread hitch (hundreds of ms) during the resize. Reintroducing a
   worker path is a local change if a platform proves isolate-capable.
3. **`ImageDescriptor.encoded` for dimensions instead of full decode** — the
   header read avoids decoding a 12 MP frame just to learn its size (the OOM
   risk PERF-03 calls out on low-RAM devices).
4. **512 KB threshold** — cheap uploads never pay decode/encode cost; the
   threshold only skips when processing can't win.
5. **Never-grow guard** — PNG of a small-but-noisy source can exceed the
   input; returning the original is strictly better.
6. **Header validation on the small-file path** — so a tiny junk file still
   fails fast as `ValidationError` instead of silently uploading garbage.

## MISTAKE blocks

- **MISTAKE (test design):** asserted `same(input)` on the skip paths — wrong
  for the `File` API: `readAsBytes` returns a *fresh* instance. Fixed to
  content equality (`equals`).
- **MISTAKE (mocktail):** `SupabaseClient.storage` is a `late final` **field**,
  not a getter — mocktail cannot stub fields, and a mock's field returns null
  (`type 'Null' is not a subtype of type 'StorageFileApi'`). Also, stubbing
  `storage.from` on one `_MockStorage` instance while `client.storage`
  returned a different instance made the stub invisible. Fixed by giving the
  client mock a constructor-injected `storage` override.
- **MISTAKE (isolate probe):** an early `on ValidationError { rethrow; }`
  branch made the fallback dead code for engine failures — any isolate-side
  engine error surfaced as ValidationError and skipped the fallback. Removed
  (the isolate-as-pure-optimization design makes the fallback unconditional).
- **MISTAKE (imports):** direct `storage_client` import in the service test
  tripped `unnecessary_import` + `depend_on_referenced_packages` —
  `supabase_flutter` re-exports `StorageFileApi`.

## 3. Empirical verification notes

- **JPEG availability (Flutter 3.44.1):** `ImageByteFormat` has no JPEG value
  (SDK source + api.flutter.dev confirmed). `instantiateImageCodec` *decodes*
  JPEG/PNG/WebP/BMP/WBMP; aspect is preserved automatically when only one
  target dimension is given; `allowUpscaling` avoids upscale.
- **Isolate probe:** with the fallback disabled, `flutter test
  test/utils/image_processor_test.dart -d macos` failed 3 tests with the
  underlying engine error — dart:ui codec calls do not work in
  `Isolate.run`-spawned isolates on flutter_tester **or** macOS desktop
  (Flutter 3.44.1). The main-isolate path passes everywhere. On-device
  (Android/iOS) verification is a follow-up (I-59 photo upload will exercise
  it in real conditions).

## 4. Test results

- `flutter test test/utils/image_processor_test.dart` — **8/8 pass** on
  flutter_tester and `-d macos`:
  shouldResize ×3 (below threshold → false, at/above → true, missing file →
  false); 3000×2000 noise PNG → long edge ≤ 1920 **and** payload smaller;
  custom `maxLongEdge: 1000` honored; dimension-skip (1600×900 noise passes
  through byte-identical); size-skip (solid 800×600 passes through); junk
  input → `ValidationError`.
- `flutter test test/services/media_service_test.dart` — **3/3 pass**:
  full-res payload compressed before `uploadBinary` (captured args), small
  payload passthrough, public-URL return.
- `flutter test test/features/groups_screens_test.dart` — green (rendering
  tests unaffected; the create flow never reaches the upload path in tests).
- Full `flutter test` — **546 pass / 13 fail**; the 13 are NOT mine: 12×
  `structure_test.dart` (documented baseline, I-47/I-48) + 1×
  `permission_service_test.dart` (I-28 in-progress, `permission_handler` not
  yet in pubspec).
- `dart analyze` — **0 errors, 0 new infos** (19 pre-existing infos, none in
  I-22 files).

## 5. Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire/release <path> --owner I-22-image-processor`:

| File | Action | Lock |
|---|---|---|
| `lib/core/utils/image_processor.dart` | created | acquired 14:46:13Z, released |
| `test/utils/image_processor_test.dart` | created | acquired, released |
| `lib/core/services/media_service.dart` | modified | acquired, released |
| `test/services/media_service_test.dart` | created | acquired, released |
| `docs/to-fix/TODO.md` | modified (M-36 → 🔄) | acquired (was briefly I-23's; free by the time of my acquire), released |
| `docs/to-fix/categories/10-PERFORMANCE.md` | modified (PERF-03 → 🔄) | acquired, released |
| `docs/history/phase-02-flutter-foundation/2026-08-09_I22-image-processor.md` | created (this log) | acquired, released |

No `pubspec.yaml` change (no new dependency).

## 6. BLOCKED — `create_group_screen.dart` call-site swap

The lock for `lib/features/groups/create_group_screen.dart` is held by
**I-27-sanitizer** (claimed 2026-08-09 14:45:36Z). Two acquire attempts with
the full 1800s timeout (plus a 300s retry) all timed out. I-27 last modified
any file at ~14:58Z and its daily log (`2026-08-09_I27-sanitizer.md`) was
written at ~14:58Z — 40+ minutes of silence while holding 10+ locks. The
file itself shows I-27's sanitizer work fully landed (name/description
sanitization at `_create()`). The lock looks **orphaned**, but per
AGENT-RULES.md §1 the semaphore is absolute: WAIT, never edit anyway. The
orchestrator should free I-27's stale locks (it is the only authority) and
apply the ready diff below.

## 7. Handoff diff for the orchestrator (apply after freeing I-27's lock)

On top of the current `create_group_screen.dart` (I-27's sanitizer version):

```diff
--- a/lib/features/groups/create_group_screen.dart
+++ b/lib/features/groups/create_group_screen.dart
@@ imports: add after `input_sanitizer.dart`
+import 'package:samay/core/utils/image_processor.dart';

@@ _create() cover block (current lines 65-72):
       String? coverUrl;
       if (_coverImage != null) {
-        final bytes = await _coverImage!.readAsBytes();
-        final ext = _coverImage!.name.split('.').last;
-        final path = 'group_covers/${DateTime.now().millisecondsSinceEpoch}.$ext';
-        await SupabaseService.instance.client.storage.from('groups').uploadBinary(path, bytes);
-        coverUrl = SupabaseService.instance.client.storage.from('groups').getPublicUrl(path);
+        final processed = await ImageProcessor.compress(File(_coverImage!.path));
+        coverUrl = await SupabaseService.instance.mediaService
+            .uploadGroupCover(processed);
       }
```

Notes: removes the raw `client.storage` usage from the screen (aligned with
the I-11 decomposition — new code must use the feature services); always
stores `.png`; `dart:io` is already imported; `image_picker` stays (still
used by `_pickImage`). Validation: `dart analyze` clean + `flutter test
test/features/groups_screens_test.dart` green (rendering test only — the
create flow never hits the upload path in tests).

## Commands run (reproducibility)

```
export AGENT_NAME="I-22-image-processor"
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME"   # per file, see §5
flutter test test/utils/image_processor_test.dart          # RED: compile error (ImageProcessor missing)
flutter test test/utils/image_processor_test.dart          # GREEN: 8/8
flutter test test/services/media_service_test.dart         # 3/3 (after mocktail fixes)
flutter test test/utils/image_processor_test.dart -d macos # 8/8 (real embedder)
flutter test                                               # 546 pass / 13 fail (12 structure_test baseline + 1 I-28 in-progress)
dart analyze                                               # 0 errors, 19 pre-existing infos, none mine
tools/agent_lock.sh acquire docs/to-fix/TODO.md            # granted after I-23 released
tools/agent_lock.sh acquire lib/features/groups/create_group_screen.dart --timeout 1800  # TIMEOUT (I-27) ×2 — BLOCKED
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"   # all acquired locks released
```

## Sources

- Flutter 3.44.1 `dart:ui` source (`/opt/homebrew/share/flutter/bin/cache/pkg/sky_engine/lib/ui/painting.dart`) — `ImageByteFormat` values, `instantiateImageCodec` semantics, `ImageDescriptor` API.
- https://api.flutter.dev/flutter/dart-ui/ImageByteFormat.html — no JPEG encoder.
- https://api.flutter.dev/flutter/dart-ui/instantiateImageCodec.html — supported decode formats, single-dimension aspect preservation, `allowUpscaling`.
- Juega reference: `/Users/daerean/Codes/apps/Juega/lib/shared/utils/image_processor.dart` + its test (isolate-first with Flutter-codec fallback, 1920px / 80% JPEG).
