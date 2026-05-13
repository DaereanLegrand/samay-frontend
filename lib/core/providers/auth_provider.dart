import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vive_app/core/services/supabase_service.dart';

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
  AuthNotifier() : super(const AuthState()) {
    _checkSession();
  }

  void _checkSession() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user != null) {
        final uid = user['id'] as String?;
        bool hasProfile = false;
        if (uid != null) {
          final res = await SupabaseService.instance.client
              .from('users')
              .select('id')
              .eq('id', uid)
              .maybeSingle();
          hasProfile = res != null;
        }
        state = AuthState(
          authenticated: true,
          hasProfile: hasProfile,
          user: user,
        );
      }
    } catch (_) {}
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await SupabaseService.instance.signIn(email, password);
      final user = SupabaseService.instance.getCurrentUser();
      state = AuthState(authenticated: true, user: user);
    } catch (e) {
      state = state.copyWith(loading: false, authenticated: false, error: e.toString());
    }
  }

  Future<void> sendOtp(String email) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await SupabaseService.instance.sendOtp(email);
      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, authenticated: false, error: e.toString());
    }
  }

  Future<void> verifyOtp(String email, String token) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await SupabaseService.instance.verifyOtp(email, token);
      final user = SupabaseService.instance.getCurrentUser();
      state = AuthState(authenticated: true, user: user);
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
