import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/supabase_service.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';

class AgeGateScreen extends StatefulWidget {
  final String? email;
  const AgeGateScreen({super.key, this.email});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  DateTime? _selectedDate;
  bool _underage = false;

  String get _email => widget.email ?? SupabaseService.instance.auth.currentUser?.email ?? '';

  bool get _isAdult {
    if (_selectedDate == null) return false;
    final cutoff = DateTime.now().subtract(const Duration(days: 365 * 18));
    return _selectedDate!.isBefore(cutoff) || _selectedDate!.isAtSameMomentAs(cutoff);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authVerifyAge)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              l10n.authBirthDateQuestion,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.authMinAgeMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                    _underage = !_isAdult;
                  });
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _selectedDate != null
                    ? l10n.authSelectedDate(
                        _selectedDate!.day,
                        _selectedDate!.month,
                        _selectedDate!.year,
                      )
                    : l10n.authSelectDate,
              ),
            ),
            if (_underage)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  l10n.authUnderageMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const Spacer(),
            VButton.emphasized(
              label: l10n.commonContinue,
              onPressed: _selectedDate != null && _isAdult
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
    );
  }
}
