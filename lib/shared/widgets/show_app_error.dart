import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/l10n/app_localizations.dart';

/// One consistent error-presentation pattern.
///
/// Maps [error] through `error.toAppError()` and surfaces the user-facing
/// message as a SnackBar (transient) or an AlertDialog (blocking).
Future<void> showAppError(
  BuildContext context,
  Object error, {
  String? fallback,
  bool blocking = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final appError = error.toAppError();
  final mapped = appError.message.trim();
  final message = mapped.isNotEmpty ? mapped : (fallback ?? l10n.errorsGeneric);
  final code = appError.code;
  if (!context.mounted) return;

  if (blocking) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.discoBlack,
        title: Text(
          l10n.commonError,
          style: const TextStyle(color: AppColors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: Theme.of(
                dialogContext,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedStrong),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${l10n.errorCodeLabel}: $code',
              style: Theme.of(
                dialogContext,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedStrong),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              l10n.commonOk,
              style: const TextStyle(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.discoBlack,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              size: 18,
              // Error semantics — the one place pink may appear (LUXE
              // directive 2026-08-12): AppColors.error aliases glowPink.
              color: AppColors.error,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.white),
                  ),
                  Text(
                    '${l10n.errorCodeLabel}: $code',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedStrong,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SnackBar-only variant of [showAppError] for transient contexts.
Future<void> showErrorSnackBar(
  BuildContext context,
  Object error, {
  String? fallback,
}) {
  return showAppError(context, error, fallback: fallback);
}
