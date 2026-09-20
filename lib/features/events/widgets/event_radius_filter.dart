import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/features/events/providers/event_radius_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_chip.dart';

/// Radius chips (5/20/50/anywhere) from `app_config`
/// (`feed.nearby_radius_km_options`); the selection drives
/// [eventRadiusFilterProvider]. Functional today as a preference — the
/// distance filter applies once a device location exists.
///
/// Monochrome: plain `VChip` — white border + label, white fill + black
/// label when selected.
class RadiusFilterBar extends ConsumerWidget {
  final AppLocalizations l10n;

  const RadiusFilterBar({super.key, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(eventRadiusOptionsProvider);
    final selected = ref.watch(eventRadiusFilterProvider);
    return SizedBox(
      // U-19 (§7.3): the chip row must grow with the text scale — a hard
      // 36px height clips the chips at ≥1.5× (the `AppSpacing.scale` helper).
      height: AppSpacing.scale(context, 36),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final radius = options[index];
          final anywhere = radius >= kEventRadiusAnywhereKm;
          return VChip(
            label: anywhere
                ? l10n.feedRadiusAnywhere
                : l10n.feedRadiusKm(radius.round()),
            selected: selected == radius,
            onSelected: () =>
                ref.read(eventRadiusFilterProvider.notifier).select(radius),
          );
        },
      ),
    );
  }
}

/// The radius filter block at the top of the events tab: chips + honest
/// no-location notice. Scrolls away beneath the pinned [VHeaderSliver] glass.
class EventRadiusHeader extends StatelessWidget {
  final AppLocalizations l10n;

  const EventRadiusHeader({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadiusFilterBar(l10n: l10n),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.feedNoLocationNotice,
          style: const TextStyle(color: AppColors.mutedStrong, fontSize: 12),
        ),
      ],
    );
  }
}
