import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final family = AppGradients.familyOf('welcome');
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
                      // LUXE §6.2: the welcome wordmark is the flagship
                      // display element — VDisplayText keeps the breathing
                      // glow feel (violet gradient fill + slow halo pulse +
                      // once-only shimmer sweep; reduced-motion → static
                      // mid-α halo).
                      VDisplayText(
                        text: l10n.welcomeVive,
                        size: 64,
                        gradient: family,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.welcomeTagline,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 48),
                      // §5.1 brand moment: the primary CTA is the filled
                      // glowAccent (violet-family gradient fill + black
                      // text, 6.00:1). XL-19 (01_welcome — "sheer volume
                      // of text / visual clutter"): the VDiscoDivider is
                      // gone and the login entry is a plain muted text
                      // link (the login-screen secondary pattern) — the
                      // wordmark + tagline + ONE primary CTA is the whole
                      // screen.
                      VButton.glowAccent(
                        label: l10n.commonCreateAccount,
                        filled: true,
                        gradient: family,
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
