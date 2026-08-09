import 'package:samay/core/logging/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a client-side ban check for the current user.
///
/// [isBanned] true means the `users.banned_at` column is set (the Go CLI
/// `USRS ban` command writes it); [reason] carries the `ban_reason` text when
/// the administrator provided one.
class BanStatus {
  final bool isBanned;
  final String? reason;

  const BanStatus({this.isBanned = false, this.reason});

  const BanStatus.banned(this.reason) : isBanned = true;

  static const notBanned = BanStatus();
}

/// Client-side ban enforcement (AUTH spec gap — ban enforcement, phase 03).
///
/// GoTrue keeps a banned user's JWT valid until expiry, so the app checks
/// `users.banned_at` at every auth boundary (app start, sign-in, OTP verify,
/// token refresh) and forces a sign-out onto a dedicated ban screen. This is a
/// best-effort UX gate: the authoritative enforcement belongs server-side (a
/// Supabase Auth Hook — `custom_access_token_hook` — rejecting token issuance
/// when `banned_at IS NOT NULL`; handoff noted in the I-35 daily log).
///
/// Fail-open by design: when the check itself cannot run (network, RLS, no
/// profile row yet), the user is treated as not banned — a false positive here
/// would sign out every user on a transient error, which is strictly worse
/// than a temporarily-visible session. Results are cached briefly so the
/// auth-state listener does not hammer the DB on every token refresh.
class BanService {
  final SupabaseClient client;

  BanService({required this.client});

  /// How long a ban check result stays valid before it is re-queried.
  static const Duration cacheDuration = Duration(seconds: 30);

  BanStatus? _cached;
  DateTime? _cachedAt;
  String? _cachedUserId;
  Future<BanStatus>? _inFlight;

  /// Checks whether the current user is banned.
  ///
  /// Returns [BanStatus.notBanned] for anonymous sessions and for users
  /// without a `users` row (pre-signup) — both are legitimate non-banned
  /// states. Pass `force: true` at security-relevant boundaries (sign-in, OTP
  /// verify, app start) to bypass the short-lived cache.
  Future<BanStatus> checkBanStatus({bool force = false}) async {
    final user = client.auth.currentUser;
    if (user == null) return BanStatus.notBanned;

    final now = DateTime.now();
    if (!force && _cached != null && _cachedUserId == user.id &&
        now.difference(_cachedAt!) < cacheDuration) {
      return _cached!;
    }

    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final future = _fetch(user.id).then((status) {
      _cached = status;
      _cachedAt = DateTime.now();
      _cachedUserId = user.id;
      return status;
    });
    _inFlight = future;
    try {
      return await future;
    } finally {
      _inFlight = null;
    }
  }

  /// Drops the cached result so the next check re-queries the database.
  void invalidate() {
    _cached = null;
    _cachedAt = null;
    _cachedUserId = null;
  }

  Future<BanStatus> _fetch(String userId) async {
    try {
      final row = await client
          .from('users')
          .select('banned_at, ban_reason')
          .eq('id', userId)
          .maybeSingle();
      return _statusFromRow(row);
    } catch (e, st) {
      // Fail-open (see class doc): a failed check must never lock the user
      // out. Logged for observability; server-side enforcement covers bans.
      AppLogger.instance.error('checkBanStatus error: $e', '$st');
      return BanStatus.notBanned;
    }
  }

  static BanStatus _statusFromRow(Map<String, dynamic>? row) {
    if (row == null) return BanStatus.notBanned;
    final bannedAt = row['banned_at'];
    if (bannedAt == null || bannedAt is! String) {
      return BanStatus.notBanned;
    }
    final reason = row['ban_reason'];
    return BanStatus.banned(reason is String ? reason : '');
  }
}
