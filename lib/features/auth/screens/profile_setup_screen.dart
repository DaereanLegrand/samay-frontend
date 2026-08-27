import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/features/auth/logic/username_policy.dart';
import 'package:samay/features/auth/providers/auth_form_errors.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_input.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final String email;
  final String dateOfBirth;
  const ProfileSetupScreen({
    super.key,
    required this.email,
    required this.dateOfBirth,
  });

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Fresh entry = fresh error surface: a previous attempt's messages must
    // never survive into a re-entered screen (flow-scoped error providers,
    // 2026-08-24 fake-OTP-error fix). Post-frame: provider writes are
    // illegal during the widget life-cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(signupErrorsProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String username = InputSanitizer.sanitizeUsername(_usernameController.text);
    final errors = ref.read(signupErrorsProvider.notifier)..clear();

    // Specific, multiple field errors from the username requirements — the
    // request is never sent while any rule is violated.
    final fieldErrors = usernamePolicyErrors(username);
    if (fieldErrors.isNotEmpty) {
      errors.setUsernameErrors(fieldErrors);
      return;
    }

    setState(() => _saving = true);
    await ref
        .read(authStateProvider.notifier)
        .createProfile(username, dateOfBirth: widget.dateOfBirth);
    if (!mounted) return;
    setState(() => _saving = false);

    // Own-action scoping: capture THIS save's failure once — the global auth
    // stream is never mirrored (a stale unrelated error used to render as a
    // fake "código expirado" on entry).
    final auth = ref.read(authStateProvider);
    if (auth.hasError) {
      errors.setServerError(auth.errorMessage!);
      return;
    }
    context.go(RoutePaths.mainFeed);
  }

  @override
  Widget build(BuildContext context) {
    final signupErrors = ref.watch(signupErrorsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(),
      // XL-16 (07_profile_setup — minimalism 1/10: "multiple overlapping
      // elements create visual noise and cheap ornamentation"): stripped to
      // hero, one hint, the field, the CTA. The avatar placeholder and the
      // inline "@usuario" hint are gone — the immutable-username caption is
      // the one line of guidance the screen needs.
      // §7.3: scroll-safe body (the OTP pattern, U-07) — the fixed Column
      // overflows at ≥1.5× text scale on small phones; pins the CTA when
      // the content fits and scrolls when it doesn't. Never clip.
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
                    // §3.2 auth big header — monochrome VDisplayText.
                    VDisplayText(text: l10n.authCompleteProfile),
                    const SizedBox(height: 40),
                    VInput(
                      controller: _usernameController,
                      label: l10n.commonUsername,
                      // §5.2: the flow's OWN errors ride the username field
                      // as `errorText` (glowPink — never raw red on black).
                      // Multiple messages render as one block.
                      errorText: signupErrors.displayText,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.authUsernameImmutable,
                      // §2.4/§3.3: informational caption = bodySmall in
                      // mutedStrong (7.37:1 AA — was grey[500]).
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mutedStrong,
                      ),
                    ),
                    const Spacer(),
                    // §5.1 primary CTA — emphasized white fill, black text.
                    VButton.emphasized(
                      label: l10n.commonSave,
                      loading: _saving ||
                          ref.watch(authStateProvider).isLoading,
                      onPressed: _save,
                    ),
                    const SizedBox(height: 32),
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
