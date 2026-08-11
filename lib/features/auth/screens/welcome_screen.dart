import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/disco_widgets.dart';
import 'package:samay/shared/widgets/v_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              Text(
                l10n.welcomeVive,
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeTagline,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              // §5.1 brand moment: the primary CTA is the filled glowAccent
              // (pink fill + black text, 6.00:1); the disco divider separates
              // the two auth entries (U-06 widget).
              VButton.glowAccent(
                label: l10n.commonCreateAccount,
                filled: true,
                onPressed: () => context.push(RoutePaths.signup),
              ),
              const SizedBox(height: 12),
              const VDiscoDivider(),
              const SizedBox(height: 12),
              VButton(
                label: l10n.commonSignIn,
                onPressed: () => context.push(RoutePaths.login),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
