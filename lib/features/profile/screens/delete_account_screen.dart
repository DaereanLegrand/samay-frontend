import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_input.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _emailMatches {
    try {
      final currentEmail =
          ref.read(authServiceProvider).auth.currentUser?.email ?? '';
      return _emailController.text.trim().toLowerCase() == currentEmail.toLowerCase();
    } catch (e, st) {
      AppLogger.instance.error('emailMatches error: $e', '$st');
      return false;
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    if (!_emailMatches) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileEmailMismatch)),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileDeleteQuestion),
        content: Text(l10n.profileDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.commonDelete,
              // §5.2 (U-09): never raw red on black — the danger confirm
              // uses the error semantic (glowPink, 6.00:1 AA).
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).deleteAccount();
      if (mounted) context.go(RoutePaths.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailFilled = _emailController.text.trim().isNotEmpty;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileDeleteTitle)),
      // §7.3: scroll-safe body (the OTP pattern, U-07) — the fixed Column
      // overflows at ≥1.5× text scale on small phones; pins the CTA when
      // the content fits and scrolls when it doesn't. Never clip.
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      l10n.profileDeleteExplanation,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.profileConfirmEmail,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    VInput(
                      controller: _emailController,
                      label: l10n.commonEmail,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const Spacer(),
                    // §5.1 danger CTA (U-09): the glowAccent *outline* — pink
                    // 1px border + pink label; the danger is a function, not
                    // a brand moment, so no pink fill. Disabled (empty email)
                    // drops to `muted` per the VButton disabled state.
                    VButton.glowAccent(
                      label: l10n.profileDeleteTitle,
                      onPressed: emailFilled ? _delete : null,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
