import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';

/// Full-area error state: icon + message + optional retry button.
///
/// Themed per DISCO-DESIGN-SYSTEM.md: black background, white/gray text,
/// signature `glowPink` accent icon.
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

  static const _accent = AppColors.glowPink;
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
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 200,
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
