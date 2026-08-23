import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';

/// Full-area error state: icon + message + optional retry button.
///
/// Themed per DESIGN.md: black background, white/gray text,
/// accent icon in the **error** role — [AppColors.error], the semantic
/// alias of the glowPink token (6.00:1 — AA). Error is the one place pink
/// may appear (LUXE directive 2026-08-12: pink is not a main color; error
/// semantics keep it as the documented exception).
class ErrorView extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const ErrorView({
    super.key,
    required this.message,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.retryLabel,
  });

  static const _accent = AppColors.error;
  static const _muted = AppColors.mutedStrong;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSizes.xxl, color: _accent),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _muted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              // U-19: full-width CTA capped at 320 — the fixed 200px width
              // clipped long labels at 1.5× text scale (§7.3).
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: VButton.outlined(
                  label: retryLabel ?? l10n.commonRetry,
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
