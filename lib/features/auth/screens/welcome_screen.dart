import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Spacer(),
                      // Monochrome: the welcome wordmark is the
                      // flagship display element — verbatim copy, flat white
                      // Playfair glyphs, no gradient/glow.
                      VDisplayText(text: l10n.welcomeSamay, size: 64),
                      const SizedBox(height: 8),
                      Text(
                        l10n.welcomeTagline,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 48),
                      // §5.1 primary CTA — the black button voice, matching
                      // the login CTA.
                      VButton.dark(
                        label: l10n.commonCreateAccount,
                        onPressed: () => context.push(RoutePaths.signup),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push(RoutePaths.login),
                        child: Text(
                          l10n.commonSignIn,
                          style: const TextStyle(
                            color: AppColors.mutedStrong,
                          ),
                        ),
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
