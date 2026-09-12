import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/auth_service.dart';
import 'package:samay/core/services/ban_service.dart';
import 'package:samay/core/services/crash_reporter.dart';
import 'package:samay/core/services/telemetry_service.dart';
import 'package:samay/core/utils/async_ops.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';

class AuthState {
  final bool authenticated;
  final bool hasProfile;
  final bool banned;
  final String? banReason;
  final Map<String, dynamic>? user;

  const AuthState({
    this.authenticated = false,
    this.hasProfile = false,
    this.banned = false,
    this.banReason,
    this.user,
  });

  AuthState copyWith({
    bool? authenticated,
    bool? hasProfile,
    bool? banned,
    String? banReason,
    Map<String, dynamic>? user,
  }) {
    return AuthState(
      authenticated: authenticated ?? this.authenticated,
      hasProfile: hasProfile ?? this.hasProfile,
      banned: banned ?? this.banned,
      banReason: banReason ?? this.banReason,
      user: user ?? this.user,
    );
  }
}

/// Convenience view over the auth [AsyncValue] for consumers: exposes the
/// user-facing error message (already mapped through [AppError]) without
/// leaking raw exceptions into widgets.
extension AuthAsyncValueX on AsyncValue<AuthState> {
  String? get errorMessage {
    final err = error;
    if (err == null) return null;
    return err is AppError ? err.message : err.toString();
  }
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  StreamSubscription<dynamic>? _authSubscription;

  AuthService get _service => ref.read(authServiceProvider);

  @override
  Future<AuthState> build() async {
    await _authSubscription?.cancel();
    _authSubscription = _service.onAuthStateChange.listen(_onAuthStateChange);
    ref.onDispose(() => _authSubscription?.cancel());
    return _resolveInitialState();
  }

  /// Reloads the initial session state (SM-09 refresh pattern).
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Explicitly renews the access token (SEC-04 / H-22): callers that need a
  /// fresh session now (e.g. before a long-lived operation) use this instead
  /// of waiting for the SDK's auto-refresh. [AuthService] swallows transport
  /// errors and returns null, so both a thrown refresh and a revoked/expired
  /// refresh token land here as an unauthenticated state — never a silently
  /// stale session. The SDK's own refresh is covered by the `tokenRefreshed`
  /// event path in [_onAuthStateChange].
  Future<void> refreshSession() async {
    final user = await _service.refreshSession();
    if (user == null) {
      AppLogger.instance.warn(
        'refreshSession() returned no user — session expired, '
        'transitioning to unauthenticated',
      );
      state = const AsyncData(AuthState());
      return;
    }
    state = AsyncData(await _authStateForUser(user));
  }

  Future<AuthState> _resolveInitialState() async {
    try {
      final user = _service.getCurrentUser();
      if (user != null) {
        final state = await _authStateForUserSafe(user, forceBanCheck: true);
        final resolved = await _orphanGate(user, state);
        if (!resolved.authenticated) return resolved;
        await _ensureE2eeKeysPublished(uid: user['id'] as String?);
        return resolved;
      }
    } catch (e, st) {
      AppLogger.instance.error('checkInitialSession error: $e', '$st');
    }
    return const AuthState();
  }

  /// Orphan-session gate (2026-09-01): an authenticated [user] with NO
  /// `users` row is an account that no longer exists on the server (backend
  /// reset, account deletion, admin wipe). The profile probe must NOT
  /// masquerade as the signup funnel — the funnel is only ever entered
  /// EXPLICITLY (OTP → age gate). Sign out and return unauthenticated instead
  /// of surfacing an `authenticated && !hasProfile` state to the router (which
  /// previously flashed the feed, or — before the guard change — bounced to
  /// the birthdate screen).
  Future<AuthState> _orphanGate(
    Map<String, dynamic> user,
    AuthState state,
  ) async {
    if (!state.authenticated || state.hasProfile) return state;
    AppLogger.instance.warn(
      'session has no profile row (uid=${user['id']}) — orphan session, '
      'signing out to the login screen',
    );
    await _service.signOut();
    return const AuthState();
  }

