import 'package:flutter/material.dart';
import 'package:samay/core/config/legal_links.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Static privacy/terms info — wires the settings Privacidad row.
///
/// The signup-funnel [PrivacyTermsScreen] cannot render standalone (it is a
/// consent gate that carries email/dateOfBirth extras and pushes the profile
/// setup step), so the settings row lands here: the same l10n copy the funnel
/// uses, presented as readable sections instead of consent checkboxes. Each
/// section also links to the full public document served from
/// `samay.qallariy.lat` (the URL registered with the stores).
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
              url: LegalLinks.privacyUrl,
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              icon: Icons.rule_outlined,
              title: l10n.authServiceTerms,
              subtitle: l10n.authServiceTermsSubtitle,
              body: l10n.settingsServiceTermsBody,
              url: LegalLinks.termsUrl,
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
  final String url;

  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.palette.mutedForeground),
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
            ).textTheme.bodyMedium?.copyWith(color: context.palette.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.legalOpenOnline),
              onPressed: () async {
                final ok = await LegalLinks.open(url);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.errorsServer)),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
