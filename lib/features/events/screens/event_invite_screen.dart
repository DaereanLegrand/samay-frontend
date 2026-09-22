import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/models/user_search_result.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/friends/widgets/user_picker_view.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Event guest picker (060_events/05_manual_invites, Stage 2) — a THIN
/// scaffold over the reusable [UserPickerView] (the ChatThreadView / minigame
/// architecture): search + multi-select is the shared widget; this screen
/// only owns the [VHeaderBar] confirm action and pops the selected user ids
/// for the caller to invite. Invitees come from the whole user-search pool
/// (any user — the server enforces blocked/live gates + the frozen capacity).
///
/// The HOST's picker shows a "invitado/sent" tag on users who already hold an
/// invite for this event — read-only, from
/// [eventGuestsProvider]. Picking them again is a no-op server-side
/// (idempotent), so the row stays tappable to deselect.
class EventInviteScreen extends ConsumerStatefulWidget {
  const EventInviteScreen({
    super.key,
    required this.eventId,
    this.excludedIds = const {},
  });

  /// The event being invited into — the host's guest rows (RLS
  /// `ei_read_event_access`) drive the "sent" tags.
  final String eventId;

  /// User ids to exclude from the picker (e.g. already host/staff).
  final Set<String> excludedIds;

  @override
  ConsumerState<EventInviteScreen> createState() => _EventInviteScreenState();
}

class _EventInviteScreenState extends ConsumerState<EventInviteScreen> {
  final Set<String> _selected = {};

  void _onSelectionChanged(Set<String> selection) {
    setState(
      () => _selected
        ..clear()
        ..addAll(selection),
    );
  }

  void _confirm() {
    if (_selected.isEmpty) return;
    Navigator.of(context).pop(_selected.toList());
  }

  /// A right-aligned "invitado/sent" tag for a user who already holds an
  /// invite (pending/accepted/attended) — the invite was sent; picking them
  /// again is a no-op server-side, so the row stays tappable to deselect.
  Widget? _trailingFor(UserSearchResult user) {
    final l10n = AppLocalizations.of(context);
    final guests = ref.watch(eventGuestsProvider(widget.eventId)).valueOrNull;
    if (guests == null) return null;
    final invited = guests.any((g) => g['user_id'] == user.id);
    if (!invited) return null;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Text(
        l10n.eventsInviteSentTag,
        style: AppTypography.bodySmall.copyWith(color: AppColors.mutedStrong),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: VHeaderBar(
        title: l10n.eventsInviteTitle,
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text(l10n.eventsInviteCount(_selected.length)),
            ),
        ],
        child: UserPickerView(
          excludedIds: widget.excludedIds,
          onSelectionChanged: _onSelectionChanged,
          trailingBuilder: _trailingFor,
        ),
      ),
    );
  }
}
