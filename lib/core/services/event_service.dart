import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/models/event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Event lifecycle: creation, listing, updates and photo likes.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11). Photo upload/signed URLs live in [MediaService]
/// (lib/core/services/media_service.dart); realtime subscriptions live in
/// [RealtimeService] (lib/core/services/realtime_service.dart).
class EventService {
  final SupabaseClient client;

  EventService({required this.client});

  GoTrueClient get auth => client.auth;

  /// Creates an event and returns `{id, invite_token}`.
  ///
  /// The insert now goes through the SECURITY DEFINER `create_event` RPC
  /// (060_events/04_capacity.sql) which atomically writes the `events` row,
  /// the creator's `event_hosts` host row and the event `chats` row, while
  /// the `assert_event_capacity_trigger` freezes `capacity` at (or below) the
  /// creator's entitlement tier. Business rejections surface as RPC errors
  /// (e.g. `capacity_exceeds_tier`).
  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc('create_event', params: {
      'p_name': data['name'],
      'p_description': data['description'],
      'p_type': data['type'],
      'p_cover_url': data['cover_url'],
      'p_group_id': data['group_id'],
      'p_location_name': data['location_name'],
      'p_location_lat': data['location_lat'],
      'p_location_lng': data['location_lng'],
      'p_starts_at': data['starts_at'],
      'p_ends_at': data['ends_at'],
      'p_join_mode': data['join_mode'],
      'p_preshards_pool': data['preshards_pool'] ?? 0,
      'p_preshards_cap_per_user': data['preshards_cap_per_user'],
      'p_preshards_remainder_action': data['preshards_remainder_action'],
      'p_capacity': data['capacity'],
    });
    final map = Map<String, dynamic>.from(res as Map);
    return {
      'id': map['id'] as String,
      'invite_token': map['inviteToken'] as String,
    };
  }

  Future<List<Event>> listEvents([String? status, String? type]) async {
    var query = client.from('events').select();
    if (status != null) query = query.eq('status', status);
    if (type != null) query = query.eq('type', type);
    final res = await query.order('starts_at', ascending: true);
    return (res as List)
        .map((e) => Event.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Event> getEvent(String id) async {
    final res = await client.from('events').select().eq('id', id).single();
    return Event.fromJson(Map<String, dynamic>.from(res));
  }

  /// Resolves an invite token to its event (EINV deep links —
  /// `samay://event/{invite_token}`). `invite_token` is UNIQUE + indexed
  /// (full_schema.sql §5), so the lookup is exact; null when the token
  /// matches no event. Typed [Event] — the router only consumes `id`; the
  /// detail screen re-fetches the full row via [getEvent].
  Future<Event?> getEventByInviteToken(String token) async {
    final res = await client
        .from('events')
        .select()
        .eq('invite_token', token)
        .maybeSingle();
    return res == null ? null : Event.fromJson(Map<String, dynamic>.from(res));
  }

  /// Hosts of an event, enriched with `users.username` for display.
  Future<List<Map<String, dynamic>>> getEventHosts(String eventId) async {
    final res = await client
        .from('event_hosts')
        // OPT-009: join through the security-barrier user_search_view — the
        // raw `users` join is own-row-only under RLS (staff' rows
        // silently vanished).
        .select(
          'id, event_id, user_id, role, preshards_contributed, added_at, '
          'users:user_search_view!inner(username)',
        )
        .eq('event_id', eventId);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// The current user's invite row for [eventId] (null when not invited).
  Future<Map<String, dynamic>?> getMyEventInvite(String eventId) async {
    final user = auth.currentUser;
    if (user == null) return null;
    final res = await client
        .from('event_invites')
        .select()
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();
    return res == null ? null : Map<String, dynamic>.from(res);
  }

  Future<void> updateEvent(String id, Map<String, dynamic> patch) async {
    final data = Map<String, dynamic>.from(patch);
    data['updated_at'] = DateTime.now().toIso8601String();
    if (patch.containsKey('preshards_pool')) {
      data['dynamic_qr_enabled'] = (patch['preshards_pool'] as int) > 0;
    }
    await client.from('events').update(data).eq('id', id);
  }

  Future<void> likePhoto(String photoId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final existing = await client
        .from('event_photo_likes')
        .select('id')
        .eq('photo_id', photoId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (existing != null) return;

    // The `event_photos.likes_count` column is maintained by the
    // `photo_likes_count_trigger` (AFTER INSERT OR DELETE ON
    // event_photo_likes — full_schema.sql §5.5): no RPC is needed here.
    // (A previous build called a nonexistent likes RPC — PGRST202 at runtime;
    // the insert alone is the contract. See the EF-03 daily log.)
    await client.from('event_photo_likes').insert({
      'photo_id': photoId,
      'user_id': user.id,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Removes the current user's like on [photoId] (PHUP like toggle — I-59).
  /// The `likes_count` decrement is the same trigger as [likePhoto]. Deleting
  /// a nonexistent row is a no-op, so unlike-after-expiry is safe.
  Future<void> unlikePhoto(String photoId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    await client
        .from('event_photo_likes')
        .delete()
        .eq('photo_id', photoId)
        .eq('user_id', user.id);
  }

  /// The photo ids the current user has liked within [eventId] — the
  /// gallery's `likedByMe` source (PHUP — I-59). Filtering happens through
  /// the embedded `event_photos` resource (PostgREST `!inner` join), which
  /// the `epl_read_access` policy also gates by event access.
  Future<List<String>> getMyPhotoLikes(String eventId) async {
    final user = auth.currentUser;
    if (user == null) return const [];

    final res = await client
        .from('event_photo_likes')
        .select('photo_id, event_photos!inner(event_id)')
        .eq('user_id', user.id)
        .eq('event_photos.event_id', eventId);
    return res.map((e) => e['photo_id'] as String).toList();
  }

  /// The current user's attendance-QR token row for [eventId], or `null` when
  /// the server has not issued one yet (pre-activation window, or the
  /// EEDG/QEDG `qr-token-manager` Edge Function is not deployed — QRAT).
  ///
  /// Rotation accumulates rows over time, so the query returns the **latest**
  /// row per user+event (`created_at DESC`); the server always intends the
  /// newest row to be the valid token, and client-side `expires_at` judges
  /// whether a rotation happened (I-57 foundation decision).
  Future<Map<String, dynamic>?> getMyQrToken(String eventId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client
        .from('event_qr_tokens')
        .select()
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return res == null ? null : Map<String, dynamic>.from(res);
  }

  /// Validates an attendee QR token as a host/staff — QRSC.
  ///
  /// Invokes the `validate_qr_token` RPC (migration 20260809000005, the SQL
  /// stand-in for the blocked `validate-attendance` Edge Function). Business
  /// outcomes are returned as jsonb `status` payloads (never exceptions);
  /// infra failures (missing RPC PGRST202, network) throw and surface as the
  /// scanner's retryable banner. Swapping to the Edge Function later is a
  /// one-line change here.
  Future<Map<String, dynamic>> validateQrToken(
    String eventId,
    String token,
  ) async {
    final res = await client.rpc('validate_qr_token', params: {
      'p_event_id': eventId,
      'p_token': token,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Rotates (or first-issues) the caller's attendance-QR token for
  /// [eventId] — QRAT.
  ///
  /// Invokes the `rotate_qr_token` RPC (migration 20260814000004, the SQL
  /// stand-in for the blocked `qr-token-manager` Edge Function). The server
  /// returns the still-valid current token, or atomically invalidates the
  /// previous one and issues a fresh token (`qr.token_valid_seconds`
  /// lifetime). Business outcomes are `status` payloads (`not_in_window`,
  /// `not_invited`, `ok`) — never exceptions; infra failures throw and the
  /// provider degrades to re-reading the current row.
  Future<Map<String, dynamic>?> rotateQrToken(String eventId) async {
    final res = await client.rpc('rotate_qr_token', params: {
      'p_event_id': eventId,
    });
    return res == null ? null : Map<String, dynamic>.from(res as Map);
  }
}
