import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

/// Single source of truth for every top-header dimension in the app.
///
/// Both header presentations (the fixed title bar and the iOS-style
/// collapsing header) share these values so they can never drift. Screens
/// only ever reference these (or [VDisplayText] / [VHeaderBar] /
/// [VHeaderSliver]) instead of inventing their own insets.
abstract final class VHeaderMetrics {
  /// Horizontal inset for every title row AND every hero title. 24px
  /// (`AppSpacing.screenHorizontal` — the Feed/Eventos hero pad), so
  /// "social" / "perfil" / "notificaciones" start on the same x as "samay" /
  /// "mis eventos".
  static const EdgeInsets titleInset = EdgeInsets.symmetric(
    horizontal: AppSpacing.screenHorizontal,
  );

  /// App-added gap between the OS safe inset and the title row's top — 16px
  /// (`AppSpacing.lg`). Both the fixed bar and the collapsed header reserve
  /// this, so every title glyph sits at the same y at rest.
  static const double heroTopPad = AppSpacing.lg;

  /// Height of the title-content band. Fixed 48px so the row always starts at
  /// [heroTopPad] whether or not a back arrow / action is present.
  static const double titleRowHeight = 48;

  /// Height the fixed bar reserves (top pad + row + matching bottom pad).
  static const double barHeight = 80;

  /// The compact band below the status inset once fully collapsed.
  static const double collapsedBarHeight = titleRowHeight;

  /// Neutral glass surface behind the collapsed title (matches the bottom-nav
  /// pill: `surface` α0.85 over black).
  static const Color glassFill = Color(0xD90A0A0A);

  /// Faint white bottom sheen of the glass (the nav pill's α0.15 border).
  static const Color glassSheen = Color(0x26FFFFFF);

  /// Backdrop blur sigma of the glass (matches the nav pill).
  static const double glassBlur = 20;

  /// Playfair's hhea optical correction — title glyph ink centers above the
  /// geometric center, so leading icons are nudged down to read centered.
  static const double iconOpticalNudge = 6;
}

/// The single shared title row used by every header presentation: an optional
/// back arrow, the title (plain [VDisplayText] or a custom [titleWidget] such
/// as the truth/dare two-line header), and trailing [actions].
class VHeaderTitleRow extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final int? maxLines;
  final double height;

  const VHeaderTitleRow({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.maxLines = 1,
    this.height = VHeaderMetrics.titleRowHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (showBack)
            Transform.translate(
              offset: const Offset(0, VHeaderMetrics.iconOpticalNudge),
              child: BackButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ),
          if (showBack && (title != null || titleWidget != null))
            const SizedBox(width: AppSpacing.xs),
          if (titleWidget != null)
            Expanded(child: titleWidget!)
          else if (title != null)
            Expanded(
              child: VDisplayText(text: title!, maxLines: maxLines),
            ),
          ...?actions,
        ],
      ),
    );
  }
}

/// Unified top bar — one definition for every pushed screen's header.
///
/// Fixed title bar (does not scroll): [VHeaderMetrics.heroTopPad] below the OS
/// safe inset, the shared [VHeaderTitleRow], an optional full-bleed [bottom]
/// strip, and an expanding [child] body.
class VHeaderBar extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final int? maxLines;
  final Widget? bottom;
  final Widget? child;

  const VHeaderBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.maxLines = 1,
    this.bottom,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: VHeaderMetrics.barHeight,
          child: Padding(
            padding: VHeaderMetrics.titleInset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: VHeaderMetrics.heroTopPad),
                VHeaderTitleRow(
                  title: title,
                  titleWidget: titleWidget,
                  actions: actions,
                  showBack: showBack,
                  onBack: onBack,
                  maxLines: maxLines,
                ),
              ],
            ),
          ),
        ),
        ?bottom,
      ],
    );

    final content = child == null
        ? header
        : Column(
            children: [
              header,
              Expanded(child: child!),
            ],
          );

    return SafeArea(bottom: false, child: content);
  }
}

