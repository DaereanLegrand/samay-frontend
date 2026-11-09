import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_glass_pill.dart';
import 'package:samay/core/theme/app_palette_context.dart';

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

  /// Apple-style glass-pill mode: the glyph size the title shrinks to inside
  /// its capsule (`headlineLarge` — Playfair 28) and, when [VHeaderTitleRow]
  /// [VHeaderTitleRow.pills] is on, the back arrow / title / actions each get
  /// their own [VGlassPill] over a fully transparent bar.
  static const double pillTitleSize = 28;

  /// Horizontal padding of the title capsule (the circles have none).
  static const EdgeInsets pillTitlePadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
  );

  /// Circle diameter of the back arrow / icon actions, and the height of the
  /// title capsule — matches [titleRowHeight], so a pill row never grows.
  static const double pillDiameter = titleRowHeight;

  /// Gap between adjacent pills.
  static const double pillGap = AppSpacing.sm;

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
// [VHeaderTitleRow] uses these to slide the back glyph from its bare optical x
// (start-aligned, ink on the inset edge) to the centre of its glass circle as
// the pill state animates in.
const double _kBackArrowIconSize = 24;
const double _arrowBackInkLeft = 85 / 512 * _kBackArrowIconSize;
const double _arrowBackInkRight = (512 - 427) / 512 * _kBackArrowIconSize;
const double _arrowBackIosInkLeft = 137 / 512 * _kBackArrowIconSize;
const double _arrowBackIosInkRight = (512 - 368.25) / 512 * _kBackArrowIconSize;

/// The single shared title row used by every header presentation: an optional
/// back arrow, the title (plain [VDisplayText] or a custom [titleWidget] such
/// as the truth/dare two-line header), and trailing [actions].
///
/// [pillProgress] drives the Apple "liquid glass" morph: `0` is the bare
/// historical row (large display title, plain icons); `1` is the pill state —
/// back arrow, title (shrunk to [VHeaderMetrics.pillTitleSize]) and every
/// action each in their own [VGlassPill] over a transparent bar. Intermediate
/// values interpolate the title size, the capsule paddings/gaps and the bubble
/// opacity/scale, so the transition animates smoothly both ways. [VHeaderBar]
/// holds it at `1`; the pinned [VHeaderSliver] animates `0 → 1` on scroll.
class VHeaderTitleRow extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final int? maxLines;
  final double height;

  /// 0 = bare row, 1 = glass pills; values between animate the morph.
  final double pillProgress;

  const VHeaderTitleRow({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.maxLines = 1,
    this.height = VHeaderMetrics.titleRowHeight,
    this.pillProgress = 0,
  });

  @override
  Widget build(BuildContext context) {
    final p = pillProgress.clamp(0.0, 1.0);

    // Model A — one shared optical centerline. The Row's own center is the
    // centerline; each element is shifted so its reference band center lands
    // there: icons by their grid-balanced box, text by its font-metric band.
    final titleSize = lerpDouble(
      VDisplayText.defaultSize,
      VHeaderMetrics.pillTitleSize,
      p,
    )!;
    final titleStyle = VDisplayText.styleFor(titleSize);
    final titleShift = title != null && titleWidget == null
        ? _opticalShift(context, titleStyle)
        : 0.0;
    final labelShift = _opticalShift(context, _actionLabelStyle(context));
    final hasTitle = title != null || titleWidget != null;

    // Same platform icon as [BackButtonIcon]. The shared legibility shadow
    // keeps the arrow readable over imagery in the bare state; in the pill
    // state the glyph sits on its own glass bubble over a solid surface, so
    // the soft dark halo reads as a SECOND faint chevron (seen on the group
    // theme colours) — drop it there.
    final backIcon = Icon(switch (Theme.of(context).platform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS => Icons.arrow_back_ios_new_rounded,
      _ => Icons.arrow_back,
    }, shadows: p >= 0.99 ? null : AppTypography.legibilityShadows);

    final Widget? titleInner =
        titleWidget ??
        (title != null
            ? Transform.translate(
                offset: Offset(0, titleShift),
                child: VDisplayText(
                  text: title!,
                  size: titleSize,
                  maxLines: maxLines,
                ),
              )
            : null);

    // Actions: icons align by box center, text buttons by their label band.
    // Fine-tune rides `actionNudge` — callers never offset.
    final actionWidgets = <Widget>[
      for (final action in actions ?? const <Widget>[])
        Transform.translate(
          offset: Offset(
            0,
            (_actionIsText(action) ? labelShift : 0.0) +
                VHeaderMetrics.actionNudge,
          ),
          child: action,
        ),
    ];

    // Morph geometry: bare at 0, pill at 1.
    final backGap = lerpDouble(AppSpacing.md, VHeaderMetrics.pillGap, p)!;
    final actionGap = lerpDouble(0, VHeaderMetrics.pillGap, p)!;
    final titlePadding = EdgeInsets.symmetric(
      horizontal: lerpDouble(0, AppSpacing.lg, p)!,
    );
    final actionScale = lerpDouble(0.8, 1.0, p)!;

    // The back glyph keeps its bare optical x at p=0 and slides to the centre
    // of its circle as the bubble grows.
    final isIos = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    final inkLeft = isIos ? _arrowBackIosInkLeft : _arrowBackInkLeft;
    final inkRight = isIos ? _arrowBackIosInkRight : _arrowBackInkRight;
    final bareIconDx =
        (inkRight - inkLeft).clamp(0.0, 24.0) +
        _kBackArrowIconSize / 2 -
        VHeaderMetrics.pillDiameter / 2;
    final iconDx = (1 - p) * bareIconDx;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (showBack)
            VGlassPill(
              reveal: p,
              scale: actionScale,
              child: SizedBox(
                width: VHeaderMetrics.pillDiameter,
                height: VHeaderMetrics.pillDiameter,
                child: IconButton(
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: Transform.translate(
                    offset: Offset(iconDx, VHeaderMetrics.backArrowNudge),
                    child: backIcon,
                  ),
                ),
              ),
            ),
          if (showBack && hasTitle) SizedBox(width: backGap),
          if (titleInner != null)
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: VGlassPill(
                  reveal: p,
                  scale: lerpDouble(0.95, 1.0, p)!,
                  padding: titlePadding,
                  child: SizedBox(
                    height: VHeaderMetrics.pillDiameter,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: 1,
                      child: titleInner,
                    ),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < actionWidgets.length; i++) ...[
            if (i > 0 || hasTitle || showBack) SizedBox(width: actionGap),
            VGlassPill(reveal: p, scale: actionScale, child: actionWidgets[i]),
          ],
        ],
      ),
    );
  }
}

