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

## Canonical URLs (served by the Samay public site)

- Privacy:   https://samay.qallariy.lat/privacy
- Terms:     https://samay.qallariy.lat/terms
- Support:   https://samay.qallariy.lat/support
- Marketing: https://samay.qallariy.lat

## TODO(owner)

- `review_information/*`: real App Review contact + demo account.
- `es-419` locale code: confirm the store-accepted value (Play uses `es-419`;
  App Store Connect may prefer `es-ES`/`es-MX`).
