# TODO — samay-frontend

## Facts
- Flutter app `samay` (`com.qallariy.samay`). Split from `Samay`.
- Makefile is Flutter-only; `guard-local` gates local-only releases.
- CI: `.gitea/workflows/ci.yml`. iOS `PrivacyInfo.xcprivacy` wired into the Runner target.

## TODO
- [x] Prune cross-brand refs; `welcomeVive`→`welcomeSamay` (see <private-ops-repo>/REPO-AUDIT.md).
- [ ] Prune stale the reference app references (lib/ services + docs).
- [ ] Rename stale l10n key `welcomeSamay`.
- [ ] Trim README backend/infra sections (belong to samay-backend / <private-ops-repo>).
- [ ] Add `fastlane/metadata/` store copy + screenshots.
- [ ] Comment prune (lib/, docs/).
- [ ] TODO(vault): android keystore + Play service account + FCM; Apple ASC keys.
