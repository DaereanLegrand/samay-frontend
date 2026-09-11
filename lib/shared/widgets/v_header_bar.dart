import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
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

  /// The typographic band that defines the header's SHARED optical centerline.
  /// Every element in [VHeaderTitleRow] (back arrow, title, actions) is
  /// centered on this one line, measured from the title font's real metrics, so
  /// the alignment is identical at ANY font size (app-wide standard).
  static const HeaderOpticalReference opticalReference =
      HeaderOpticalReference.xHeight;

  /// Fine-tune (px, down-positive) applied to the back arrow AFTER optical
  /// centering. 0 by default — the optical band does the alignment.
  static const double backArrowNudge = 0;

  /// Fine-tune (px, down-positive) applied to every action AFTER optical
  /// centering. 0 by default.
  static const double actionNudge = 0;
}

/// Which typographic band defines the header's shared optical centerline.
///
/// Model A (Apple's approach): the three elements keep their native heights;
/// only their centers are forced onto one band centerline. Because the band is
/// derived from the font's own metrics (not from the glyphs of a particular
/// string), it is stable across text and font size.
enum HeaderOpticalReference {
  /// Cap height — Apple's default reference for aligning symbols to text.
  capHeight,

  /// x-height — the lowercase body (v/e/a/x), ignoring ascenders/descenders.
  xHeight,
}

// ── Optical alignment (Model A) ──────────────────────────────────────────────
//
// One shared centerline per header: the title's reference band center (cap- or
// x-height, per [VHeaderMetrics.opticalReference]). The band is derived from
// the title FONT's metrics plus the real laid-out baseline, so it is stable at
// any font size and for any title string. Each element (back arrow, title,
// action) is centered on that one line.

/// The cap/x-height ratio for [family] for the configured reference band.
double _referenceRatio(String? family) =>
    VHeaderMetrics.opticalReference == HeaderOpticalReference.capHeight
    ? AppTypography.capHeightRatioFor(family)
    : AppTypography.xHeightRatioFor(family);

/// The baseline position (from the top of the single-line box) for a line at
/// [fontSize] with [style]'s line-height, using the font's natural typo metrics.
///
/// Flutter centers the font's NATURAL run inside a shorter line box (and scales
/// it up when the box is taller):
///   natural line = fontSize·(ascent+descent)
///   shorter box → baseline = (box − natural)/2 + fontSize·ascent
///   taller  box → baseline = box · ascent/(ascent+descent)
/// An analytic [TextPainter] does NOT reproduce this for a compressed box, so
/// computing it here keeps the header shift exact at any font/size.
double _baselineInBox(TextStyle style, double fontSize) {
  final family = style.fontFamily;
  final boxH = fontSize * (style.height ?? 1.0);
  final asc = AppTypography.ascentRatioFor(family);
  final desc = AppTypography.descentRatioFor(family);
  final naturalH = fontSize * (asc + desc);
  if (boxH <= naturalH) return (boxH - naturalH) / 2 + fontSize * asc;
  return boxH * asc / (asc + desc);
}

/// Down-positive offset that centers [style]'s reference band inside its own
/// laid-out line box, at the ambient text scale. Adding it makes the Row's
/// default center alignment land every element's band center on the same line.
double _opticalShift(BuildContext context, TextStyle style) {
  final fontSize = MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14);
  final baseline = _baselineInBox(style, fontSize);
  final bandCenter =
      baseline - fontSize * _referenceRatio(style.fontFamily) / 2;
  final boxH = fontSize * (style.height ?? 1.0);
  return boxH / 2 - bandCenter;
}

