import 'package:samay/core/errors/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Realtime: channel lifecycle and Postgres-change subscriptions.
///
/// Full lifecycle handling (reconnect/backoff) lives in
/// [RealtimeStatusNotifier] (lib/core/providers/realtime_provider.dart).
class RealtimeService {
  final SupabaseClient client;

  RealtimeService({required this.client});

  GoTrueClient get auth => client.auth;

  /// Subscribes to Postgres changes on [table] (schema `public`) over the
  /// channel [channelName], forwarding each `newRecord` to [callback].
  ///
  /// [onStatus] receives the channel subscription lifecycle: `subscribed`
  /// when the join is acknowledged, `channelError`/`timedOut` when the
  /// subscription fails (RLS denial, server decline, join timeout), `closed`
  /// when the socket closed. This is the seam the realtime provider
  /// uses to drive connection state + reconnect backoff.
  ///
  /// [filter] narrows which rows are delivered (postgres_changes column
  /// filter — e.g. the inbox's `sender_id <> me`). RLS still gates what the
  /// caller may receive.
  ///
  /// Returns the channel — the caller owns the unsubscribe handle.
  RealtimeChannel subscribeToChannel(
    String channelName,
    PostgresChangeEvent event,
    String table,
    void Function(Map<String, dynamic>) callback, {
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatus,
    PostgresChangeFilter? filter,
  }) {
    final channel = client.channel(channelName);
    channel.onPostgresChanges(
      event: event,
      schema: 'public',
      table: table,
      filter: filter,
      callback: (payload) => callback(payload.newRecord),
    );
    if (onStatus != null) {
      channel.subscribe(onStatus);
    } else {
      channel.subscribe();
    }
    return channel;
  }

  RealtimeChannel subscribeToMessages(String chatId, void Function(Map<String, dynamic>) onInsert) {
    return subscribeToChannel('messages:$chatId', PostgresChangeEvent.insert, 'messages', onInsert);
  }

