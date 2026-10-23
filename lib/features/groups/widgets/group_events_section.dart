import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/events/logic/event_formatters.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';

/// The group's events rendered INLINE (non-scrolling) — the group detail is
/// a single scroll: the Events tab is gone and this section feeds the parent
/// scroll. Loading/error/empty are handled here; an empty group hides the
/// section entirely.
class GroupEventsSection extends ConsumerStatefulWidget {
  const GroupEventsSection({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupEventsSection> createState() => _GroupEventsSectionState();
}

class _GroupEventsSectionState extends ConsumerState<GroupEventsSection> {
  bool _loading = true;
  Object? _error;
  List<Event> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await ref.read(eventServiceProvider).listEvents();
      final mine = all.where((e) => e.groupId == widget.groupId).toList();
      if (!mounted) return;
      setState(() {
        _events = mine;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: VLoadingView(),
      );
    }
    if (_error != null) {
      return ErrorView(message: _error!.toAppError().message, onRetry: _load);
    }
    if (_events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.groupsTabEvents.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final event in _events) _EventRow(event: event),
      ],
    );
  }
}

/// One group-event row: name, date range and location; tap → event detail.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final dateText = formatEventDateRange(
      event.startsAt,
      event.endsAt,
      Localizations.localeOf(context).languageCode,
    );

    return InkWell(
      onTap: () => context.push(RoutePaths.eventDetail(event.id)),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event, color: AppColors.mutedStrong),
            title: Text(event.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateText),
                if ((event.locationCity ?? event.locationName) != null &&
                    (event.locationCity ?? event.locationName)!.isNotEmpty)
                  Text(event.locationCity ?? event.locationName!),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
