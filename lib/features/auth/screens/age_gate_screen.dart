import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/auth/logic/age_policy.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

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
    return Scaffold(
      body: VHeaderBar(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      // §3.2 auth big header — monochrome VDisplayText.
                      VDisplayText(text: l10n.authBirthDateQuestion),
                      const SizedBox(height: 8),
                      Text(
                        l10n.authMinAgeMessage,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      // Hint → picker at 32 (tighter rhythm than 40) —
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
                      // §5.1 primary CTA — emphasized white fill, black text.
                      VButton.emphasized(
                        label: l10n.commonContinue,
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
      ),
    );
  }
}
