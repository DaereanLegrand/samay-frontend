import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final bool authenticated;
  final bool loading;
  final Map<String, dynamic>? user;

  const AuthState({
    this.authenticated = false,
    this.loading = false,
    this.user,
  });

  AuthState copyWith({bool? authenticated, bool? loading, Map<String, dynamic>? user}) {
    return AuthState(
      authenticated: authenticated ?? this.authenticated,
      loading: loading ?? this.loading,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(loading: true);
    try {
      state = state.copyWith(authenticated: true, loading: false, user: {});
    } catch (e) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> signUp(String email, String password) async {
    state = state.copyWith(loading: true);
    try {
      state = state.copyWith(authenticated: true, loading: false, user: {});
    } catch (e) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> signOut() async {
    state = const AuthState();
  }

  Future<void> deleteAccount() async {
    state = const AuthState();
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
