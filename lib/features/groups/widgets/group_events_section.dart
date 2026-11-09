import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/events/logic/event_formatters.dart';
import 'package:samay/core/theme/app_palette.dart';
import 'package:samay/core/theme/app_theme_scope.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/core/theme/app_palette_context.dart';

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
    final palette = AppThemeScope.paletteOf(context);
    final themed = AppThemeScope.isThemed(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.groupsTabEvents.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: themed ? palette.foreground : context.palette.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final event in _events)
          _EventRow(event: event, palette: themed ? palette : null),
      ],
    );
  }
}

/// One group-event row: name, date range and location; tap → event detail.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, this.palette});

  final Event event;
  final AppPalette? palette;

  @override
  Widget build(BuildContext context) {
    final dateText = formatEventDateRange(
      event.startsAt,
      event.endsAt,
      Localizations.localeOf(context).languageCode,
    );
    final muted = palette?.mutedForeground ?? context.palette.mutedForeground;
    final ink = palette?.foreground ?? context.palette.foreground;

    return InkWell(
      onTap: () => context.push(RoutePaths.eventDetail(event.id)),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            iconColor: ink,
            textColor: ink,
            leading: Icon(Icons.event, color: muted),
            title: Text(
              event.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: ink),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateText, style: TextStyle(color: muted)),
                if ((event.locationCity ?? event.locationName) != null &&
                    (event.locationCity ?? event.locationName)!.isNotEmpty)
                  Text(
                    event.locationCity ?? event.locationName!,
                    style: TextStyle(color: muted),
                  ),
              ],
            ),
            trailing: Icon(Icons.chevron_right, size: 20, color: muted),
          ),
          Divider(height: 1, color: palette?.hairline ?? context.palette.hairline),
        ],
      ),
    );
  }
}