/// Animates [VHeaderTitleRow]'s glass-pill morph from the enclosing list's
/// scroll state.
///
/// The pinned [SliverPersistentHeader] cannot rebuild per scroll frame itself
/// (its geometry is constant when `minExtent == maxExtent`), so this stateful
/// wrapper listens to the [ScrollPosition] and drives an [AnimationController]
/// `0 → 1` when the list moves and `1 → 0` when it returns to the top. The
/// controller's value is the row's [VHeaderTitleRow.pillProgress].
class _AnimatedPillHeaderRow extends StatefulWidget {
  const _AnimatedPillHeaderRow({required this.builder});

  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<_AnimatedPillHeaderRow> createState() => _AnimatedPillHeaderRowState();
}

class _AnimatedPillHeaderRowState extends State<_AnimatedPillHeaderRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SamayDurations.standard,
  );
  ScrollPosition? _position;
  bool _scrolled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : SamayDurations.standard;
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_handleScroll);
      _position = position;
      _position?.addListener(_handleScroll);
      _scrolled = (position?.pixels ?? 0) > 0.5;
      _controller.value = _scrolled ? 1 : 0;
    }
  }

  void _handleScroll() {
    final scrolled = (_position?.pixels ?? 0) > 0.5;
    if (scrolled == _scrolled) return;
    _scrolled = scrolled;
    if (scrolled) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
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
/// full-bleed [bottom] strip, and an expanding [child] body. The bar paints
/// NOTHING: its [VHeaderTitleRow] is always in pill mode, so the back arrow,
/// title and actions each float in their own [VGlassPill] (blurring whatever
/// the screen paints behind the bar).
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
    // Fully transparent bar: the title row floats its own glass pills over
    // whatever the screen paints behind it. [VHeaderBar] is always in pill mode.
    final bar = Padding(
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
                pillProgress: 1,
              ),
            ],
          ),
        ),
      ),
    );
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [bar, ?bottom],
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
/// There is NO collapse and NO opaque band: the shared title row (title +
/// actions) stays pinned at the SAME y at rest and while scrolling, over a top
/// scrim gradient that keeps it legible above the content passing beneath. At
/// REST the row is bare (the large display title, unfilled icons); once the
/// list is SCROLLED the row switches to Apple-style [VGlassPill]s — back arrow,
/// title (shrunk to [VHeaderMetrics.pillTitleSize]) and actions each blur their
/// own backdrop. Geometry matches the fixed [VHeaderBar]: the title sits at
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
    // scrolling. `_AnimatedPillHeaderRow` morphs it into glass pills once the
    // list moves.
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
            child: _AnimatedPillHeaderRow(
              builder: (context, progress) => VHeaderTitleRow(
                title: title,
                titleWidget: titleWidget,
                actions: actions,
                showBack: showBack,
                onBack: onBack,
                maxLines: maxLines,
                pillProgress: progress,
              ),
            ),
          ),
        ),
      ),
    );

    // A top scrim gradient keeps the bare row legible over the content passing
    // beneath; the pills carry their own blur. No opaque surface, no collapse.
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
                    context.palette.background.withValues(alpha: 0.45),
                    context.palette.background.withValues(alpha: 0.0),
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