/// The label style used to align a TEXT action (buttons). Icons are aligned by
/// their box; text buttons by their label's optical band.
TextStyle _actionLabelStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14);

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
    // Model A — one shared optical centerline. The Row's own center is the
    // centerline; each element is shifted so its reference band center lands
    // there: icons by their grid-balanced box, text by its font-metric band.
    final titleStyle = VDisplayText.styleFor(VDisplayText.defaultSize);
    final titleShift = title != null && titleWidget == null
        ? _opticalShift(context, titleStyle)
        : 0.0;
    final labelShift = _opticalShift(context, _actionLabelStyle(context));
    final hasTitle = title != null || titleWidget != null;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (showBack)
            Transform.translate(
              offset: const Offset(0, VHeaderMetrics.backArrowNudge),
              child: BackButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ),
          if (showBack && hasTitle) const SizedBox(width: AppSpacing.xs),
          if (titleWidget != null)
            Expanded(child: titleWidget!)
          else if (title != null)
            Expanded(
              child: Transform.translate(
                offset: Offset(0, titleShift),
                child: VDisplayText(text: title!, maxLines: maxLines),
              ),
            ),
          // Actions: icons align by box center, text buttons by their label
          // band. Fine-tune rides `actionNudge` — callers never offset.
          ...?actions?.map((action) {
            final shift =
                (_actionIsText(action) ? labelShift : 0.0) +
                VHeaderMetrics.actionNudge;
            return Transform.translate(offset: Offset(0, shift), child: action);
          }),
        ],
      ),
    );
  }
}

/// Whether [action] is a text-labeled button (align by its label band) vs an
/// icon/composite (align by box center). Unwraps a single [Padding] so a padded
/// [TextButton] still counts. Icons and composite rows (icon + text) use the
/// box center — their internal content is grid-balanced by construction.
bool _actionIsText(Widget action) {
  Widget? w = action;
  while (w is Padding) {
    w = w.child;
  }
  return w is ButtonStyleButton;
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

  /// A permanently visible strip pinned at the BOTTOM of the header (e.g. the
  /// Social pill tab bar). Mirrors `SliverAppBar.bottom`: only the title
  /// region above it collapses — [bottom] stays fixed. The caller must supply
  /// its exact [bottomHeight] so the header extents are correct.
  final Widget? bottom;

  /// Height of [bottom], included in both min and max extents.
  final double? bottomHeight;

  const VHeaderSliver({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBack = false,
    this.onBack,
    this.maxLines = 1,
    this.bottom,
    this.bottomHeight,
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
        bottom: bottom,
        bottomHeight: bottomHeight ?? 0,
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
  final Widget? bottom;
  final double bottomHeight;

  _CollapsingDelegate({
    required this.title,
    required this.titleWidget,
    required this.actions,
    required this.showBack,
    required this.onBack,
    required this.maxLines,
    required this.statusTop,
    required this.bottom,
    required this.bottomHeight,
  });

  double get _titleExpandedInset =>
      statusTop + VHeaderMetrics.heroTopPad + VHeaderMetrics.titleRowHeight;

  double get _titleCollapsedInset =>
      statusTop + VHeaderMetrics.collapsedBarHeight;

  @override
  double get minExtent => _titleCollapsedInset + bottomHeight;

  @override
  double get maxExtent => _titleExpandedInset + bottomHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // The status-bar/notch inset. The collapsed glass extends under it (iOS
    // large-title style); the expanded title clears it with [heroTopPad].
    final statusTop = MediaQuery.paddingOf(context).top;
    final titleRange = maxExtent - minExtent - bottomHeight;
    final progress = (shrinkOffset / titleRange).clamp(0.0, 1.0).toDouble();
    final titleCurrentHeight = maxExtent - shrinkOffset - bottomHeight;

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
          height: titleCurrentHeight,
          color: VHeaderMetrics.glassFill,
          child: Stack(
            children: [
              // Compact title centered in the band BELOW the status inset.
              Positioned(
                left: 0,
                right: 0,
                top: statusTop,
                height: (titleCurrentHeight - statusTop).clamp(
                  0,
                  double.infinity,
                ),
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

    final titleStack = Stack(
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

    // The title region (collapsing) sits above the pinned bottom strip.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: titleCurrentHeight, child: titleStack),
        if (bottom != null) ...[SizedBox(height: bottomHeight, child: bottom)],
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
        statusTop != oldDelegate.statusTop ||
        bottom != oldDelegate.bottom ||
        bottomHeight != oldDelegate.bottomHeight;
  }
}
