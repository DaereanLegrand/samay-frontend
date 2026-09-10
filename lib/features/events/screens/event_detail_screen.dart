import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/events/logic/event_formatters.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/events/screens/event_invite_screen.dart';
import 'package:samay/features/events/screens/event_staff_screen.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_network_image.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// Event detail (EDET): header, date/location, preshard pool status,
/// hosts, own invite status and role-based actions (edit/cancel for
/// hosts). Invitee actions (accept/decline) and the QR/scanner buttons
/// ship with EINV/QRAT.
class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _cancelling = false;

  /// Live roster channels for this event while the current user BELONGS to it
  /// (host/staff, or a CONFIRMED invitee — see [_syncRosterRealtime]):
  /// [`_guestChannel`] streams `event_invites` (invitee accept/decline flips
  /// the guest list), [`_hostsChannel`] streams `event_hosts` (the host
  /// designating/removing staff updates the organizer list),
  /// [`_attendancesChannel`] streams `event_attendances` (the scanner's
  /// confirmation flips the caller's own row → terminal "Ya te registraste").
  /// Owned and unsubscribed on dispose.
  RealtimeChannel? _guestChannel;
  RealtimeChannel? _hostsChannel;
  RealtimeChannel? _attendancesChannel;
  bool _subscribingRoster = false;

  @override
  void initState() {
    super.initState();
    // Fresh entry = fresh roster + own-invite state (the providers are cached
    // for the session — a host re-opening the detail after an invitee
    // accepted on their own device must see it). Post-frame: provider writes
    // are illegal during the widget life-cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(eventGuestsProvider(widget.eventId));
      ref.invalidate(myEventInviteProvider(widget.eventId));
      ref.invalidate(myAttendanceProvider(widget.eventId));
      _syncRosterRealtime();
    });
  }

  @override
  void dispose() {
    _unsubscribeRosterChannels();
    super.dispose();
  }

  Future<void> _cancelEvent() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.discoBlack,
        title: Text(
          l10n.eventCancelDialogTitle,
          style: const TextStyle(color: AppColors.white),
        ),
        content: Text(
          l10n.eventCancelDialogBody,
          style: const TextStyle(color: AppColors.mutedStrong),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.eventCancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      // NOTE (I-55): the client only flips the status. Returning the pool to
      // the hosts (preshard_ledger `event_pool_returned` + pool=0) is
      // server-side logic (Go admin CancelEvent / EEDG) — see the I-55 daily
      // log for the S-07/EEDG gap flag.
      await ref.read(eventDetailProvider(widget.eventId).notifier).patch({
        'status': 'cancelled',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.eventCancelledSnack)));
    } catch (e, _) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  /// Subscribes this event's live roster channels while the current user
  /// belongs to the event — a host/staff member or a CONFIRMED invitee
  /// (accepted/attended — 2026-09-09, 060_events/08 + 09; tightened 2026-09-09
  /// so a PENDING invitee subscribes to nothing). Remote invitee accept/decline
  /// flips the guest list on the spot (`event_invites`), the host
  /// designating/removing staff updates the organizer list (`event_hosts`),
  /// and the scanner confirming the caller writes `event_attendances` → the
  /// terminal "Ya te registraste" state (host/staff included — 2026-09-10).
  /// Best-effort: on failure the entry-refresh + local actions still keep the
  /// lists usable. Unsubscribes when the user stops being a member or signs out.
  Future<void> _syncRosterRealtime() async {
    final uid =
        ref.read(authStateProvider).valueOrNull?.user?['id'] as String?;
    final hosts = ref.read(eventHostsProvider(widget.eventId)).valueOrNull;
    final privileged = uid != null &&
        (hosts?.any((p) => p['user_id'] == uid) ?? false);
    final invite = ref.read(myEventInviteProvider(widget.eventId)).valueOrNull;
    final member = privileged || _isConfirmedMember(invite);
    if (!member) {
      _unsubscribeRosterChannels();
      return;
    }
    if (_guestChannel != null &&
        _hostsChannel != null &&
        _attendancesChannel != null) {
      return;
    }
    if (_subscribingRoster) return;
    _subscribingRoster = true;
    try {
      final guest = ref
          .read(realtimeServiceProvider)
          .subscribeToEventInvites(widget.eventId, (_) {
            if (!mounted) return;
            ref.invalidate(eventGuestsProvider(widget.eventId));
            ref.invalidate(myEventInviteProvider(widget.eventId));
          });
      final host = ref
          .read(realtimeServiceProvider)
          .subscribeToEventHosts(widget.eventId, (_) {
            if (!mounted) return;
            ref.invalidate(eventHostsProvider(widget.eventId));
          });
      // The scanner's confirmation (guest OR host/staff) writes the caller's
      // `event_attendances` row — the authoritative assist signal. Re-read it
      // so an open detail (or the QR screen pushed over it) flips terminal
      // without a re-entry (2026-09-10, Task C).
      final attendances = ref
          .read(realtimeServiceProvider)
          .subscribeToEventAttendances(widget.eventId, (_) {
            if (!mounted) return;
            ref.invalidate(myAttendanceProvider(widget.eventId));
          });
      if (!mounted) {
        // The screen closed while the joins were in flight — never leak live
        // channels.
        await guest.unsubscribe();
        await host.unsubscribe();
        await attendances.unsubscribe();
        return;
      }
      _guestChannel = guest;
      _hostsChannel = host;
      _attendancesChannel = attendances;
    } catch (e, st) {
      // Realtime is best-effort; entry-refetch/pull-to-refresh remains.
      AppLogger.instance.error(
        'event roster realtime subscribe failed: $e',
        '$st',
      );
    } finally {
      _subscribingRoster = false;
    }
  }

  void _unsubscribeRosterChannels() {
    _guestChannel?.unsubscribe();
    _guestChannel = null;
    _hostsChannel?.unsubscribe();
    _hostsChannel = null;
    _attendancesChannel?.unsubscribe();
    _attendancesChannel = null;
  }

  Widget _scaffold(Widget body) {
    return Scaffold(
      body: VHeaderBar(
        title: AppLocalizations.of(context).eventDetailTitle,
        child: body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(eventDetailProvider(widget.eventId));
    // Roster/provider changes (hosts first resolve, staff added/removed, the
    // own invite resolving/accepting → the user becomes a member) or an
    // account switch (re)drive the live roster channels.
    ref.listen(eventHostsProvider(widget.eventId), (_, _) {
      _syncRosterRealtime();
    });
    ref.listen(myEventInviteProvider(widget.eventId), (_, _) {
      _syncRosterRealtime();
    });
    ref.listen(authStateProvider, (_, _) {
      _syncRosterRealtime();
    });

    return detailAsync.when(
      // U-25 (§5.8): the detail is the heaviest events screen (detail +
      // hosts + invite stacked fetches), so the nothing-on-screen frame
      // shows the cover+lines skeleton (U-22's handoff named event_detail →
      // VSkeletonDetail) instead of the bare spinner. `VSkeletonDetail(rows:
      // 1)` is the closest existing skeleton to the hero geometry — the same
      // call U-24 made on group_detail.
      loading: () => _scaffold(const VSkeletonDetail(rows: 1)),
      error: (e, _) => _scaffold(
        ErrorView(
          message: e.toAppError().message,
          onRetry: () => ref.invalidate(eventDetailProvider(widget.eventId)),
        ),
      ),
      data: (event) {
        final hostsAsync = ref.watch(
          eventHostsProvider(widget.eventId),
        );
        final inviteAsync = ref.watch(myEventInviteProvider(widget.eventId));
        return _buildDetail(event, hostsAsync, inviteAsync);
      },
    );
  }

  Widget _buildDetail(
    Event event,
    AsyncValue<List<Map<String, dynamic>>> hostsAsync,
    AsyncValue<Map<String, dynamic>?> inviteAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    final uid =
        ref.watch(authStateProvider).valueOrNull?.user?['id'] as String?;
    final hosts = hostsAsync.valueOrNull;
    final invite = inviteAsync.valueOrNull;
    final privileged = _isPrivileged(hosts, uid);
    // A PENDING invitee (and not host/staff) may only accept/decline: no
    // Código, no Fotos, no roster cards (2026-09-09 security fix).
    final pendingInvite = !privileged && _isPendingInvite(invite);
    // Assisted (scanned/confirmed) — the authoritative own `event_attendances`
    // read, uniform for guests and host/staff. Once true the Código action is
    // permanently disabled for this event (2026-09-10, Task C).
    final assisted =
        ref.watch(myAttendanceProvider(widget.eventId)).valueOrNull == true;

    return Scaffold(
      body: VHeaderBar(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            if (event.coverUrl != null) ...[
              VNetworkImage(
                imageUrl: event.coverUrl!,
                height: 200,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            VDisplayText(text: event.name, maxLines: 2),
            const SizedBox(height: AppSpacing.sm),
            // XL-17 (Gemma round 2, 10_events: "overly saturated colors...
            // cheap"): flat monochrome chrome — badges carry status by the
            // label alone (white text, never a color spray).
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                VBadge(label: _typeLabel(l10n, event.type)),
                VBadge(label: _statusLabel(l10n, event.status)),
                if (event.groupId != null) VBadge(label: l10n.eventGroupScoped),
              ],
            ),
            if (event.description != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                event.description!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            // XL-17: flat white-only glass (no family border, no glow).
            VCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.schedule,
                    text: formatEventDateRange(
                      event.startsAt,
                      event.endsAt,
                      Localizations.localeOf(context).languageCode,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    icon: Icons.place_outlined,
                    text: event.locationName ?? l10n.eventNoLocation,
                  ),
                  if (event.groupId != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.push(
                          RoutePaths.groupDetail(event.groupId!),
                        ),
                        icon: const Icon(Icons.group_outlined, size: 18),
                        label: Text(l10n.eventViewGroup),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildPoolSection(event),
            if (!pendingInvite) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildHostsSection(event, hostsAsync, uid),
            ],
            if (!privileged &&
                _isConfirmedMember(invite) &&
                !_isClosed(event.status)) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildConfirmedRoster(),
            ],
            if (privileged && !_isClosed(event.status)) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildGuestRoster(uid),
            ],
            if (invite != null && invite.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              if (_isPending(invite) && !_isClosed(event.status))
                _buildInviteActions(invite)
              else
                _InfoRow(
                  icon: Icons.mail_outline,
                  text: l10n.eventInviteStatus(
                    _inviteStatusLabel(
                      l10n,
                      invite['status'] as String? ?? 'pending',
                    ),
                  ),
                ),
            ],
            if (_canEdit(uid, event.status, hostsAsync.valueOrNull)) ...[
              const SizedBox(height: AppSpacing.lg),
              VButton.dark(
                label: l10n.eventEditButton,
                onPressed: () =>
                    context.push(RoutePaths.eventEdit(widget.eventId)),
              ),
            ],
            if (_canCancel(uid, event.status, hostsAsync.valueOrNull)) ...[
              const SizedBox(height: AppSpacing.sm),
              VButton.outlined(
                label: l10n.eventCancelButton,
                loading: _cancelling,
                onPressed: _cancelling ? null : _cancelEvent,
              ),
            ],
            if (!_isClosed(event.status))
              _buildLiveActions(hostsAsync.valueOrNull, uid, invite, assisted),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  /// Plugged event actions (2026-08-13): the attendee QR, the host/staff
  /// scanner and the photo gallery — each flag-gated and hidden once the
  /// event is closed (ended/cancelled). A PENDING invitee sees none of these
  /// (only the accept/decline card, 2026-09-09 security fix). An ASSISTED
  /// attendee ([assisted]) keeps the Scanner (host/staff) and Fotos but the
  /// Código action is permanently disabled — no navigation (2026-09-10).
  Widget _buildLiveActions(
    List<Map<String, dynamic>>? hosts,
    String? uid,
    Map<String, dynamic>? invite,
    bool assisted,
  ) {
    final l10n = AppLocalizations.of(context);
    // Scanner visibility (Stage 3): host AND staff scan attendance codes
    // (`validate_code` gates on role IN host/staff).
    final privileged = _isPrivileged(hosts, uid);
    if (!privileged && _isPendingInvite(invite)) {
      return const SizedBox.shrink();
    }
    final canScan = privileged;
    final showQr = ref.isEnabled(AppFeatureFlag.qr);
    final showPhotos = ref.isEnabled(AppFeatureFlag.photoUpload);
    if (!showQr && !showPhotos) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        if (showQr) ...[
          Row(
            children: [
              Expanded(
                child: VButton.outlined(
                  label: l10n.qrAttendanceTitle,
                  // Assisted → terminal: the button stays visible but disabled
                  // (no navigation). Re-entry never re-mints a QR.
                  onPressed: assisted
                      ? null
                      : () => context.push(RoutePaths.qr(widget.eventId)),
                ),
              ),
              if (canScan) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: VButton.outlined(
                    label: l10n.qrScannerTitle,
                    onPressed: () =>
                        context.push(RoutePaths.scanner(widget.eventId)),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (showPhotos) ...[
          const SizedBox(height: AppSpacing.sm),
          VButton.outlined(
            label: l10n.photosTitle,
            onPressed: () =>
                context.push(RoutePaths.eventPhotos(widget.eventId)),
          ),
        ],
      ],
    );
  }

  bool _isClosed(String status) {
    return status == 'ended' || status == 'cancelled';
  }

  bool _canEdit(
    String? uid,
    String status,
    List<Map<String, dynamic>>? hosts,
  ) {
    if (uid == null || hosts == null) return false;
    if (status == 'ended' || status == 'cancelled') return false;
    return hosts.any(
      (p) => p['user_id'] == uid && p['role'] == 'host',
    );
  }

  bool _canCancel(
    String? uid,
    String status,
    List<Map<String, dynamic>>? hosts,
  ) {
    return _canEdit(uid, status, hosts);
  }

  /// Whether the viewer is a host/staff of this event. Privileged people see
  /// the guest roster (RLS `ei_read_event_access`) and can scan (Stage 3,
  /// `validate_code` role IN host/staff); the full host/staff roster is
  /// read through `ep_read_event_access` (060_events/06_staff.sql).
  bool _isPrivileged(
    List<Map<String, dynamic>>? hosts,
    String? uid,
  ) {
    if (uid == null || hosts == null) return false;
    return hosts.any(
      (p) =>
          p['user_id'] == uid &&
          (p['role'] == 'host' || p['role'] == 'staff'),
    );
  }

  bool _isPending(Map<String, dynamic> invite) {
    return (invite['status'] as String? ?? 'pending') == 'pending';
  }

  /// A CONFIRMED member is an invitee whose invite is accepted/attended
  /// (2026-09-09). Host/staff are handled separately by [_isPrivileged]. Only
  /// confirmed members read the roster / mint a code.
  bool _isConfirmedMember(Map<String, dynamic>? invite) {
    final status = invite?['status'] as String?;
    return status == 'accepted' || status == 'attended';
  }

  /// Whether the caller holds a live PENDING invite. A pending invitee is not
  /// yet an attendee: they may only accept/decline (2026-09-09 security fix).
  bool _isPendingInvite(Map<String, dynamic>? invite) {
    return invite != null && invite.isNotEmpty && _isPending(invite);
  }

  /// Invitee accept/decline card for a PENDING invite (Stage 2,
  /// 060_events/05_manual_invites): the server flips status / frees the seat.
  Widget _buildInviteActions(Map<String, dynamic> invite) {
    final l10n = AppLocalizations.of(context);
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.eventInvitePendingBody,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: VButton.emphasized(
                  label: l10n.eventInviteAccept,
                  loading: _inviteBusy,
                  onPressed: _inviteBusy ? null : () => _acceptInvite(invite),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: VButton.outlined(
                  label: l10n.eventInviteDecline,
                  loading: _inviteBusy,
                  onPressed: _inviteBusy ? null : () => _declineInvite(invite),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _inviteBusy = false;
  bool _staffBusy = false;

  Future<void> _acceptInvite(Map<String, dynamic> invite) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _inviteBusy = true);
    try {
      await ref.read(myEventInviteProvider(widget.eventId).notifier).accept();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventInviteAcceptedSnack)),
      );
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _inviteBusy = false);
    }
  }

  Future<void> _declineInvite(Map<String, dynamic> invite) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _inviteBusy = true);
    try {
      await ref.read(myEventInviteProvider(widget.eventId).notifier).decline();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventInviteDeclinedSnack)),
      );
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _inviteBusy = false);
    }
  }

  /// Host/staff guest-roster card (Stage 2): "Invitar personas" opens the
  /// picker (reusing the minigame UserPickerView mechanism); the roster then
  /// lists every invite row with a per-status label (pending / accepted /
  /// attended). Invites are server-enforced against the frozen capacity.
  Widget _buildGuestRoster(String? uid) {
    final l10n = AppLocalizations.of(context);
    final guestsAsync = ref.watch(eventGuestsProvider(widget.eventId));
    final excluded = {
      ?uid,
    };

    Future<void> openInvitePicker() async {
      final picked = await Navigator.of(context).push<List<String>>(
        MaterialPageRoute(
          builder: (_) => EventInviteScreen(
            eventId: widget.eventId,
            excludedIds: excluded,
          ),
        ),
      );
      if (picked == null || picked.isEmpty || !mounted) return;
      try {
        await ref
            .read(eventGuestsProvider(widget.eventId).notifier)
            .inviteGuests(picked);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.eventsInviteSent)),
        );
      } catch (e) {
        if (mounted) showAppError(context, e);
      }
    }

    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.eventGuestsTitle,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              TextButton.icon(
                onPressed: openInvitePicker,
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: Text(l10n.eventInviteGuestsButton),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          guestsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text(
              l10n.eventGuestsLoadError,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (guests) => guests.isEmpty
                ? Text(
                    l10n.eventGuestsEmpty,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Column(
                    children: [
                      for (var i = 0; i < guests.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.xs),
                        _GuestRow(
                          username:
                              guests[i]['users']?['username'] as String? ??
                              '${guests[i]['user_id']}'.substring(0, 8),
                          status:
                              guests[i]['status'] as String? ?? 'pending',
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Read-only "confirmed attendees" card for a NON-privileged CONFIRMED event
  /// member (invite status accepted/attended — 2026-09-09, 060_events/09
  /// `ei_read_confirmed_roster` RLS): who is actually going. The server only
  /// returns the caller's own rows + the event's accepted/attended rows to a
  /// confirmed member (other people's pending stays host/own-only); the
  /// confirmed filter below is belt-and-braces. Hosts/staff keep the full management roster
  /// in [_buildGuestRoster]; this card is the attendee-side view of the same
  /// `event_invites` stream and updates live over realtime.
  Widget _buildConfirmedRoster() {
    final l10n = AppLocalizations.of(context);
    final guestsAsync = ref.watch(eventGuestsProvider(widget.eventId));

    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.eventAttendeesTitle,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          guestsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text(
              l10n.eventAttendeesLoadError,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (guests) {
              final confirmed = guests
                  .where((g) {
                    final status = g['status'] as String? ?? 'pending';
                    return status == 'accepted' || status == 'attended';
                  })
                  .toList();
              if (confirmed.isEmpty) {
                return Text(
                  l10n.eventAttendeesEmpty,
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < confirmed.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.xs),
                    _GuestRow(
                      username:
                          confirmed[i]['users']?['username'] as String? ??
                          '${confirmed[i]['user_id']}'.substring(0, 8),
                      status:
                          confirmed[i]['status'] as String? ?? 'accepted',
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPoolSection(Event event) {
    final l10n = AppLocalizations.of(context);
    final pool = event.preshardsPool;
    final distributed = event.preshardsDistributed;
    final cap = event.preshardsCapPerUser;
    final remainder = event.preshardsRemainderAction;

    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.eventsPreshardsPoolLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (pool <= 0)
            Text(
              l10n.eventNoPool,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else ...[
            Row(
              children: [
                const VShardIcon(),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.eventPoolAmount(pool),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              distributed
                  ? l10n.eventPoolDistributed
                  : l10n.eventPoolNotDistributed,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (cap != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.eventCapPerUser(cap),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (remainder != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.eventRemainderAction(
                  remainder == 'redistribute'
                      ? l10n.eventsRemainderRedistribute
                      : l10n.eventsRemainderReturn,
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Host + staff roster card (Stage 3): the header carries an "Añadir staff"
  /// action when the viewer is a role=host member and the event is open; each
  /// STAFF row gets a remove affordance (host only). Reads through the
  /// `ep_read_event_access` policy for hosts/staff (full roster) AND, since
  /// 2026-09-09 (060_events/09_attendee_roster.sql, `ep_read_member_roster`),
  /// event members (invitees) see the organizer roster read-only.
  Widget _buildHostsSection(
    Event event,
    AsyncValue<List<Map<String, dynamic>>> async,
    String? uid,
  ) {
    final l10n = AppLocalizations.of(context);
    final hosts = async.valueOrNull;
    final isHost =
        uid != null &&
        (hosts?.any(
              (p) => p['user_id'] == uid && p['role'] == 'host',
            ) ??
            false);
    final open = !_isClosed(event.status);

    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.eventHosts,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (isHost && open)
                TextButton.icon(
                  onPressed: _staffBusy ? null : _openStaffPicker,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: Text(l10n.eventStaffAddButton),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          async.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text(
              l10n.eventHostsError,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (members) => members.isEmpty
                ? Text(
                    l10n.eventNoHosts,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Column(
                    children: [
                      for (var i = 0; i < members.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.xs),
                        _HostMemberRow(
                          username:
                              members[i]['users']?['username'] as String? ??
                              '${members[i]['user_id']}'.substring(0, 8),
                          role: members[i]['role'] as String? ?? 'host',
                          removable:
                              isHost &&
                              open &&
                              (members[i]['role'] as String? ?? '') == 'staff',
                          busy: _staffBusy,
                          onRemove: () => _confirmRemoveStaff(
                            members[i],
                            members[i]['users']?['username'],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Opens the staff picker ([EventStaffScreen]); designates the selection
  /// through the host's roster provider (server-enforced capacity/gates).
  Future<void> _openStaffPicker() async {
    final l10n = AppLocalizations.of(context);
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => EventStaffScreen(eventId: widget.eventId),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _staffBusy = true);
    try {
      await ref
          .read(eventHostsProvider(widget.eventId).notifier)
          .designateStaff(picked);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.eventStaffAdded)));
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _staffBusy = false);
    }
  }

  /// Confirm-then-remove a staff member (host only — the server also rejects
  /// removing the host row). Removals free the staff member's seat.
  Future<void> _confirmRemoveStaff(
    Map<String, dynamic> member,
    Object? rawUsername,
  ) async {
    final l10n = AppLocalizations.of(context);
    final username =
        rawUsername is String && rawUsername.isNotEmpty
            ? rawUsername
            : '${member['user_id']}'.substring(0, 8);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.discoBlack,
        title: Text(
          l10n.eventStaffRemoveDialogTitle(username),
          style: const TextStyle(color: AppColors.white),
        ),
        content: Text(
          l10n.eventStaffRemoveDialogBody,
          style: const TextStyle(color: AppColors.mutedStrong),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.eventStaffRemoveConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final staffUserId = member['user_id'] as String;
    setState(() => _staffBusy = true);
    try {
      await ref
          .read(eventHostsProvider(widget.eventId).notifier)
          .removeStaff(staffUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.eventStaffRemoved)));
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _staffBusy = false);
    }
  }

  String _typeLabel(AppLocalizations l10n, String type) {
    return switch (type) {
      'casual' => l10n.eventsTypeCasual,
      'tono' => l10n.eventsTypeTono,
      _ => l10n.eventsTypeJuerga,
    };
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'draft' => l10n.eventStatusDraft,
      'live' => l10n.eventStatusLive,
      'ended' => l10n.eventStatusEnded,
      'cancelled' => l10n.eventStatusCancelled,
      _ => l10n.eventStatusUpcoming,
    };
  }

  String _inviteStatusLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'accepted' => l10n.eventInviteAccepted,
      'declined' => l10n.eventInviteDeclined,
      'attended' => l10n.eventInviteAttended,
      _ => l10n.eventInvitePending,
    };
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mutedStrong),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

/// One host/staff roster row — avatar + username + role label, with a
/// host-only remove affordance for STAFF rows. The label carries the state
/// (ESTA §1 / design doc §2.5 rule 5: color is never the only signal); the
/// avatar stays neutral glass.
class _HostMemberRow extends StatelessWidget {
  final String username;
  final String role;
  final bool removable;
  final bool busy;
  final VoidCallback onRemove;

  const _HostMemberRow({
    required this.username,
    required this.role,
    required this.removable,
    required this.busy,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roleLabel = role == 'host'
        ? l10n.eventRoleHost
        : l10n.eventRoleStaff;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.surfaceAlt,
          child: Text(
            // U-26 (U-25 F5): an empty (non-null) username would RangeError
            // on substring — the '?' initial fallback.
            username.isEmpty ? '?' : username.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 13, color: AppColors.white),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                roleLabel,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        if (removable)
          IconButton(
            tooltip: l10n.eventStaffRemove,
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.person_remove_outlined, size: 20),
            color: AppColors.mutedStrong,
          ),
      ],
    );
  }
}

/// One invited-guest row on the event detail roster (Stage 2): the
/// username + a per-invite-status label — never color-only (design §2.5
/// rule 5), matching the event invite status wording used elsewhere.
class _GuestRow extends StatelessWidget {
  final String username;
  final String status;

  const _GuestRow({required this.username, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusLabel = switch (status) {
      'accepted' => l10n.eventInviteAccepted,
      'attended' => l10n.eventInviteAttended,
      'declined' => l10n.eventInviteDeclined,
      _ => l10n.eventInvitePending,
    };
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.surfaceAlt,
          child: Text(
            username.isEmpty ? '?' : username.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 11, color: AppColors.white),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            username,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          statusLabel,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
