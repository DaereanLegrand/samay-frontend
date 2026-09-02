import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/models/user_search_result.dart';
import 'package:samay/features/friends/widgets/user_picker_view.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Minigame player picker (140_minigame_invites / 205_minigame_invite_lobby) —
/// a THIN scaffold over the reusable [UserPickerView] (the ChatThreadView
/// architecture): the search + multi-select is the shared widget; this screen
/// only owns the [VHeaderBar] confirm action and pops the selected user ids
/// for the caller to create the session with. Invitees come from the whole
/// user-search pool (any user, not just group members) — the friends-only +
/// blocked gates are enforced server-side.
///
/// The HOST's picker shows an "enviada"/"sent" tag on invitees who already
/// hold a PENDING invite for this session (2026-09-02) — read-only, from
/// [minigameInviteeStatesProvider]. A declined invite deletes its row, so a
/// declined (or kicked) player renders as a fresh invitee: re-inviting is a
/// normal invite, there is no distinct resend affordance.
class MinigameInviteScreen extends ConsumerStatefulWidget {
  const MinigameInviteScreen({
    super.key,
    this.excludedIds = const {},
    required this.sessionId,
  });

  /// User ids to exclude from the picker (e.g. already-participant members).
  final Set<String> excludedIds;

  /// The session being invited into — the host's invite rows (RLS
  /// `mi_read_own` created_by) drive the "sent" tags.
  final String sessionId;

  @override
  ConsumerState<MinigameInviteScreen> createState() =>
      _MinigameInviteScreenState();
}

class _MinigameInviteScreenState extends ConsumerState<MinigameInviteScreen> {
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

  /// A right-aligned "enviada"/"sent" tag for a user who already holds a
  /// pending invite — the invite was sent, picking them again is a no-op
  /// server-side (idempotent), so the row stays tappable to deselect.
  Widget? _trailingFor(UserSearchResult user) {
    final l10n = AppLocalizations.of(context);
    final states = ref
        .watch(minigameInviteeStatesProvider(widget.sessionId))
        .valueOrNull;
    if (states == null) return null;
    if (states[user.id] != 'pending') return null;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Text(
        l10n.minigamesInviteSent,
        style: const TextStyle(
          color: AppColors.mutedStrong,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: VHeaderBar(
        title: l10n.minigamesInviteTitle,
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text(l10n.minigamesInviteCount(_selected.length)),
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
