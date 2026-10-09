import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/utils/form_validators.dart' as form_validators;
import 'package:samay/features/auth/providers/auth_form_errors.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Fresh entry = fresh error surface (flow-scoped error providers,
    // fake-OTP-error fix). Post-frame: provider writes are
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
    if (_submitting) return;
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
    setState(() => _submitting = true);
    try {
      await ref.read(authStateProvider.notifier).signIn(email, password);
      if (!mounted) return;
      if (ref.read(authStateProvider).valueOrNull?.authenticated == true) {
        context.go(RoutePaths.mainFeed);
        return;
      }
      setState(() => _submitting = false);
      // Own-action scoping: capture THIS attempt's failure — the global auth
      // stream is never mirrored into the field.
      final message =
          ref.read(authStateProvider).errorMessage ??
          l10n.authUnknownLoginError;
      loginErrors.set(message);
      showAppError(context, message, blocking: true);
    } catch (e, st) {
      AppLogger.instance.error('login error: $e', '$st');
      final message = e.toAppError().message;
      loginErrors.set(message);
      if (mounted) {
        setState(() => _submitting = false);
        showAppError(context, message, blocking: true);
      }
    }
  }

  /// Runs a native social sign-in and routes to the feed on success. A
  /// cancelled sheet is handled in the notifier (state stays unauthenticated);
  /// any other failure surfaces the mapped error.
  Future<void> _social(Future<void> Function() action) async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _submitting = true);
    try {
      await action();
      if (!mounted) return;
      final auth = ref.read(authStateProvider).valueOrNull;
      if (auth != null && auth.authenticated) {
        if (auth.hasProfile) {
          // Returning account.
          context.go(RoutePaths.mainFeed);
        } else {
          // New OAuth account: GoTrue already registered the auth user, so skip
          // OTP and start the onboarding funnel (age gate → terms → profile
          // setup) to create the profile.
          setState(() => _submitting = false);
          context.push(
            RoutePaths.ageGate,
            extra: AgeGateExtra(email: auth.user?['email'] as String? ?? ''),
          );
        }
        return;
      }
      setState(() => _submitting = false);
      final message =
          ref.read(authStateProvider).errorMessage ?? l10n.authUnknownLoginError;
      showAppError(context, message, blocking: true);
    } catch (e, st) {
      AppLogger.instance.error('social sign-in error: $e', '$st');
      if (mounted) {
        setState(() => _submitting = false);
        showAppError(context, e.toAppError().message, blocking: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginError = ref.watch(loginErrorProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: VHeaderBar(
        showBack: false,
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
                      VDisplayText(text: l10n.commonSignIn),
                      // Hero → fields breathes at 40.
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
                        // instead of a standalone inline Text (ledger,
                        // handoff 4). Sourced from the login-scoped provider —
                        // never the global auth stream.
                        errorText: loginError,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        // the inline resetPasswordForEmail call is
                        // replaced by the dedicated /forgot-password screen
                        // (email → confirmation).
                        child: TextButton(
                          onPressed: () =>
                              context.push(RoutePaths.forgotPassword),
                          // Secondary links stay plain + muted — the
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
                      // directive — cyan/skyblue is banned on
                      // buttons): black fill, white text, white hairline.
                      // No family gradient on the login CTA.
                      VButton.dark(
                        label: l10n.commonSignIn,
                        loading:
                            _submitting ||
                            ref.watch(authStateProvider).isLoading,
                        onPressed: _login,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: AppColors.hairline),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              l10n.authOrDivider,
                              style: const TextStyle(
                                color: AppColors.mutedStrong,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: AppColors.hairline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      VButton.outlined(
                        label: l10n.authContinueWithGoogle,
                        loading: _submitting,
                        onPressed: _submitting
                            ? null
                            : () => _social(
                                  () => ref
                                      .read(authStateProvider.notifier)
                                      .signInWithGoogle(),
                                ),
                      ),
                      if (defaultTargetPlatform == TargetPlatform.iOS ||
                          defaultTargetPlatform == TargetPlatform.macOS) ...[
                        const SizedBox(height: 12),
                        VButton.outlined(
                          label: l10n.authContinueWithApple,
                          loading: _submitting,
                          onPressed: _submitting
                              ? null
                              : () => _social(
                                    () => ref
                                        .read(authStateProvider.notifier)
                                        .signInWithApple(),
                                  ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push(RoutePaths.signup),
                        child: Text(
                          l10n.commonCreateAccount,
                          style: const TextStyle(color: AppColors.mutedStrong),
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