  /// Inbound messages for the current user's INBOX — any insert from someone
  /// else.
  ///
  /// postgres_changes cannot OR two columns and `neq` needs one column, so
  /// the stream is `sender_id <> me`; RLS (`messages_read_participant`)
  /// additionally restricts delivery to chats the user participates in, so
  /// the consumer can refresh the inbox on every event. The consumer
  /// invalidates `chatInboxProvider` (unread counts re-derive server-side).
  ///
  /// Returns the channel — the caller owns the unsubscribe handle.
  Future<RealtimeChannel> subscribeToInbox(
    void Function(Map<String, dynamic>) onInsert,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    return subscribeToChannel(
      'messages:inbox:${user.id}',
      PostgresChangeEvent.insert,
      'messages',
      onInsert,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.neq,
        column: 'sender_id',
        value: user.id,
      ),
    );
  }

  /// Returns the live channel so callers can unsubscribe on dispose
  /// (same contract as [subscribeToMessages] — the notification center keeps
  /// its screen-level subscription dispose-safe).
  Future<RealtimeChannel> subscribeToNotifications(
    void Function(Map<String, dynamic>) onInsert,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    return subscribeToChannel(
      'notifications:${user.id}',
      PostgresChangeEvent.insert,
      'notifications',
      onInsert,
    );
  }

  Future<void> subscribeToEventStatus(String eventId, void Function(String) onChange) async {
    final channel = client.channel('event-status:$eventId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'events',
      callback: (payload) {
        final newStatus = payload.newRecord['status'] as String?;
        if (newStatus != null) onChange(newStatus);
      },
    );
    channel.subscribe();
  }

  /// Group memberships involving the current user — any insert/update/delete.
  ///
  /// postgres_changes cannot OR two columns, so the whole `group_members`
  /// stream is subscribed and [onChange] fires only when the row belongs to
  /// the current user (member rows carry `user_id`). The consumer invalidates
  /// the invites/my-groups providers — the remote-side fix for group
  /// invitations only appearing after an app restart. Requires
  /// the table in `supabase_realtime` + REPLICA IDENTITY FULL for full-row
  /// DELETE payloads (migration 20260817000001).
  Future<RealtimeChannel> subscribeToGroupMemberships(
    void Function(Map<String, dynamic>) onChange,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    return subscribeToChannel(
      'group-members:${user.id}',
      PostgresChangeEvent.all,
      'group_members',
      (row) {
        if (row['user_id'] == user.id) {
          onChange(row);
        }
      },
    );
  }

  /// Friendships involving the current user — any insert/update/delete.
  ///
  /// postgres_changes cannot OR two columns, so the whole `friendships`
  /// stream is subscribed and [onChange] fires only when the row touches
  /// the current user (requester OR addressee). The consumer invalidates
  /// the friends/requests providers — the remote-side fix for the stale
  /// friends list.
  Future<RealtimeChannel> subscribeToFriendships(
    void Function(Map<String, dynamic>) onChange,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    return subscribeToChannel(
      'friendships:${user.id}',
      PostgresChangeEvent.all,
      'friendships',
      (row) {
        if (row['requester_id'] == user.id ||
            row['addressee_id'] == user.id) {
          onChange(row);
        }
      },
    );
  }

  /// `minigame_sessions` rows the current user may read — any
  /// insert/update/delete.
  ///
  /// postgres_changes cannot match an array membership (`participants` is a
  /// uuid[]), so the whole `minigame_sessions` stream is subscribed and the
  /// RLS SELECT policies (`ms_read_direct_participant` / `ms_read_group_member`
  /// / `ms_read_invitee`) gate which rows are even delivered — a client only
  /// receives sessions it may read, exactly like the group-memberships seam.
  /// The consumer invalidates the my-sessions list providers on every event:
  /// an invite accept flips the row's `participants` (REPLICA
  /// IDENTITY FULL ships the full new row), so the invitee's per-game ongoing
  /// list picks the match up without a pull-to-refresh or restart.
  ///
  /// Returns the channel — the caller owns the unsubscribe handle.
  Future<RealtimeChannel> subscribeToMinigameSessions(
    void Function(Map<String, dynamic>) onChange,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    return subscribeToChannel(
      'minigame-sessions:${user.id}',
      PostgresChangeEvent.all,
      'minigame_sessions',
      onChange,
    );
  }

  /// One event's `event_invites` rows — any insert/update/delete.
  ///
  /// The host/staff guest-roster seam:
  /// when an invitee accepts/declines on their own device, the event detail's
  /// cached roster would otherwise go stale with no refresh. The channel is
  /// FILTERED to `event_id = <uuid>` (a fixed value per screen) so a host only
  /// hears about this event's invite rows; RLS still gates delivery — the
  /// event's hosts/staff receive the full roster rows (`ei_read_event_access`),
  /// an invitee only their own row (`ei_read_own`). REPLICA IDENTITY FULL ships
  /// event_id in every UPDATE/DELETE record so the filter always matches.
  ///
  /// Returns the channel — the caller owns the unsubscribe handle.
  RealtimeChannel subscribeToEventInvites(
    String eventId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    return subscribeToChannel(
      'event-invites:$eventId',
      PostgresChangeEvent.all,
      'event_invites',
      onChange,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'event_id',
        value: eventId,
      ),
    );
  }

  /// One event's `event_hosts` rows — any insert/update/delete.
  ///
  /// The organizer-roster seam:
  /// when the host designates/removes staff, everyone who belongs to the event
  /// (hosts/staff + invited members) sees the "Anfitrión y staff" list update
  /// live. Filtered to `event_id = <uuid>`; RLS gates delivery (hosts/staff
  /// full rows; event invitees the roster of the events they belong to via the
  /// ep_read_member_roster policy). REPLICA IDENTITY FULL ships event_id in
  /// every UPDATE/DELETE record so the filter always matches.
  ///
  /// Returns the channel — the caller owns the unsubscribe handle.
  RealtimeChannel subscribeToEventHosts(
    String eventId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    return subscribeToChannel(
      'event-hosts:$eventId',
      PostgresChangeEvent.all,
      'event_hosts',
      onChange,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'event_id',
        value: eventId,
      ),
    );
  }

  /// One event's `event_attendances` rows — insert/update/delete.
  ///
  /// The assist flip seam: when the host/staff scanner
  /// confirms an attendee on another device, an already-open detail screen (or
  /// the QR screen pushed over it) must flip to the terminal "Ya te registraste"
  /// state without a re-entry. Host/staff have no invite row, so the
  /// `event_invites` channel cannot observe their confirmation — only
  /// `event_attendances` does. Filtered to `event_id = <uuid>`; RLS gates
  /// delivery (`ea_read_access`: a caller receives their own row everywhere,
  /// plus all the event's rows when they are host/staff or a group member).
  /// REPLICA IDENTITY FULL ships event_id in UPDATE/DELETE records.
  ///
  /// Returns the channel — the caller owns the unsubscribe handle.
  RealtimeChannel subscribeToEventAttendances(
    String eventId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    return subscribeToChannel(
      'event-attendances:$eventId',
      PostgresChangeEvent.all,
      'event_attendances',
      onChange,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'event_id',
        value: eventId,
      ),
    );
  }
}
