import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/glass/v_glass.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

/// Coming-soon screen — LUXE v2 restyle (XL-13) of DISCO §5.7 (U-05).
///
/// Black AppBar (theme), a centered **liquid-glass panel** ([VGlass], radius
/// 20) carrying the faint [iconColor] icon at `xxl 48`, "PRÓXIMAMENTE" in the
/// LUXE display voice ([VDisplayText]: Playfair italic bold UPPERCASE with the
/// family gradient fill + slow glow) and the muted description. The panel
/// adopts the optional [family] accent — **default [AppGradients.violet]**
/// (never pink, 2026-08-12) — for its border, halo and headline. Outlined
/// back button keeps the documented behavior: a pushed route pops; a TAB-level
/// coming-soon (nothing to pop) falls back to the feed home.
///
/// XL-19 (10_events — "overly saturated / cheap"): the glass panel's ring +
/// glow ride the **watered** family run (`wateredFamily(family, mix: 0.4)`)
/// — pale chrome, no saturated pastel; the headline shader stays the raw
/// family (the one brand moment) and the icon defaults to the watered mid
/// tone of the family.
class VComingSoonScreen extends StatelessWidget {
  final String title;
  final String description;
  final bool showBackButton;
  final IconData icon;

  /// Icon tint; when null the widget uses the family's **watered mid tone**
  /// (`AppGradients.watered(family.colors, mix: 0.4)[1]`).
  final Color? iconColor;

  /// The glass panel + headline accent family. Defaults to the LUXE default
  /// [AppGradients.violet] — screens pass their own `AppGradients.familyOf`.
  final AppGradient family;

  const VComingSoonScreen({
    super.key,
    required this.title,
    required this.description,
    this.showBackButton = true,
    this.icon = Icons.construction,
    this.iconColor,
    this.family = AppGradients.violet,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The icon rides the watered mid stop of the family — visible but
    // pale (no saturated pastel fills, LUXE directive #3).
    final resolvedIconColor =
        iconColor ?? AppGradients.watered(family.colors, mix: 0.4)[1];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        // §7.3: scroll-safe body (the OTP pattern, U-07) — the centered
        // panel overflows small screens at ≥1.5× text scale; keeps the
        // centered layout when the content fits and scrolls when it
        // doesn't. Never clip.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: VGlass(
                      // XL-19: the ring + glow ride the watered family run
                      // (mix 0.4) — pale chrome; the vivid end only survives
                      // in the headline shader below.
                      gradient: AppGradients.wateredFamily(family, mix: 0.4),
                      radius: BorderRadius.circular(20),
                      glowAlpha: 0.22,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: AppIconSizes.xxl, color: resolvedIconColor),
                            const SizedBox(height: AppSpacing.lg),
                            VDisplayText(
                              text: l10n.comingSoonSoon,
                              size: 32,
                              // XL-19: the headline keeps the RAW family —
                              // the one brand moment on the screen.
                              gradient: family,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              description,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.mutedStrong),
                            ),
                            if (showBackButton) ...[
                              const SizedBox(height: AppSpacing.xl),
                              // U-19: the back CTA is full-width (max 320) —
                              // the fixed 200px width clipped long labels at
                              // 1.5×.
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: VButton.outlined(
                                  label: l10n.comingSoonBack,
                                  gradient: family,
                                  // A pushed route pops (the normal back
                                  // CTA); a TAB-level coming-soon (e.g. the
                                  // flag-gated /main/events tab) has nothing
                                  // to pop — a bare Navigator.pop there throws
                                  // go_router's "popped the last page off of
                                  // the stack", so the fallback goes to the
                                  // feed home instead.
                                  onPressed: () {
                                    final navigator = Navigator.of(context);
                                    if (navigator.canPop()) {
                                      navigator.pop();
                                    } else {
                                      GoRouter.of(
                                        context,
                                      ).go(RoutePaths.mainFeed);
                                    }
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xs),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
