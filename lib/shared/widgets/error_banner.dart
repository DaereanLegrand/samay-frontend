import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/l10n/app_localizations.dart';

/// Inline error banner: accent icon + message + optional retry / close.
///
/// Themed per DISCO-DESIGN-SYSTEM.md: black surface, hairline border,
/// white/gray text, accent icon in the **error** role — [AppColors.error],
/// the semantic alias of the glowPink token (6.00:1 — AA). Error is the one
/// place pink may appear (LUXE directive 2026-08-12: pink is not a main
/// color; error semantics keep it as the documented exception).
class ErrorBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;

  const ErrorBanner({
    super.key,
    required this.message,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.onClose,
  });

  static const _accent = AppColors.error;
  static const _muted = AppColors.mutedStrong;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _muted),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: AppSpacing.xs,
                ),
              ),
              child: Text(l10n.commonRetry),
            ),
          ],
          if (onClose != null) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              onPressed: onClose,
              icon: const Icon(
                Icons.close,
                size: AppIconSizes.sm,
                color: _muted,
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              tooltip: l10n.commonClose,
            ),
          ],
        ],
      ),
    );
  }
}
