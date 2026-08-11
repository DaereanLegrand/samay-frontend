import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_breathing_glow.dart';
import 'package:samay/shared/widgets/v_button.dart';

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
      appBar: AppBar(title: Text(l10n.authTermsTitle)),
      // §7.3: scroll-safe body — the long checkbox subtitles + displayMedium
      // header overflow the fixed Column at ≥1.5× text scale on small
      // phones. `SliverFillRemaining` pins the CTA when the content fits
      // and scrolls when it doesn't. The checkbox rows are custom
      // (checkbox + texts) instead of `CheckboxListTile` because a
      // ListTile's *intrinsic* height is smaller than its laid-out height
      // when the subtitle wraps — that under-measure breaks both this
      // sliver pattern and the OTP `IntrinsicHeight + Spacer` variant
      // (U-19 finding; plain Texts measure exactly).
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  // §3.2 auth big header — Playfair Display italic 40 with
                  // the glow, breathed by U-18's §6.2 disco-glow animation
                  // (auth headers are in §6.2's breathing scope; this was
                  // U-18's flagged gap — closed by U-23; reduced-motion →
                  // static full-α glow).
                  VBreathingGlow(
                    text: l10n.authAcceptTermsToContinue,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 16),
                  _ConsentRow(
                    title: l10n.authPrivacyPolicy,
                    subtitle: l10n.authPrivacyPolicySubtitle,
                    value: _privacyAccepted,
                    onChanged: (v) => setState(() => _privacyAccepted = v),
                  ),
                  _ConsentRow(
                    title: l10n.authServiceTerms,
                    subtitle: l10n.authServiceTermsSubtitle,
                    value: _termsAccepted,
                    onChanged: (v) => setState(() => _termsAccepted = v),
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
          ),
        ],
      ),
    );
  }
}

/// One consent row (the U-19 replacement for `CheckboxListTile`): the
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

