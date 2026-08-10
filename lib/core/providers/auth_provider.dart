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
import 'package:samay/core/services/supabase_service.dart';
import 'package:samay/core/services/telemetry_service.dart';
import 'package:samay/core/utils/async_ops.dart';

/// Legacy facade provider (I-09 seam, kept for feature agents migrating off
/// `SupabaseService.instance`; new code should use the decomposed service
/// providers in `lib/core/providers/service_providers.dart`).
final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => SupabaseService.instance,
);

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
    _authSubscription = _service.onAuthStateChange.listen(
      _onAuthStateChange,
    );
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
        return _authStateForUser(user, forceBanCheck: true);
      }
    } catch (e, st) {
      AppLogger.instance.error('checkInitialSession error: $e', '$st');
    }
    return const AuthState();
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
          // 30 s cache window on a long-lived session.
          state = AsyncData(
            await _authStateForUser(user, forceBanCheck: false),
          );
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
          state = AsyncData(
            await _authStateForUser(user, forceBanCheck: true),
          );
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
  Future<AuthState> _authStateForUser(
    Map<String, dynamic> user, {
    bool forceBanCheck = false,
  }) async {
    var status = BanStatus.notBanned;
    try {
      status = await ref.read(banServiceProvider).checkBanStatus(force: forceBanCheck);
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
    return AuthState(
      authenticated: true,
      hasProfile: hasProfile,
      user: user,
    );
  }

  Future<bool> _userHasProfile(Map<String, dynamic> user) async {
    final uid = user['id'] as String?;
    if (uid == null) return false;
    return _service.userHasProfile(uid);
  }

  /// Returns 'signup' if email is available (new or cleaned up), 'exists' if fully registered.
  Future<String> checkEmail(String email) async {
    try {
      return await _service.checkSignupEmail(email);
    } catch (e, st) {
      AppLogger.instance.error('checkEmail error: $e', '$st');
      return 'signup';
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWithPrevious(const AsyncLoading());
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
    state = state.copyWithPrevious(const AsyncLoading());
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
      state = AsyncError(e.toAppError(), st);
    }
  }

  Future<void> verifyOtp(String email, String token, [String? password]) async {
    state = state.copyWithPrevious(const AsyncLoading());
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
    state = state.copyWithPrevious(const AsyncLoading());
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
    state = state.copyWithPrevious(const AsyncLoading());
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
    await _service.signOut();
    state = const AsyncData(AuthState());
  }

  Future<void> deleteAccount() async {
    await _service.softDeleteUser();
    await _service.signOut();
    state = const AsyncData(AuthState());
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
