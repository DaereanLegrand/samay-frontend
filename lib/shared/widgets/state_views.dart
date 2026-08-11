import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/v_button.dart';

/// Full-area loading state: white spinner + optional `mutedStrong` caption,
/// centered on black (DISCO-DESIGN-SYSTEM §5.8).
///
/// The spinner is **white** — not `glowPink` — because loading is not a brand
/// moment (P3: accents are privileges, not defaults; pink is reserved for
/// welcome/checkout-class moments). 24px per §5.8.
class VLoadingView extends StatelessWidget {
  final String? label;

  const VLoadingView({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.white,
            ),
          ),
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
/// and optional outlined CTA (DISCO-DESIGN-SYSTEM §5.9). Centered,
/// `sectionGap` spacing between the blocks.
class VEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const VEmptyView({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSizes.xxl, color: AppColors.border),
            const SizedBox(height: AppSpacing.sectionGap),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedStrong),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 200,
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
/// error → [ErrorView] (I-06), else the [child] or the [empty] view.
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
    if (loading) return VLoadingView(label: loadingLabel);
    final err = error;
    if (err != null) {
      return ErrorView(
        message: errorMessage ?? err.toString(),
        onRetry: onRetry,
      );
    }
    return child ?? empty ?? const SizedBox.shrink();
  }
}
