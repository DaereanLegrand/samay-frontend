import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/utils/form_validators.dart' as form_validators;
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_aurora.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final formState = form_validators.FormState()
      ..validate(
        {
          'email': form_validators.requiredValidator,
          'password': form_validators.requiredValidator,
        },
        {'email': email, 'password': password},
      );
    if (!formState.isValid) return;
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(authStateProvider.notifier).signIn(email, password);
      if (mounted &&
          ref.read(authStateProvider).valueOrNull?.authenticated == true) {
        context.go(RoutePaths.mainFeed);
        return;
      }
      final msg =
          ref.read(authStateProvider).errorMessage ??
          l10n.authUnknownLoginError;
      if (mounted) showAppError(context, msg, blocking: true);
    } catch (e, st) {
      AppLogger.instance.error('login error: $e', '$st');
      if (mounted) showAppError(context, e, blocking: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final l10n = AppLocalizations.of(context);
    final family = AppGradients.familyOf('login');

    return Scaffold(
      // LUXE v2 directive #8: no duplicate titles — the hero owns the
      // headline; the AppBar stays title-less so the pushed route keeps the
      // iOS back affordance (swipe-back is theme-wide, XL-03).
      appBar: AppBar(),
      // XL-16 (Gemma 02_login — hierarchy 5/10): the form screen's ambient
      // aurora is a whisper (opacity 0.05 — the glow belongs to the hero
      // gradient and the CTA, nowhere else).
      body: VAurora(
        gradients: [family],
        opacity: 0.05,
        // §7.3: scroll-safe body (the OTP pattern, U-07) — the fixed Column
        // overflows at ≥1.5× text scale on small phones; pins the CTAs when
        // the content fits and scrolls when it doesn't. Never clip.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      VDisplayText(text: l10n.commonSignIn, gradient: family),
                      // XL-16 (03_signup density verdict): hero → fields
                      // breathes at 40.
                      const SizedBox(height: 40),
                      VInput(
                        controller: _emailController,
                        label: l10n.commonEmail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      VInput(
                        controller: _passwordController,
                        label: l10n.commonPassword,
                        obscureText: true,
                        // §5.2: the auth error rides the password field as
                        // `errorText` (glowPink — never raw red on black)
                        // instead of a standalone inline Text (U-07 ledger,
                        // handoff 4).
                        errorText: auth.hasError ? auth.errorMessage : null,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        // U-14 R3: the inline resetPasswordForEmail call is
                        // replaced by the dedicated /forgot-password screen
                        // (email → confirmation).
                        child: TextButton(
                          onPressed: () =>
                              context.push(RoutePaths.forgotPassword),
                          // XL-16: secondary links stay plain + muted — the
                          // primary CTA must dominate.
                          child: Text(
                            l10n.authForgotPassword,
                            style: const TextStyle(
                              color: AppColors.mutedStrong,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // §5.1 brand moment: the primary CTA is the filled
                      // glowAccent (cyan-family gradient fill + black text) —
                      // the only full-strength surface on the screen.
                      VButton.glowAccent(
                        label: l10n.commonSignIn,
                        loading: auth.isLoading,
                        filled: true,
                        gradient: family,
                        onPressed: _login,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push(RoutePaths.signup),
                        child: Text(
                          l10n.commonCreateAccount,
                          style: const TextStyle(
                            color: AppColors.mutedStrong,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
