import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
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

  /// Playfair's hhea optical correction for the leading BACK ARROW — the glyph
  /// ink centers above the geometric center, so the arrow is nudged down to
  /// read centered with the title. [VHeaderTitleRow] applies it to every
  /// header; callers never specify it.
  static const double backArrowNudge = 6;

  /// Playfair's hhea optical correction for trailing ACTIONS (icon or text) —
  /// same optical reason as [backArrowNudge]. Applied to every action of every
  /// header by [VHeaderTitleRow]; callers never specify it.
  static const double actionNudge = 6;
}

// =============================================================================
// TEMP DEBUG — header layout probe (2026-09-11). Flip [kDebugHeaderLayout] to
// false (or delete this block + the `_dbg`/`_nudged` calls) when tuning is done.
//
//   blue   → header band dimension (VHeaderMetrics.barHeight)
//   orange → back-arrow dimension
//   green  → action dimension(s)
//   purple → back-arrow nudge band (VHeaderMetrics.backArrowNudge)
//   cyan   → action nudge band (VHeaderMetrics.actionNudge)
//   red    → padding region
//   sky    → margin / spacing region
//   mix    → a parent container blends its children's colors
//   black  → bottom dimension line of each of the three elements
//            (back arrow / title / action)
//   red    → x-height band of the title font, both edges + middle (TOP of
//            letters like v/e/a/x, MIDDLE, and BOTTOM = the baseline where
//            g/p/q descend)
//   neon   → glyph guides (top/middle/bottom) of the back arrow and each
//            action glyph (icon or text label)
// =============================================================================
const bool kDebugHeaderLayout = true;

const Color _dbgHeader = Color(0x802196F3); // blue
const Color _dbgArrow = Color(0x80FF9800); // orange
const Color _dbgAction = Color(0x804CAF50); // green
const Color _dbgBackNudge = Color(0x809C27B0); // purple
const Color _dbgActionNudge = Color(0x8000BCD4); // cyan
const Color _dbgPad = Color(0x80F44336); // red
const Color _dbgMargin = Color(0x8003A9F4); // sky

/// Average (50% lerp) of two child colors — the parent-container "mix".
Color _dbgMix(Color a, Color b) => Color.lerp(a, b, 0.5)!;

/// Wraps [child] in a translucent [color] band when the probe is on; a no-op
/// passthrough when off, so layout is byte-identical to production.
Widget _dbg(Widget child, Color color) {
  if (!kDebugHeaderLayout) return child;
  return Container(color: color, child: child);
}

/// A 1px solid black line along the bottom edge of [child] — the bottom
/// dimension line of one header element (back arrow / title / action). A
/// no-op passthrough when the probe is off.
Widget _dbgBottomLine(Widget child) {
  if (!kDebugHeaderLayout) return child;
  return Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFF000000), width: 1)),
    ),
    child: child,
  );
}

// ── glyph guides ────────────────────────────────────────────────────────────
// Anchored to the ACTUAL rendered paragraph (RenderParagraph.getBoxesForSelection
// with BoxHeightStyle.tight = the run's tight box), NOT a separately-created
// TextPainter (whose baseline drifted from the real glyphs). A probe walks the
// subtree to find the first RenderParagraph (so it also works for the icon
// glyph inside a BackButton/IconButton and for a text button label).
//
// Playfair Display has USE_TYPO_METRICS set, so the title run box = ascent 1082
// / descent 251 (unitsPerEm 1000). Within that box:
//   baseline   = 1082 / (1082+251) = 0.8117
//   x-height top ('x'=515, 'e'/'a'=529) = (1082-529)/1333 = 0.4149
//   middle     = midpoint of the two above
// Fraction lists are tunable — nudge these if the lines must sit differently.
const List<double> _titleGuideFractions = [0.4149, 0.6133, 0.8117];

/// Neon guides for the back arrow and the action glyphs — top / middle / bottom
/// of the measured glyph box (fractions 0 / 0.5 / 1).
const List<double> _glyphGuideFractions = [0.0, 0.5, 1.0];
const Color _dbgNeon = Color(0xFF39FF14); // neon green

