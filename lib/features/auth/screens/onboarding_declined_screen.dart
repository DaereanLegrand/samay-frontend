import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

/// The dead-end a visitor reaches by declining onboarding (the X).
///
/// It exists so declining is *possible* without becoming a way into the app.
/// No session is created and no acceptance is recorded, so the router keeps
/// this visitor out of every game route; on the next boot onboarding shows
/// again. The only way forward is the consent screen, and the copy says so
/// plainly rather than pretending the decline succeeded.
class OnboardingDeclinedScreen extends ConsumerWidget {
  const OnboardingDeclinedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bodyStyle = AppTypography.bodyLarge.copyWith(
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
              const Spacer(),
              const VDisplayText(text: 'samay'),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.onboardingDeclinedTitle, style: bodyStyle),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.onboardingDeclinedBody, style: bodyStyle),
              const SizedBox(height: AppSpacing.xl),
              VButton.emphasized(
                label: l10n.onboardingDeclinedBack,
                onPressed: () => context.go(RoutePaths.onboarding),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
