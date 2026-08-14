# Phase 02 — Flutter App Foundation (FLUT + DSNG + STAT + ROUT + SBAS + STOR)

## Date: 2026-05-11

## Overview
Build the complete Flutter app foundation: project scaffolding, design system, state management, navigation, Supabase client, and local storage. All steps in a single day since they share the same dependency chain.

## Steps Completed
1. FLUT — Flutter project scaffolding
2. DSNG — Design system & theme
3. STAT — Riverpod state management
4. ROUT — GoRouter navigation
5. SBAS — Supabase client integration
6. STOR — Local storage

---

### FLUT — Flutter Project Scaffolding

**What was built:**
- `flutter create` with package `com.qallariy.samay`
- `pubspec.yaml` with all MVP dependencies
- Folder structure: `lib/core/{theme,config,router,services}/`, `lib/features/{auth,profile,...}/`, `lib/shared/{widgets,models,providers}/`
- `lib/main.dart` with Hive + Supabase initialization scaffold
- `lib/app.dart` with MaterialApp + GoRouter + Riverpod

**MISTAKE:** `flutter create` with `--org com.qallariy` produces `com.qallariy.samay` but the initial `flutter create` command must be run outside the project directory. Created in `/tmp` and moved.

**Tests:**
- `test/widget_test.dart` — basic app renders test
- `test/pubspec_test.dart` — verifies all required dependencies exist
- `test/structure_test.dart` — verifies folder structure

### DSNG — Design System & Theme

**What was built:**
- `lib/core/theme/app_theme.dart` — ThemeData with black/white color scheme, custom TextTheme (Inter font, bold headlines, light body), AppBarTheme, BottomNavigationBarTheme
- `lib/core/theme/samay_durations.dart` — fast/standard/slow duration constants
- `lib/shared/widgets/v_button.dart` — VButton (outlined + emphasized)
- `lib/shared/widgets/v_card.dart` — VCard (sharp corners, gray border)
- `lib/shared/widgets/v_input.dart` — VInput (underline style)
- `lib/shared/widgets/v_chip.dart` — VChip
- `lib/shared/widgets/v_badge.dart` — VBadge
- `lib/shared/widgets/v_shard_icon.dart` — VShardIcon

**Decisions:**
- Single sans-serif family via Google Fonts Inter, with system fallback
- Theme doesn't reference GoogleFonts directly (avoids network dep) — uses `fontFamily: 'Inter',` with a fallback to system sans-serif
- All component widgets are `const`-constructable

### STAT — Riverpod State Management

**What was built:**
- `lib/core/providers/auth_provider.dart` — AuthNotifier + authStateProvider
- `lib/core/providers/user_provider.dart` — currentUserProvider
- `lib/core/providers/config_provider.dart` — appConfigProvider
- `lib/shared/providers/realtime_provider.dart` — StreamProvider helpers

### ROUT — GoRouter Navigation

**What was built:**
- `lib/core/router/app_router.dart` — full GoRouter with auth redirect guard, ShellRoute for bottom nav, all routes per spec
- `lib/core/router/auth_guard.dart` — redirect logic

### SBAS — Supabase Client Integration

**What was built:**
- `lib/core/services/supabase_service.dart` — SupabaseService class with Auth, Users, Events, Friends, Groups, Chat, Photos, Notifications, Shards, Reports, Config, Realtime subscriptions, Edge Function calls

### STOR — Local Storage

**What was built:**
- `lib/core/services/storage_service.dart` — SecureStorageService (JWT tokens) + HiveService (config cache, photo cache, message cache, notification cache)

---

## Decisions Made
- **Single `lib/core/services/` directory** for Supabase and Storage instead of splitting into separate service dirs
- **ProviderTestWidget** extension on `ProviderContainer` for easy test override patterns
- **Realtime stream pattern**: single `RealtimeService` inside SupabaseService rather than a separate class
- **All widget tests** use `ProviderScope` wrapper to avoid "no ProviderContainer" errors

## MISTAKE: `flutter create` org flag
`flutter create --org com.samay` output dir defaults to `samay` inside the parent. Had to create in `/tmp` then copy over.

## MISTAKE: GoRouter `redirect` loop
Initial redirect guard didn't use `_isAuthenticated` check properly, causing infinite redirect loops. Fixed by checking auth state before redirecting to `/login`.

## Commands Run
```bash
# PREP
mkdir -p docs/history/phase-02

# FLUT
mkdir -p /tmp/samay-flutter-temp
cd /tmp/samay-flutter-temp && flutter create --org com.samay --project-name samay_app .
# Moved lib/, test/, pubspec.yaml, analysis_options.yaml to project root
rm -rf /tmp/samay-flutter-temp

flutter pub get
flutter test

# VALIDATE
cd /home/daerean/Codes/apps/Samay && flutter test
go test ./...
```

## Validation Gate
- [x] All Flutter tests pass
- [x] `dart analyze` passes (0 issues)
- [x] All Go tests still pass
- [x] Spec docs satisfied
- [x] Cross-references updated
- [x] Daily log written

## Next Steps
**Phase 03 — Auth & Profiles**: AUTH (signup/login screens), PRFL (profile screen), DELE (account deletion)
