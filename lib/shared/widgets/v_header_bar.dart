import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

/// Unified top bar — the Mis Eventos hero header, everywhere.
///
/// Replaces the raw Material `AppBar` across the app so every screen shares
/// one height, one font (Playfair Display white via [VDisplayText]) and one
/// contract. Lives in the Scaffold `body` (exactly like the My Events tab
/// header it ports): a `SafeArea` top pad, a fixed [barHeight] title row with
/// an optional back arrow + trailing [actions], and an optional [bottom] slot
/// (the TabBar on group detail / friend requests).
///
/// When [child] is given, [VHeaderBar] fills the Scaffold body: header strip
/// on top and [child] expanding below it (the Mis Eventos SafeArea pattern).
/// Without [child] it renders just the strip (for screens with custom layout
/// below the header, e.g. the Social tab's pill tab bar).
class VHeaderBar extends StatelessWidget {
  /// Header title (Playfair Display, size 40). Omit for back-arrow-only bars.
  final String? title;

  /// A CUSTOM title widget that replaces the plain [VDisplayText] rendering
  /// of [title] (multi-line / mixed-font bar titles, e.g. the minigame play
  /// screen's two-line header). Mutually exclusive with [title]; when set it
  /// fills the same Expanded slot inside the fixed [barHeight] row, so the bar
  /// height is unchanged. Long content must fit (ellipsize / scale down
  /// itself).
  final Widget? titleWidget;

  /// Trailing actions (icon buttons, text buttons, popup menus).
  final List<Widget>? actions;

  /// Whether a leading back arrow renders. Tabs pass `false` — pushing
  /// from a shell tab breaks the tab UX.
  final bool showBack;

  /// Custom back handling; defaults to `Navigator.maybePop`.
  final VoidCallback? onBack;

  /// Max title lines before ellipsis (default 1 — long titles never wrap).
  final int? maxLines;

  /// Optional strip below the title row (e.g. a `TabBar`).
  final Widget? bottom;

  /// Body content that expands to fill the space below the header.
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

  /// The fixed title-row height (48 content + 16 top + 16 bottom) — one
  /// height everywhere by construction.
  static const double barHeight = 80;

  @override
  Widget build(BuildContext context) {
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: barHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                if (showBack)
                  Transform.translate(
                    // Playfair's hhea box is top-heavy (ascent 1082 / descent
                    // -251): the title's glyph ink centers above the row's
                    // geometric center at 40px, so the arrow is nudged to read
                    // vertically centered against the title.
                    offset: const Offset(0, 6),
                    child: BackButton(
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                  ),
                if (showBack && (title != null || titleWidget != null))
                  // Matches the search field's icon→text gap (4px): the
                  // header title lands on the same x as the input's starting
                  // cursor, and the leading icons (arrow ↔ magnifier) line up.
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
