import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:samay/core/services/supabase_service.dart';

class AuthState {
  final bool authenticated;
  final bool loading;
  final bool hasProfile;
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({
    this.authenticated = false,
    this.loading = false,
    this.hasProfile = false,
    this.user,
    this.error,
  });

  AuthState copyWith({bool? authenticated, bool? loading, bool? hasProfile, Map<String, dynamic>? user, String? error}) {
    return AuthState(
      authenticated: authenticated ?? this.authenticated,
      loading: loading ?? this.loading,
      hasProfile: hasProfile ?? this.hasProfile,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  StreamSubscription<dynamic>? _authSubscription;

  AuthNotifier() : super(const AuthState(loading: true)) {
    _authSubscription = SupabaseService.instance.auth.onAuthStateChange.listen(
      _onAuthStateChange,
    );
    _checkInitialSession();
  }

  void _checkInitialSession() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user != null) {
        final hasProfile = await _userHasProfile(user);
        state = AuthState(authenticated: true, hasProfile: hasProfile, user: user);
        return;
      }
    } catch (_) {}
    state = const AuthState();
  }

  void _onAuthStateChange(dynamic event) async {
    final session = event.session;
    switch (event.event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
        if (session?.user != null) {
          final user = session!.user.toJson();
          final hasProfile = await _userHasProfile(user);
          state = AuthState(authenticated: true, hasProfile: hasProfile, user: user);
        } else {
          state = const AuthState();
        }
        break;
      case AuthChangeEvent.signedOut:
        state = const AuthState();
        break;
      case AuthChangeEvent.userUpdated:
        if (session?.user != null) {
          state = state.copyWith(user: session!.user.toJson());
        }
        break;
      case AuthChangeEvent.passwordRecovery:
        break;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _userHasProfile(Map<String, dynamic> user) async {
    final uid = user['id'] as String?;
    if (uid == null) return false;
    try {
      final res = await SupabaseService.instance.client
          .from('users')
          .select('id')
          .eq('id', uid)
          .maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  /// Returns 'signup' if email is available (new or cleaned up), 'exists' if fully registered.
  Future<String> checkEmail(String email) async {
    try {
      return await SupabaseService.instance.checkSignupEmail(email);
    } catch (_) {
      return 'signup';
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await SupabaseService.instance.signIn(email, password);
      final user = SupabaseService.instance.getCurrentUser();
      final hasProfile = user != null ? await _userHasProfile(user) : false;
      state = AuthState(authenticated: true, hasProfile: hasProfile, user: user);
    } catch (e) {
      state = state.copyWith(loading: false, authenticated: false, error: e.toString());
    }
  }

  Future<void> sendOtp(String email) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await SupabaseService.instance.sendOtp(email);
      await SupabaseService.instance.upsertSignupTracker(email, false);
      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, authenticated: false, error: e.toString());
    }
  }

  Future<void> verifyOtp(String email, String token, [String? password]) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await SupabaseService.instance.verifyOtp(email, token);
      if (password != null && password.isNotEmpty) {
        await SupabaseService.instance.auth.updateUser(
          UserAttributes(password: password),
        );
      }
      final user = SupabaseService.instance.getCurrentUser();
      final hasProfile = user != null ? await _userHasProfile(user) : false;
      state = AuthState(authenticated: true, hasProfile: hasProfile, user: user);
    } catch (e) {
      await SupabaseService.instance.signOut();
      state = state.copyWith(loading: false, authenticated: false, error: e.toString());
    }
  }

  Future<void> signUp(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await SupabaseService.instance.signUp(email, password);
      final user = SupabaseService.instance.getCurrentUser();
      if (user != null) {
        state = AuthState(authenticated: true, user: user);
      } else {
        state = state.copyWith(loading: false);
      }
    } catch (e) {
      state = state.copyWith(loading: false, authenticated: false, error: e.toString());
    }
  }

  Future<void> createProfile(String username, {String? dateOfBirth}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await SupabaseService.instance.createUserProfile(
        username: username,
        dateOfBirth: dateOfBirth,
      );
      state = state.copyWith(loading: false, hasProfile: true);
    } catch (e) {
      state = state.copyWith(loading: false, authenticated: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await SupabaseService.instance.signOut();
    state = const AuthState();
  }

  Future<void> deleteAccount() async {
    await SupabaseService.instance.softDeleteUser();
    await SupabaseService.instance.signOut();
    state = const AuthState();
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
