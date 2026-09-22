import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';

/// Glass pill segmented control matching the floating nav bar's palette: a
/// `surface`@[trackOpacity] track with a white@[borderOpacity] hairline border;
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

  /// Opacity of the `surface` track fill, matching the nav pill.
  static const double trackOpacity = 0.85;

  /// Opacity of the white hairline border, matching the nav pill.
  static const double borderOpacity = 0.15;

  /// Fully-rounded pill geometry, derived from the track height.
  static const double _radius = trackHeight / 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: trackHeight,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: trackOpacity),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: AppColors.white.withValues(alpha: borderOpacity),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          border: Border.all(color: AppColors.white),
          borderRadius: BorderRadius.circular(_radius),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.transparent,
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.muted,
        labelStyle: Theme.of(context).textTheme.labelMedium,
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        tabs: [for (final label in labels) Tab(text: label)],
      ),
    );
  }
}
