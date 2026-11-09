import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/core/theme/app_palette_context.dart';

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
  final mapped = appError.localize(l10n).trim();
  final message = mapped.isNotEmpty ? mapped : (fallback ?? l10n.errorsGeneric);
  // Diagnostic detail stays client-side: never render codes or raw exception
  // text in the UI.
  AppLogger.instance.error('[${appError.code}] ${appError.message}');
  if (!context.mounted) return;

  if (blocking) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.palette.background,
        title: Text(
          l10n.commonError,
          style: TextStyle(color: context.palette.foreground),
        ),
        content: Text(
          message,
          style: Theme.of(
            dialogContext,
          ).textTheme.bodyMedium?.copyWith(color: context.palette.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              l10n.commonOk,
              style: TextStyle(color: context.palette.foreground),
            ),
          ),
        ],
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.palette.background,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              size: 18,
              // Error semantics — the one place pink may appear:
              // AppColors.error aliases glowPink.
              color: AppColors.error,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.palette.foreground),
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
