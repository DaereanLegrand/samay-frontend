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
import 'package:samay/core/utils/form_validators.dart' as form_validators;
import 'package:samay/features/auth/logic/password_policy.dart';
import 'package:samay/features/auth/providers/auth_form_errors.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
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
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Fresh entry = fresh error surface (flow-scoped error providers,
    // fake-OTP-error fix). Post-frame: provider writes are
    // illegal during the widget life-cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(signupErrorsProvider.notifier).clear();
    });
  }

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
    final emailError = form_validators.compose([
      (v) =>
          form_validators.requiredValidator(v, message: l10n.authFieldRequired),
      (v) =>
          form_validators.emailValidator(v, message: l10n.errorsInvalidEmail),
    ])(email);
    final passwordErrorText = password.isEmpty
        ? l10n.authFieldRequired
        : passwordError(password) != null
        ? l10n.authPasswordTooWeak
        : null;
    final confirmErrorText = confirm.isEmpty
        ? l10n.authFieldRequired
        : password != confirm
        ? l10n.authPasswordsDontMatch
        : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordErrorText;
      _confirmError = confirmErrorText;
    });
    if (emailError != null ||
        passwordErrorText != null ||
        confirmErrorText != null) {
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
                // Explicit labeled navigation (no-fallback policy): the ONLY
                // way off this dialog is a button the user deliberately taps —
                // "Iniciar sesión" goes to login.
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
      // Own-action scoping: the failure of THIS submit rides the screen's
      // scoped error provider — the global auth stream is never mirrored.
      ref
          .read(signupErrorsProvider.notifier)
          .setServerError(appError.localize(l10n));
      if (mounted) showAppError(context, e, blocking: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signupErrors = ref.watch(signupErrorsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: VHeaderBar(
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
                      // §3.2 auth big header — monochrome VDisplayText
                      // (verbatim copy, flat white glyphs).
                      VDisplayText(text: l10n.authCreateYourAccount),
                      // Hero → fields rhythm tightens to 32 and the field
                      // group reads at 16 — the 3 fields + CTA are ONE quiet
                      // column, nothing else.
                      const SizedBox(height: 32),
                      VInput(
                        controller: _emailController,
                        label: l10n.commonEmail,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        onChanged: (_) {
                          if (_emailError != null) {
                            setState(() => _emailError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      VInput(
                        controller: _passwordController,
                        label: l10n.authPasswordWithRequirements,
                        obscureText: true,
                        // §5.2: validation errors ride the fields as
                        // `errorText` (glowPink — never raw red on black).
                        errorText: _passwordError,
                        onChanged: (_) {
                          if (_passwordError != null) {
                            setState(() => _passwordError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      VInput(
                        controller: _confirmController,
                        label: l10n.commonConfirmPassword,
                        obscureText: true,
                        errorText: _confirmError,
                        onChanged: (_) {
                          if (_confirmError != null) {
                            setState(() => _confirmError = null);
                          }
                        },
                      ),
                      if (signupErrors.displayText != null ||
                          _emailError != null ||
                          _passwordError != null ||
                          _confirmError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            signupErrors.displayText ?? l10n.authCheckFields,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      const Spacer(),
                      // §5.1 primary CTA — emphasized white fill, black text.
                      VButton.emphasized(
                        label: l10n.commonCreateAccount,
                        loading:
                            _submitting ||
                            ref.watch(authStateProvider).isLoading,
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
