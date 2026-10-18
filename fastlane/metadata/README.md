# Store listing metadata (draft)

Store listing copy for **Samay** (`com.qallariy.samay`), drafted per locale.

## Scope

The `deploy` lanes upload the **artifact only** (`skip_metadata` on iOS,
`skip_upload_metadata` on Android), so nothing here is pushed by fastlane.
These files are the source of truth for the copy that is entered **by hand** in
App Store Connect and the Google Play Console.

## Layout

```
metadata/
  en-US/                     # iOS (deliver)
    name.txt                 # <= 30 chars
    subtitle.txt             # <= 30 chars
    keywords.txt             # <= 100 chars, comma-separated
    description.txt          # <= 4000 chars
    promotional_text.txt     # <= 170 chars
    release_notes.txt
    support_url.txt
    marketing_url.txt
    privacy_url.txt
  es-419/                    # iOS (deliver)
  review_information/        # App Review contact + demo account (FILL BEFORE SUBMIT)
  android/
    en-US/                   # Play (supply)
      title.txt              # <= 30 chars
      short_description.txt  # <= 80 chars
      full_description.txt   # <= 4000 chars
      changelogs/<versionCode>.txt  # <= 500 chars
    es-419/
```

Screenshots live in `../screenshots/<locale>/` (captured from the simulator).

## Play preview assets (`android/<loc>/images/`)

Format rules that Play enforces (a violated rule blocks the upload):

- `icon.png` — 512×512, 32-bit PNG **with alpha**, ≤ 1 MB.
- `featureGraphic.png` — 1024×500, 24-bit PNG **no alpha**, ≤ 15 MB.
- `phoneScreenshots/*.png` — **no alpha**, each side 320–3840 px, and the
  longest side **≤ 2× the shortest**; use **1080×1920 (9:16)** (also the size
  Play needs to consider them for promotion, min 1080 px per side).

The UI is Spanish-only (the app forces `Locale('es')`), so both locales carry
the same captures. Captures are real Android app screens (device/emulator, adb
`exec-out screencap`). A modern phone is ~9:20 (2.2:1), which Play rejects, so
normalize each to **1080×1920 (9:16)** by scaling to full height and padding the
sides black (the app background is black, so the pad is invisible) and strip
alpha. Prefer a **9:16 capture profile** (Pixel 2 / Nexus 5X 1080×1920, Nexus 6P
1440×2560) to skip the pad.

```sh
# each capture -> 1080x1920, rgb24 (strip alpha); `scale=-2:1920` keeps aspect
for loc in en-US es-419; do
  d=fastlane/metadata/android/$loc/images/phoneScreenshots
  ffmpeg -y -i <capture>.png \
    -vf "scale=-2:1920:flags=lanczos,pad=1080:1920:(ow-iw)/2:0:color=black" \
    -pix_fmt rgb24 "$d/<n>-<name>.png"
done
# icon -> 512x512 RGBA (opaque alpha channel)
for f in fastlane/metadata/android/*/images/icon.png; do
  ffmpeg -y -i "$f" -vf "scale=512:512" -pix_fmt rgba "$f.tmp.png" \
    && mv "$f.tmp.png" "$f"
done
```

## Canonical URLs (served by the Samay public site)

- Privacy:   https://samay.qallariy.lat/privacy
- Terms:     https://samay.qallariy.lat/terms
- Support:   https://samay.qallariy.lat/support
- Marketing: https://samay.qallariy.lat

## TODO(owner)

- `review_information/*`: real App Review contact + demo account.
- `es-419` locale code: confirm the store-accepted value (Play uses `es-419`;
  App Store Connect may prefer `es-ES`/`es-MX`).
