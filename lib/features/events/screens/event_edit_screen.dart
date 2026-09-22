import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/event.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_input.dart';

/// Event editor (EDET — hosts only, pre-live). Core details are always
/// editable until the event goes live; the preshard pool/cap/remainder are
/// editable until `starts_at` (MVP spec §6.3 edit flow). Post-live the screen
/// only supports status changes from the detail screen.
class EventEditScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventEditScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _poolController = TextEditingController();
  final _capController = TextEditingController();

  late DateTime _startsAt;
  late DateTime _endsAt;
  String _remainderAction = 'return';
  bool _initialized = false;
  bool _saving = false;
  String? _validationError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _poolController.dispose();
    _capController.dispose();
    super.dispose();
  }

  void _seedFrom(Event event) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = event.name;
    _descriptionController.text = event.description ?? '';
    _locationController.text = event.locationName ?? '';
    final pool = event.preshardsPool;
    _poolController.text = pool > 0 ? '$pool' : '';
    final cap = event.preshardsCapPerUser;
    _capController.text = cap != null ? '$cap' : '';
    _remainderAction = event.preshardsRemainderAction ?? 'return';
    _startsAt = event.startsAt;
    _endsAt = event.endsAt;
  }

  bool get _poolEditable {
    return _initialized && DateTime.now().isBefore(_startsAt);
  }

  Future<void> _pickDateTime(
    DateTime initial,
    ValueChanged<DateTime> onPicked, {
    required DateTime firstTime,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstTime,
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = l10n.eventsErrorNameRequired);
      return;
    }
    if (!_endsAt.isAfter(_startsAt)) {
      setState(() => _validationError = l10n.eventsErrorTimeRange);
      return;
    }
    final pool = int.tryParse(_poolController.text.trim());
    if (pool != null && pool < 0) {
      setState(() => _validationError = l10n.eventInvalidPoolAmount);
      return;
    }

    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final patch = <String, dynamic>{
      'name': name,
      'description': description.isEmpty ? null : description,
      'location_name': location.isEmpty ? null : location,
      'starts_at': _startsAt.toIso8601String(),
      'ends_at': _endsAt.toIso8601String(),
    };
    if (_poolEditable) {
      final cap = int.tryParse(_capController.text.trim());
      patch['preshards_pool'] = pool ?? 0;
      patch['preshards_cap_per_user'] = cap;
      patch['preshards_remainder_action'] = _remainderAction;
    }

    setState(() {
      _saving = true;
      _validationError = null;
    });
    try {
      await ref.read(eventDetailProvider(widget.eventId).notifier).patch(patch);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.eventEditUpdatedSnack)));
      Navigator.of(context).pop();
    } catch (e, _) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(eventDetailProvider(widget.eventId));
    if (detailAsync.valueOrNull != null) _seedFrom(detailAsync.valueOrNull!);

    return Scaffold(
      body: VHeaderBar(
        title: l10n.eventEditTitle,
        child: detailAsync.when(
          loading: () => const VLoadingView(),
          error: (e, _) => ErrorView(
            message: e.toAppError().message,
            onRetry: () => ref.invalidate(eventDetailProvider(widget.eventId)),
          ),
          data: (event) {
            final type = event.type;
            return _buildForm(l10n, type);
          },
        ),
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n, String type) {
    final locale = Localizations.localeOf(context).languageCode;
    final showPool = type != 'casual';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_validationError != null) ...[
            Text(
              _validationError!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.glowPink),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          VInput(label: l10n.eventsNameLabel, controller: _nameController),
          const SizedBox(height: AppSpacing.md),
          VInput(
            label: l10n.eventsDescriptionOptional,
            controller: _descriptionController,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          VInput(
            label: l10n.eventsLocationLabel,
            controller: _locationController,
          ),
          const SizedBox(height: AppSpacing.lg),
          _DateTimeButton(
            label: l10n.eventsStartsLabel,
            value: _startsAt,
            locale: locale,
            onTap: () => _pickDateTime(
              _startsAt,
              (v) => setState(() => _startsAt = v),
              firstTime: DateTime(2000),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DateTimeButton(
            label: l10n.eventsEndsLabel,
            value: _endsAt,
            locale: locale,
            onTap: () => _pickDateTime(
              _endsAt,
              (v) => setState(() => _endsAt = v),
              firstTime: _startsAt,
            ),
          ),
          if (showPool) ...[
            const SizedBox(height: AppSpacing.xl),
            // The pool editor rides neutral white-only
            // glass.
            VCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.eventsPreshardsPoolLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  if (!_poolEditable) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.eventPoolLockedNotice,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  VInput(
                    label: l10n.eventsPreshardsPoolLabel,
                    controller: _poolController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  VInput(
                    label: l10n.eventsPreshardsCapLabel,
                    controller: _capController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _remainderAction,
                    dropdownColor: AppColors.surfaceAlt,
                    decoration: InputDecoration(
                      labelText: l10n.eventsRemainderLabel,
                      labelStyle: const TextStyle(color: AppColors.mutedStrong),
                      // Pinned: dropdown row, not a text input (theme
                      // default `never`).
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'return',
                        child: Text(l10n.eventsRemainderReturn),
                      ),
                      DropdownMenuItem(
                        value: 'redistribute',
                        child: Text(l10n.eventsRemainderRedistribute),
                      ),
                    ],
                    onChanged: _poolEditable
                        ? (v) =>
                              setState(() => _remainderAction = v ?? 'return')
                        : null,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          VButton.dark(
            label: l10n.commonSave,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final String label;
  final DateTime value;
  final String locale;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: AppSpacing.md),
            Text(
              DateFormat('EEE d MMM, HH:mm', locale).format(value.toLocal()),
              style: const TextStyle(color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
