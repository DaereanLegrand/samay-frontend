import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/friends/widgets/user_picker_view.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Event staff picker (060_events/06_staff.sql, Stage 3) — a THIN scaffold
/// over the reusable [UserPickerView], exactly like [EventInviteScreen]:
/// search + multi-select is the shared widget; this screen only owns the
/// [VHeaderBar] confirm action and pops the selected user ids for the host to
/// designate as staff.
///
/// Existing hosts/staff (plus the host themself) are EXCLUDED from the pool —
/// the server treats them as idempotent no-ops anyway; the host can only ever
/// pick fresh staff here.
class EventStaffScreen extends ConsumerStatefulWidget {
  const EventStaffScreen({super.key, required this.eventId});

  /// The event getting staff — the hosts roster (RLS
  /// `ep_read_event_access`) drives the exclusion set.
  final String eventId;

  @override
  ConsumerState<EventStaffScreen> createState() => _EventStaffScreenState();
}

class _EventStaffScreenState extends ConsumerState<EventStaffScreen> {
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
    final hosts = ref.watch(eventHostsProvider(widget.eventId)).valueOrNull;
    final excluded = <String>{
      for (final h in hosts ?? const <Map<String, dynamic>>[])
        if (h['user_id'] case final String id) id,
    };
    return Scaffold(
      body: VHeaderBar(
        title: l10n.eventStaffPickerTitle,
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text(l10n.eventStaffCount(_selected.length)),
            ),
        ],
        child: UserPickerView(
          excludedIds: excluded,
          onSelectionChanged: _onSelectionChanged,
        ),
      ),
    );
  }
}
