import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/services/supabase_service.dart';
import 'package:vive_app/shared/widgets/v_button.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar edad')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              '¿Cuál es tu fecha de nacimiento?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Debes tener al menos 18 años para usar Vive!',
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
                    ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                    : 'Seleccionar fecha',
              ),
            ),
            if (_underage)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Debes tener 18 años para usar Vive!',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            const Spacer(),
            VButton.emphasized(
              label: 'Continuar',
              onPressed: _selectedDate != null && _isAdult
                  ? () => context.push('/auth/privacy-terms', extra: {
                        'email': _email,
                        'dateOfBirth': _selectedDate!.toIso8601String(),
                      })
                  : null,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
