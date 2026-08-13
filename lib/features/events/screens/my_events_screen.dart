import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/events/logic/event_formatters.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/glass/glass.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_aurora.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_network_image.dart';

/// The events tab (R1 events sweep): the session's events earliest-first,
/// with a create CTA that routes to the groups tab (an event is always
/// created inside a group).
///
/// LUXE v2: the events family is **peach** — [AppGradients.peach] aurora +
/// hero + CTA. The list cards are neutral white-only glass (XL-17: the
/// family is spent on the hero and the primary CTA, never a color spray).
class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> {
  Future<void> _refresh() async {
    await ref.read(myEventsProvider.notifier).refresh();
  }

  /// Creation lives inside a group (ECRT — I-54): the CTA lands on the
  /// groups tab where the user picks one.
  void _openGroupsTab() => context.go(RoutePaths.mainGroups);

  void _openEvent(Map<String, dynamic> event) {
    context.push(RoutePaths.eventDetail(event['id'] as String));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eventsAsync = ref.watch(myEventsProvider);

    return Scaffold(
      // LUXE directive #1: black background always — even outside the theme.
      backgroundColor: AppColors.discoBlack,
      body: SafeArea(
        child: VAurora(
          // The events ambient: black + a faint peach aurora (the family
          // alpha-capped so content stays the hero).
          gradients: const [AppGradients.peach],
          opacity: 0.08,
          child: eventsAsync.when(
            // U-22 (§5.8): the first load shows the list skeleton instead of
            // the bare spinner; pull-to-refresh keeps the list visible.
            skipLoadingOnRefresh: true,
            loading: () => const VSkeletonList(rows: 4),
            error: (e, _) =>
                ErrorView(message: e.toAppError().message, onRetry: _refresh),
            data: (events) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _EventsHeader(
                        title: l10n.eventsTabTitle,
                        onCreate: _openGroupsTab,
                      ),
                    ),
                    if (events.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: VEmptyView(
                          icon: Icons.event_outlined,
                          title: l10n.eventsEmpty,
                          description: l10n.eventsEmptyBody,
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) => _MyEventCard(
                          event: events[index],
                          onTap: () => _openEvent(events[index]),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Brand hero + create CTA. ONE hero per screen (directive #8) — the
/// "MIS EVENTOS" display voice in the peach family; the CTA explains that
/// creation happens from a group.
class _EventsHeader extends StatelessWidget {
  final String title;
  final VoidCallback onCreate;

  const _EventsHeader({required this.title, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VDisplayText(text: title, gradient: AppGradients.peach, maxLines: 2),
          const SizedBox(height: AppSpacing.lg),
          // The create CTA is a primary action — glowAccent, peach family.
          VButton.glowAccent(
            label: l10n.eventsCreateCta,
            gradient: AppGradients.peach,
            onPressed: onCreate,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.eventsCreateCtaBody,
            style: const TextStyle(color: AppColors.mutedStrong, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Regular event row: sharp hairline glass (glow reserved for CTAs), cover,
/// name, type + status badges, date range and location. Tap → event detail.
class _MyEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const _MyEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = event['id'] as String;
    final coverUrl = event['cover_url'] as String?;
    final location = event['location_name'] as String?;
    final startsAt =
        DateTime.tryParse(event['starts_at'] as String? ?? '') ??
        DateTime.now();
    final endsAt =
        DateTime.tryParse(event['ends_at'] as String? ?? '') ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.md,
      ),
      child: InkWell(
        key: ValueKey('my-event-card-$id'),
        onTap: onTap,
        child: VGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (coverUrl != null && coverUrl.isNotEmpty) ...[
                VNetworkImage(
                  imageUrl: coverUrl,
                  height: 140,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                event['name'] as String? ?? l10n.eventDetailTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  VBadge(
                    label: _typeLabel(
                      l10n,
                      event['type'] as String? ?? 'casual',
                    ),
                  ),
                  VBadge(
                    label: _statusLabel(
                      l10n,
                      event['status'] as String? ?? 'upcoming',
                    ),
                  ),
                  if (event['group_id'] != null)
                    VBadge(label: l10n.eventGroupScoped),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: AppIconSizes.sm,
                    color: AppColors.mutedStrong,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      formatEventDateRange(
                        startsAt,
                        endsAt,
                        Localizations.localeOf(context).languageCode,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedStrong,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: AppIconSizes.sm,
                    color: AppColors.mutedStrong,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      location ?? l10n.eventNoLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedStrong,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
}
