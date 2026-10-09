# TODO — samay-frontend

## Facts
- Flutter app `samay` (`com.qallariy.samay`). Split from `Samay`.
- Makefile is Flutter-only; `guard-local` gates local-only releases.
- CI: `.gitea/workflows/ci.yml`. iOS `PrivacyInfo.xcprivacy` wired into the Runner target.

## TODO
- [x] Prune cross-brand refs; `welcomeVive`→`welcomeSamay` (see <private-ops-repo>/REPO-AUDIT.md).
- [x] Per-env Android flavors (`dev`/`staging`/`prod`) + Firebase client config:
      testing committed/open, staging/prod vault-gated. Gum chooser in `make init`
      (testing/local/own). `<private-ops-repo>`.
- [ ] Prune stale the reference app references (lib/ services + docs).
- [ ] Rename stale l10n key `welcomeSamay`.
- [ ] Trim README backend/infra sections (belong to samay-backend / <private-ops-repo>).
- [ ] Add `fastlane/metadata/` store copy + screenshots.
- [ ] Comment prune (lib/, docs/).
- [ ] TODO(fastlane): prod iOS build passes the Web client id as the iOS client
      id (Makefile `TARGET=ios PROD=true`) — pass the real iOS client id.
- [ ] TODO(vault): android keystore + Play service account + FCM; Apple ASC keys
      + Gitea `match` repo password. Acquisition order:
      `<private-ops-repo>/KEY-ACQUISITION.md`.
- [~] TODO(frontend): testing GoTrue provider + remaining testing backend
      secrets (`qallariy/samay/testing/**`).