/// iOS-style collapsing header for scrollable tab roots (Feed 'samay',
/// Eventos 'mis eventos'). Use as the FIRST sliver of a `CustomScrollView`.
///
/// Expanded: the shared hero title at [VHeaderMetrics.heroTopPad], exactly
/// aligned with the fixed [VHeaderBar]. As the user scrolls, the header
/// collapses (iOS large-title style) to a compact centered title over a
/// neutral blurred glass ([VHeaderMetrics.glassFill]/[glassBlur]).
class VHeaderSliver extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final int? maxLines;

  const VHeaderSliver({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBack = false,
    this.onBack,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final statusTop = MediaQuery.paddingOf(context).top;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CollapsingDelegate(
        title: title,
        titleWidget: titleWidget,
        actions: actions,
        showBack: showBack,
        onBack: onBack,
        maxLines: maxLines,
        statusTop: statusTop,
      ),
    );
  }
}

/// [VHeaderSliver]'s persistent delegate. min = collapsed glass bar,
/// max = expanded hero.
class _CollapsingDelegate extends SliverPersistentHeaderDelegate {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final int? maxLines;
  final double statusTop;

  _CollapsingDelegate({
    required this.title,
    required this.titleWidget,
    required this.actions,
    required this.showBack,
    required this.onBack,
    required this.maxLines,
    required this.statusTop,
  });

  double get _expandedInset =>
      statusTop + VHeaderMetrics.heroTopPad + VHeaderMetrics.titleRowHeight;

  double get _collapsedInset => statusTop + VHeaderMetrics.collapsedBarHeight;

  @override
  double get minExtent => _collapsedInset;

  @override
  double get maxExtent => _expandedInset;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // The status-bar/notch inset. The collapsed glass extends under it (iOS
    // large-title style); the expanded title clears it with [heroTopPad].
    final statusTop = MediaQuery.paddingOf(context).top;
    final progress = (shrinkOffset / (maxExtent - minExtent))
        .clamp(0.0, 1.0)
        .toDouble();
    final currentHeight = maxExtent - shrinkOffset;

    // Expanded top-aligned title row (clears the status bar by heroTopPad).
    final expandedTitle = Padding(
      padding: EdgeInsets.only(top: statusTop + VHeaderMetrics.heroTopPad),
      child: VHeaderTitleRow(
        title: title,
        titleWidget: titleWidget,
        actions: actions,
        showBack: showBack,
        onBack: onBack,
        maxLines: maxLines,
      ),
    );

    // Glass surface with the compact title centered inside.
    final glassTitle = VHeaderTitleRow(
      title: title,
      titleWidget: titleWidget,
      actions: actions,
      showBack: showBack,
      onBack: onBack,
      maxLines: 1,
    );
    final glass = ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: VHeaderMetrics.glassBlur,
          sigmaY: VHeaderMetrics.glassBlur,
        ),
        child: Container(
          width: double.infinity,
          height: currentHeight,
          color: VHeaderMetrics.glassFill,
          child: Stack(
            children: [
              // Compact title centered in the band BELOW the status inset.
              Positioned(
                left: 0,
                right: 0,
                top: statusTop,
                height: (currentHeight - statusTop).clamp(0, double.infinity),
                child: Opacity(
                  opacity: progress,
                  child: Center(
                    child: Padding(
                      padding: VHeaderMetrics.titleInset,
                      child: glassTitle,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(height: 1, color: VHeaderMetrics.glassSheen),
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Glass is always present; it fades in over scrolling content.
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(opacity: progress, child: glass),
          ),
        ),
        // The expanded hero fades out as it collapses away.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: 1 - progress,
            child: IgnorePointer(
              ignoring: progress > 0.5,
              child: Padding(
                padding: VHeaderMetrics.titleInset,
                child: expandedTitle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _CollapsingDelegate oldDelegate) {
    return title != oldDelegate.title ||
        titleWidget != oldDelegate.titleWidget ||
        actions != oldDelegate.actions ||
        showBack != oldDelegate.showBack ||
        maxLines != oldDelegate.maxLines ||
        statusTop != oldDelegate.statusTop;
  }
}
