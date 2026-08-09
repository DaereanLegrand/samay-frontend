import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';

class PrivacyTermsScreen extends StatefulWidget {
  final String email;
  final String dateOfBirth;
  const PrivacyTermsScreen({super.key, required this.email, required this.dateOfBirth});

  @override
  State<PrivacyTermsScreen> createState() => _PrivacyTermsScreenState();
}

class _PrivacyTermsScreenState extends State<PrivacyTermsScreen> {
  bool _privacyAccepted = false;
  bool _termsAccepted = false;

  bool get _allAccepted => _privacyAccepted && _termsAccepted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authTermsTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              l10n.authAcceptTermsToContinue,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: Text(l10n.authPrivacyPolicy),
              subtitle: Text(l10n.authPrivacyPolicySubtitle),
              value: _privacyAccepted,
              onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: Text(l10n.authServiceTerms),
              subtitle: Text(l10n.authServiceTermsSubtitle),
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Spacer(),
            VButton.emphasized(
              label: l10n.commonCreateAccount,
              onPressed: _allAccepted
                  ? () => context.push(
                        RoutePaths.profileSetup,
                        extra: ProfileSetupExtra(
                          email: widget.email,
                          dateOfBirth: widget.dateOfBirth,
                        ),
                      )
                  : null,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
