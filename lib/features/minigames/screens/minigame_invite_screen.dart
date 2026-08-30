import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/features/friends/widgets/user_picker_view.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Minigame player picker (140_minigame_invites) — a THIN scaffold over the
/// reusable [UserPickerView] (the ChatThreadView architecture): the search +
/// multi-select is the shared widget; this screen only owns the [VHeaderBar]
/// confirm action and pops the selected user ids for the caller to create
/// the session with. Invitees come from the whole user-search pool (any
/// user, not just group members) — the friends-only + blocked gates are
/// enforced server-side at create time.
class MinigameInviteScreen extends ConsumerStatefulWidget {
  const MinigameInviteScreen({super.key, this.excludedIds = const {}});

  /// User ids to exclude from the picker (e.g. already-group-members when a
  /// caller wants only fresh invitees).
  final Set<String> excludedIds;

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
        ),
      ),
    );
  }
}
