import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
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

  /// External gap above AND below the header bar — always [AppSpacing.sm]
  /// (8px), on every device. Applied OUTSIDE [barHeight], so the bar's own
  /// geometry is unchanged; the OS top safe-area inset is additional.
  static const double headerOuterPad = AppSpacing.sm;

  /// Fallback top gap, used ONLY when the OS reserves no top safe-area inset.
  /// 16px (`AppSpacing.lg`).
  static const double fallbackHeroTopPad = AppSpacing.lg;

  /// App-added gap between the OS top safe-area inset and the title row.
  ///
  /// Per-device rule ([statusTop] is `MediaQuery.paddingOf(context).top`):
  /// when the OS already reserves a top inset — status bar / notch /
  /// Dynamic Island, `statusTop > 0` — the app adds NOTHING, because the inset
  /// itself is the spacing; when the OS reserves none (`statusTop == 0`, e.g.
  /// desktop / web / immersive) it adds [fallbackHeroTopPad] so the title is
  /// not glued to the very top. Both the fixed bar and the collapsed header
  /// use this, so every title glyph sits at the same y at rest.
  static double heroTopPad(double statusTop) =>
      statusTop > 0 ? 0 : fallbackHeroTopPad;

  /// Height of the title-content band. Fixed 48px so the row always starts at
  /// [heroTopPad] whether or not a back arrow / action is present.
  static const double titleRowHeight = 48;

  /// Height the fixed bar reserves (top gap + row + matching bottom gap).
  static double barHeight(double statusTop) =>
      heroTopPad(statusTop) * 2 + titleRowHeight;

  /// Total vertical space a fixed bar occupies below the OS safe-area inset:
  /// [headerOuterPad] + [barHeight] + [headerOuterPad]. Call sites that must
  /// reserve the header's footprint use this instead of summing by hand.
  static double barOuterHeight(double statusTop) =>
      barHeight(statusTop) + headerOuterPad * 2;

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

  /// The down-positive offset that lands [style]'s reference band (cap/x-height
  /// per [opticalReference]) on the header's shared centerline when the style's
  /// own line box is centered in the title row. Shared by titles and custom
  /// title widgets so every header element uses ONE centerline.
  static double opticalShiftFor(BuildContext context, TextStyle style) =>
      _opticalShift(context, style);
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

// Optical alignment (Model A)
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
///   taller box → baseline = box · ascent/(ascent+descent)
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

/// The label style for aligning a TEXT action (buttons). Icons are aligned by
/// their box; text buttons by their label's optical band.
TextStyle _actionLabelStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelLarge ?? AppTypography.labelLarge;

// Back-arrow optical side bearings (measured)
//
// MaterialIcons glyphs do NOT fill their 24px em box: the ink has side
// bearings, so the icon box edge is not the arrow's optical edge. Measured from
// `MaterialIcons-Regular.otf` (unitsPerEm 512) with fontTools, at 24px:
//
//   arrow_back (Android) ink x 85..427 → 3.984px L / 3.984px R
//   arrow_back_ios_new_rounded ink x 137..368.25 → 6.422px L / 6.738px R
//
// The header therefore gives the arrow the SAME optical gap on both sides:
//   leading gap = leadingPad + inkLeft
//   trailing gap = inkRight (title starts flush at the icon box edge)
// Equal ⇒ leadingPad = inkRight − inkLeft (0 Android / 0.316px iOS), and both
// gaps equal max(inkLeft, inkRight). The title's own glyph left-bearing is
// intrinsic to the text and intentionally not compensated.
const double _kBackArrowIconSize = 24;

/// Minimum tap target of the back arrow, in logical px. Kept at the 44pt
/// accessibility floor (the icon itself is only 24px).
const double _kBackArrowMinTapTarget = 44;
const double _arrowBackInkLeft = 85 / 512 * _kBackArrowIconSize;
const double _arrowBackInkRight = (512 - 427) / 512 * _kBackArrowIconSize;
const double _arrowBackIosInkLeft = 137 / 512 * _kBackArrowIconSize;
const double _arrowBackIosInkRight = (512 - 368.25) / 512 * _kBackArrowIconSize;

