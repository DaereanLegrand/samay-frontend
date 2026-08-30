import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Static privacy/terms info (R2 — wires the settings Privacidad row).
///
/// The signup-funnel [PrivacyTermsScreen] cannot render standalone (it is a
/// consent gate that carries email/dateOfBirth extras and pushes the profile
/// setup step), so the settings row lands here: the same l10n copy the funnel
/// uses, presented as readable sections instead of consent checkboxes.
class PrivacyInfoScreen extends StatelessWidget {
  const PrivacyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: VHeaderBar(
        title: l10n.profilePrivacy,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _Section(
              icon: Icons.privacy_tip_outlined,
              title: l10n.authPrivacyPolicy,
              subtitle: l10n.authPrivacyPolicySubtitle,
              body: l10n.settingsPrivacyPolicyBody,
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              icon: Icons.rule_outlined,
              title: l10n.authServiceTerms,
              subtitle: l10n.authServiceTermsSubtitle,
              body: l10n.settingsServiceTermsBody,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String body;

  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.mutedStrong),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedStrong),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
