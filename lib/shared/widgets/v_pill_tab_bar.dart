import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Glass pill segmented control: a `surface`@[trackOpacity] track with a
/// white@[borderOpacity] hairline border (flat glass — unlike `VGlassPill`,
/// no `BackdropFilter` blur);
/// the active segment carries a white outline and a white label, every other
/// segment a plain `muted` label. Built on [TabBar] so callers keep their
/// [TabController].
///
/// The track is [trackHeight] tall so each segment keeps a >=44pt tap target.
class VPillTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> labels;

  const VPillTabBar({
    super.key,
    required this.controller,
    required this.labels,
  });

  /// Track height — also the minimum tap-target height per segment (44pt).
  static const double trackHeight = 44;

  /// Opacity of the `surface` track fill.
  static const double trackOpacity = 0.85;

  /// Opacity of the white hairline border.
  static const double borderOpacity = 0.15;

  /// Fully-rounded pill geometry, derived from the track height.
  static const double _radius = trackHeight / 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: trackHeight,
      decoration: BoxDecoration(
        color: context.palette.surface.withValues(alpha: trackOpacity),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: context.palette.foreground.withValues(alpha: borderOpacity),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          border: Border.all(color: context.palette.foreground),
          borderRadius: BorderRadius.circular(_radius),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.transparent,
        labelColor: context.palette.foreground,
        // `muted` is 3.66:1 on black — AA-large only, and these are 12px
        // labels, so unselected tabs were unreadable. `mutedStrong` is AA.
        unselectedLabelColor: context.palette.mutedForeground,
        labelStyle: Theme.of(context).textTheme.labelMedium,
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        tabs: [for (final label in labels) Tab(text: label)],
      ),
    );
  }
}
