import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/auth/logic/age_policy.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

class AgeGateScreen extends ConsumerStatefulWidget {
  final String? email;
  const AgeGateScreen({super.key, this.email});

  @override
  ConsumerState<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends ConsumerState<AgeGateScreen> {
  DateTime? _selectedDate;
  bool _underage = false;

  String get _email =>
      widget.email ??
      ref.read(authServiceProvider).auth.currentUser?.email ??
      '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final family = AppGradients.familyOf('age_gate');
    return Scaffold(
      appBar: AppBar(),
      // §7.3: scroll-safe body (the OTP pattern, U-07) — the fixed Column
      // overflows at ≥1.5× text scale on small phones; pins the CTA when
      // the content fits and scrolls when it doesn't. Never clip.
      // XL-16 (05_age_gate — "a visual cacophony… strip away the ornament"):
      // one hero, one hint line, the picker, the CTA — and nothing else.
      // XL-19 (05_age_gate — "visual clutter / inconsistent effects"): the
      // form keeps the quiet surface — no extra effect behind it.
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // §3.2 auth big header — LUXE v2: violet-family
                    // VDisplayText (gradient fill + slowly pulsing glow).
                    VDisplayText(
                      text: l10n.authBirthDateQuestion,
                      gradient: family,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.authMinAgeMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    // XL-19: hint → picker at 32 (tighter rhythm than 40) —
                    // hero, one-line hint, picker, CTA.
                    const SizedBox(height: 32),
                    TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().subtract(
                            const Duration(days: 365 * 18),
                          ),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                            _underage = !isAdult(_selectedDate);
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _selectedDate != null
                            ? formatDob(_selectedDate!)
                            : l10n.authSelectDate,
                      ),
                    ),
                    if (_underage)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          l10n.authUnderageMessage,
                          // §5.2: glowPink — never raw red on black.
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    const Spacer(),
                    // §5.1 brand moment: the primary CTA is emphasized
                    // with the violet-family gradient fill + black text.
                    VButton.emphasized(
                      label: l10n.commonContinue,
                      gradient: family,
                      onPressed: isAdult(_selectedDate)
                          ? () => context.push(
                              RoutePaths.privacyTerms,
                              extra: PrivacyTermsExtra(
                                email: _email,
                                dateOfBirth: _selectedDate!.toIso8601String(),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
