import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/theme/app_theme_scope.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_spinner.dart';

/// Full-area loading state: white spinner + optional `mutedStrong` caption,
/// centered on black (DESIGN.md §5.8).
///
/// The spinner is **white** — not an accent color — because loading is not a
/// brand moment (P3: accents are privileges, not defaults; the LUXE v2
/// palette reserves gradients/glows for the screen's own family, never for
/// neutral chrome). 24px per §5.8.
class VLoadingView extends StatelessWidget {
  final String? label;

  const VLoadingView({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const VSpinner(size: 24),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              label!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedStrong),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-area empty state: `xxl` icon in `#333333` (AppColors.border),
/// `headlineSmall` title, optional `bodyMedium` description in `mutedStrong`
/// and optional outlined CTA (DESIGN.md §5.9). Centered,
/// `sectionGap` spacing between the blocks.
class VEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional icon colour for empty states rendered on a non-black surface
  /// (e.g. a group chat themed background). Defaults to the standard
  /// `AppColors.border` token.
  final Color? iconColor;

  const VEmptyView({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Inside a themed group surface every ink here comes from the derived
    // palette; [iconColor] remains an explicit override for callers.
    final palette = AppThemeScope.paletteOf(context);
    final themed = AppThemeScope.isThemed(context);
    final resolvedIcon = iconColor ??
        (themed ? palette.mutedForeground : AppColors.border);
    final titleColor = themed ? palette.foreground : null;
    final bodyColor = themed ? palette.mutedForeground : AppColors.mutedStrong;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSizes.xxl, color: resolvedIcon),
            const SizedBox(height: AppSpacing.sectionGap),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: titleColor),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: bodyColor),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              // full-width CTA capped at 320 — the fixed 200px width
              // clipped long labels at 1.5× text scale (§7.3).
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: VButton.outlined(
                  label: actionLabel ?? l10n.commonContinue,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dumb switch over the four screen states: loading → [VLoadingView],
/// error → [ErrorView], else the [child] or the [empty] view.
///
/// `AsyncValue`-agnostic by design: screens pass plain bools/widgets and the
/// already-mapped [errorMessage] (see `Object.toAppError()`), so this widget
/// stays free of Riverpod and Supabase imports. Priority: loading > error >
/// child ?? empty. Screens adopt it incrementally — it replaces the
/// hand-rolled `AsyncValue.when(loading:/error:)` triads.
class VStateView extends StatelessWidget {
  final bool loading;
  final Object? error;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Widget? child;
  final Widget? empty;
  final String? loadingLabel;

  const VStateView({
    super.key,
    this.loading = false,
    this.error,
    this.errorMessage,
    this.onRetry,
    this.child,
    this.empty,
    this.loadingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (loading) return VLoadingView(label: loadingLabel);
    final err = error;
    if (err != null) {
      // Never render `err.toString()`: callers pass the localized mapped
      // message; the generic copy is the safe fallback for raw exceptions.
      return ErrorView(
        message: errorMessage ?? l10n.errorsGeneric,
        onRetry: onRetry,
      );
    }
    return child ?? empty ?? const SizedBox.shrink();
  }
}
