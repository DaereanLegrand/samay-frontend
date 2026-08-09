import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/l10n/app_localizations.dart';

/// Inline error banner: pink icon + message + optional retry / close.
///
/// Themed per DISCO-DESIGN-SYSTEM.md: black surface, hairline border,
/// white/gray text, signature `glowPink` accent icon.
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

  static const _accent = AppColors.glowPink;
  static const _muted = AppColors.mutedStrong;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              child: Text(l10n.commonRetry),
            ),
          ],
          if (onClose != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 16, color: _muted),
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