  /// [_authStateForUser] for paths with no UI to surface an error
  /// (initial-session restore, auth-state listener events).
  ///
  /// No-fallback policy (2026-08-13): when the profile/ban probe fails here,
  /// the user must NOT be bounced anywhere — the guard no longer redirects on
  /// `hasProfile`, so staying put is explicit and safe. Log the failure and
  /// keep the previous state; never navigate, never sign out.
  Future<AuthState> _authStateForUserSafe(
    Map<String, dynamic> user, {
    bool forceBanCheck = false,
  }) async {
    try {
      return await _authStateForUser(user, forceBanCheck: forceBanCheck);
    } catch (e, st) {
      AppLogger.instance.error(
        'auth state probe failed (staying put): $e',
        '$st',
      );
      return state.valueOrNull ?? const AuthState();
    }
  }

  void _onAuthStateChange(dynamic event) async {
    final session = event.session;
    switch (event.event) {
      case AuthChangeEvent.tokenRefreshed:
        // SEC-04 / H-22 (I-30): a refresh that yields no session (expired or
        // revoked refresh token) must not silently keep a stale session —
        // transition to unauthenticated so the router redirects to login.
        if (session?.user != null) {
          final user = session!.user.toJson();
          // Cache-aware ban check (I-35): a ban lands at worst within the
          // 30 s cache window on a long-lived session. A refresh that surfaces
          // a profile-less user is an orphan (see [_orphanGate]).
          final resolved = await _orphanGate(
            user,
            await _authStateForUserSafe(user, forceBanCheck: false),
          );
          state = AsyncData(resolved);
        } else {
          AppLogger.instance.warn(
            'tokenRefreshed fired without a session — refresh failed, '
            'transitioning to unauthenticated',
          );
          state = const AsyncData(AuthState());
        }
        break;
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
        if (session?.user != null) {
          final user = session!.user.toJson();
          final resolved = await _orphanGate(
            user,
            await _authStateForUserSafe(user, forceBanCheck: true),
          );
          state = AsyncData(resolved);
          if (resolved.authenticated) {
            await _ensureE2eeKeysPublished(uid: user['id'] as String?);
          }
        } else {
          state = const AsyncData(AuthState());
        }
        break;
      case AuthChangeEvent.signedOut:
        // A ban sign-out emits `signedOut`; keep the banned flag so the guard
        // keeps the user on the ban screen instead of bouncing to login.
        final prev = state.valueOrNull;
        state = AsyncData(
          prev != null && prev.banned ? prev : const AuthState(),
        );
        break;
      case AuthChangeEvent.userUpdated:
        if (session?.user != null) {
          final current = state.valueOrNull;
          state = AsyncData(
            current == null
                ? AuthState(user: session!.user.toJson())
                : current.copyWith(user: session!.user.toJson()),
          );
        }
        break;
      case AuthChangeEvent.passwordRecovery:
        break;
    }
  }

  /// Builds the authenticated [AuthState] for [user], enforcing the ban gate.
  ///
  /// When `users.banned_at` is set the session is signed out and the returned
  /// state carries `banned: true` + the stored reason, so [AuthGuard] can
  /// redirect every route to the ban screen. The check is fail-open: if it
  /// cannot run, authentication proceeds (the authoritative enforcement is
  /// server-side).
  ///
  /// The profile probe (`users` row) PROPAGATES errors (no-fallback policy
  /// 2026-08-13): explicit callers (signIn, verifyOtp, signUp) catch and
  /// surface them; the listener/initial-restore paths use
  /// [_authStateForUserSafe] which logs and stays put — never a silent
  /// "no profile" that would redirect the user elsewhere.
  Future<AuthState> _authStateForUser(
    Map<String, dynamic> user, {
    bool forceBanCheck = false,
  }) async {
    var status = BanStatus.notBanned;
    try {
      status = await ref
          .read(banServiceProvider)
          .checkBanStatus(force: forceBanCheck);
    } catch (e, st) {
      AppLogger.instance.error('ban check failed: $e', '$st');
    }
    if (status.isBanned) {
      AppLogger.instance.warn(
        'Banned user attempted to authenticate (${user['id']}), signing out',
      );
      try {
        await _service.signOut();
      } catch (e, st) {
        AppLogger.instance.error('signOut after ban error: $e', '$st');
      }
      return AuthState(banned: true, banReason: status.reason);
    }
    // I-70: crash-reporter user context — scrubbed (SHA-256) by the reporter,
    // never PII. One line covering every authenticated transition: initial
    // restore, signIn, verifyOtp, signUp-via-auth-event, tokenRefreshed.
    unawaited(ref.read(crashReporterProvider).setUser(user['id'] as String?));
    final hasProfile = await _userHasProfile(user);
    return AuthState(authenticated: true, hasProfile: hasProfile, user: user);
  }

