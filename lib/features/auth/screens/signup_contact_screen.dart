import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/auth/logic/password_policy.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_aurora.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_input.dart';

class SignupContactScreen extends ConsumerStatefulWidget {
  const SignupContactScreen({super.key});

  @override
  ConsumerState<SignupContactScreen> createState() =>
      _SignupContactScreenState();
}

class _SignupContactScreenState extends ConsumerState<SignupContactScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _passwordError;
  String? _confirmError;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_submitting) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _passwordError = null;
      _confirmError = null;
    });
    if (email.isEmpty || password.isEmpty || confirm.isEmpty) return;
    final passwordErrorText = passwordError(password);
    if (passwordErrorText != null) {
      setState(() => _passwordError = passwordErrorText);
      return;
    }
    if (password != confirm) {
      setState(() => _confirmError = l10n.authPasswordsDontMatch);
      return;
    }
    setState(() => _submitting = true);
    try {
      final action = await ref
          .read(authStateProvider.notifier)
          .checkEmail(email);
      if (action == 'exists') {
        if (mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.authEmailAlreadyRegistered),
              content: Text(l10n.authEmailAlreadyRegisteredBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.commonOk),
                ),
                // Explicit labeled navigation (no-fallback policy
                // 2026-08-13): the ONLY way off this dialog is a button the
                // user deliberately taps — "Iniciar sesión" goes to login.
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    context.go(RoutePaths.login);
                  },
                  child: Text(l10n.commonSignIn),
                ),
              ],
            ),
          );
        }
        return;
      }
      await ref.read(authStateProvider.notifier).sendOtp(email);
      if (mounted) {
        context.push(
          RoutePaths.verify,
          extra: VerifyExtra(email: email, password: password),
        );
      }
    } catch (e, st) {
      final appError = e.toAppError();
      if (appError is RateLimitError) {
        AppLogger.instance.warn('signup OTP rate-limited for $email');
      }
      AppLogger.instance.error('signup error: $e', '$st');
      if (mounted) showAppError(context, e, blocking: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final l10n = AppLocalizations.of(context);
    final family = AppGradients.familyOf('signup');

    return Scaffold(
      // LUXE v2 directive #8: the "Crear cuenta" AppBar title is useless —
      // the hero owns the headline; the AppBar stays title-less for the back
      // affordance only.
      appBar: AppBar(),
      body: VAurora(
        gradients: [family],
        // XL-16 (03_signup — density 3/10, minimalism 2/10): the aurora is a
        // whisper on input surfaces; the glow lives in the hero + CTA only.
        opacity: 0.05,
        // §7.3: scroll-safe body (the OTP pattern, U-07) — the fixed Column
        // overflows at ≥1.5× text scale on small phones; pins the CTA when
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
                      // §3.2 auth big header — LUXE v2: the VDisplayText
                      // hero is the multi-color violet-family gradient
                      // (pastel → vivid) with the slowly pulsating glow and
                      // the once-only shimmer sweep — NOT pink (user
                      // directive 2026-08-12); reduced-motion → static
                      // mid-α halo.
                      VDisplayText(
                        text: l10n.authCreateYourAccount,
                        gradient: family,
                      ),
                      // XL-19 (03_signup — still "dense", luxury 3/10): the
                      // hero → fields rhythm tightens to 32 and the field
                      // group reads at 16 — the 3 fields + CTA are ONE quiet
                      // column, nothing else.
                      const SizedBox(height: 32),
                      VInput(
                        controller: _emailController,
                        label: l10n.commonEmail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      VInput(
                        controller: _passwordController,
                        label: l10n.authPasswordWithRequirements,
                        obscureText: true,
                        // §5.2: validation errors ride the fields as
                        // `errorText` (glowPink — never raw red on black).
                        errorText: _passwordError,
                      ),
                      const SizedBox(height: 16),
                      VInput(
                        controller: _confirmController,
                        label: l10n.commonConfirmPassword,
                        obscureText: true,
                        errorText: _confirmError,
                      ),
                      if (auth.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      const Spacer(),
                      // §5.1 brand moment: the primary CTA is emphasized
                      // with the violet-family gradient fill + black text.
                      VButton.emphasized(
                        label: l10n.commonCreateAccount,
                        loading: auth.isLoading || _submitting,
                        gradient: family,
                        onPressed: _signup,
                      ),
                      const SizedBox(height: 32),
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
