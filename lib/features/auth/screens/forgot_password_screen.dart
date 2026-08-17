import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/utils/form_validators.dart' as form_validators;
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_input.dart';

/// Password recovery (U-14 R3) — Juega's dedicated `/forgot-password` screen
/// with the disco treatment: `displayMedium` header (§3.2 auth site), the
/// `VInput` underline, and the F14 in-place success state (the form morphs
/// into a confirmation, no route push).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _emailError;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    final formState = form_validators.FormState()
      ..validate({'email': form_validators.emailValidator}, {'email': email});
    if (!formState.isValid) {
      setState(() => _emailError = formState.errors['email']);
      return;
    }
    setState(() => _emailError = null);
    final l10n = AppLocalizations.of(context);
    await ref.read(authStateProvider.notifier).resetPasswordForEmail(email);
    if (!mounted) return;
    if (ref.read(authStateProvider).hasError) return;
    setState(() => _sent = true);
    // F7: success feedback is the floating snackbar.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.authForgotPasswordSnack)));
  }

  void _backToLogin() => context.go(RoutePaths.login);

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final l10n = AppLocalizations.of(context);
    final family = AppGradients.familyOf('forgot_password');

    return Scaffold(
      appBar: AppBar(),
      // §7.3: same scroll-safe pattern as the OTP screen — the pinned CTA must
      // never clip under large text scales or small surfaces.
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: _sent
                      ? _successContent(
                          l10n,
                          _emailController.text.trim(),
                          family,
                        )
                      : _formContent(auth, l10n, family),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _formContent(
    AsyncValue<AuthState> auth,
    AppLocalizations l10n,
    AppGradient family,
  ) {
    return [
      const SizedBox(height: 32),
      // §3.2 auth big header — LUXE v2: peach-family VDisplayText (gradient
      // fill + slowly pulsing glow + once-only shimmer sweep).
      VDisplayText(text: l10n.authForgotPasswordHeading, gradient: family),
      const SizedBox(height: 8),
      Text(
        l10n.authForgotPasswordHint,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      // XL-16: hint → field breathes at 40.
      const SizedBox(height: 40),
      VInput(
        controller: _emailController,
        label: l10n.commonEmail,
        keyboardType: TextInputType.emailAddress,
        // §5.2: errors ride the field as `errorText` (glowPink — never raw
        // red on black): field validation first, then the auth-level error
        // (mirroring the login screen's password field).
        errorText: _emailError ?? (auth.hasError ? auth.errorMessage : null),
      ),
      const Spacer(),
      // §5.1 brand moment: the primary CTA is the filled glowAccent
      // (peach-family gradient fill + black text).
      VButton.glowAccent(
        label: l10n.authForgotPasswordSend,
        loading: auth.isLoading,
        filled: true,
        gradient: family,
        onPressed: _send,
      ),
      const SizedBox(height: 8),
      // XL-16: secondary links stay plain + muted so the CTA dominates.
      TextButton(
        onPressed: _backToLogin,
        child: Text(
          l10n.authBackToLogin,
          style: const TextStyle(color: AppColors.mutedStrong),
        ),
      ),
      const SizedBox(height: 32),
    ];
  }

  List<Widget> _successContent(
    AppLocalizations l10n,
    String email,
    AppGradient family,
  ) {
    return [
      const SizedBox(height: 32),
      // The success state keeps the same display hero (one hero per screen,
      // §6.2) — the peach family rides both states.
      VDisplayText(text: l10n.authForgotPasswordSuccessTitle, gradient: family),
      const SizedBox(height: 8),
      Text(
        l10n.authForgotPasswordSuccessBody(email),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const Spacer(),
      // The escape hatch is available from the success state too.
      TextButton(
        onPressed: _backToLogin,
        child: Text(
          l10n.authBackToLogin,
          style: const TextStyle(color: AppColors.mutedStrong),
        ),
      ),
      const SizedBox(height: 32),
    ];
  }
}
