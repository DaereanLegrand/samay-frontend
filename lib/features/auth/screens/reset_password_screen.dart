import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_input.dart';

/// Terminal password-recovery screen (D4/E3). The recovery link establishes a
/// session and the router confines it here until the new password is saved.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.length < 8) {
      setState(() => _error = l10n.resetPasswordTooShort);
      return;
    }
    if (password != confirm) {
      setState(() => _error = l10n.resetPasswordMismatch);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(authStateProvider.notifier).updatePassword(password);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _done = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.resetPasswordError;
      });
    }
  }

  void _continue() {
    // The session is valid; the guard routes to the normal post-auth flow.
    context.go(RoutePaths.mainFeed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            VHeaderBar(title: l10n.resetPasswordTitle),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _done
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VDisplayText(text: l10n.resetPasswordSuccess),
                          const SizedBox(height: 24),
                          VButton(
                            label: l10n.resetPasswordContinue,
                            onPressed: _continue,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VDisplayText(text: l10n.resetPasswordBody),
                          const SizedBox(height: 24),
                          VInput(
                            controller: _passwordController,
                            label: l10n.resetPasswordNew,
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          VInput(
                            controller: _confirmController,
                            label: l10n.resetPasswordConfirm,
                            obscureText: true,
                            errorText: _error,
                          ),
                          const SizedBox(height: 24),
                          VButton(
                            label: l10n.resetPasswordSubmit,
                            loading: _saving,
                            onPressed: _saving ? null : _save,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
