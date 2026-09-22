import 'package:samay/core/models/user_profile.dart';
import 'package:samay/core/services/user_service.dart';

/// Own-profile repository: thin, typed facade over [UserService].
///
/// Dependency direction doctrine (DEVELOPMENT-WORKFLOW §5): providers depend
/// on repositories, repositories on services, services on the Supabase client.
/// The profile feature must read this repository via `profileRepositoryProvider`
/// (Riverpod) instead of the `SupabaseService.instance` singleton.
///
/// The current user is resolved internally via [UserService.auth], so the
/// repository API is self-contained (`updateBio(String)` instead of
/// `updateBio(userId, bio)`) — returning null / no-oping on an unauthenticated
/// session.
class ProfileRepository {
  ProfileRepository({required UserService users}) : _users = users;

  final UserService _users;

  /// The current user's profile row, or null when unauthenticated / the row
  /// does not exist.
  Future<UserProfile?> getMyProfile() async {
    final user = _users.auth.currentUser;
    if (user == null) return null;
    final res = await _users.getUserProfile(user.id);
    return res == null ? null : UserProfile.fromJson(res);
  }

  /// Persists the current user's bio (own-row only, `users_update_own` RLS).
  Future<void> updateBio(String bio) async {
    final user = _users.auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await _users.updateBio(user.id, bio);
  }

  /// Persists the current user's public avatar URL.
  Future<void> updateAvatarUrl(String avatarUrl) async {
    final user = _users.auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await _users.updateAvatarUrl(user.id, avatarUrl);
  }
}
