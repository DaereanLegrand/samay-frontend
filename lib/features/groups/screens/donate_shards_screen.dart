import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/utils/form_validators.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';

class DonateShardsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const DonateShardsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<DonateShardsScreen> createState() => _DonateShardsScreenState();
}

class _DonateShardsScreenState extends ConsumerState<DonateShardsScreen> {
  final _amountController = TextEditingController();
  bool _loading = false;

  Future<void> _donate() async {
    final l10n = AppLocalizations.of(context);
    final sanitized = InputSanitizer.sanitizeAmount(_amountController.text);
    final amountError = numericValidator(
      sanitized,
      min: 1,
      message: l10n.groupsInvalidAmount,
    );
    if (amountError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(amountError)));
      return;
    }
    final amount = int.parse(sanitized);

    setState(() => _loading = true);
    try {
      await ref
          .read(groupsRepositoryProvider)
          .donateToGroup(widget.groupId, amount);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.groupsDonationSuccess)));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: VHeaderBar(
        title: l10n.groupsDonateTitle,
        child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.groupsDonateTo(widget.groupName),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.groupsDonateBlurb,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                VInput(
                  controller: _amountController,
                  label: l10n.groupsShardsAmount,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 32),
                // Donating is the screen's primary action; the amount VInput
                // already carries the token treatment + errorText seam.
                VButton.dark(
                  label: l10n.groupsDonate,
                  loading: _loading,
                  onPressed: _donate,
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
