import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/models/user_profile.dart';
import 'package:samay/core/services/config_service.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication and account lifecycle (signup, OTP, session, profile row).
///
/// The auth-state *listener* stays in
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

  /// Google OAuth client id (public), injected at build time via
  /// `--dart-define` from the vault (`public/google-oauth-client-id`). No
  /// fallback: an unconfigured build fails loudly instead of silently
  /// downgrading the flow.
  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
  );

  /// iOS Google OAuth client id (public), required by the native iOS flow.
  static const String _googleIosClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_IOS_CLIENT_ID',
  );

  static bool _googleInitialized = false;

  /// Native Google Sign-In (official Flutter iOS/Android flow): obtain the
  /// Google ID token on-device and exchange it with Supabase via
  /// [GoTrueClient.signInWithIdToken] — no browser redirect.
  Future<void> signInWithGoogle() async {
    if (_googleServerClientId.isEmpty) {
      throw const AuthException(
        'Google sign-in is not configured: GOOGLE_OAUTH_CLIENT_ID is missing.',
      );
    }
    final isApplePlatform =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (isApplePlatform && _googleIosClientId.isEmpty) {
      throw const AuthException(
        'Google sign-in is not configured: '
        'GOOGLE_OAUTH_IOS_CLIENT_ID is missing.',
      );
    }
    final googleSignIn = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await googleSignIn.initialize(
        serverClientId: _googleServerClientId,
        clientId: isApplePlatform ? _googleIosClientId : null,
      );
      _googleInitialized = true;
    }
    final account = await googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in returned no ID token.');
    }
    await auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// Native Sign in with Apple (official Flutter flow). The raw nonce is sent
  /// to Supabase; Apple receives its SHA-256 hex digest.
  Future<void> signInWithApple() async {
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple sign-in returned no ID token.');
    }
    await auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<void> sendOtp(String email) async {
    await auth.signInWithOtp(email: email);
  }

  /// Sends the password-recovery email. GoTrue always answers
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

  /// The current user's app profile from the `users` table, parsed into a
  /// typed [UserProfile]. Returns null when no session is active or the
  /// profile row does not exist (pre-profile state after signup).
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final res = await client
        .from('users')
        .select(
          'id, username, avatar_url, bio, personal_shards, preshards, '
          'subscription_tier, entitlement_tier, deleted_at, date_of_birth',
        )
        .eq('id', user.id)
        .maybeSingle();
    if (res == null) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(res));
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
    if (user == null) throw const UnauthorizedError();
    // Profile-RPC lockdown: clients hold NO table write
    // privilege — deletion goes through the SECURITY DEFINER RPC, which
    // tombstones the row server-side (deleted_at + deleted_user_ rename +
    // PII nulling).
    await client.rpc('delete_my_account');
  }

  /// Mode A — request deletion: tombstone + revoke sessions; the account is
  /// fully erased by the cron after the grace window, and is restorable by
  /// signing in and calling [restoreAccount] within that window.
  Future<void> requestAccountDeletion() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    await client.rpc('request_account_deletion');
  }

  /// Mode B — immediate, irreversible full erasure (public rows, auth.users,
  /// and queued storage objects). No recovery.
  Future<void> purgeAccountNow() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    await client.rpc('purge_my_account_now');
  }

  /// Undo a scheduled deletion within the grace window.
  Future<void> restoreAccount() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    await client.rpc('restore_my_account');
  }

  /// Returns the caller's own data as a JSON string (`export_my_data`).
  /// Chat is E2EE, so the server can only return ciphertext; readable history
  /// is merged on-device by the export feature.
  Future<String> exportMyData() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc('export_my_data');
    return jsonEncode(res);
  }

  /// Whether a `users` row exists for [userId].
  ///
  /// Returns false when the row is absent (a legitimate pre-profile state).
  /// PostgREST/network errors PROPAGATE — the caller decides how to surface
  /// them (an error must never masquerade as
  /// "no profile" and silently change the flow).
  Future<bool> userHasProfile(String userId) async {
    final res = await client
        .from('users')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return res != null;
  }

  /// Creates the signed-in user's profile row via the create_my_profile RPC
  /// (the table is INSERT-revoked for
  /// clients). The RPC sanitizes + validates the username server-side
  /// (client-side sanitize stays as defense in depth), enforces the DOB
  /// rules, applies the economy defaults, and writes the signup shard grant
  /// atomically. The signup tracker flip stays a separate call to preserve
  /// the funnel's existing contract.
  Future<void> createUserProfile({
    required String username,
    String? dateOfBirth,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    await client.rpc('create_my_profile', params: {
      'p_username': InputSanitizer.sanitizeUsername(username),
      'p_date_of_birth': dateOfBirth,
    });

    final email = user.email;
    if (email != null) {
      await upsertSignupTracker(email, true);
    }
  }
}