/// Scoped [IconButtonTheme] override for the back arrow only.
///
/// The button keeps a >=44pt tap target ([_kBackArrowMinTapTarget]) while the
/// glyph is start-aligned so its ink sits at its natural bearing. The sub-pixel
/// platform leading pad below equalizes the optical gaps on both sides of the
/// arrow (see the bearing table above). Scoped to the back arrow so trailing
/// icon actions keep their default targets.
ButtonStyle _backArrowButtonStyle(BuildContext context) {
  final isIos = switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
  final inkLeft = isIos ? _arrowBackIosInkLeft : _arrowBackInkLeft;
  final inkRight = isIos ? _arrowBackIosInkRight : _arrowBackInkRight;
  return ButtonStyle(
    padding: WidgetStatePropertyAll(
      EdgeInsetsDirectional.only(start: (inkRight - inkLeft).clamp(0.0, 24.0)),
    ),
    minimumSize: const WidgetStatePropertyAll(
      Size(_kBackArrowMinTapTarget, _kBackArrowMinTapTarget),
    ),
    alignment: AlignmentDirectional.centerStart,
  );
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
    // Model A — one shared optical centerline. The Row's own center is the
    // centerline; each element is shifted so its reference band center lands
    // there: icons by their grid-balanced box, text by its font-metric band.
    final titleStyle = VDisplayText.styleFor(VDisplayText.defaultSize);
    final titleShift = title != null && titleWidget == null
        ? _opticalShift(context, titleStyle)
        : 0.0;
    final labelShift = _opticalShift(context, _actionLabelStyle(context));

    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (showBack)
            Transform.translate(
              offset: const Offset(0, VHeaderMetrics.backArrowNudge),
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style: _backArrowButtonStyle(context),
                ),
                child: IconButton(
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  // Same platform icon as [BackButtonIcon], plus the shared
                  // legibility shadow so the arrow reads over imagery.
                  icon: Icon(switch (Theme.of(context).platform) {
                    TargetPlatform.iOS ||
                    TargetPlatform.macOS => Icons.arrow_back_ios_new_rounded,
                    _ => Icons.arrow_back,
                  }, shadows: AppTypography.legibilityShadows),
                ),
              ),
            ),
          if (showBack && (title != null || titleWidget != null))
            const SizedBox(width: AppSpacing.md),
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
/// Fixed title bar (does not scroll): [VHeaderMetrics.headerOuterPad] above and
/// below the bar, [VHeaderMetrics.heroTopPad] below the OS safe inset (0 when
/// the OS already reserves one), the shared [VHeaderTitleRow], an optional
/// full-bleed [bottom] strip, and an expanding [child] body.
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
    final statusTop = MediaQuery.paddingOf(context).top;
    final topGap = VHeaderMetrics.heroTopPad(statusTop);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: VHeaderMetrics.headerOuterPad,
          ),
          child: SizedBox(
            height: VHeaderMetrics.barHeight(statusTop),
            child: Padding(
              padding: VHeaderMetrics.titleInset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: topGap),
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

/// Always-transparent pinned header for scrollable tab roots (Feed 'samay',
/// Eventos 'mis eventos', Perfil, Notificaciones, Social). Use as the FIRST
/// sliver of a `CustomScrollView`.
///
/// There is NO collapse and NO glass fill: the shared title row (title +
/// actions) stays pinned at the SAME y at rest and while scrolling, over a top
/// scrim gradient that keeps it legible above the content passing beneath.
/// Geometry matches the fixed [VHeaderBar]: the title sits at
/// [VHeaderMetrics.heroTopPad] below the OS inset and
/// [VHeaderMetrics.headerOuterPad], with a trailing
/// [VHeaderMetrics.headerOuterPad] band under the row.
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
      delegate: _TransparentHeaderDelegate(
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

/// [VHeaderSliver]'s delegate: a fixed, transparent, pinned header
/// (`minExtent == maxExtent`).
class _TransparentHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final int? maxLines;
  final double statusTop;
  final Widget? bottom;
  final double bottomHeight;

  _TransparentHeaderDelegate({
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

  /// Title band + the external top/bottom [VHeaderMetrics.headerOuterPad].
  double get _extent =>
      statusTop +
      VHeaderMetrics.headerOuterPad +
      VHeaderMetrics.heroTopPad(statusTop) +
      VHeaderMetrics.titleRowHeight +
      VHeaderMetrics.headerOuterPad;

  @override
  double get minExtent => _extent + bottomHeight;

  @override
  double get maxExtent => _extent + bottomHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final statusTop = MediaQuery.paddingOf(context).top;
    final topGap = VHeaderMetrics.heroTopPad(statusTop);

    // The shared title row (title + actions) at the SAME y at rest and while
    // scrolling — always pinned, always transparent.
    final titleRow = Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: VHeaderMetrics.titleInset,
        child: Padding(
          padding: EdgeInsets.only(
            top: statusTop + VHeaderMetrics.headerOuterPad + topGap,
          ),
          child: SizedBox(
            height: VHeaderMetrics.titleRowHeight,
            child: VHeaderTitleRow(
              title: title,
              titleWidget: titleWidget,
              actions: actions,
              showBack: showBack,
              onBack: onBack,
              maxLines: maxLines,
            ),
          ),
        ),
      ),
    );

    // Transparent header: a top scrim gradient for legibility over the content
    // passing beneath, with the title + actions always on top. No opaque
    // surface, no collapse.
    final band = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.discoBlack.withValues(alpha: 0.55),
                    AppColors.discoBlack.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        titleRow,
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _extent, child: band),
        if (bottom != null) ...[SizedBox(height: bottomHeight, child: bottom)],
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _TransparentHeaderDelegate oldDelegate) {
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
