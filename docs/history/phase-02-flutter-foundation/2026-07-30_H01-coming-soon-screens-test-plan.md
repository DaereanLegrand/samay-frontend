# Test Plan — H-01: Replace Blank `Scaffold()` Placeholder Routes with Coming-Soon Screens

## Date: 2026-07-30

## Scope

Fix finding H-01 (`docs/to-fix/TODO.md`): 15 placeholder routes returning bare
`const Scaffold()` render black screens. Replace with a shared, design-consistent
"Próximamente" (`VComingSoonScreen`) widget. Routes stay registered (deep-link
shape per `ROUT` spec and NAV-01 fix guidance).

## 1. Static Checks

- [ ] `dart analyze` reports zero errors (info-level pre-existing warnings acceptable)
- [ ] `flutter test` — all existing tests still pass
- [ ] `grep -rn "const Scaffold()" lib/core/router/app_router.dart` → no matches
- [ ] All 15 placeholder route builders now construct `VComingSoonScreen` (or `GroupMembersScreen` for `/group/:groupId/members`)
- [ ] No changes outside `lib/`, `test/`, `docs/` (scope discipline)

## 2. Widget Tests — `test/widgets/v_coming_soon_test.dart`

- [ ] Renders the feature title in the AppBar
- [ ] Renders "Próximamente" headline
- [ ] Renders the feature description text
- [ ] Optional "Volver" button pops the navigator when present
- [ ] No "Volver" button when `showBackButton: false` (if the parameter exists)

## 3. Router Tests — `test/router/app_router_test.dart` (extend)

For each of the 15 routes below: build the router (with a test harness that
overrides `authStateProvider` if Supabase initialization is unavailable in tests —
follow existing repo patterns), `go()` to the path, pump, and assert the
"Próximamente" screen renders (e.g. `find.text('Próximamente')` or the
`VComingSoonScreen` type) — NOT a bare `Scaffold`:

| # | Path | Expected title |
|---|------|----------------|
| 1 | `/main/events` | Eventos |
| 2 | `/main/notifications` | Notificaciones |
| 3 | `/event/<uuid>` | Evento |
| 4 | `/event/<uuid>/edit` | Editar evento |
| 5 | `/event/<uuid>/invite` | Invitar |
| 6 | `/event/<uuid>/photos` | Fotos |
| 7 | `/event/<uuid>/collage` | Collage |
| 8 | `/event/<invite-token>` | Invitación |
| 9 | `/group/<uuid>/members` | Miembros (real `GroupMembersScreen` — renders member list or empty state, NOT a placeholder) |
| 10 | `/group/<uuid>/create-event` | Crear evento |
| 11 | `/chat/<uuid>` | Chat |
| 12 | `/qr/<uuid>` | QR |
| 13 | `/scanner/<uuid>` | Escáner |
| 14 | `/subscriptions` | Suscripciones |
| 15 | `/party-finder` | Party Finder |

Note: tests for `/main/events` and `/main/notifications` must verify the shell
bottom nav still renders alongside the coming-soon body.

## 4. Group Members Screen — `test/features/groups_screens_test.dart` (extend)

- [ ] `GroupMembersScreen` renders a loading state first
- [ ] Renders member list from mocked `getGroupMembers()` (username + role)
- [ ] Renders empty state ("No hay miembros") when no members

## 5. Regression

- [ ] `flutter test` full suite green (81 existing + new tests)
- [ ] `dart analyze` — no new issues
- [ ] Auth screens, group detail, friends flows untouched and their tests still pass

## 6. Documentation

- [ ] `docs/to-fix/TODO.md`: H-01 marked ✅
- [ ] `docs/specs/steps/cross-references.md`: "14 routes are empty `Scaffold()` stubs" known issue resolved/updated
- [ ] Daily log written per AGENTS.md format

## Out of Scope (document, do not fix)

- `/event/:inviteToken` route ordering: `/event/:eventId` is registered first, so
  the invite-token pattern currently never matches. Pre-existing NAV issue,
  belongs to Phase 05 (ECRT/EINV) work.
- `errorBuilder`, route constants, typed extras (NAV-02/03/04/06) — separate findings.
