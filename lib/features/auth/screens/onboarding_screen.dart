import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/legal_links.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/features/auth/logic/consent_versions.dart'
    show ConsentVersions;
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

/// The onboarding gate — ONE tap to play.
///
/// There is no checkbox: the affirmative action ("aceptar y jugar") IS the
/// acceptance, which is what both stores require (an unchecked box plus a
/// disabled button is the pattern that adds friction without adding consent).
/// The two documents are inline, tappable links right under the button, so the
/// user can read them before tapping and the copy is explicit about what
/// tapping means.
///
/// Tapping calls `startGuestOnboarding`, which creates the anonymous session
/// and records the acceptance + guest profile server-side in one atomic RPC.
/// Apple/Google sign-in stays optional (menu → iniciar sesión).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(authStateProvider.notifier)
          .startGuestOnboarding(termsVersion: ConsentVersions.terms);
      if (!mounted) return;
      context.go(RoutePaths.gamesHome);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final message = e.toAppError().message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? l10n.commonError : message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final linkStyle = TextStyle(
      color: context.palette.foreground,
      decoration: TextDecoration.underline,
      decorationColor: context.palette.mutedForeground,
      height: 1.5,
    );
    final bodyStyle = AppTypography.bodySmall.copyWith(
      color: context.palette.mutedForeground,
      height: 1.5,
    );

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DECLINE affordance: the X. Declining records nothing, so this
              // screen returns on the next boot until consent is given.
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: _busy ? null : _decline,
                  icon: const Icon(Icons.close_rounded),
                  color: context.palette.mutedForeground,
                  tooltip: l10n.onboardingDecline,
                ),
              ),
              const Spacer(),
              const VDisplayText(text: 'samay'),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.onboardingTagline,
                style: AppTypography.bodyLarge.copyWith(
                  color: context.palette.mutedForeground,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // The single affirmative action = the consent.
              VButton.emphasized(
                label: l10n.onboardingStart,
                loading: _busy,
                onPressed: _start,
              ),
              const SizedBox(height: AppSpacing.md),
              // Explicit, readable consent with the documents one tap away.
              Text.rich(
                TextSpan(
                  style: bodyStyle,
                  children: [
                    TextSpan(text: '${l10n.onboardingConsent} '),
                    _legalLink(
                      l10n.onboardingAcceptTerms,
                      LegalLinks.termsUrl,
                      linkStyle,
                    ),
                    TextSpan(text: ' ${l10n.onboardingAcceptAnd} '),
                    _legalLink(
                      l10n.onboardingAcceptPrivacy,
                      LegalLinks.privacyUrl,
                      linkStyle,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _decline() => context.go(RoutePaths.onboardingDeclined);

  TextSpan _legalLink(String label, String url, TextStyle style) {
    return TextSpan(
      text: label,
      style: style,
      recognizer: TapGestureRecognizer()..onTap = () => LegalLinks.open(url),
      semanticsLabel: label,
    );
  }
}
