import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  String? _emailError;
  String? _passwordError;

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
    final l10n = AppLocalizations.of(context);
    final emailError = form_validators.compose([
      (v) =>
          form_validators.requiredValidator(v, message: l10n.authFieldRequired),
      (v) =>
          form_validators.emailValidator(v, message: l10n.errorsInvalidEmail),
    ])(email);
    final passwordError = form_validators.requiredValidator(
      password,
      message: l10n.authFieldRequired,
    );
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    if (emailError != null || passwordError != null) return;

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
      final authError = ref.read(authStateProvider).error;
      final message = authError == null
          ? l10n.authUnknownLoginError
          : authError.toAppError().localize(l10n);
      loginErrors.set(message);
      showAppError(context, message, blocking: true);
    } catch (e, st) {
      AppLogger.instance.error('login error: $e', '$st');
      final message = e.toAppError().localize(l10n);
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
      final authError = ref.read(authStateProvider).error;
      final message = authError == null
          ? l10n.authUnknownLoginError
          : authError.toAppError().localize(l10n);
      showAppError(context, message, blocking: true);
    } catch (e, st) {
      AppLogger.instance.error('social sign-in error: $e', '$st');
      if (mounted) {
        setState(() => _submitting = false);
        showAppError(context, e.toAppError().localize(l10n), blocking: true);
      }
    }
  }

  /// Apple platforms provide a native Sign in with Apple control; elsewhere the
  /// button is hidden (Google Play has no equivalent mandate; the iOS app still
  /// offers Apple for App Store guideline 4.8).
  bool get _isApplePlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// A borderless, transparent, icon-only sign-in control: a 44pt white disc
  /// holding a provider mark, with an accessible label. 44pt is Apple's
  /// recommended logo-only button size and the size at which each brand's mark
  /// keeps its official proportion (Google's "G" ≈41% of the disc, Apple's logo
  /// ≈43%), so the two controls are equal and neither mark reads as smaller.
  /// While [_submitting] it dims (no spinner) and is inert.
  Widget _socialIconButton({
    required String label,
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return Semantics(
      button: true,
      enabled: !_submitting,
      label: label,
      child: Tooltip(
        message: label,
        child: SizedBox(
          width: 44,
          height: 44,
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const CircleBorder(),
              foregroundColor: AppColors.white,
              backgroundColor: AppColors.transparent,
              overlayColor: AppColors.white,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _submitting ? 0.4 : 1,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  /// Brand-compliant "Continue with Google" control: the official Google "G"
  /// (full color, on a white disc). The G is displayed at its supplied 18pt
  /// size — Google prohibits recoloring or resizing the mark — which is ≈41% of
  /// the 44pt disc, in line with Google's own icon-button proportion.
  Widget _googleSignInButton(AppLocalizations l10n) {
    return _socialIconButton(
      label: l10n.authContinueWithGoogle,
      onPressed: _submitting
          ? null
          : () => _social(
              () => ref.read(authStateProvider.notifier).signInWithGoogle(),
            ),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
        ),
        child: Image.asset(
          'assets/icons/google.png',
          width: 18,
          height: 18,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  /// Apple's guideline-conformant **logo-only** Sign in with Apple control.
  ///
  /// A custom button (Apple's system-provided buttons always carry a title):
  /// the official Apple Design Resources logo-only artwork — white square +
  /// black logo — used unmodified at a 1:1 aspect ratio and masked to a circle
  /// (the HIG's sanctioned "circular mask"). The artwork's own square is the
  /// button face, so it is scaled until that square fills the 44pt disc (no
  /// crop, no added padding, never a hand-drawn mark) and the logo keeps the
  /// artwork's built-in proportion — Apple's own masked-circle geometry. At 44pt
  /// the Apple mark (≈43%) is at least the size of Google's "G" (≈41%), so it is
  /// no smaller than the other sign-in option. Icon-only, so an accessible label
  /// is attached; while [_submitting] it dims (no spinner) and is inert.
  Widget _appleSignInButton(AppLocalizations l10n) {
    return _socialIconButton(
      label: l10n.authContinueWithApple,
      onPressed: _submitting
          ? null
          : () => _social(
              () => ref.read(authStateProvider.notifier).signInWithApple(),
            ),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
        ),
        child: Transform.scale(
          // The bundled SVG canvas is 56pt and its coloured square is 44pt.
          // Enlarging by 56/44 makes that square exactly fill the disc, so the
          // logo keeps the artwork's built-in proportion.
          scale: 56 / 44,
          child: SvgPicture.asset(
            'assets/icons/apple_logo_only.svg',
            width: 44,
            height: 44,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
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
                        errorText: _emailError,
                        onChanged: (_) {
                          if (_emailError != null) {
                            setState(() => _emailError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      VInput(
                        controller: _passwordController,
                        label: l10n.commonPassword,
                        obscureText: true,
                        // §5.2: THIS attempt's error rides the password field
                        // as `errorText` (glowPink — never raw red on black).
                        // Local validation wins over the server failure;
                        // sourced from the login-scoped provider — never the
                        // global auth stream.
                        errorText: _passwordError ?? loginError,
                        onChanged: (_) {
                          if (_passwordError != null || loginError != null) {
                            setState(() => _passwordError = null);
                            ref.read(loginErrorProvider.notifier).clear();
                          }
                        },
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
                      if (_emailError != null ||
                          _passwordError != null ||
                          loginError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            l10n.authCheckFields,
                            style: const TextStyle(color: AppColors.error),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                      const SizedBox(height: 20),
                      if (_isApplePlatform)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _googleSignInButton(l10n),
                            // >= 1/10 of the 44pt button height (HIG).
                            const SizedBox(width: 16),
                            _appleSignInButton(l10n),
                          ],
                        )
                      else
                        Center(child: _googleSignInButton(l10n)),
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
