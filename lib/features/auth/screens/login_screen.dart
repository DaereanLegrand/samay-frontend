import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/utils/form_validators.dart' as form_validators;
import 'package:samay/features/auth/providers/auth_form_errors.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
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
  void initState() {
    super.initState();
    // Fresh entry = fresh error surface (flow-scoped error providers,
    // 2026-08-24 fake-OTP-error fix). Post-frame: provider writes are
    // illegal during the widget life-cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loginErrorProvider.notifier).clear();
    });
  }

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
    final loginErrors = ref.read(loginErrorProvider.notifier)..clear();
    try {
      await ref.read(authStateProvider.notifier).signIn(email, password);
      if (mounted &&
          ref.read(authStateProvider).valueOrNull?.authenticated == true) {
        context.go(RoutePaths.mainFeed);
        return;
      }
      // Own-action scoping: capture THIS attempt's failure — the global auth
      // stream is never mirrored into the field.
      final message = ref.read(authStateProvider).errorMessage ??
          l10n.authUnknownLoginError;
      loginErrors.set(message);
      if (mounted) showAppError(context, message, blocking: true);
    } catch (e, st) {
      AppLogger.instance.error('login error: $e', '$st');
      final message = e.toAppError().message;
      loginErrors.set(message);
      if (mounted) showAppError(context, message, blocking: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginError = ref.watch(loginErrorProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // LUXE v2 directive #8: no duplicate titles — the hero owns the
      // headline; the AppBar stays title-less so the pushed route keeps the
      // iOS back affordance (swipe-back is theme-wide, XL-03).
      appBar: AppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    VDisplayText(text: l10n.commonSignIn),
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
                      // §5.2: THIS attempt's error rides the password field
                      // as `errorText` (glowPink — never raw red on black)
                      // instead of a standalone inline Text (U-07 ledger,
                      // handoff 4). Sourced from the login-scoped provider —
                      // never the global auth stream.
                      errorText: loginError,
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
                    // §5.1 brand moment: the primary CTA is BLACK (user
                    // directive 2026-08-14 — cyan/skyblue is banned on
                    // buttons): black fill, white text, white hairline.
                    // No family gradient on the login CTA.
                    VButton.dark(
                      label: l10n.commonSignIn,
                      loading: ref.watch(authStateProvider).isLoading,
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
    );
  }
}
