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

  /// Whether the CALLER has been assisted (scanned/confirmed) into [eventId].
  ///
  /// Reads the caller's own `event_attendances` row — the single-confirmation
  /// marker written by `validate_code` (07_code.sql). It is the authoritative
  /// "already attended" signal and is uniform across roles: a guest's invite
  /// also flips to `attended`, but host/staff have no invite row and are only
  /// recorded here. The read is RLS-scoped by `ea_read_access`
  /// (`user_id = auth.uid()`), so the client can neither see nor forge another
  /// attendee's row. `false` when not signed in or not yet assisted.
  Future<bool> isAttended(String eventId) async {
    final user = auth.currentUser;
    if (user == null) return false;
    final res = await client
        .from('event_attendances')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();
    return res != null;
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

  /// Validates an attendee's rotating code as a host/staff — QRSC.
  ///
  /// The attendee shows the code as a plain QR (`QrImageView`); the scanner
  /// reads the QR payload and validates the code string here. Invokes the
  /// `validate_code` RPC (07_code.sql). Business outcomes are returned as
  /// jsonb `status` payloads (never exceptions); infra failures (missing RPC
  /// PGRST202, network) throw and surface as the scanner's retryable banner.
  /// Swapping to the Edge Function later is a one-line change here.
  Future<Map<String, dynamic>> validateCode(
    String eventId,
    String code,
  ) async {
    final res = await client.rpc('validate_code', params: {
      'p_event_id': eventId,
      'p_code': code,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Fetches the caller's code session for [eventId] (Stage 5, `get_my_code`,
  /// 07_code.sql) — the current 24-hex code plus the per-attendee secret and
  /// window bounds so the device can derive every later `code.window_seconds`
  /// window locally (authenticator style, no per-window round-trip). Non-fatal
  /// RPC outcomes are returned as jsonb `status` payloads
  /// (`not_in_window`, `not_invited`, `ok`) — never exceptions; infra
  /// failures throw and surface through the provider's AsyncError.
  Future<Map<String, dynamic>?> getMyCode(String eventId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc('get_my_code', params: {
      'p_event_id': eventId,
    });
    return res == null ? null : Map<String, dynamic>.from(res as Map);
  }

  // ---------------------------------------------------------------------
  // Stage-2 manual guest invites (060_events/05_manual_invites.sql) — the
  // host invites SPECIFIC users (reusing the minigame invite mechanism);
  // invitees accept/decline and the frozen capacity is enforced server-side.
  // RPCs return jsonb `status` payloads (I-57 contract), never exceptions.
  // ---------------------------------------------------------------------

  /// The host invites [inviteeIds] to [eventId] via the `invite_event_guests`
  /// SECURITY DEFINER RPC. Business outcomes are jsonb `status` payloads; the
  /// positive result is `ok` carrying the `invited` count (idempotent
  /// re-invites report 0). Failures map to typed [AppError]s (never raw
  /// exception text):
  ///   not_authenticated → [UnauthorizedError]
  ///   event_not_found → [NotFoundError]
  ///   event_closed → [ConflictError] (`event_closed`)
  ///   not_host → [PermissionError]
  ///   invitee_not_allowed → [ConflictError] (`invitee_not_allowed`)
  ///   too_many_invitees → [ConflictError] (`too_many_invitees`)
  ///   capacity_reached → [ConflictError] (`capacity_reached`)
  Future<int> inviteEventGuests(String eventId, List<String> inviteeIds) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc('invite_event_guests', params: {
      'p_event_id': eventId,
      'p_invitees': inviteeIds,
    });
    final result = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    return switch (result['status']) {
      'ok' => result['invited'] as int? ?? 0,
      'not_authenticated' => throw const UnauthorizedError(),
      'event_not_found' => throw const NotFoundError('Evento'),
      'event_closed' => throw ConflictError(
        'El evento ya terminó o fue cancelado.',
        code: 'event_closed',
      ),
      'not_host' => throw PermissionError(),
      'invitee_not_allowed' => throw ConflictError(
        'No puedes invitar a esta persona.',
        code: 'invitee_not_allowed',
      ),
      'too_many_invitees' => throw ConflictError(
        'Máximo 20 invitaciones por envío.',
        code: 'too_many_invitees',
      ),
      'capacity_reached' => throw ConflictError(
        'El evento alcanzó su capacidad máxima.',
        code: 'capacity_reached',
      ),
      _ => throw const ServerError('Unexpected invite_event_guests response'),
    };
  }

  /// The invitee accepts [inviteId] via the `accept_event_invite` SECURITY
  /// DEFINER RPC (self only): pending → accepted (responded_at). Idempotent.
  /// Typed [AppError]s mirror [inviteEventGuests]; extra states:
  ///   already_accepted / already_attended → [ConflictError] with that code
  Future<void> acceptEventInvite(String inviteId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc('accept_event_invite', params: {
      'p_invite_id': inviteId,
    });
    final result = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    switch (result['status']) {
      case 'accepted' || 'already_accepted':
        return;
      case 'not_authenticated':
        throw const UnauthorizedError();
      case 'invite_not_found':
        throw const NotFoundError('Invitación');
      case 'already_attended':
        throw ConflictError(
          'Ya asististe a este evento.',
          code: 'already_attended',
        );
      case 'event_closed':
        throw ConflictError(
          'El evento ya terminó o fue cancelado.',
          code: 'event_closed',
        );
      default:
        throw const ServerError('Unexpected accept_event_invite response');
    }
  }

  /// The invitee declines [inviteId] via the `decline_event_invite` SECURITY
  /// DEFINER RPC (self only). The server DELETES the pending row (2026-09-02
  /// directive: a declined invite is indistinguishable from one that never
  /// existed) — freeing the reserved seat so the host can invite someone else.
  /// Typed [AppError]s as in [acceptEventInvite].
  Future<void> declineEventInvite(String inviteId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc('decline_event_invite', params: {
      'p_invite_id': inviteId,
    });
    final result = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    switch (result['status']) {
      case 'declined':
        return;
      case 'not_authenticated':
        throw const UnauthorizedError();
      case 'invite_not_found':
        throw const NotFoundError('Invitación');
      case 'already_accepted':
        throw ConflictError(
          'Ya aceptaste la invitación.',
          code: 'already_accepted',
        );
      case 'already_attended':
        throw ConflictError(
          'Ya asististe a este evento.',
          code: 'already_attended',
        );
      default:
        throw const ServerError('Unexpected decline_event_invite response');
    }
  }

  /// The HOST/STAFF view of an event's guest roster — one row per
  /// `event_invites` entry enriched with `users.username` (via the
  /// security-barrier `user_search_view`, mirroring [getEventHosts]). The
  /// `ei_read_event_access` RLS policy (05_manual_invites) bounds this to the
  /// event's hosts/staff; everyone else sees only their own rows, so this
  /// method is only mounted where the caller is privileged.
  Future<List<Map<String, dynamic>>> getEventGuests(String eventId) async {
    final res = await client
        .from('event_invites')
        .select(
          'id, event_id, user_id, invited_by_user_id, status, invited_at, '
          // `user_id` is the invitee — disambiguate from the two FKs to users
          // (user_id + invited_by_user_id) by naming the relationship.
          'users:user_search_view!event_invites_user_id_fkey(username)',
        )
        .eq('event_id', eventId)
        .order('invited_at', ascending: true);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ---------------------------------------------------------------------
  // Stage-3 host/staff management (060_events/06_staff.sql) — the HOST
  // designates specific users as staff (and removes them). RPCs return jsonb
  // `status` payloads (I-57 contract), never exceptions.
  // ---------------------------------------------------------------------

  /// The host designates [staffIds] as staff of [eventId] via the
  /// `designate_event_staff` SECURITY DEFINER RPC. The server enforces the
  /// frozen capacity, idempotency (already-privileged users are skipped) and
  /// the host-only gate, and CONVERTS any existing invite seat (a designated
  /// guest's invite row is deleted — their seat moves into `event_hosts`, so
  /// staff never double-count against capacity). Returns the count of NEW
  /// staff rows. Typed [AppError]s mirror [inviteEventGuests]:
  ///   not_authenticated → [UnauthorizedError]
  ///   event_not_found → [NotFoundError]
  ///   event_closed → [ConflictError] (`event_closed`)
  ///   not_host → [PermissionError]
  ///   staff_not_allowed → [ConflictError] (`staff_not_allowed`)
  ///   too_many_staff → [ConflictError] (`too_many_staff`)
  ///   capacity_reached → [ConflictError] (`capacity_reached`)
  Future<int> designateStaff(String eventId, List<String> staffIds) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc('designate_event_staff', params: {
      'p_event_id': eventId,
      'p_staff_ids': staffIds,
    });
    final result = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    return switch (result['status']) {
      'ok' => result['added'] as int? ?? 0,
      'not_authenticated' => throw const UnauthorizedError(),
      'event_not_found' => throw const NotFoundError('Evento'),
      'event_closed' => throw ConflictError(
        'El evento ya terminó o fue cancelado.',
        code: 'event_closed',
      ),
      'not_host' => throw PermissionError(),
      'staff_not_allowed' => throw ConflictError(
        'No puedes añadir a esta persona como staff.',
        code: 'staff_not_allowed',
      ),
      'too_many_staff' => throw ConflictError(
        'Máximo 20 personas por envío.',
        code: 'too_many_staff',
      ),
      'capacity_reached' => throw ConflictError(
        'El evento alcanzó su capacidad máxima.',
        code: 'capacity_reached',
      ),
      _ => throw const ServerError('Unexpected designate_event_staff response'),
    };
  }

  /// The host removes [staffUserId] from [eventId]'s staff via the
  /// `remove_event_staff` SECURITY DEFINER RPC (frees their seat). The host
  /// row can never be removed (`host_not_removable`); removing an already
  /// removed member is an idempotent `ok`. Typed [AppError]s as in
  /// [designateStaff]; extra state:
  ///   host_not_removable → [ConflictError] (`host_not_removable`)
  Future<void> removeStaff(String eventId, String staffUserId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc('remove_event_staff', params: {
      'p_event_id': eventId,
      'p_staff_user_id': staffUserId,
    });
    final result = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    switch (result['status']) {
      case 'ok':
        return;
      case 'not_authenticated':
        throw const UnauthorizedError();
      case 'event_not_found':
        throw const NotFoundError('Evento');
      case 'event_closed':
        throw ConflictError(
          'El evento ya terminó o fue cancelado.',
          code: 'event_closed',
        );
      case 'not_host':
        throw PermissionError();
      case 'host_not_removable':
        throw ConflictError(
          'No puedes quitar al anfitrión del evento.',
          code: 'host_not_removable',
        );
      default:
        throw const ServerError('Unexpected remove_event_staff response');
    }
  }
}
