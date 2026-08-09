import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/services/supabase_service.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_input.dart';

class DonateShardsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const DonateShardsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<DonateShardsScreen> createState() => _DonateShardsScreenState();
}

class _DonateShardsScreenState extends State<DonateShardsScreen> {
  final _amountController = TextEditingController();
  bool _loading = false;

  Future<void> _donate() async {
    final l10n = AppLocalizations.of(context);
    final amount = int.tryParse(InputSanitizer.sanitizeAmount(_amountController.text));
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupsInvalidAmount)),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService.instance.donateToGroup(widget.groupId, amount);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupsDonationSuccess)),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toAppError().message)),
        );
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
      appBar: AppBar(title: Text(l10n.groupsDonateTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.groupsDonateTo(widget.groupName),
              style: Theme.of(context).textTheme.headlineMedium),
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
          VButton.emphasized(
            label: l10n.groupsDonate,
            loading: _loading,
            onPressed: _donate,
          ),
        ],
      ),
    );
  }
}
