# Test Plan — H-02: RoutePaths Constants Class (NAV-02)

## Date: 2026-07-31

## Scope

Eliminate raw string route paths from navigation. All route paths live in a single
`RoutePaths` constants class (`lib/core/router/route_paths.dart`); feature files,
route definitions, and the auth guard reference it. Path values must NOT change.

## 1. Static Checks

- [ ] `dart analyze` reports zero errors (info-level pre-existing warnings allowed)
- [ ] No raw string route literals remain in `lib/` outside `route_paths.dart`
      (grep for `context.push('/`, `context.go('/`, `path: '/'` in feature/router files)

## 2. Unit Tests (new `test/router/route_paths_test.dart`)

- [ ] `RoutePaths` exposes every route used by the app (all 23 static + 15 builders)
- [ ] All static constants are non-empty and start with `/`
- [ ] Builder methods interpolate correctly:
      `groupDetail('g1') == '/group/g1'`, `eventDetail('e1') == '/event/e1'`,
      `userProfile('u1') == '/user/u1'`, `chat('c1') == '/chat/c1'`,
      `qr('e1') == '/qr/e1'`, `scanner('e1') == '/scanner/e1'`,
      `eventInviteToken('t1') == '/event/t1'`, `donateToGroup('g1') == '/group/g1/donate'`,
      `createGroupEvent('g1') == '/group/g1/create-event'`,
      `inviteToGroup('g1') == '/group/g1/invite'`,
      `groupMembers('g1') == '/group/g1/members'`,
      `eventEdit('e1') == '/event/e1/edit'`, `eventInvite('e1') == '/event/e1/invite'`,
      `eventPhotos('e1') == '/event/e1/photos'`, `eventCollage('e1') == '/event/e1/collage'`

## 3. Router Coherence Tests (`test/router/app_router_test.dart`)

- [ ] Every `RoutePaths` static value and built path resolves to a registered route
      (pumping it renders a screen, never the error page)
- [ ] Existing navigation tests still pass using `RoutePaths` references

## 4. Regression

- [ ] The set of path values before/after the change is identical (no route renamed)
- [ ] `flutter test` — all existing tests pass (81+ tests)
- [ ] Auth guard behavior unchanged (public routes, redirect targets identical)

## 5. Documentation

- [ ] `docs/to-fix/TODO.md`: H-02 marked ✅
- [ ] Daily log written to
      `docs/history/phase-02-flutter-foundation/2026-07-31_H02-route-paths.md`
      covering what was built, decisions, mistakes, commands run
