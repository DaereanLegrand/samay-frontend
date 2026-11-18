import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Optional account upgrade.
///
/// A guest keeps its uid when it links Apple/Google (GoTrue manual linking), so
/// nothing is lost — this screen exists only because the credentials are
/// optional: the app is fully playable as a guest forever.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toAppError().message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.palette.background,
      body: VHeaderBar(
        titleWidget: VDisplayText(text: l10n.authSignInTitle),
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
          ),
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.authSignInBody,
              style: AppTypography.bodyLarge.copyWith(
                color: context.palette.mutedForeground,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            VButton.emphasized(
              label: l10n.authContinueWithApple,
              onPressed: _busy
                  ? null
                  : () => _run(ref.read(authStateProvider.notifier).linkWithApple),
            ),
            const SizedBox(height: AppSpacing.md),
            VButton.outlined(
              label: l10n.authContinueWithGoogle,
              onPressed: _busy
                  ? null
                  : () => _run(ref.read(authStateProvider.notifier).linkWithGoogle),
            ),
          ],
        ),
      ),
    );
  }
}
