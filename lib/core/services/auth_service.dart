import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/config_service.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication and account lifecycle (signup, OTP, session, profile row).
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11). The auth-state *listener* stays in
/// `AuthNotifier` (lib/core/providers/auth_provider.dart) — this service only
/// exposes the stream for wiring.
class AuthService {
  final SupabaseClient client;
  final ConfigService config;

  AuthService({required this.client, required this.config});

  GoTrueClient get auth => client.auth;

  /// Auth-state change stream (session changes, sign-in/out, token refresh).
  Stream<AuthState> get onAuthStateChange => auth.onAuthStateChange;

  /// Returns 'signup' when the email is available (new or cleaned up),
  /// 'exists' when fully registered.
  Future<String> checkSignupEmail(String email) async {
    final res = await client.rpc(
      'check_signup_email',
      params: {'p_email': email},
    );
    return res as String;
  }

  Future<void> upsertSignupTracker(String email, bool profileCreated) async {
    await client.rpc(
      'upsert_signup_tracker',
      params: {'p_email': email, 'p_profile_created': profileCreated},
    );
  }

  Future<void> signIn(String email, String password) async {
    await auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<void> sendOtp(String email) async {
    await auth.signInWithOtp(email: email);
  }

  /// Sends the password-recovery email (U-14 R3). GoTrue always answers
  /// success for a valid request shape — even when no account exists — so the
  /// screen never reveals which emails are registered.
  Future<void> resetPasswordForEmail(String email) async {
    await auth.resetPasswordForEmail(email);
  }

  Future<void> verifyOtp(String email, String token) async {
    await auth.verifyOTP(email: email, token: token, type: OtpType.email);
  }

  Map<String, dynamic>? getCurrentUser() {
    final user = auth.currentUser;
    if (user == null) return null;
    return user.toJson();
  }

  Future<Map<String, dynamic>?> refreshSession() async {
    try {
      final response = await auth.refreshSession();
      return response.session?.user.toJson();
    } catch (e, st) {
      AppLogger.instance.error('refreshSession error: $e', '$st');
      return null;
    }
  }

  Future<void> updateUser(Map<String, dynamic> patch) async {
    await auth.updateUser(
      UserAttributes(
        email: patch['email'] as String?,
        password: patch['password'] as String?,
        data: patch['data'] as Map<String, dynamic>?,
      ),
    );
  }

  Future<void> softDeleteUser() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client
        .from('users')
        .update({
          'deleted_at': DateTime.now().toIso8601String(),
          'username': 'deleted_user_${user.id}',
          'avatar_url': null,
          'bio': null,
        })
        .eq('id', user.id);
  }

  /// Whether a `users` row exists for [userId].
  ///
  /// Returns false when the row is absent (a legitimate pre-profile state).
  /// PostgREST/network errors PROPAGATE — the caller decides how to surface
  /// them (no-fallback policy 2026-08-13: an error must never masquerade as
  /// "no profile" and silently change the flow).
  Future<bool> userHasProfile(String userId) async {
    final res = await client
        .from('users')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return res != null;
  }

  Future<void> createUserProfile({
    required String username,
    String? avatarUrl,
    String? dateOfBirth,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final shards = await config.getSignupShardGrant();
    final now = DateTime.now().toIso8601String();

    await client.from('users').insert({
      'id': user.id,
      'username': InputSanitizer.sanitizeUsername(username),
      'avatar_url': avatarUrl,
      'date_of_birth': dateOfBirth,
      'bio': null,
      'banned_at': null,
      'ban_reason': null,
      'deleted_at': null,
      'personal_shards': shards,
      'preshards': 0,
      'subscription_tier': 'free',
      'subscription_expires_at': null,
      'created_at': now,
      'updated_at': now,
    });

    await client.from('shard_ledger').insert({
      'user_id': user.id,
      'delta': shards,
      'reason': 'admin_grant',
      'reference_id': null,
      'created_at': now,
    });

    final email = user.email;
    if (email != null) {
      await upsertSignupTracker(email, true);
    }
  }
}
