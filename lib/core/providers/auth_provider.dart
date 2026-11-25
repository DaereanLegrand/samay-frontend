import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/auth_service.dart';
import 'package:samay/core/services/ban_service.dart';
import 'package:samay/core/services/crash_reporter.dart';
import 'package:samay/core/services/push_service.dart';
import 'package:samay/core/utils/async_ops.dart';

class AuthState {
  final bool authenticated;
  final bool hasProfile;
  final bool banned;
  final String? banReason;
  final Map<String, dynamic>? user;

  /// True when the signed-in GoTrue user is an ANONYMOUS guest (slim build:
  /// the default state). A guest has a real `users` row — it is only the
  /// credential that is missing, so the account can later be upgraded in
  /// place by linking Apple/Google (same uid).
  final bool isGuest;
  /// True after GoTrue emits [AuthChangeEvent.passwordRecovery]; the guard
  /// confines the app to the reset screen until the new password is set.
  final bool passwordRecovery;

  const AuthState({
    this.authenticated = false,
    this.hasProfile = false,
    this.banned = false,
    this.banReason,
    this.user,
    this.isGuest = false,
    this.passwordRecovery = false,
  });

  AuthState copyWith({
    bool? authenticated,
    bool? hasProfile,
    bool? banned,
    String? banReason,
    Map<String, dynamic>? user,
    bool? isGuest,
    bool? passwordRecovery,
  }) {
    return AuthState(
      authenticated: authenticated ?? this.authenticated,
      hasProfile: hasProfile ?? this.hasProfile,
      banned: banned ?? this.banned,
      banReason: banReason ?? this.banReason,
      user: user ?? this.user,
      isGuest: isGuest ?? this.isGuest,
      passwordRecovery: passwordRecovery ?? this.passwordRecovery,
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

  /// Reloads the initial session state.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Explicitly renews the access token: callers that need a
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
        return resolved;
      }
    } catch (e, st) {
      AppLogger.instance.error('checkInitialSession error: $e', '$st');
    }
    return const AuthState();
  }

  /// Orphan-session gate: an authenticated [user] with NO
  /// `users` row is an account that no longer exists on the server (backend
  /// reset, account deletion, admin wipe). The profile probe must NOT
  /// masquerade as the signup funnel — the funnel is only ever entered
  /// EXPLICITLY (onboarding consent). Sign out and return unauthenticated
  /// instead of surfacing an `authenticated && !hasProfile` state to the
  /// router (which would bounce into the consent route with a stale session).
  Future<AuthState> _orphanGate(
    Map<String, dynamic> user,
    AuthState state,
  ) async {
    if (!state.authenticated || state.hasProfile) return state;
    // A GUEST with no `users` row is pre-onboarding, not an orphan: the
    // onboarding screen is about to create the profile via
    // `bootstrap_profile`. Only a credentialed account with no row is stale.
    if (user['is_anonymous'] == true) return state;
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
  /// No-fallback policy: when the profile/ban probe fails here,
  /// the user must NOT be bounced anywhere — the guard does not redirect on
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
        // a refresh that yields no session (expired or
        // revoked refresh token) must not silently keep a stale session —
        // transition to unauthenticated so the router redirects to login.
        if (session?.user != null) {
          final user = session!.user.toJson();
          // Cache-aware ban check: a ban lands at worst within the
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
        // A RESTORED session with no profile is a true orphan (backend reset /
        // account wipe): sign out. A FRESH sign-in (signedIn below) may be a
        // signup in progress, so it is never orphan-gated here.
        if (session?.user != null) {
          final user = session!.user.toJson();
          final resolved = await _orphanGate(
            user,
            await _authStateForUserSafe(user, forceBanCheck: true),
          );
          state = AsyncData(resolved);
          if (resolved.authenticated) {
              }
        } else {
          state = const AsyncData(AuthState());
        }
        break;
      case AuthChangeEvent.signedIn:
        // A fresh sign-in. OAuth (Google/Apple) auto-creates the auth user on
        // the id-token grant; OTP signup creates it on verification. Either way
        // the `users` row does NOT exist yet — that is "signup in progress",
        // not an orphan. Surface `authenticated && !hasProfile` so the router
        // walks the onboarding funnel (age gate → terms → profile setup). The
        // password path rejects a profile-less account explicitly (see
        // [signIn]); restored sessions are gated on initialSession / refresh.
        if (session?.user != null) {
          final user = session!.user.toJson();
          final resolved = await _authStateForUserSafe(
            user,
            forceBanCheck: true,
          );
          state = AsyncData(resolved);
          if (resolved.authenticated) {
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
        final prevRecovery = state.valueOrNull ?? const AuthState();
        state = AsyncData(prevRecovery.copyWith(passwordRecovery: true));
        break;
    }
  }

  /// Builds the authenticated [AuthState] for [user], enforcing the ban gate.
  ///
  /// When `users.banned_at` is set the returned state carries `banned: true`
  /// + the stored reason, so [AuthGuard] redirects every route to the ban
  /// screen. The SESSION IS KEPT so the user can open the appeals screen and
  /// submit a ban appeal (Q6); every other data path is still blocked by the
  /// server's active-user RLS/trigger. The check is fail-open: if it cannot
  /// run, authentication proceeds (the authoritative enforcement is
  /// server-side).
  ///
  /// The profile probe (`users` row) PROPAGATES errors (no-fallback policy):
  /// explicit callers (signIn, verifyOtp, signUp) catch and
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
        'Banned user attempted to authenticate (${user['id']}); '
        'keeping the session for the appeal flow',
      );
      return AuthState(
        authenticated: true,
        hasProfile: true,
        banned: true,
        banReason: status.reason,
        user: user,
      );
    }
    // crash-reporter user context — scrubbed (SHA-256) by the reporter,
    // never PII. One line covering every authenticated transition: initial
    // restore, signIn, verifyOtp, signUp-via-auth-event, tokenRefreshed.
    unawaited(ref.read(crashReporterProvider).setUser(user['id'] as String?));
    final hasProfile = await _userHasProfile(user);
    return AuthState(
      authenticated: true,
      hasProfile: hasProfile,
      user: user,
      isGuest: user['is_anonymous'] == true,
    );
  }

  Future<bool> _userHasProfile(Map<String, dynamic> user) async {
    final uid = user['id'] as String?;
    if (uid == null) return false;
    return _service.userHasProfile(uid);
  }

  /// Returns 'signup' if email is available (new or cleaned up), 'exists' if
  /// fully registered. Errors PROPAGATE: a
  /// failed check must never silently degrade to 'signup' and push the
  /// funnel forward — the signup screen surfaces the error instead.
  Future<String> checkEmail(String email) async {
    return _service.checkSignupEmail(email);
  }

  /// Onboarding entry (slim build): creates the anonymous session when there
  /// is none, then records the single 18+ / terms acceptance and creates the
  /// guest profile row (server-side, atomic).
  ///
  /// Throws on failure so the onboarding screen can show a blocking error; the
  /// router's guard is what actually navigates.
  Future<void> startGuestOnboarding({required String termsVersion}) async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      if (_service.getCurrentUser() == null) {
        await _service.signInAnonymously();
      }
      await _service.bootstrapProfile(termsVersion: termsVersion);
      final user = _service.getCurrentUser();
      if (user == null) throw const UnauthorizedError();
      state = AsyncData(await _authStateForUser(user, forceBanCheck: true));
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
      rethrow;
    }
  }

  /// Optional account upgrade: an existing guest already has a session, so
  /// Apple/Google LINK the identity onto it (same uid, progress kept). After a
  /// successful link the account is promoted out of guest state.
  Future<void> linkWithGoogle() async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      // AuthService decides link-vs-sign-in from the session's anonymity.
      await _service.signInWithGoogle();
      await _completeSocialSignIn();
    } on GoogleSignInException catch (e, st) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = AsyncData(state.valueOrNull ?? const AuthState());
        return;
      }
      state = AsyncError(e.toAppError(), st);
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
    }
  }

  Future<void> linkWithApple() async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      await _service.signInWithApple();
      await _completeSocialSignIn();
    } on SignInWithAppleAuthorizationException catch (e, st) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = AsyncData(state.valueOrNull ?? const AuthState());
        return;
      }
      state = AsyncError(e.toAppError(), st);
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
    }
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
      final resolved = await _authStateForUser(user, forceBanCheck: true);
      if (!resolved.hasProfile) {
        // Password sign-in implies a registered account. An auth user with no
        // `users` row is an orphan (backend reset / admin wipe) — NOT an OAuth
        // signup — so sign out and land on login instead of the funnel.
        AppLogger.instance.warn(
          'password sign-in with no profile row (uid=${user['id']}) — orphan '
          'session, signing out to the login screen',
        );
        await _service.signOut();
        state = const AsyncData(AuthState());
        return;
      }
      state = AsyncData(resolved);
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
    }
  }

  /// Native Google sign-in. A user-cancelled sheet is a no-op, not an error.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      await _service.signInWithGoogle();
      await _completeSocialSignIn();
    } on GoogleSignInException catch (e, st) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = AsyncData(state.valueOrNull ?? const AuthState());
        return;
      }
      state = AsyncError(e.toAppError(), st);
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
    }
  }

  /// Native Sign in with Apple. A user-cancelled sheet is a no-op.
  Future<void> signInWithApple() async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      await _service.signInWithApple();
      await _completeSocialSignIn();
    } on SignInWithAppleAuthorizationException catch (e, st) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = AsyncData(state.valueOrNull ?? const AuthState());
        return;
      }
      state = AsyncError(e.toAppError(), st);
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
    }
  }

  Future<void> _completeSocialSignIn() async {
    final user = _service.getCurrentUser();
    if (user == null) {
      state = AsyncData(state.valueOrNull ?? const AuthState());
      return;
    }
    state = AsyncData(await _authStateForUser(user, forceBanCheck: true));
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
      // stale error instead of the contact screen's blocking error dialog.
      state = AsyncError(e.toAppError(), st);
      rethrow;
    }
  }

  /// requests the password-recovery email for [email] (GoTrue's
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

  /// Sets a new password from the in-app recovery screen (the session was
  /// established by the recovery link). Clears the recovery flag on success.
  Future<void> updatePassword(String password) async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    try {
      await _service.updateUser({'password': password});
      final prev = state.valueOrNull ?? const AuthState();
      state = AsyncData(prev.copyWith(passwordRecovery: false));
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
      rethrow;
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

  Future<void> createProfile(String username, {required String dateOfBirth}) async {
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
      final current = state.valueOrNull ?? const AuthState();
      state = AsyncData(current.copyWith(hasProfile: true));
    } catch (e, st) {
      state = AsyncError(e.toAppError(), st);
    }
  }

  Future<void> signOut() async {
    // Push: drop the device token BEFORE the session ends (the RPC is
    // authenticated-only), so a signed-out device stops receiving pushes.
    // SEC-031: unregister never throws and always clears local token state.
    await _unregisterPush();
    await _service.signOut();
    // SEC-033: no prior account cache may remain readable after logout.
    await _purgeLocalData();
    state = const AsyncData(AuthState());
  }

  /// Explicit "Borrar datos locales" (Settings): signs out, revokes the push
  /// token and purges every local cache. The account itself is untouched.
  Future<void> clearLocalData() async {
    await _unregisterPush();
    await _service.signOut();
    await _purgeLocalData();
    state = const AsyncData(AuthState());
  }

  /// Q1 — erase immediately and irreversibly. There is no restore path.
  Future<void> deleteAccountNow() async {
    await _unregisterPush();
    await _service.purgeAccountNow();
    await _service.signOut();
    await _purgeLocalData();
    state = const AsyncData(AuthState());
  }

  Future<void> _unregisterPush() async {
    try {
      await ref.read(pushServiceProvider).unregister();
    } catch (e, st) {
      AppLogger.instance.warn('push unregister failed: $e', '$st');
    }
  }

  Future<void> _purgeLocalData() async {
    try {
      await ref.read(localDataPurgerProvider).purge();
    } catch (e, st) {
      AppLogger.instance.warn('local data purge failed: $e', '$st');
    }
  }

}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
