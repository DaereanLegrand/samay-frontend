import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
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
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = InputSanitizer.sanitizeUsername(_usernameController.text);
    if (username.isEmpty) return;

    setState(() => _saving = true);
    await ref
        .read(authStateProvider.notifier)
        .createProfile(username, dateOfBirth: widget.dateOfBirth);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ref.read(authStateProvider).hasError) {
      context.go(RoutePaths.mainFeed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final l10n = AppLocalizations.of(context);
    final family = AppGradients.familyOf('profile_setup');

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
                    // §3.2 auth big header — LUXE v2: violet-family
                    // VDisplayText (gradient fill + slowly pulsing glow).
                    VDisplayText(
                      text: l10n.authCompleteProfile,
                      gradient: family,
                    ),
                    const SizedBox(height: 40),
                    VInput(
                      controller: _usernameController,
                      label: l10n.commonUsername,
                      // §5.2: the server error rides the username field as
                      // `errorText` (glowPink — never raw red on black).
                      errorText: auth.hasError ? auth.errorMessage : null,
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
                    // §5.1 brand moment: the primary CTA is emphasized
                    // with the violet-family gradient fill + black text.
                    VButton.emphasized(
                      label: l10n.commonSave,
                      loading: _saving || auth.isLoading,
                      gradient: family,
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
