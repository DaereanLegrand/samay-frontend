import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_button.dart';
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
    if (email.isEmpty || password.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(authStateProvider.notifier).signIn(email, password);
      if (mounted && ref.read(authStateProvider).valueOrNull?.authenticated == true) {
        context.go(RoutePaths.mainFeed);
        return;
      }
      final msg = ref.read(authStateProvider).errorMessage ?? l10n.authUnknownLoginError;
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.commonSignIn)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            VInput(
              controller: _emailController,
              label: l10n.commonEmail,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            VInput(
              controller: _passwordController,
              label: l10n.commonPassword,
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.resetPasswordForEmail(
                    _emailController.text.trim(),
                  );
                },
                child: Text(l10n.authForgotPassword),
              ),
            ),
            const SizedBox(height: 24),
            if (auth.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  auth.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            VButton.emphasized(
              label: l10n.commonSignIn,
              loading: auth.isLoading,
              onPressed: _login,
            ),
            const SizedBox(height: 12),
            VButton(
              label: l10n.commonCreateAccount,
              onPressed: () => context.push(RoutePaths.signup),
            ),
          ],
        ),
      ),
    );
  }
}