/// First [RenderParagraph] in the subtree rooted at [root] (or [root] itself)
/// — finds the icon glyph / text label inside a button.
RenderParagraph? _firstParagraph(RenderObject root) {
  if (root is RenderParagraph) return root;
  RenderParagraph? found;
  void visit(RenderObject child) {
    if (found != null) return;
    if (child is RenderParagraph) {
      found = child;
      return;
    }
    child.visitChildren(visit);
  }

  root.visitChildren(visit);
  return found;
}

/// The tight TEXT box of [p]'s single run — correct for letter glyphs (Playfair
/// carries its ascent/descent on the run). NOT the visual ink for icons.
Rect? _tightTextBox(RenderParagraph p) {
  final text = p.text.toPlainText();
  if (text.isEmpty) return null;
  final boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
    boxHeightStyle: ui.BoxHeightStyle.tight,
  );
  if (boxes.isEmpty) return null;
  final b = boxes.first;
  return Rect.fromLTRB(b.left, b.top, b.right, b.bottom);
}

/// The glyph's ACTUAL ink box: re-paint the paragraph's span offscreen and scan
/// the alpha channel. Neither the layout box nor [BoxHeightStyle.tight] yields
/// the visual bounds of an icon glyph (both carry the icon font's line metrics),
/// so icons measure the rasterized pixels instead. Rasterizes at the device
/// pixel ratio ([dpr]) so the offscreen glyph hinting matches the on-screen
/// one, and returns logical local coordinates.
Future<Rect?> _measureInk(RenderParagraph p, TextScaler scaler, double dpr) async {
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textScaler: scaler,
    textAlign: p.textAlign,
    maxLines: 1,
  )..layout();
  final w = painter.width.ceil();
  final h = painter.height.ceil();
  if (w <= 0 || h <= 0) return null;
  final pw = (w * dpr).ceil();
  final ph = (h * dpr).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(dpr, dpr);
  painter.paint(canvas, Offset.zero);
  final picture = recorder.endRecording();
  final ui.Image image;
  try {
    image = picture.toImageSync(pw, ph);
  } catch (_) {
    picture.dispose();
    return null;
  }
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  if (data == null) return null;
  final bytes = data.buffer.asUint8List();
  var minX = pw, minY = ph, maxX = -1, maxY = -1;
  for (var y = 0; y < ph; y++) {
    for (var x = 0; x < pw; x++) {
      if (bytes[(y * pw + x) * 4 + 3] > 180) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0 || maxY < 0) return null;
  return Rect.fromLTRB(
    minX / dpr,
    minY / dpr,
    (maxX + 1) / dpr,
    (maxY + 1) / dpr,
  );
}

/// Wraps [child] so a painter can read the ACTUAL rendered [RenderParagraph]
/// and draw guide lines (top/middle/bottom at [fractions] of the measured box)
/// in the same coordinate space as the painted glyphs. No-op when off.
///
/// [ink] selects the measured box:
///   * `true`  — the tight TEXT box (letters; Playfair's run box).
///   * `false` — the rasterized glyph INK box (icons) — the visual bounds.
class _GuideProbe extends StatefulWidget {
  const _GuideProbe({
    required this.child,
    required this.fractions,
    required this.color,
    this.ink = true,
  });

  final Widget child;
  final List<double> fractions;
  final Color color;
  final bool ink;

  @override
  State<_GuideProbe> createState() => _GuideProbeState();
}

class _GuideProbeState extends State<_GuideProbe> {
  final _key = GlobalKey();
  Rect? _inkRect;

