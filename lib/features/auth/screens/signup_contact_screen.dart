import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/auth/logic/password_policy.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_button.dart';
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
            builder: (_) => AlertDialog(
              title: Text(l10n.authEmailAlreadyRegistered),
              content: Text(l10n.authEmailAlreadyRegisteredBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonOk),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.commonCreateAccount)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // §3.2 auth big header — Playfair Display italic 40 with the glow
            // (baked into the theme's displayMedium role).
            Text(
              l10n.authCreateYourAccount,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.authSignupSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
              // §5.2: validation errors ride the fields as `errorText`
              // (glowPink — never raw red on black).
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
            VButton.emphasized(
              label: l10n.commonCreateAccount,
              loading: auth.isLoading || _submitting,
              onPressed: _signup,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
