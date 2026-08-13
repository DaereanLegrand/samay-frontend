import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/events/logic/event_formatters.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';

/// Group events tab (R2 — replaces the "Eventos próximamente" placeholder).
///
/// Lists the group's events from [EventService.listEvents], filtered by the
/// `group_id` column (events carry the group FK, see `createEvent`).
/// Loading / error / empty / list states are real; tapping an event pushes
/// the event-detail route.
class GroupEventsTab extends ConsumerStatefulWidget {
  final String groupId;

  const GroupEventsTab({super.key, required this.groupId});

  @override
  ConsumerState<GroupEventsTab> createState() => _GroupEventsTabState();
}

class _GroupEventsTabState extends ConsumerState<GroupEventsTab> {
  bool _loading = true;
  Object? _error;
  List<Map<String, dynamic>> _events = const [];

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
      final mine = all.where((e) => e['group_id'] == widget.groupId).toList();
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

  Widget _scrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) return _scrollable(const VLoadingView());
    if (_error != null) {
      return _scrollable(
        ErrorView(message: _error!.toAppError().message, onRetry: _load),
      );
    }
    if (_events.isEmpty) {
      return _scrollable(
        VEmptyView(
          icon: Icons.event_outlined,
          title: l10n.groupsEventsEmptyTitle,
          description: l10n.groupsEventsEmptyBody,
        ),
      );
    }
    return _scrollable(
      Column(children: [for (final event in _events) _EventRow(event: event)]),
    );
  }
}

/// One group-event row (hairline style, mirroring the members tab rows):
/// name, date range and location; tap → event detail.
class _EventRow extends StatelessWidget {
  final Map<String, dynamic> event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = event['name'] as String? ?? l10n.commonGroup;
    final locationName = event['location_name'] as String?;
    final startsAt = DateTime.tryParse(event['starts_at'] as String? ?? '');
    final endsAt = DateTime.tryParse(event['ends_at'] as String? ?? '');
    final dateText = startsAt != null && endsAt != null
        ? formatEventDateRange(
            startsAt,
            endsAt,
            Localizations.localeOf(context).languageCode,
          )
        : null;

    return InkWell(
      onTap: () => context.push(RoutePaths.eventDetail(event['id'] as String)),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.event,
              size: AppIconSizes.md,
              color: AppGradients.violet.colors.first,
            ),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dateText != null) Text(dateText),
                if (locationName != null && locationName.isNotEmpty)
                  Text(locationName),
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
