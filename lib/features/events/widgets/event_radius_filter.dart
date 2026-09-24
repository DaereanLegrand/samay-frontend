import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/features/events/providers/event_discovery_providers.dart';
import 'package:samay/features/events/providers/event_radius_providers.dart';
import 'package:samay/l10n/app_localizations.dart';

/// The Events-tab distance filter: a single radius [Slider] (0..100 km in 5 km
/// steps) with its value to the right. 0 is the deactivated position — the
/// track shows only its faint inactive tint and the thumb stays visible; the
/// user drags up to activate the distance filter.
///
/// The slider is only operable once a reference point exists (set through the
/// location controls next to it). Replaces the old km chip row and the
/// "Cerca de mí" switch.
class RadiusSlider extends ConsumerWidget {
  final AppLocalizations l10n;

  const RadiusSlider({super.key, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLocation = ref.watch(eventReferencePointProvider) != null;
    final value = ref
        .watch(eventRadiusFilterProvider)
        .clamp(kEventRadiusMinKm, kEventRadiusMaxKm)
        .toDouble();
    final divisions =
        ((kEventRadiusMaxKm - kEventRadiusMinKm) / kEventRadiusStepKm).round();
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value,
            min: kEventRadiusMinKm,
            max: kEventRadiusMaxKm,
            divisions: divisions,
            label: l10n.feedRadiusKm(value.round()),
            // Disabled (greyed) until a reference point exists — without one
            // the distance filter cannot apply.
            onChanged: hasLocation
                ? (v) => ref.read(eventRadiusFilterProvider.notifier).select(v)
                : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Fixed slot so the track never shifts as the value changes.
        SizedBox(
          width: 56,
          child: Text(
            l10n.feedRadiusKm(value.round()),
            textAlign: TextAlign.right,
            style: AppTypography.labelMedium.copyWith(
              color: hasLocation ? AppColors.white : AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}
