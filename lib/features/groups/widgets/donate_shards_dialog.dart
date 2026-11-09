import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/utils/form_validators.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/features/groups/theme/group_theme_palette.dart';
import 'package:samay/features/groups/theme/group_theme_theme.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_input.dart';

/// The donate-shards overlay: a centered box over the group detail screen.
///
/// Donating is a quick, single-field action, so it does not deserve a pushed
/// route — it floats over the group (which stays themed behind a dimmed
/// barrier) with the heading, the 14-day ranking blurb, the amount field and
/// the Donar button.
Future<void> showDonateToGroupDialog(
  BuildContext context, {
  required String groupId,
  required String groupName,
  GroupThemePalette? palette,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: (palette?.background ?? AppColors.discoBlack).withValues(
      alpha: 0.72,
    ),
    builder: (_) => _DonateToGroupDialog(
      groupId: groupId,
      groupName: groupName,
      palette: palette,
    ),
  );
}

class _DonateToGroupDialog extends ConsumerStatefulWidget {
  const _DonateToGroupDialog({
    required this.groupId,
    required this.groupName,
    this.palette,
  });

  final String groupId;
  final String groupName;
  final GroupThemePalette? palette;

  @override
  ConsumerState<_DonateToGroupDialog> createState() =>
      _DonateToGroupDialogState();
}

class _DonateToGroupDialogState extends ConsumerState<_DonateToGroupDialog> {
  final _amountController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _donate() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final sanitized = InputSanitizer.sanitizeAmount(_amountController.text);
    final amountError = numericValidator(
      sanitized,
      min: 1,
      message: l10n.groupsInvalidAmount,
    );
    if (amountError != null) {
      messenger.showSnackBar(SnackBar(content: Text(amountError)));
      return;
    }
    final amount = int.parse(sanitized);

    setState(() => _loading = true);
    try {
      await ref
          .read(groupsRepositoryProvider)
          .donateToGroup(widget.groupId, amount);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.groupsDonationSuccess)),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toAppError().message)));
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = widget.palette;
    return GroupThemeSurface(
      palette: palette,
      child: Dialog(
        backgroundColor: palette?.surface ?? AppColors.discoBlack,
        surfaceTintColor: AppColors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.sharp,
          side: BorderSide(color: palette?.border ?? AppColors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.groupsDonateTo(widget.groupName),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: palette?.foreground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.groupsDonateBlurb,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette?.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  VInput(
                    controller: _amountController,
                    label: l10n.groupsShardsAmount,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  VButton.dark(
                    label: l10n.groupsDonate,
                    loading: _loading,
                    onPressed: _donate,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