  Future<bool> _userHasProfile(Map<String, dynamic> user) async {
    final uid = user['id'] as String?;
    if (uid == null) return false;
    return _service.userHasProfile(uid);
  }

  /// Returns 'signup' if email is available (new or cleaned up), 'exists' if
  /// fully registered. Errors PROPAGATE (no-fallback policy 2026-08-13): a
  /// failed check must never silently degrade to 'signup' and push the
  /// funnel forward — the signup screen surfaces the error instead.
  Future<String> checkEmail(String email) async {
    return _service.checkSignupEmail(email);
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      await resilient(
        () => _service.signIn(email, password),
        timeout: const Duration(seconds: 5),
        maxRetries: 2,
        initialDelay: const Duration(seconds: 1),
      );
      final user = _service.getCurrentUser();
      if (user == null) {
        // The signedIn event listener may already have handled a ban
        // sign-out; keep whatever state it produced.
        state = AsyncData(state.valueOrNull ?? const AuthState());
        return;
      }
      state = AsyncData(await _authStateForUser(user, forceBanCheck: true));
      // I-68: telemetry — a completed sign-in with a user. No PII is ever
      // attached (SECURITY.md §2.8); the stub mode logs the event name only.
      ref.read(telemetryServiceProvider).track('auth_sign_in');
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
    }
  }

  Future<void> sendOtp(String email) async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      await resilient(
        () => _service.sendOtp(email),
        timeout: const Duration(seconds: 5),
        maxRetries: 2,
        initialDelay: const Duration(seconds: 1),
      );
      await resilient(
        () => _service.upsertSignupTracker(email, false),
        timeout: const Duration(seconds: 5),
        maxRetries: 2,
        initialDelay: const Duration(seconds: 1),
      );
      state = AsyncData(state.valueOrNull ?? const AuthState());
    } catch (e, st) {
      // Rethrow on purpose: the contact screen NAVIGATES on sendOtp success,
      // so a swallowed error would land the user on the OTP screen with a
      // stale error (the pre-OTP signup_tracker write used to 42501 into
      // "No tienes permiso para realizar esta acción."). Rethrowing keeps
      // the funnel on the contact screen with its blocking error dialog.
      state = AsyncError(e.toAppError(), st);
      rethrow;
    }
  }

  /// U-14 R3: requests the password-recovery email for [email] (GoTrue's
  /// anti-enumeration contract: the response never reveals whether the email
  /// has an account — the screen always lands on its success state).
  Future<void> resetPasswordForEmail(String email) async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      await resilient(
        () => _service.resetPasswordForEmail(email),
        timeout: const Duration(seconds: 5),
        maxRetries: 2,
        initialDelay: const Duration(seconds: 1),
      );
      state = AsyncData(state.valueOrNull ?? const AuthState());
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
    }
  }

  Future<void> verifyOtp(String email, String token, [String? password]) async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      await resilient(
        () => _service.verifyOtp(email, token),
        timeout: const Duration(seconds: 5),
        maxRetries: 2,
        initialDelay: const Duration(seconds: 1),
      );
      if (password != null && password.isNotEmpty) {
        await resilient(
          () => _service.updateUser({'password': password}),
          timeout: const Duration(seconds: 5),
          maxRetries: 2,
          initialDelay: const Duration(seconds: 1),
        );
      }
      final user = _service.getCurrentUser();
      if (user == null) {
        // Same as signIn: the signedIn event listener may already have
        // enforced a ban sign-out; keep its state.
        state = AsyncData(state.valueOrNull ?? const AuthState());
        return;
      }
      state = AsyncData(await _authStateForUser(user, forceBanCheck: true));
    } catch (e, st) {
      await _service.signOut();
      state = AsyncError(e.toAppError(), st);
    }
  }

  Future<void> signUp(String email, String password) async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      await _service.signUp(email, password);
      final user = _service.getCurrentUser();
      if (user != null) {
        state = AsyncData(AuthState(authenticated: true, user: user));
      } else {
        state = AsyncData(state.valueOrNull ?? const AuthState());
      }
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
    }
  }

  Future<void> createProfile(String username, {String? dateOfBirth}) async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      await resilient(
        () => _service.createUserProfile(
          username: username,
          dateOfBirth: dateOfBirth,
        ),
        timeout: const Duration(seconds: 5),
        maxRetries: 2,
        initialDelay: const Duration(seconds: 1),
      );
      await _ensureE2eeKeysPublished(force: true, uid: _service.getCurrentUser()?['id'] as String?);
      final current = state.valueOrNull ?? const AuthState();
      state = AsyncData(current.copyWith(hasProfile: true));
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    // E2EE §7.6 (Signal model, 2026-08-15): the identity + prekeys + chat
    // sessions SURVIVE a sign-out — the key material is bound to the
    // ACCOUNT, not the session. Only an account switch (ownership guard in
    // [_ensureE2eeKeysPublished]) or account deletion wipes it.
    state = const AsyncData(AuthState());
  }

  Future<void> deleteAccount() async {
    await _service.softDeleteUser();
    await _service.signOut();
    await _wipeE2eeMaterial();
    state = const AsyncData(AuthState());
  }

  /// E2EE §12.2 step 4 (auth lifecycle hooks — wired 2026-08-15): guarantees
  /// the account's prekey bundle exists on the server before any chat. A peer
  /// without a published bundle cannot receive a first message
  /// (`fetch_prekey_bundle` → null → X3DH cannot initiate), so:
  ///
  /// - `createProfile` publishes unconditionally (`force: true` — the row
  ///   cannot exist yet);
  /// - session restore / sign-in calls [E2eePrekeyService.handleMissingSession]
  ///   (idempotent) to heal legacy accounts created before this hook, and
  ///   republishes when the published identity differs from the local one.
  ///
  /// Account ownership (Signal model, 2026-08-15): the key material is bound
  /// to the FIRST account that uses this install. When a DIFFERENT account
  /// signs in, the previous material is wiped (identity, prekeys, sessions)
  /// so keys never cross accounts; a fresh install (no owner recorded)
  /// claims the current account.
  ///
  /// Best-effort by design: a publish failure must never block auth — the
  /// send-time bootstrap in `ChatService.sendMessage` remains as a backstop,
  /// and the next restore retries the heal.
  Future<void> _ensureE2eeKeysPublished({
    bool force = false,
    String? uid,
  }) async {
    if (uid != null) {
      final keys = ref.read(e2eeKeyStoreProvider);
      try {
        final owner = await keys.ownerUid();
        if (owner != null && owner != uid) {
          AppLogger.instance.warn(
            'e2ee ownership switch $owner → $uid — wiping previous key '
            'material (Signal model: keys are per-account)',
          );
          await _wipeE2eeMaterial();
        }
        if (owner != uid) {
          await keys.setOwnerUid(uid);
        }
      } catch (e, st) {
        AppLogger.instance.error('E2EE ownership check failed: $e', '$st');
      }
    }
    try {
      final prekeys = ref.read(e2eePrekeyServiceProvider);
      final stopwatch = Stopwatch()..start();
      if (force) {
        await prekeys.publishAll();
        AppLogger.instance.debug(
          'e2ee auth-hook publishAll done force=true '
          'ms=${stopwatch.elapsedMilliseconds}',
        );
      } else {
        await prekeys.handleMissingSession();
        AppLogger.instance.debug(
          'e2ee auth-hook handleMissingSession done '
          'ms=${stopwatch.elapsedMilliseconds}',
        );
      }
    } catch (e, st) {
      AppLogger.instance.error('E2EE prekey publish failed: $e', '$st');
    }
  }

  /// E2EE §7.6: wipes ALL device-local key material and chat sessions after
  /// account DELETION or an account SWITCH (identity keys, signed + one-time
  /// prekeys, every persisted session). Best-effort: a storage failure must
  /// never block the auth transition itself.
  Future<void> _wipeE2eeMaterial() async {
    try {
      await ref.read(e2eeKeyStoreProvider).wipeAll();
      await ref.read(e2eeSessionStoreProvider).wipeAll();
    } catch (e, st) {
      AppLogger.instance.error('E2EE key/session wipe failed: $e', '$st');
    }
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
