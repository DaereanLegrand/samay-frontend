import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// User-facing crash-recovery banner (LOG-03): shown once after the app
/// recovered from a previous crash (a `.samay_crash_marker` existed at
/// launch — see [main.dart]'s `recoverCrashMarker` handshake).
///
/// Mounted by [SamayApp] inside `MaterialApp.router`'s builder, above the
/// ConnectivityBanner, with `visible` set from the recovered-marker result.
/// Dismissible: the OK action collapses it for the rest of the session
/// (local state — no marker to clear, recovery already happened at boot).
class CrashRecoveryBanner extends StatefulWidget {
  final bool visible;

  const CrashRecoveryBanner({super.key, this.visible = false});

  @override
  State<CrashRecoveryBanner> createState() => _CrashRecoveryBannerState();
}

class _CrashRecoveryBannerState extends State<CrashRecoveryBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || _dismissed) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      color: AppColors.errorFill,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      child: Row(
        children: [
          Icon(
            Icons.healing,
            size: 14,
            // Error semantics — white on the glowPinkDeep fill (5.87:1 AA).
            color: context.palette.foreground,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.crashRecoveryBannerTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.palette.foreground),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            // The dismiss label reuses the common affirmative (commonOk).
            onPressed: () => setState(() => _dismissed = true),
            style: TextButton.styleFrom(
              foregroundColor: context.palette.foreground,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }
}
