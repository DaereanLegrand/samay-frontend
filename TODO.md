# TODO — samay-frontend

## Facts
- Split from `Vive` (monorepo) with full history; Flutter app `samay`.
- Bundle id `com.qallariy.samay`.

## TODO
- [ ] Remove infra/VM targets from `Makefile` (supabase-prod-*, <source-host>-*,
      ci-*, mail-*, release*); they now live in `<private-ops-repo>`.
- [ ] Vendor missing app-local scripts referenced by `Makefile`:
      `tools/check_secrets.sh`, `tools/hooks/`, `tools/xcode_login.py`,
      `<tunnel-host-helper>`.
- [ ] Fix stale `../Juega` references in `Makefile` and
      `lib/{core,shared}/services/*`.
- [ ] Rename stale `welcomeVive` l10n key to a brand-neutral name.
- [ ] Prune `docs/history/` operational entries or point them at `<private-ops-repo>`.