  @override
  void initState() {
    super.initState();
    if (kDebugHeaderLayout && !widget.ink) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  Future<void> _measure() async {
    final context = _key.currentContext;
    if (context == null || !mounted) return;
    final root = context.findRenderObject();
    if (root == null) return;
    final paragraph = _firstParagraph(root);
    if (paragraph == null) return;
    final scaler = MediaQuery.textScalerOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final local = await _measureInk(paragraph, scaler, dpr);
    if (local == null || !mounted) return;
    final shift = paragraph.localToGlobal(Offset.zero, ancestor: root);
    debugPrint(
      '[hdrink] dpr=$dpr paragraph=${paragraph.size} local=$local '
      'shift=$shift global=${local.shift(shift)}',
    );
    setState(() => _inkRect = local.shift(shift));
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugHeaderLayout) return widget.child;
    return CustomPaint(
      foregroundPainter: _GuidePainter(
        _key,
        widget.fractions,
        widget.color,
        widget.ink,
        _inkRect,
      ),
      child: KeyedSubtree(key: _key, child: widget.child),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(
    this.textKey,
    this.fractions,
    this.color,
    this.ink,
    this.inkRect,
  );

  final GlobalKey textKey;
  final List<double> fractions;
  final Color color;

  /// `null` is tolerated only so a hot-reloaded instance created before this
  /// field existed cannot crash [shouldRepaint]; treated as the default `true`.
  final bool? ink;

  /// Measured glyph-ink box in painter space (icons), or null until measured.
  final Rect? inkRect;

  bool get _ink => ink ?? true;

  @override
  void paint(Canvas canvas, Size size) {
    final root = textKey.currentContext?.findRenderObject();
    final paragraph = root == null ? null : _firstParagraph(root);
    Offset? shift;
    if (paragraph != null && root != null) {
      shift = paragraph.localToGlobal(Offset.zero, ancestor: root);
    }
    final layoutBox = (paragraph != null && shift != null)
        ? (Offset.zero & paragraph.size).shift(shift)
        : null;
    final tightLocal = paragraph == null ? null : _tightTextBox(paragraph);
    final tightBox = (tightLocal != null && shift != null)
        ? tightLocal.shift(shift)
        : null;
    final box = _ink
        ? (tightBox ?? layoutBox ?? (Offset.zero & size))
        : (inkRect ?? layoutBox ?? (Offset.zero & size));
    final height = box.height;
    final guide = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final f in fractions) {
      final y = box.top + height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) =>
      oldDelegate.textKey != textKey ||
      oldDelegate.color != color ||
      oldDelegate.ink != ink ||
      oldDelegate.inkRect != inkRect ||
      !identical(oldDelegate.fractions, fractions);
}

/// Applies [nudge] below [child] and paints [nudgeColor] around it. The
/// nudge band stays at the un-nudged layout rect while the inner [dimColor]
/// box shifts, so the offset itself is visible.
Widget _nudged(Widget child, double nudge, Color nudgeColor, Color dimColor) {
  return _dbg(
    Transform.translate(
      offset: Offset(0, nudge),
      child: _dbg(_dbgBottomLine(child), dimColor),
    ),
    nudgeColor,
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
    final children = <Widget>[
      if (showBack)
        _nudged(
          _GuideProbe(
            fractions: _glyphGuideFractions,
            color: _dbgNeon,
            ink: false,
            child: BackButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
          ),
          VHeaderMetrics.backArrowNudge,
          _dbgBackNudge,
          _dbgArrow,
        ),
      if (showBack && (title != null || titleWidget != null))
        _dbg(const SizedBox(width: AppSpacing.xs), _dbgMargin),
      if (titleWidget != null)
        Expanded(child: _dbgBottomLine(titleWidget!))
      else if (title != null)
        Expanded(
          child: _dbgBottomLine(
            _GuideProbe(
              fractions: _titleGuideFractions,
              color: const Color(0xFFFF0000),
              child: VDisplayText(text: title!, maxLines: maxLines),
            ),
          ),
        ),
      // Every action inherits the shared action nudge — no call-site offset.
      ...?actions?.map(
        (action) => _nudged(
          _GuideProbe(
            fractions: _glyphGuideFractions,
            color: _dbgNeon,
            ink: false,
            child: action,
          ),
          VHeaderMetrics.actionNudge,
          _dbgActionNudge,
          _dbgAction,
        ),
      ),
    ];

    return SizedBox(
      height: height,
      child: _dbg(Row(children: children), _dbgMix(_dbgArrow, _dbgAction)),
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
          child: _dbg(
            Container(
              padding: VHeaderMetrics.titleInset,
              color: kDebugHeaderLayout ? _dbgPad : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dbg(
                    const SizedBox(height: VHeaderMetrics.heroTopPad),
                    _dbgMargin,
                  ),
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
            _dbgHeader,
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
