import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

class PrivacyTermsScreen extends StatefulWidget {
  final String email;
  final String dateOfBirth;
  const PrivacyTermsScreen({
    super.key,
    required this.email,
    required this.dateOfBirth,
  });

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
      body: VHeaderBar(
        child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  // §3.2 auth big header — monochrome VDisplayText
                  // (verbatim copy, flat white glyphs).
                  VDisplayText(text: l10n.authAcceptTermsToContinue),
                  const SizedBox(height: 24),
                  _ConsentRow(
                    title: l10n.authPrivacyPolicy,
                    subtitle: l10n.authPrivacyPolicySubtitle,
                    value: _privacyAccepted,
                    onChanged: (v) => setState(() => _privacyAccepted = v),
                  ),
                  const SizedBox(height: 20),
                  _ConsentRow(
                    title: l10n.authServiceTerms,
                    subtitle: l10n.authServiceTermsSubtitle,
                    value: _termsAccepted,
                    onChanged: (v) => setState(() => _termsAccepted = v),
                  ),
                  const Spacer(),
                  // §5.1 primary CTA — emphasized white fill, black text.
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
          ),
        ],
      ),
      ),
    );
  }
}

/// One consent row (the replacement for `CheckboxListTile`): the
/// checkbox + title/subtitle column are plain widgets whose intrinsic
/// height is exact, so the pinned/scroll body above never under-measures.
/// Renders the same theme roles as the ListTile it replaces (titleMedium
/// title, bodyMedium subtitle); tapping the whole row toggles it.
class _ConsentRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConsentRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
