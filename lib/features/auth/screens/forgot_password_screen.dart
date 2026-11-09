import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/utils/form_validators.dart' as form_validators;
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Password recovery — the reference app's dedicated `/forgot-password` screen
/// with the disco treatment: `displayMedium` header (§3.2 auth site), the
/// `VInput` underline, and the in-place success state (the form morphs
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
    // Success feedback is the floating snackbar.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.authForgotPasswordSnack)));
  }

  void _backToLogin() => context.go(RoutePaths.login);

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
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
                    children: _sent
                        ? _successContent(l10n, _emailController.text.trim())
                        : _formContent(auth, l10n),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _formContent(AsyncValue<AuthState> auth, AppLocalizations l10n) {
    return [
      const SizedBox(height: 32),
      // §3.2 auth big header — monochrome VDisplayText.
      VDisplayText(text: l10n.authForgotPasswordHeading),
      const SizedBox(height: 8),
      Text(
        l10n.authForgotPasswordHint,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      // Hint → field breathes at 40.
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
      // §5.1 primary CTA — the black button voice.
      VButton.dark(
        label: l10n.authForgotPasswordSend,
        loading: auth.isLoading,
        onPressed: _send,
      ),
      const SizedBox(height: 8),
      // Secondary links stay plain + muted so the CTA dominates.
      TextButton(
        onPressed: _backToLogin,
        child: Text(
          l10n.authBackToLogin,
          style: TextStyle(color: context.palette.mutedForeground),
        ),
      ),
      const SizedBox(height: 32),
    ];
  }

  List<Widget> _successContent(AppLocalizations l10n, String email) {
    return [
      const SizedBox(height: 32),
      // The success state keeps the same display hero (one hero per screen,
      // §6.2).
      VDisplayText(text: l10n.authForgotPasswordSuccessTitle),
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
          style: TextStyle(color: context.palette.mutedForeground),
        ),
      ),
      const SizedBox(height: 32),
    ];
  }
}
